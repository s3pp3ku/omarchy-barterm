# Omarchy BarTerm

A one-line command prompt for the [Omarchy](https://omarchy.org) bar. Type a command, press Enter, and the output opens in a themed popup above the bar, readable and scrollable, without leaving what you are doing.

```
Omarchy >_    run a command…
```

The prompt is drawn in your theme's accent color, with a few spaces before where you type.

## Install

```sh
omarchy plugin add https://github.com/s3pp3ku/omarchy-barterm.git --enable --yes
```

It is a bar widget: add it to your bar, or host it in a bottom/side bar with [Extra Bars](https://github.com/s3pp3ku/omarchy-extra-bars).

## Using it

| Key | Action |
|---|---|
| Click the input, or `omarchy-shell s3pp3ku.barterm focus` | Start typing (bind the command to a key) |
| Enter | Run the command; output opens in the popup |
| Shift+Enter | Run in a real terminal window |
| Up / Down | History |
| Ctrl+C | Stop the running command |
| Esc | Close the popup and stop typing |

Also available over IPC: `toggle` and `close`. Clicking the logo re-opens the last output. `cd` carries over between commands; `clear` clears the output.

It is a command runner, not a terminal emulator. Anything that needs a real TTY opens in a **real tiled terminal** (via `xdg-terminal-exec`) automatically: commands containing `sudo`, `su`, `pkexec`, `doas`, `passwd`, and programs like `vim`, `btop`, `ssh`, `less`, `man`.

## Settings

| Setting | Default | |
|---|---|---|
| `inputWidth` | 260 | Width of the input |
| `gap` | 4 | Spaces between the logo and where you type |
| `popupWidth` / `popupHeight` | 640 / 280 | Output popup size |
| `interactiveShell` | false | Load `~/.zshrc` for each command (aliases), at the cost of running anything it prints |

## Keyboard safety

While you type, the bar takes the keyboard. It lets go as soon as you press Enter or Esc, when you click anywhere outside the bar, and after 20 seconds without a keypress, so it can never keep your keyboard.

## Requirements

Omarchy with the shell plugin system and zsh. Written for Hyprland.

## License

MIT
