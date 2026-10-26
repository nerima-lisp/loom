# Adding R1–R3 command-path E2E scenarios

R1, R2, and R3 are command-path coverage rules for command entry, prompt outcomes, and command effects or mutations. R8 covers restoration after restarting the process; its PTY scenarios live in `packages/feature/session/t/e2e/scenarios/`.

The core module `packages/core/command/t/e2e/scenarios/command_path_scenarios.py` loads `packages/core/command/t/e2e/scenarios/command-paths.json` and registers one PTY scenario per record. Feature sidecars at `packages/feature/<slice>/t/e2e/scenarios/command-paths.json` are loaded by `t/e2e/loom_e2e/scenario_discovery.py`. Add each required route to its owning slice's `t/paths.sexp`: the JSON record defines the executable scenario, and the ledger row claims path coverage. The core command slice stores its ledger at `packages/core/command/t/paths.sexp`.

## Routes and ownership

For example, global TAB has the compact key signature `{"keymap":"global","sequence":[{"key":"tab","modifiers":[]}]}`. The missing-path report supplies the generated `lane`, `entry`, `state`, `outcome`, and `observe`; set `scenario` to the exact JSON record name. The `state` and `outcome` fields describe the starting condition and expected result, while `observe` lists evidence types such as `screen_text`, `file_bytes`, `cursor`, or `external_state`. A simple cross-file example is `r1:load-session:mx`: the session sidecar maps it to `command-path/r1/load-session/mx`, and the session ledger uses the same ID and scenario name.

To find generated path IDs, run `nix run .#e2e -- --require-path-coverage` and read the `id` fields in the `missing_paths` array in the `path-coverage.json` file. The runner prints that file's path. A missing route can make the command exit 1 after it writes the report. For command catalog routes, key paths use `r1:<command>:key:<URL-encoded key signature>`, M-x paths use `r1:<command>:mx`, prompt paths use `r2:<command>:prompt-<index>:<prompt>:<outcome>`, and mutation paths use `r3:<command>:<mutation case>`. Prompt indexes start at 1. A key signature is the compact, key-sorted JSON form of a catalog key; the path ID URL-encodes it, while the ledger keeps it after `key:`. The matching ledger `entry` is `key:<signature>`, `mx`, or the command's first catalog key followed by `;prompt:<index>:<prompt>`; use `mx` when the command has no key. Macro replay uses the literal ledger entry `macro`. Set `state` to the starting condition, `outcome` to the expected result, `observe` to the required evidence types, and `scenario` to the exact JSON record name. The runtime catalog is emitted by `packages/core/command/src/command-registry.lisp` and loaded by `t/e2e/loom_e2e/commands.py`; `t/e2e/loom_e2e/path_generation.py` maps its `owner` to a lane with `LANE_REGISTRY`. Use the generated route's `lane` to identify the owning slice, then add the route to that slice's `t/paths.sexp` (for example, `feature/mode` maps to `packages/feature/mode/t/paths.sexp`).

## Shared expectations

`command` names the command invoked by the scenario; `commands` declares the command IDs associated with that scenario for coverage and must include the generated route's target command. Screen checks default to exact text matching; set `match` to `contains` for a substring check.

Every record declares exact `initial_bytes`, `expected_bytes`, `expected_cursor`, `expected_minibuffer`, and `expected_screen` values. `columns` and `rows` set positive terminal dimensions and default to 80 columns and 24 rows. Use a wider terminal when a prompt must display a long path. Cursor rows and columns are zero-based and relative to `expected_cursor_region`, which defaults to `body`; set the region to `minibuffer` when the command leaves input focus there. Use an empty string when the expected minibuffer is empty. Set `expected_minibuffer_match` to `contains` when the result includes dynamic text. Each `expected_screen` item names a `body`, `minibuffer`, or `screen` region; its optional zero-based `index` selects a row, and `match: contains` checks text within a decorated row. `commands` lists the canonical command IDs the scenario trace must contain; the trace reader maps a bound wrapper to its catalog command when needed. `command` names the logical command path under test. Keep each record focused on one generated command path; fixture keys and files may establish its starting state.

When an R1 or R2 command changes bytes, set `save_after_effect` to `true`. The runner saves the buffer before checking the exact file bytes.

## R1: command entries

Set `entry_mode` to `key`, `mx`, or `open-mx`. A `key` case declares `entry_keys`; `mx` invokes `command` through M-x; `open-mx` sends the real Alt-x key and checks the prompt without executing a command. Use `open-mx` to cover `execute-extended-command`, which has no M-x catalog entry.

## R2: completion prompts

The supported `prompt_kind` values are `free-string`, `completion`, `yes-no`, and `numeric`. Find the command's `:prompts` declaration in the owning slice's `src/command-specs-*.lisp` file.

Use one record for each generated prompt outcome: `accept`, `cancel`, `empty`, `tab`, and `history`; completion, yes-no, and numeric prompts also have an `invalid` outcome. Set `entry_mode` to `key` or `mx` for a command prompt, and declare the actual entry plus `prompt_open`, the full visible prompt label as a string. `open-mx` covers the M-x completion prompt itself. Set `prompt_kind` to the command's catalog prompt kind from its `:prompts` field in the `command-specs-*.lisp` declaration. Set `input_text` to the exact input, including `""` for empty input. A TAB case declares the exact `tab_expected` text. For M-x completion, accepted cases also declare `accepted_command`.

Use `fixture_keys` to establish state before opening the prompt, such as a completion candidate. If setup needs an asynchronous screen update before more keys, declare `fixture_wait` with its `region`, `text`, and optional zero-based `index`; `fixture_keys_after_wait` run after that text appears. A history case declares `history_seed_input` for a command prompt or `history_seed_command` for M-x, plus `history_expected`. `input_text` may contain a distinct value already typed into the target prompt. Target prompt cases declare `history_next_expected`; the runner checks M-p to the previous history value, M-n back to the typed value, then M-p to the previous value again. `history_expected` and `history_next_expected` are prompt input only, without the prompt label; the runner checks the full displayed prompt text. For example, the `load-session` history record seeds `previous`, opens the target prompt with draft `p`, and expects `previous`, then `p`, then `previous`. Set `history_cancel` to `true` to cancel after navigation; otherwise the runner accepts the selected history value and checks the command result. M-x command history uses Up. `fixture_keys` run before history seeding and before the target prompt is opened.

Use `fixture_files` to create named files inside the scenario's temporary directory before launching the editor. Each item has a single-filename `path` and string `contents`. The `$scenario_dir` token expands to the temporary directory, and `$fixture_file:<name>` expands to a fixture's path in string values, including the rename prompt; `<name>` is the exact filename in that fixture's `path` field. Use `expected_filesystem` to assert each named file or directory is `file`, `directory`, or `absent` after the scenario.

R2 prompt scenarios for `load-session` may declare `session_fixture` with `path: "$session_file"` and text `contents`; the runner writes it to temporary `session.sexp` before launching. In string values, `$session_file` resolves to that file and `$buffer_file` resolves to temporary `buffer.txt`, including prompt input and fixture contents. These prompt cases cover loading a named session file; process-restart restoration is covered by the separate R8 scenarios in `packages/feature/session/t/e2e/scenarios/`.

## R3: mutations

For macro replay, the runner records and saves the effect, undoes it, waits for the exact row declared in `restore_screen`, and saves the original bytes. It then sends `replay_prefix_keys` followed by `C-x e`, and checks the replayed effect.

The loader in `t/e2e/loom_e2e/command_path_scenarios.py` checks that `expected_bytes` equals `effect_bytes` for effect, narrow, split-window, macro-replay, and prefix-u4; it must equal `initial_bytes` for undo and read-only.

Set `mutation_case` to `effect`, `undo`, `read-only`, `narrow`, `split-window`, `macro-replay`, or `prefix-u4`. Declare the exact triggering sequence in `command_keys`, the command's immediate result in `effect_bytes` and `effect_screen`, and the final state in `expected_bytes`, `expected_cursor`, `expected_minibuffer`, and `expected_screen`. For an undo case, `expected_cursor` is the cursor after the command effect and `expected_undo_cursor` is the cursor after restoring the original bytes; other mutation cases use `expected_cursor` for their final cursor.

Read-only cases declare `read_only_command` and assert its refusal message without changing file bytes. `fixture_keys` establish state before the mutation, for example by recording a keyboard macro. Macro-replay cases declare `restore_screen` and `replay_prefix_keys`, which sets the cursor before `C-x e`. R3 path generation excludes `load-session` because restart restoration belongs to R8, and excludes `call-last-kbd-macro` macro-replay because that case would recursively record itself.

Set `major_mode` when the command must run with a language mode active. `prepare_keys` and `prepare_commands` establish state before the mutation; `post_setup_keys` runs after those commands. Narrow cases must prepare a narrowed region with `narrow-to-region`; split-window cases must prepare a second view with `split-window-below`; prefix-u4 cases start `command_keys` with `C-u` and verify the command's prefix behavior.

The runner selects `major_mode`, sends `prepare_keys`, runs each `prepare_commands` item through M-x in list order, then sends `post_setup_keys` before the mutation.

Run the commands below to verify a harness change, one PTY scenario, and full path coverage. `--only` selects scenarios whose names contain the supplied substring. The harness test ends with `OK`; a passing PTY case prints `PASS <scenario name>`, and the full run prints lane coverage.

```sh
python3 t/e2e/test_command_path_scenarios.py
nix run .#e2e -- --only command-path/r3/comment-line/effect
nix run .#e2e -- --require-path-coverage
```
