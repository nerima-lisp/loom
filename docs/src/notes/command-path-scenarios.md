# Adding R1–R3 command-path E2E scenarios

The current examples live in `packages/core/command/t/e2e/scenarios/command-paths.json`, and `packages/core/command/t/e2e/scenarios/command_path_scenarios.py` registers every record as a PTY scenario. Add each command's required route to the `t/paths.sexp` file in its owning slice. For these W3-1 examples, that is `packages/core/command/t/paths.sexp`.

## Routes and ownership

To find generated path IDs, run `nix run .#e2e -- --require-path-coverage` and read the `id` fields in the `missing_paths` array in the `path-coverage.json` file. The runner prints that file's path. A missing route can make the command exit 1 after it writes the report. For command catalog routes, key paths use `r1:<command>:key:<URL-encoded key signature>`, M-x paths use `r1:<command>:mx`, prompt paths use `r2:<command>:prompt-<index>:<prompt>:<outcome>`, and mutation paths use `r3:<command>:<mutation case>`. Prompt indexes start at 1. The matching `entry` is `key:<signature>`, `mx`, or the prompt entry with its `;prompt:<index>:<prompt>` suffix. Macro replay uses `macro`. Set `state` to the starting condition, `outcome` to the expected result, `observe` to the required evidence types, and `scenario` to the exact JSON record name. Keep `lane` equal to the generated route's lane; the generator derives it from the command catalog owner through `LANE_REGISTRY` in `t/e2e/loom_e2e/path_generation.py`. The catalog's `owner` identifies the owning slice; add the route to that slice's `t/paths.sexp` (for example, `feature/mode` maps to `packages/feature/mode/t/paths.sexp`).

## Shared expectations

Every record declares exact `initial_bytes`, `expected_bytes`, `expected_cursor`, `expected_minibuffer`, and `expected_screen` values. Cursor rows and columns are zero-based and relative to `expected_cursor_region`, which defaults to `body`; set the region to `minibuffer` when the command leaves input focus there. Use an empty string when the expected minibuffer is empty. `commands` lists the canonical command IDs the scenario must expose to path coverage; the trace reader maps a bound wrapper to its catalog command when needed. `command` names the logical command path under test.

For an R3 undo case, `expected_cursor` describes the effect and `expected_undo_cursor` describes the cursor after restoring the original bytes.

When an R1 or R2 command changes bytes, set `save_after_effect` to `true`. The runner saves the buffer before checking the exact file bytes.

## R1: command entries

Set `entry_mode` to `key`, `mx`, or `open-mx`. A `key` case declares `entry_keys`; `mx` invokes `command` through M-x; `open-mx` sends the real Alt-x key and checks the prompt without executing a command. Use `open-mx` to cover `execute-extended-command`, which has no M-x catalog entry.

## R2: completion prompts

Use one record for each prompt outcome: `accept`, `cancel`, `empty`, `tab`, `history`, and `invalid`. Set `input_text` to the exact text typed into the prompt, including `""` for empty input. A history case does not type `input_text`; set it to `""`, then declare a `history_seed_command` and `history_expected`. The runner seeds history, opens M-x, and presses UP. `accept`, `tab`, and `history` cases declare `accepted_command`; a TAB case also declares the exact `tab_expected` completion text. The runner opens `execute-extended-command` with the real Alt-x key.

## R3: mutations

Set `mutation_case` to `effect`, `undo`, `read-only`, `narrow`, `split-window`, `macro-replay`, or `prefix-u4`. Declare the exact triggering sequence in `command_keys`, the command's immediate result in `effect_bytes` and `effect_screen`, and the final state in `expected_bytes`, `expected_cursor`, `expected_minibuffer`, and `expected_screen`. Effect, narrow, split-window, macro-replay, and prefix-u4 cases must end at `effect_bytes`; undo and read-only cases must end at `initial_bytes`. The loader rejects records that disagree.

Read-only cases declare `read_only_command` and assert its refusal message without changing file bytes. Macro-replay cases declare `restore_screen` and `replay_prefix_keys`, which sets the cursor before `C-x e`. The runner saves the recorded effect, restores the original bytes, replays the macro once, and checks that the replay produces the same declared bytes, screen, and cursor.

Set `major_mode` when the command must run with a language mode active. `prepare_keys` and `prepare_commands` establish state before the mutation; `post_setup_keys` runs after those commands. Narrow cases must prepare a narrowed region with `narrow-to-region`; split-window cases must prepare a second view with `split-window-below`; prefix-u4 cases start `command_keys` with `C-u` and verify the command's prefix behavior.

Run the focused harness tests, one PTY scenario, and the full suite with path coverage required. `--only` selects scenarios whose names contain the supplied substring. The harness test ends with `OK`; a passing PTY case prints `PASS <scenario name>`, and the full run prints lane coverage.

```sh
python3 t/e2e/test_command_path_scenarios.py
nix run .#e2e -- --only command-path/r3/comment-line/effect
nix run .#e2e -- --require-path-coverage
```
