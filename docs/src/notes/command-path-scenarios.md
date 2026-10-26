# Adding command-path E2E scenarios

Command-path cases live in `packages/core/command/t/e2e/scenarios/command-paths.json`. The slice scenario module registers each record as a PTY test. Keep each record's `path_id`, `entry`, and `lane` aligned with the generated route and its catalog owner. The lane comes from the source owner through `LANE_REGISTRY` in `t/e2e/loom_e2e/path_generation.py`.

Every case declares exact `initial_bytes`, `expected_bytes`, `expected_cursor`, `expected_minibuffer`, and `expected_screen` values. The cursor is a body-relative `[row, column]`. Use an empty string when the expected minibuffer is empty. `commands` lists the commands that the scenario trace must contain; `command` names the command under test.

## R2: completion prompts

Use one record for each prompt outcome: `accept`, `cancel`, `empty`, `tab`, `history`, and `invalid`. Set `input_text` to the exact prompt input, including `""` for empty input. Accepted cases declare `accepted_command`; TAB cases also declare `tab_expected`. A history case declares a `history_seed_command` and `history_expected`, then the runner presses UP after opening M-x. The runner opens `execute-extended-command` with the real Alt-x key, even though that command has no catalog M-x name.

For example, `command-path/r2/accept` enters `capitalize-word` in M-x, expects `One two\n` from `one two\n`, and saves the changed bytes before checking them.

## R3: mutations

Set `mutation_case` to `effect`, `undo`, `read-only`, or `macro-replay`. Declare `effect_bytes` for the state immediately after the command and `expected_bytes` for the final state. For `effect` and `macro-replay`, final bytes must equal `effect_bytes`; for `undo` and `read-only`, they must equal `initial_bytes`. The loader rejects records that disagree.

Use `effect_screen` to assert the post-command view. Undo also checks the restored screen and original bytes. Read-only cases assert the refusal in `expected_minibuffer` and confirm that bytes did not change. Macro-replay records the command, restores the original bytes, then checks that both replays produce the same exact bytes.

Add a matching route to the slice's `t/paths.sexp` and register its scenario data with the slice runner. Run the focused harness tests, then exercise a PTY case and the full suite:

```sh
python3 t/e2e/test_command_path_scenarios.py
nix run .#e2e -- --only command-path/r2/accept
nix run .#e2e
```
