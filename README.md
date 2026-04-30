# TodoMD

TodoMD is a minimal macOS menu bar app for quickly editing a Markdown note. I use it for my Todo list, which is a file in Obsidian. When quickly wanting to add a note or check my todo list, I don't want to be opening Obsidian though, which is where TodoMD comes in. 

See it as a Todo app that saves to a file and syncs with your other devices (depending on where you store that file). Use Settings from the popup or menu bar item to choose the Markdown file and configure the shortcut.

**Install by downloading the Release dmg at the right.**

![Usage Preview](https://github.com/ffabbr/TodoMD/blob/main/Resources/screen-recording.gif)

![Icon Banner](https://github.com/ffabbr/TodoMD/blob/main/Resources/Name-Banner-1x.png)

## Features

- Compact floating editor popup
- Global shortcut support
- Markdown file picker in Settings
- Popup position memory between opens
- Optional menu bar icon auto-hide after launch or reopen
- Custom macOS app icon

## Build if yourself

```sh
./build.sh
```

The build script creates `TodoMD.app` in the project folder.

```sh
open ./TodoMD.app
```
