# Wordcraft

An iOS proof of concept: a custom keyboard that suggests the next word using a language model that runs entirely on the device. Nothing is sent over the network.

## How it works

- **Wordcraft** (`Wordcraft/App`) is the host app. It explains how to enable the keyboard, lets you pick a model backend, downloads/prepares MLX models, and has a demo text field for testing suggestions.
- **WordcraftKeyboard** (`WordcraftKeyboard`) is the keyboard extension. It shows a QWERTY layout with a suggestion bar of 1–3 words. Tapping a suggestion inserts the word and a space.
- **WordcraftShared** (`WordcraftShared`) is compiled into both targets. It holds the suggestion engine (`LocalLLMSuggestionEngine`) and the MLX runtime wrapper (`MLXLocalRuntime`).

The app and the keyboard share settings through the App Group `group.com.wordcraft.local`.

## Model backends

| Backend | Runtime | Notes |
|---|---|---|
| Apple Foundation Models | `FoundationModels` (iOS 26+) | Default. Needs Apple Intelligence on the device. |
| Gemma 4 | MLX (`mlx-swift-lm`) | Defaults to `gemma4_e2b_it_4bit`. |
| MLXVLM | MLX | Set a Hugging Face repository ID or a local model folder. |

If the selected model is unavailable, the engine returns hard-coded mock suggestions so the UI still works. Every request logs latency, model load time, backend, and whether the mock was used.

> Download MLX models in the host app first. The keyboard extension reuses what the app prepared and should not be the first to fetch model files.

## Requirements

- Xcode with the iOS 17+ SDK (iOS 26 SDK for Foundation Models)
- An iPhone or the Simulator
- Swift packages, resolved automatically: `mlx-swift-lm`, `swift-huggingface`, `swift-transformers`

## Build and run

1. Open `Wordcraft.xcodeproj` and run the `Wordcraft` scheme. The project is generated from `project.yml`. If you change it, regenerate with [XcodeGen](https://github.com/yonaskolb/XcodeGen): `xcodegen generate`.
2. On the device, go to **Settings > General > Keyboard > Keyboards > Add New Keyboard** and choose **Wordcraft**.
3. In any text field, switch to Wordcraft with the globe key.

Open Access stays off, so the keyboard has no network access.

## Testing

There are no automated tests. See [ManualTestPlan.md](ManualTestPlan.md) for manual checks in Notes, Messages, Safari, password fields, keyboard switching, and cold start.
