#if canImport(SwiftUI) && os(macOS)
import SwiftUI
import AppKit
import NotebookCore

@main
struct NotebookDesktopApp: App {
    @StateObject private var model = NotebookViewModel()

    var body: some Scene {
        WindowGroup {
            NotebookRootView()
                .environmentObject(model)
                .frame(minWidth: 1100, minHeight: 700)
        }
    }
}

@MainActor
final class NotebookViewModel: ObservableObject {
    @Published var nodes: [NotebookNode] = []
    @Published var selectedID: UUID?
    @Published var selectedNotebook: NotebookDocument?
    @Published var settings: NotebookSettings = .init()
    @Published var terminalOutput = ""
    @Published var aiSummary = ""

    private let engine = NotebookEngine()
    private let debouncer = AutosaveDebouncer()
    private let aiService: AppleAIService = FallbackAppleAIService()

    init() {
        Task { await reload() }
    }

    func reload() async {
        settings = await engine.currentSettings()
        nodes = await engine.notebookTree()
        if selectedID == nil {
            selectedID = nodes.first?.id
        }
        await loadSelection()
    }

    func loadSelection() async {
        guard let selectedID else {
            selectedNotebook = nil
            return
        }
        selectedNotebook = await engine.notebook(id: selectedID)
    }

    func createChildNotebook() {
        Task {
            let created = await engine.addNotebook(title: "New Notebook", color: .green, parentID: selectedID)
            await persistChanges(select: created.id)
        }
    }

    func updateTitle(_ title: String) {
        updateSelected { $0.title = title }
    }

    func setMode(_ mode: EditorMode) {
        updateSelected { $0.mode = mode }
    }

    func setRichText(rtfData: Data) {
        updateSelected {
            $0.rtfData = rtfData
            $0.mode = .richText
        }
    }

    func setMarkdown(_ text: String) {
        updateSelected {
            $0.markdownText = text
            $0.mode = .markdown
        }
    }

    func insertAttachment(path: String) {
        updateSelected {
            $0.attachments.append(path)
            if $0.mode == .markdown {
                $0.markdownText += "\n[Attachment](\(path))\n"
            }
        }
    }

    func insertTableTemplate() {
        updateSelected {
            $0.markdownText += "\n| Column A | Column B |\n|---|---|\n| Value | Value |\n"
            $0.mode = .markdown
        }
    }

    func updateSelected(_ mutate: (inout NotebookDocument) -> Void) {
        guard var notebook = selectedNotebook else { return }
        mutate(&notebook)
        selectedNotebook = notebook
        Task {
            await engine.updateNotebook(notebook)
            scheduleAutosave()
        }
    }

    func toggleSetting(_ keyPath: WritableKeyPath<NotebookSettings, Bool>) {
        settings[keyPath: keyPath].toggle()
        Task {
            await engine.updateSettings(settings)
            await persistChanges(select: selectedID)
        }
    }

    func moveToTrashSelected() {
        guard let selectedID else { return }
        Task {
            await engine.softDeleteNotebook(id: selectedID)
            await persistChanges(select: nil)
        }
    }

    func runTrashPurge() {
        Task {
            await engine.purgeExpiredTrash()
            await persistChanges(select: selectedID)
        }
    }

    func runTerminal(command: String) {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/zsh")
        process.arguments = ["-lc", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            terminalOutput = String(decoding: data, as: UTF8.self)
        } catch {
            terminalOutput = "Terminal error: \(error.localizedDescription)"
        }
    }

    func summarizeWithAppleAI() {
        guard settings.useAppleAI, let selectedNotebook else { return }
        let content = selectedNotebook.mode == .markdown ? selectedNotebook.markdownText : String(data: selectedNotebook.rtfData, encoding: .utf8) ?? ""
        Task {
            aiSummary = (try? await aiService.summarize(text: content)) ?? "Unable to summarize."
        }
    }

    func headings(for notebookID: UUID) async -> [String] {
        await engine.tableOfContents(for: notebookID)
    }

    private func scheduleAutosave() {
        debouncer.schedule(after: settings.autosaveDebounceSeconds) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                do {
                    try await self.engine.save()
                } catch {
                    self.terminalOutput = "Autosave failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func persistChanges(select: UUID?) async {
        do {
            try await engine.save()
        } catch {
            terminalOutput = "Save failed: \(error.localizedDescription)"
        }

        nodes = await engine.notebookTree()
        selectedID = select ?? nodes.first?.id
        await loadSelection()
    }
}

struct NotebookRootView: View {
    @EnvironmentObject private var model: NotebookViewModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedID) {
                OutlineGroup(model.nodes, children: \.children) { node in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: node.notebook.color.hex))
                            .frame(width: 8, height: 18)
                        Text(node.notebook.title)
                    }
                    .tag(node.id as UUID?)
                }
            }
            .navigationTitle("Notebooks")
            .toolbar {
                Button("Add Child", action: model.createChildNotebook)
                Button("Trash", role: .destructive, action: model.moveToTrashSelected)
            }
            .onChange(of: model.selectedID) { _, _ in
                Task { await model.loadSelection() }
            }
        } detail: {
            VStack(spacing: 0) {
                if let notebook = model.selectedNotebook {
                    NotebookEditorView(notebook: notebook)
                } else {
                    ContentUnavailableView("No Notebook", systemImage: "book.closed")
                }

                if model.settings.showTerminal {
                    Divider()
                    TerminalView()
                }
            }
        }
        .preferredColorScheme(model.settings.preferredColorScheme == "dark" ? .dark : (model.settings.preferredColorScheme == "light" ? .light : nil))
        .onAppear {
            model.runTrashPurge()
        }
    }
}

struct NotebookEditorView: View {
    @EnvironmentObject private var model: NotebookViewModel
    let notebook: NotebookDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Title", text: Binding(
                    get: { notebook.title },
                    set: { model.updateTitle($0) }
                ))
                .textFieldStyle(.roundedBorder)

                Picker("Mode", selection: Binding(
                    get: { notebook.mode },
                    set: { model.setMode($0) }
                )) {
                    Text("Rich Text").tag(EditorMode.richText)
                    Text("Markdown").tag(EditorMode.markdown)
                }
                .pickerStyle(.segmented)

                Button("Insert Image/PDF") { openAttachmentPanel() }
                Button("Insert Table", action: model.insertTableTemplate)
                Button("AI Summary", action: model.summarizeWithAppleAI)
            }

            if notebook.mode == .markdown {
                TextEditor(text: Binding(
                    get: { notebook.markdownText },
                    set: { model.setMarkdown($0) }
                ))
                .font(.custom(model.settings.useNerdFontWhenAvailable ? "Hack Nerd Font" : "Menlo", size: 14))
            } else {
                RichTextEditor(initialRTF: notebook.rtfData) { model.setRichText(rtfData: $0) }
            }

            if model.settings.showTableOfContents {
                ToCSidebarView(notebookID: notebook.id)
            }

            HStack {
                Toggle("Mind Graph", isOn: Binding(
                    get: { model.settings.showMindGraph },
                    set: { _ in model.toggleSetting(\.showMindGraph) }
                ))
                Toggle("Database Config", isOn: Binding(
                    get: { model.settings.showDatabaseConfig },
                    set: { _ in model.toggleSetting(\.showDatabaseConfig) }
                ))
                Toggle("Terminal", isOn: Binding(
                    get: { model.settings.showTerminal },
                    set: { _ in model.toggleSetting(\.showTerminal) }
                ))
            }

            if model.settings.showMindGraph {
                MindGraphView(rootTitle: notebook.title)
            }

            if model.settings.showDatabaseConfig {
                DatabaseStructureView()
            }

            if !model.aiSummary.isEmpty {
                Text("Apple AI: \(model.aiSummary)")
                    .font(.callout)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
    }

    private func openAttachmentPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .pdf]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            model.insertAttachment(path: url.path)
        }
    }
}

struct ToCSidebarView: View {
    @EnvironmentObject private var model: NotebookViewModel
    let notebookID: UUID
    @State private var headings: [String] = []

    var body: some View {
        VStack(alignment: .leading) {
            Text("Table of Contents")
                .font(.headline)
            ForEach(headings, id: \.self) { heading in
                Text("• \(heading)")
                    .font(.caption)
            }
        }
        .onAppear {
            Task { headings = await model.headings(for: notebookID) }
        }
    }
}

struct MindGraphView: View {
    let rootTitle: String

    var body: some View {
        VStack(alignment: .leading) {
            Text("Mind Graph")
                .font(.headline)
            Text("Root: \(rootTitle)")
            Text("(Graph rendering placeholder)")
                .foregroundStyle(.secondary)
        }
    }
}

struct DatabaseStructureView: View {
    @State private var tableName = "notes"
    @State private var schema = "id INTEGER PRIMARY KEY, title TEXT, body TEXT"

    var body: some View {
        VStack(alignment: .leading) {
            Text("Database Structure")
                .font(.headline)
            TextField("Table Name", text: $tableName)
            TextEditor(text: $schema)
                .frame(height: 80)
        }
    }
}

struct TerminalView: View {
    @EnvironmentObject private var model: NotebookViewModel
    @State private var command = "ls"

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                TextField("Command", text: $command)
                Button("Run") {
                    model.runTerminal(command: command)
                }
            }
            .padding(.horizontal)

            ScrollView {
                Text(model.terminalOutput)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(height: 160)
        }
        .padding(.bottom, 8)
    }
}

struct RichTextEditor: NSViewRepresentable {
    var initialRTF: Data
    var onChange: (Data) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = true
        textView.importsGraphics = true
        textView.delegate = context.coordinator
        if let attributed = try? NSAttributedString(
            data: initialRTF,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            textView.textStorage?.setAttributedString(attributed)
        }

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let onChange: (Data) -> Void

        init(onChange: @escaping (Data) -> Void) {
            self.onChange = onChange
        }

        func textDidChange(_ notification: Notification) {
            guard
                let textView = notification.object as? NSTextView,
                let data = try? textView.attributedString().data(
                    from: NSRange(location: 0, length: textView.attributedString().length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                )
            else {
                return
            }
            onChange(data)
        }
    }
}

extension Color {
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}
#else
import Foundation

@main
struct NotebookDesktopApp {
    static func main() {
        print("NotebookApp macOS UI requires SwiftUI/AppKit and runs on macOS.")
    }
}
#endif
