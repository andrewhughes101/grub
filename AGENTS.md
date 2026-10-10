# AGENTS.md

## What This Is

GRUB (Git Remote User Build) is a three-script Bash toolkit that synchronises a local git repository to a remote server and runs a build there. It is a developer workflow aid — not a CI system.

Primary target is **z/OS UNIX** (IBM mainframe), where source is authored locally but compilation must run on the remote system. It also works on Linux remote servers.

## Repository Layout

```
bin/grub_client       # Local orchestrator (bash). Entry point for users.
bin/grub_server       # Remote build runner (sh). Piped over SSH at runtime.
bin/grub_remote_setup # Remote repo init/clean (sh). Piped over SSH at runtime.
bin/grub_yaml         # Pure POSIX sh YAML parser. Sourced by grub_client.
install.sh            # One-liner installer from GitHub Releases.
sample/               # Templates: VSCode settings, tasks, inventory, host_vars, build_vars.
```

Neither `grub_server` nor `grub_remote_setup` is installed on the remote — they are piped over SSH via `cat script | ssh host sh -s -- args`.

## How It Works

1. Creates a patch of all local changes (staged, unstaged, untracked) via `git diff HEAD`
2. Runs `grub_remote_setup` over SSH to prepare/clean remote repo and check if remote HEAD matches local HEAD
3. Pushes committed changes to the remote via `git push --force` over SSH (skipped if remote HEAD and branch already match)
4. Transfers the patch file via `scp -C` (if uncommitted changes exist)
5. Runs `grub_server` on the remote: applies the patch, then executes the build command
6. Streams build output live, then downloads stdout/stderr log files via `ssh cat`
7. Cleans up all temp files, the added git remote, and any temporary branch on exit via `trap`

## Scripting Language Constraints

- `grub_client` is **bash** — runs locally where bash is always available
- `grub_server` and `grub_remote_setup` are **POSIX `sh`** — deliberately, to minimise server-side prerequisites, particularly on minimal z/OS UNIX setups where `/bin/bash` may not be at the standard path even if bash is present
- When editing server-side scripts, avoid bash-specific constructs: no arrays, no `[[`, no `$(())` arithmetic, no `local` in functions, no process substitution

## Build Command

`build_command` defaults to `./build`. In practice it is almost always a script invocation inside the user's repo rather than a simple shell command. It is executed via `bash -c "$build_command"` on the remote, so multi-word commands work but the quoting is the user's responsibility.

## Exit Codes

The client exits with the build command's exit code propagated through SSH. GRUB's own internal errors currently use exit code `4` or `8` but there is no formally defined exit code scheme — this is a known gap and a good area for improvement.

## z/OS-Specific Behaviour

- Platform detected by `uname -s` matching `OS/390`
- Default `git_dir` on z/OS: `/usr/lpp/IBM/foz/v1r1/bin`
- When a new remote repo is created by GRUB, the user's `.gitattributes` (including any `zos-working-tree-encoding` entries) is pushed with the rest of the repo and honoured on the remote
- The `.gitattributes` in this repo only tags `bin/grub_server` itself — this is for GRUB's own development, not user repos
- Patch files tagged `iso8859-1` before apply; 3-way merge (`git apply --3way`) used to handle encoding mismatch between ASCII patch and IBM-1047 working tree files
- Log files created and tagged with `chtag -b` before the build runs
- Build output downloaded via `ssh cat` rather than `scp` to avoid `scp`'s auto EBCDIC conversion

## Patch and Untracked Files

The patch includes untracked files that are **not** gitignored (`git ls-files --others --exclude-standard`). Gitignored files are intentionally excluded — this prevents large build artefact directories (e.g. Gradle caches) from being transferred, but it also means builds that rely on gitignored files (e.g. a `.env` config) will break. This is a known and accepted trade-off.

## Key Design Constraints

- **No server install required** — all remote scripts are piped over SSH
- **Local working directory is never modified**
- **Single-user tool** — concurrent builds against the same remote repo are not supported
- `run_id` (`YYYYmmdd_HHMMSS_PID`) namespaces all temp files to prevent clashes between sequential runs
- Remote git repo uses `receive.denyCurrentBranch updateInstead` so `git push` updates the working tree directly

## Inventory Support

`grub_client` can load host configuration from Ansible-compatible YAML files. No Ansible installation is required — `grub_yaml` parses the files using pure `sh`, `awk`, and `sed`.

**Host resolution order:** CLI args > inventory host vars > `~/.gitconfig` cache > `~/.ssh/config` > auto-detect defaults.

Two formats are supported:

- **`host_vars/<server>.yml`** — flat key/value file, auto-discovered in the current directory
- **`-i` / `--inventory <file>`** — Ansible inventory YAML (`all.hosts.<server>.*` structure)

Supported variables:

| Variable | Effect |
|---|---|
| `ansible_host` | Passed as `ssh -o HostName=` |
| `ansible_user` | Passed as `ssh -l` |
| `ansible_ssh_private_key_file` | Passed as `ssh -i` (~ expanded) |
| `ansible_port` | Passed as `ssh -o Port=` |
| `ansible_ssh_common_args` | Appended to SSH options (e.g. ProxyJump) |
| `grub_ssh_multiplex` | Set to `false` to disable OpenSSH `ControlMaster` |
| `grub_server_root` | Sets `server_root` if not given via CLI |
| `grub_git_dir` | Sets `git_dir` if not given via CLI |

When any of the SSH vars or multiplexing options are present, `GIT_SSH_COMMAND` is also exported so that `git push` uses the exact same connection options.

OpenSSH connection multiplexing (`ControlMaster=auto`, `ControlPersist=600`) is enabled by default so all SSH, SCP, and Git push operations share a single connection without repeated handshakes.

`~/.ssh/config` continues to work and is used as fallback for anything not specified in the inventory.

See `sample/inventory.yml` and `sample/host_vars/myzos.yml` for templates.

## Extra Vars & Build Variable Precedence

`-e` / `--extra-vars <file>` passes a flat YAML key/value file to the remote build as environment variables.

- Parsed client-side using `grub_yaml_iter_flat`; keys validated as legal shell identifiers
- Flat key/value pairs are recommended; nested mappings are parsed line-by-line (parent key receives `''`, indented child key is exported directly)
- Transformed into a `export KEY='value'` shell file and transferred via `scp` to the remote tmpdir
- Tagged with `chtag -tc iso8859-1` on z/OS and sourced by `grub_server` immediately before `bash -c "$build_command"`, then deleted from the remote
- Variables are scoped to the build command only — not visible client-side, not applied during patch
- `sample/build_vars.yml` is a template

**Build Variable Precedence:**
1. Inline command-line variable assignments (e.g. `grub_client myserver TEST=21 ./build`)
2. `--extra-vars` / `-e <file>` exported environment variables
3. Remote server pre-existing environment variables

## VSCode Settings Keys

| Setting | CLI flag | Default |
|---|---|---|
| `grub.server` | positional `<server>` | — |
| `grub.client_build_tool` | n/a (path to `grub_client`) | — |
| `grub.server_root` | `--server-root` | `~/dev` |
| `grub.git_dir` | `--git-dir` | auto-detected |

See `sample/grub_variables.json` for a settings template and `sample/tasks.json` for the VSCode build task template.

## Releasing

Bump `VERSION="x.y.z"` in `bin/grub_client`, commit, and push to `main`. The GitHub Actions workflow (`.github/workflows/release.yml`) detects the new version, creates a tag, and publishes a GitHub Release with a tarball automatically. No other steps required.

## Testing

Unit tests live in `test/`. No external dependencies — the framework is pure POSIX `sh`.

```
test/
  run_tests.sh          # Runner: discovers test_*.sh, exits non-zero on failure
  lib/assert.sh         # assert_eq, assert_empty, assert_contains, assert_exit helpers
  test_grub_yaml.sh     # Tests for all grub_yaml functions
  test_extra_vars.sh    # Tests for --extra-vars key validation and env file generation
  test_remote_setup.sh  # Tests for grub_remote_setup repo init, cleanup, and push cache
  test_cli_args.sh      # Tests for grub_client CLI option handling, exit codes, and precedence
  test_patch.sh         # Tests for patch generation and application (untracked, unstaged, staged)
  fixtures/             # YAML input files used by tests
```

Run locally:
```bash
sh test/run_tests.sh
```

Run a single file:
```bash
sh test/run_tests.sh test/test_cli_args.sh
```

Tests run automatically on every push and pull request to `main` via `.github/workflows/test.yml`.

**What is tested:** `grub_yaml` functions (all four), `--extra-vars` key validation, env file generation, eval-safety of generated output, `grub_remote_setup` repository lifecycle (init, compression, cleanup, push cache, and `.gitattributes` change detection), `grub_client` CLI argument parsing, option precedence, and error exit codes, and diff patch generation/application across staged, unstaged, and untracked files.

**What is not tested:** End-to-end SSH orchestration — full `grub_client` and `grub_server` execution across real network connections.
