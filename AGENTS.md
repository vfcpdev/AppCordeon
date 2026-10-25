# AGENTS.md

## Layout

- `acordeon_flutter/` — the Flutter app (the active product). Run **all** commands from this directory.
- `acordeon_engine/` — Rust crate (`serde`, no tonic/wasm). DSP synthesis + chord/key/BPM analysis exposed through a C ABI (`lib.rs`). Presently groundwork: the Flutter side does **not** link it via FFI/WASM yet; analysis runs as pure Dart (`lib/core/audio/analysis/`), synth as Web Audio.
- Root `README.md` documents the legacy JS prototype (`index.html`, `src/`, `css/`) which no longer exists in this repo — treat it as stale.

## Commands (from `acordeon_flutter/`)

```powershell
flutter analyze lib <path>              # lint; run before committing
flutter test test\<name>_test.dart      # single test file
flutter test                            # full suite (~10 files, fast, no device/fixture needed)
flutter run -d chrome                   # web (primary target — audio only fully works here)
flutter run -d windows                  # Windows desktop (audio player/synth fall back to stubs)
```

Verification order: `flutter analyze` → `flutter test`. Android and web are pre-compiled platform targets; there is no `ios/` or `linux/` directory.

## Architecture

- Riverpod 3 + ChangeNotifier-style controllers. Composition root: `lib/core/di/providers.dart` — the only place concrete implementations are chosen. Tests override providers via `ProviderContainer(overrides: [...])`, not singletons.
- **Platform-adapters via conditional imports** (critical pattern): `web_audio_synth.dart`, `web_audio_decoder.dart`, `audio_file_loader.dart`, `audio_file_player.dart` each resolve a `_web` vs `_stub` implementation using `if (dart.library.js_interop)`. When touching an interface, keep the interface file, `_web`, and `_stub` in sync or native builds break.
- Entry point: `lib/main.dart` → `lib/presentation/screens/home_screen.dart`. Layers: `core/` (audio, DI, constants), `domain/` (models, theory), `presentation/` (`controllers/` + `widgets/`, one controller per menu section).
- Single global UI state: `accordionSimulatorProvider` (in `presentation/controllers/accordion_controller.dart`, ~1200 lines) holds measures grid, free chord, detector, and audio-analysis state. Both `MeasureGridWidget` instances (Acordeón 1 and A2) watch this same provider — shared state, do not assume per-accordion isolation.

## Testing quirks

- Controller tests construct `AccordionSimulatorState` directly with many required fields; when adding a state field, make it optional with a default (`required this.X` only if truly needed) or you'll break every test constructor.
- Tests avoid platform channels; set widget `key`/`ValueKey` for finders (existing convention: e.g. `'beat_checkbox_..._...'`).

## Conventions

- Comments, docstrings and UI strings are in **Spanish**; identifiers/keep them Spanish for anything user-facing.
- Icons use `font_awesome_flutter` (`FaIcon`), not Material Icons.
- Commit style from history: `feat: <concise summary>`, no config or lockfile churn in feature commits.
- Shell is Windows PowerShell: no `&&`, no `rg`; chain with `;` and quote paths with spaces.
