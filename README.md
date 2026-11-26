# Read Aloud

A small Omarchy shell plugin that turns selected text into speech with `edge-tts`, then plays it with `mpv`. Long passages are split into chunks and played as soon as the first chunk is ready, while the remaining audio is still being generated.

## Features

- Select text anywhere and press `SUPER + ALT + R` to listen to it.
- Streaming playback: chunk 1 starts while chunks 2, 3, ... are still being synthesized.
- Automatic Russian/English voice selection based on Cyrillic characters.
- Bar icon with a keyboard panel: play/pause, stop, jump ±5 seconds, previous/next chunk, speed control, and download.
- Smart progress bar: tracks the current chunk during generation and the whole recording once generation is complete.
- Scrubbing by mouse or keyboard; percentage and ETA are visible while preparing audio.
- Save the combined recording as an MP3 through a native file dialog.
- English and Russian UI translations.

## Requirements

| Dependency | Purpose |
| --- | --- |
| Omarchy shell / Quickshell | Bar widget and keyboard panel |
| Hyprland / Wayland | Clipboard selection and hotkeys |
| `edge-tts` | Speech synthesis |
| `mpv` | Audio playback and IPC control |
| `ffmpeg`, `ffprobe` | Concatenating chunks and measuring duration |
| `wl-clipboard` | Reading the selected text |
| `zenity` | Save-file dialog |
| `python3`, `jq` | Runtime helpers |
| JetBrainsMono Nerd Font | Icon glyphs in the panel |

## Installation

```bash
omarchy plugin add https://github.com/toshich20/omarchy-read-aloud.git --enable --yes
omarchy pkg aur add python-edge-tts
omarchy pkg add mpv ffmpeg zenity wl-clipboard
~/.config/omarchy/plugins/toshich20.read-aloud/install.sh
```

If the widget is not visible, rescan and place it manually:

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable toshich20.read-aloud
omarchy bar move toshich20.read-aloud --section right
```

## Hotkey

Add this line to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + R", "Read selection aloud", os.getenv("HOME") .. "/.local/bin/read-selection")
```

Then reload Hyprland:

```bash
hyprctl reload
```

Pressing the shortcut again stops the current playback and closes the panel.

## Usage

1. Select text in any application.
2. Press `SUPER + ALT + R`, or right-click the bar icon.
3. Use the panel controls:

| Control | Action |
| --- | --- |
| Left click on bar icon | Open/close the player panel |
| `P`, `Space`, `Enter` | Play/pause |
| `S` | Stop |
| `R` | Read the current selection |
| `D` | Download the MP3 |
| `V` | Cycle playback speed: 1x → 1.5x → 2x |
| `Back 5s`, `Forward 5s` | Seek relative to the current position |
| `Previous`, `Next` | Switch chunks |

During generation the progress bar follows the current chunk. Once all chunks have been generated, it follows the full combined recording. The download button becomes active only after the MP3 has been assembled.

## Configuration

Open the panel and click the Russian or English voice button to cycle through available voices. Click the speed button or press `V` to cycle 1x, 1.5x and 2x. Choices are stored in `~/.config/omarchy/shell.json` under the `toshich20.read-aloud` entry and survive shell restarts. The selected speed is applied to the running `mpv` process, so it is not reset when the next chunk starts.

Default voices:

- Russian: `ru-RU-DmitryNeural`
- English: `en-US-AndrewNeural`
- Speed: `1x`

## How it works

Text is split into chunks of up to 450 characters. Each chunk is synthesized with `edge-tts`, measured with `ffprobe`, and appended to the running `mpv` playlist through its Unix socket. After the last chunk is generated, `ffmpeg` concatenates the pieces into `final.mp3` so it can be saved. Runtime state lives in `$XDG_RUNTIME_DIR/read-aloud/state.json`.

## Troubleshooting

Check the current player state:

```bash
~/.config/omarchy/plugins/toshich20.read-aloud/bin/read-aloud-ctl status
```

If the bar icon does not appear after an update, restart the shell:

```bash
omarchy restart shell
```

If `edge-tts` reports `NoAudioReceived`, the service is temporarily rejecting a request; the plugin retries failed chunks with short backoff.

To verify synthesis directly:

```bash
edge-tts --voice en-US-AndrewNeural --text "Test" --write-media /tmp/read-aloud-test.mp3
```

## Author

toshich20
