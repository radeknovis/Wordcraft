# Wordcraft manual checks

Use the standard project and an iPhone simulator for the first four checks. The companion app opens on **Demo**. The [README](README.md) covers keyboard installation and device signing.

| Check | Steps | Expected result |
| --- | --- | --- |
| First run | On a fresh install, tap **Generate suggestions** for the prefilled `i `. Change the text to `thank ` and generate again. | The first result is **think**, **can**, **will**. Changing the text clears it. The next result is **you**, **again**, **everyone**, labeled **Built-in demo**. |
| Insertion | Enable Wordcraft in Settings. Select **Built-in demo** in the host. In a normal text field, switch to Wordcraft and start from an empty field. Type `i`, pause, then tap space. Tap **think**. | A partial word has no suggestions. After space, three words appear. Tapping inserts `think` and a trailing space. |
| Editing and switching | Type several letters rapidly, delete, and tap return. Tap the keyboard’s globe, then switch back with the system globe. | Keys affect the focused field, stale results clear, and the keyboard can be selected again. |
| Other fields | Try a regular web form and a secure password field. | In a regular field that permits third-party keyboards, Wordcraft can insert words. iOS supplies the keyboard for the secure field. |
| Apple Foundation Models | In the host, choose **Apple Foundation Models**. Generate on a device with the model available and again on a runtime without it. | Each result shows its actual source. Exact words vary for a live model. Fallback results are labeled **Built-in fallback**. |
| Optional MLX | On a signed physical device, open the MLX build. Prepare a compatible model in the host, then generate. Switch to the keyboard in a separate app and try the prepared selection. | A successful host load identifies the model. The host labels genuine inference with the configured model name. Check the extension separately for responsiveness and memory pressure. |
