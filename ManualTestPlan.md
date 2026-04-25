# Wordcraft Manual Test Plan

## Scope

- Host app opens and shows enablement instructions.
- Keyboard extension appears in enabled keyboards.
- Suggestion bar shows 1-3 local mock next-word suggestions.
- Tapping a suggestion inserts the word plus trailing space.
- No network permission or remote analytics are used.

## Test Cases

1. Notes app
   - Enable Wordcraft in Settings.
   - Open Notes and switch to Wordcraft.
   - Type `i ` and confirm suggestions appear.
   - Tap `think` and confirm insertion.

2. Messages
   - Open a message draft.
   - Type with letters, space, delete, and return.
   - Confirm stale suggestions are replaced while typing.

3. Safari text field
   - Open a normal search/text field.
   - Confirm keyboard appears and suggestions insert into the field.

4. Secure password field
   - Focus a secure password field.
   - Confirm iOS blocks or replaces the custom keyboard as expected.

5. Keyboard switching
   - Tap the globe button.
   - Confirm the next input mode appears.

6. Cold start and memory pressure
   - Force quit the host app.
   - Reopen a text field and switch to Wordcraft.
   - Confirm first suggestion request logs model load time.
   - Use memory pressure testing in Simulator and confirm the keyboard can relaunch.
