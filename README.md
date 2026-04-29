# TodoMD

TodoMD is a minimal macOS menu bar app for quickly editing a Markdown note. I use it for my Todo list, which is a file in Obsidian. When quickly wanting to add a note or check my todo list, I don't want to be opening Obsidian though, which is where TodoMD comes in. 

See it as a Todo app that saves to a file and syncs with your other devices (depending on where you store that file).

## Features

- Compact floating editor popup
- Global shortcut support
- Markdown file picker in Settings
- Popup position memory between opens
- Optional menu bar icon auto-hide after launch or reopen
- Custom macOS app icon

## Build

```sh
./build.sh
```

The build script creates `TodoMD.app` in the project folder.

## Run

```sh
open ./TodoMD.app
```

Use Settings from the popup or menu bar item to choose the Markdown file and configure the shortcut.

## Package

```sh
./scripts/package_dmg.sh
```

The packaging script creates a styled drag-and-drop installer at `dist/TodoMD.dmg`.
