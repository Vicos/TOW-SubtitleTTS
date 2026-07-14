# SubtitleTTS – Voice-over dialogues for The Outer Worlds

## 🎭 Installation

The mod runs on **two independent TTS servers**. Choose one:

```powershell
$env:TTS_MODE = "python"  # optional, defaults to PowerShell
.\tts-server.ps1             # Server A — local PC Speech Synthesis (default)
python -m subtitle_tts       # Server B — Microsoft Edge TTS (Python)
```

A server is started with a command-line flag:

| Mode        | Script                 | Voice | Notes                                     |
|-------------|------------------------|-------|-------------------------------------------|
| `powershell`| `tts-server.ps1`       | Windows Speech Synthesizer | Default, no Python needed               |
| `python`    | `subtitle_tts.py`      | Microsoft Edge TTS          | Requires `pip install edge-tts sounddevice`, MP3 decoding via *av/ffmpeg* |

By default, (no flag) the mod uses **Server A** (`tts-server.ps1`).  
To use **Server B**, add `$env:TTS_MODE = "python"` before launching, or edit `enabled.txt`.

Both servers:
- Listen on a Windows named pipe
- Do not need firewall rules
- Are fully independent — switching requires only changing `TTS.ResetPipe()` at runtime (binding `Ctrl + END`)

---

## 🟢 Usage

The mod activates as soon as UE4SS loads. Nothing config is required:

* **Overlay** — every subtitle in dialogue → speaker `overlay` (*Denise Online*, 50 dB, pitch 0)
* **Conversation** — spoken chat dialogues → speaker `default` (*Henri Online*, rate +3, volume 100 %)

Each text line triggers audio only once (deduplicated via `lastConversationSubtitle`).

---

## ⚙️ Speaker configuration

```lua
local TTS = require("tts")
TTS.SetSpeaker("default", "Microsoft Henri Online", 3, 100, 3)   -- voice, rate (-10..+10), volume (0..100), pitch (Hz offset)
TTS.SetSpeaker("overlay", "Microsoft Denise Online", 4, 50, 0)  -- same params
```

| Speaker     | Parameters            | Range                       |
|-------------|-----------------------|----------------------------|
| `default`   | voice, rate, volume, pitch | see above                  |
| `overlay`   | same                  | see above                   |

The list of available voices can be found on [Read Aloud API](https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/voices/list?trustedclienttoken=6A5AA1D4EAFF4E9FB37E23D68491D6F4)

---

## 🛠 Troubleshooting

* **No sound** → verify the server is running (`tts-server.ps1` in a PS window or `python -m subtitle_tts`).
* **Wrong voice / weird tone** → check `TTS.SetSpeaker()` — syntax is strict, use exact Windows Speech or Edge TTS names.
* Stuck pipe  → press `Ctrl + END` to force reconnect.

---

## 📁 Mod structure

```
Scripts/              # Lua client: UE4SS ↔ named pipe
tts.lua             # TTS module — pipe management & speech commands
enabled.txt        # Marker (optional, remove if unused)

python-server/       # Standalone Python server (independent of PowerShell)
subtitle_tts.py     # Server B — Microsoft Edge TTS + MP3 decoder + playback via sounddevice
ttsplayer.py         # AudioDecoder/AudioPlayer internals (av → sounddevice stream)
pyvenv/              # Python 3.12 virtualenv with required deps: edge-tts, av, numpy, scipy, scikit-learn, joblib

# TTS servers
tts-server.ps1       # Server A — PowerShell Speech Synthesizer (default)
tts-server2.ps1      # Same, for fallback or experimental setups
```

---

## 📜 Licences et sources

* **Mod Lua** — domaine public / Creative Commons Zero
* **Server Python**  — MIT License  
    *edge_tts: edge-tts (MIT) · av: ffmpeg-python (LGPL) · sounddevice: pysoundfile (BSD)*
