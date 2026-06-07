# notebookapp

A Swift package scaffold for a macOS-first notebook desktop app with:
- hierarchical, color-tagged notebooks
- local persistence with optional iCloud container path usage
- rich text + markdown editing modes
- attachment insertion hooks (images/PDF), table insertion template
- optional ToC, mind graph pane, database structure pane, and built-in terminal pane
- autosave debounce and 90-day trash purge behavior
- dark/light/system appearance support and Apple AI summary service hook

## Build

```bash
cd /tmp/workspace/kizzlah/notebookapp
swift build
```

## Test

```bash
cd /tmp/workspace/kizzlah/notebookapp
swift test
```
