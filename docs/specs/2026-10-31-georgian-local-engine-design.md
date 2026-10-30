# Georgian local engine (replaces GigaAM)

## Intent

This is a personal fork, used by someone who records Georgian meetings and is
learning how local speech models work. Today none of the three local engines
transcribe Georgian well. The goal is one local engine that does, using
[EchoesML/Georgian-NeMo](https://huggingface.co/EchoesML/Georgian-NeMo), and a
way to re-run a finished recording through it.

The fork is not released or shipped. That matters because the model card says
"research and educational purposes only".

## Decisions

- **GigaAM goes, and Georgian takes its slot.** Parakeet and Whisper large-v3-turbo stay
  unchanged. Every GigaAM surface is replaced or removed: the setup card,
  settings choices, config, analytics, model storage, the re-transcribe
  menu, the README and tests.
- **The model file is the community GGUF**
  [LeonardoDaviti/Georgian-NeMo-GGUF](https://huggingface.co/LeonardoDaviti/Georgian-NeMo-GGUF),
  published with EchoesML's permission. It is the RNN-T head, greedy decoding,
  matched against the original NeMo model on FLEURS. No Python, torch or ONNX
  is involved.
  - Repo revision: `deb86504b4e4374429442046fc598be035674e82`
  - File: `georgian-nemo-Q8_0.gguf`, 135,383,168 bytes
  - SHA-256: `5e43433e5ac6933bafcc191a5d518cfe50c66e33d205f29fcc491bfc4fe49625`
- **The runtime stays as it is.** The app already links transcribe.cpp v0.2.0 for
  GigaAM. On 2026-10-31 that exact framework (checksum-matched) opened the
  file and transcribed three FLEURS `ka_ge` dev clips (9–15 s each) correctly
  on Metal, with `language = NULL`. It reported "parakeet: using metal backend".
  No upgrade is needed.
- **Two ways to use it, both as GigaAM has today.** Georgian can be chosen in
  setup and settings as the default local engine for new recordings. The
  Recordings window's right-click menu item "Re-transcribe with GigaAM" also
  becomes "Re-transcribe with Georgian", which re-runs one recording through
  the Georgian engine with the same confirm dialog and versioning as every
  other engine. Choosing it as the default means non-Georgian meetings come
  out wrong. The user accepted that.
- **No automatic language detection.** None of the engines reports a detected
  language today, so "switch to Georgian on `ka`" is out of scope.

## Shape of the change

The GigaAM engine is already a generic transcribe.cpp GGUF engine. It
decodes a track in 20-second pieces, passes the PCM to `transcribe_run`, and
returns timed segments. Rename rather than rewrite:

| Today | Becomes |
|---|---|
| `GigaAMModelStore` (manifest above, dir `models/gigaam`) | `GeorgianModelStore`, dir `models/georgian` |
| `GigaAMEngine`, `GigaAMRuntime`, `GigaAMCPPRuntime`, engine name `gigaam` | `GeorgianEngine` …, engine name `georgian`, model id `georgian-nemo-q8_0` |
| `"gigaam"` in `Config.localEngines`, the `SettingsSchema` choices, `EngineResolver.localEngine`, `RecordingsWindow.retranscriptionEngines`, `SetupForm`, `SetupProgress`, `ModelStorage`, `AnalyticsCatalogue` | `"georgian"`, displayed as **Georgian** (setup card: "Georgian (NeMo)", described as Georgian-only, ~135 MB) |
| GigaAM tests | the same tests, retargeted to Georgian |
| GigaAM in README, PRIVACY, `docs/analytics.md` | Georgian |

The chunked decode stays at 20 s. FastConformer can take longer input, but
the existing chunking is already tested and fits meeting tracks.

## Settled during review

- **Download** works exactly like GigaAM's. It uses a `resolve/<revision>/…`
  URL pinned to the commit above, and checks the size and SHA-256 through
  `VerifiedModelStore`. It never follows `main`.
- **Live transcription** is untouched. It runs its own Nemotron model,
  whatever the post-recording engine is.
- **Behaviour parity** *(my call)*: the retargeted tests check the same
  things the GigaAM tests did. These are the 20-second chunking, an
  unreadable or empty track counting as permanent, runtime failures staying
  retryable, and the verified-store install and corrupt-download handling.
  RNN-T versus CTC makes no difference at the `transcribe_run` /
  `transcribe_full_text` level.
- **Size figures** *(my call)*: every hard-coded ~260 MB figure for GigaAM
  becomes ~135 MB. That covers `SetupForm`'s per-engine size table,
  `advertisedDownloadBytes` and the README.
- **Non-Georgian audio** *(my call)*: the setup card and the settings
  choice say "Georgian only". There is no extra warning UI.

## Leftovers from GigaAM

- `TranscriptVersions` keeps its `"gigaam" → "GigaAM"` label, so older
  transcript versions made with GigaAM are still named correctly.
- A config file that still says `local_engine = "gigaam"` or `engine =
  "gigaam"` must not fail. It should fall through the way any unknown
  engine name already does. The builder confirms the current behaviour and
  adds a test.
- A GigaAM model already on disk at `models/gigaam` is left alone. It drops
  out of the storage list, and the user can delete the folder by hand.
- Past release notes are history and stay untouched.

## Verification

- `swift test` passes.
- The real-model test (today `GigaAMRealModelTests`, gated on env vars) is
  retargeted to `AMANU_GEORGIAN_GGUF` and `AMANU_GEORGIAN_AUDIO`. It is run
  once with the downloaded GGUF and a FLEURS Georgian clip, and expects
  Georgian script in the output.
- A manual check by hand: `make app`, pick Georgian in setup (it downloads
  and verifies), record or import Georgian audio, then right-click →
  Re-transcribe with Georgian.

## Non-goals

- Automatic language detection and per-language engine routing.
- Running the original `.ckpt` through Python/NeMo, or converting it to ONNX.
- KenLM rescoring.
- Live (during-recording) transcription in Georgian.

## Left to the builder

- Exact wording of the setup card and its Russian localisation.
- Whether to pass `language = "ka"` or keep `NULL`. Both should work; NULL
  was what got tested.
- Commit granularity, following the repo's commit-message voice.
