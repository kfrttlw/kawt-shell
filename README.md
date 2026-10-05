# kawt-shell

```
  ____________
 | >_         |    kawt // a Hyprland rice that looks like an old terminal
 |            |    ThinkPads, green phosphor, Mr. Robot, [brackets] everywhere
 |____________|
/ :::::●:::::: \
\______________/
```

A [Quickshell](https://quickshell.org) desktop shell for Hyprland, plus matching
configs, all in one monospace, square-cornered, text-first style.

## What's inside

**bar**: `[~] [$] [1] 2 3 · [wifi] [↓ ▁▃▅▇] [> ▂▅▃] [12:34] · [tray 3 v] [us] [vol 40%] [br 60%] [bat 72%] [log 2] [>_]`

| | |
|---|---|
| `[~]` profile | your `~/.face` as ascii art, live cpu/mem graphs, today's tasks, a `top` with kill, todo (folders, importance, icons, notes inside, reminders), notes in folders with search, settings, power buttons |
| `[$]` dock | pinned apps |
| launcher | rofi-like, with modes: apps · `!` run · `>` in terminal · `=` calculator · `?` ask the ai · `:` clipboard history |
| `[>_]` ai | chat with a local [ollama](https://ollama.com) model (nothing leaves the machine) or any OpenAI-compatible api; saved chats with times and speed, system prompt; a wide mode with a files column that can only attach text files from one folder you pick; personas, clipboard actions (explain / translate / fix / summary), markdown answers with framed code + copy, retry / edit / save to notes, compare two models, ctrl +/- text size, left or right side; context grows by itself for long messages and looping answers get stopped; installed models with sizes, pull / delete, what sits in ram and an unload button; limits for context, cpu threads, gpu and keep-alive so it doesn't eat the machine |
| `[log]` | notification daemon, `dmesg`-style history, do-not-disturb |
| style | wallpapers (arrow keys to pick) + themes: `mono` `amber` `phosphor` `thinkpad` and `wallpaper` (colors taken from the wallpaper), each dark (CRT) or light (paper) |
| theme export | switching themes recolors open terminals live and rewrites colors for kitty, Hyprland borders, foot, alacritty and shell scripts |
| lock | a terminal-style lock screen (`kawt lockTest` tries it safely: it unlocks itself after 30 s) |
| osd | volume / brightness pop up when they change; plugging the charger in or out shows the battery; low battery notifies at 20 / 10 / 5% |
| bluetooth | `[bt airpods 80%]`: on/off, scan, pair, connect, forget, headphone battery |
| mic | `[mic ● discord]` appears while an app records you (red), click to mute |
| recording | `[● rec 0:42]` in the bar; area or whole screen, optional mic audio |
| screenshots | area / window / screen, saved and copied to the clipboard |
| prompt | an oh-my-zsh theme: `┌[user@host]─[~/dir]─[branch*]` / `└$`, greeting with your motto; uses the 16 terminal colors, so it follows the theme |
| also | wifi, volume per app, brightness, battery + power profiles, mpris player, calendar, tray, keyboard layout |

## Layout

```
quickshell/kawt-shell/   the shell        -> ~/.config/quickshell/kawt-shell
  hypr/kawt.lua          Hyprland binds   (loaded from hyprland.lua)
kitty/kitty.conf         terminal         -> ~/.config/kitty/kitty.conf
zsh/kawt.zsh-theme       prompt           -> oh-my-zsh custom themes (if oh-my-zsh is installed)
install.sh
```

## Install

```sh
git clone https://github.com/kfrttlw/kawt-shell ~/kawt
cd ~/kawt
./install.sh --dry-run   # see what it would do
./install.sh
```

The installer checks everything first (packages, font, icons, your Hyprland config) and
changes nothing if something is missing; it prints one `pacman` line with what to install.
Then it symlinks the configs, so `git pull` updates everything in place. Configs that are
already there are replaced but kept in `~/.local/state/kawt/backups/<date>/`, and your
`hyprland.lua` gets one line that loads `hypr/kawt.lua` (wrapped in `pcall`, so a broken
kawt can never take Hyprland down). Running it again is safe.

```sh
./install.sh --uninstall   # remove the links and the line, put your old configs back
./install.sh --help
```

Keep the clone somewhere permanent (like `~/kawt`): the configs point into it.
Don't clone it into `~/.config/quickshell/kawt-shell` itself; the installer refuses that.

**Needs:** `quickshell` `hyprland` `kitty` `ttf-jetbrains-mono-nerd` `papirus-icon-theme` `libnotify` `grim` `slurp` `wl-clipboard` `cliphist` `wf-recorder`, `brightnessctl` on laptops
**Optional:** `oh-my-zsh` (prompt), `fortune-mod` (fortune motto), `ollama` (ai panel), `awww`/`swww` (wallpapers), `power-profiles-daemon`

## Keys

| | |
|---|---|
| `super + space` | launcher |
| `super + r` | run a command |
| `super + shift + v` | clipboard history |
| `super + d` | pinned apps |
| `super + a` | ai panel |
| `super + w` / `super + shift + w` | wallpaper & themes / dark ↔ light |
| `super + n` / `super + shift + n` | notifications / do not disturb |
| `super + i` | profile, full screen (`[~]` opens the small one) |
| `super + l` | lock screen |
| `super + /` | all keys (read from `hypr/kawt.lua`) |
| `super + escape` | power menu: shutdown / reboot / suspend / logout / lock, with a 5 s countdown |
| `print` / `super + shift + s` | screenshot of an area (`shift + print` screen, `alt + print` window) |
| `super + shift + r` / `super + alt + r` | record an area / the screen (same key again: stop) |

In the launcher: `↑↓` select, `ctrl+s` pin, `ctrl+tab` switch mode.
Everything is also reachable over IPC: `qs -c kawt-shell ipc call kawt toggle <panel>`.

## Environment

Nothing has to be set. The icon theme is picked in `shell.qml`
(`//@ pragma IconTheme Papirus-Dark`); to use another one, set `QS_ICON_THEME`
for the `qs` process. No API keys are involved anywhere: the ai panel talks to a
local ollama.

## Where things live

- `~/.local/state/kawt/settings.json`: theme, wallpaper, ai model...
- `~/.local/state/kawt/theme/`: generated color files, rewritten on every theme switch
- `quickshell/kawt-shell/config/Colors.qml`: the themes themselves; edit colors here

## Hacking

```sh
python3 tools/check.py   # catches the mistakes that stop the shell from loading
./doctor.sh              # where the "theme -> files -> apps" chain breaks on this machine
./colortest.sh           # which kind of terminal color something uses
```
