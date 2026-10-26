# Adding R1–R3 command-path E2E scenarios

Scenario data lives in `packages/core/command/t/e2e/scenarios/command-paths.json`. The slice module loads every record and registers it as a PTY scenario, so adding a JSON record is the registration step. Add its matching route to the slice's `t/paths.sexp`.

## Routes and ownership

Copy `path_id` and `entry` from the generated required paths. For command catalog routes, key paths use `r1:<command>:key:<URL-encoded key signature>`, M-x paths use `r1:<command>:mx`, prompt paths use `r2:<command>:prompt-<index>:<prompt>:<outcome>`, and mutation paths use `r3:<command>:<mutation case>`. The matching `entry` is `key:<signature>`, `mx`, or the prompt entry with its `;prompt:<index>:<prompt>` suffix. Macro replay uses `macro`. Keep `lane` equal to the generated route's lane; the generator derives it from the catalog owner through `LANE_REGISTRY` in `t/e2e/loom_e2e/path_generation.py`.

## Shared expectations

Every record declares exact `initial_bytes`, `expected_bytes`, `expected_cursor`, `expected_minibuffer`, and `expected_screen` values. The cursor is a `[row, column]` relative to `expected_cursor_region`, which defaults to `body`; set the region to `minibuffer` when the command leaves input focus there. Use an empty string when the expected minibuffer is empty. `commands` lists the commands that the scenario trace must contain; `command` names the command under test.

When an R1 or R2 command changes bytes, set `save_after_effect` to `true`. The runner saves the buffer before checking the exact file bytes.

## R1: command entries

Set `entry_mode` to `key`, `mx`, or `open-mx`. A `key` case declares `entry_keys`; `mx` invokes `command` through M-x; `open-mx` sends the real Alt-x key and checks the prompt without executing a command. Use `open-mx` to cover `execute-extended-command`, which has no M-x catalog entry.

## R2: completion prompts

Use one record for each prompt outcome: `accept`, `cancel`, `empty`, `tab`, `history`, and `invalid`. Set `input_text` to the exact prompt input, including `""` for empty input. Accepted cases declare `accepted_command`; TAB cases also declare `tab_expected`. A history case declares a `history_seed_command` and `history_expected`, then the runner presses UP after opening M-x. The runner opens `execute-extended-command` with the real Alt-x key.

For example, `command-path/r2/accept` enters `capitalize-word` in M-x, expects `One two\n` from `one two\n`, and saves the changed bytes before checking them.

## R3: mutations

Set `mutation_case` to `effect`, `undo`, `read-only`, or `macro-replay`. Declare the exact triggering sequence in `command_keys`, the command's immediate result in `effect_bytes` and `effect_screen`, and the final state in `expected_bytes`, `expected_cursor`, `expected_minibuffer`, and `expected_screen`. Effect and macro-replay cases must end at `effect_bytes`; undo and read-only cases must end at `initial_bytes`. The loader rejects records that disagree.

Read-only cases declare `read_only_command` and assert its refusal message without changing file bytes. Macro-replay cases declare `restore_screen`; the runner checks the initial effect, restores the original bytes, replays the macro twice, and compares both exact saved results.

Run the focused harness tests, one PTY scenario, and the full suite. The harness test ends with `OK`; a passing PTY case prints `PASS <scenario name>`, and the full run prints lane coverage.

```sh
python3 t/e2e/test_command_path_scenarios.py
nix run .#e2e -- --only command-path/r2/accept
nix run .#e2e
```
