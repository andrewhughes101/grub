# GRUB: Git Remote User Build

Build your local git repository on a remote server

## What It Does

GRUB synchronizes your local repository (including uncommitted changes) to a remote server and runs a build command there:

1. Creates a patch file of all local changes (staged, unstaged, and untracked files)
2. Pushes committed changes via git
3. Transfers the patch file to the server
4. Applies the patch on the server
5. Runs your build command
6. Downloads build output and errors

**Your local git working directory is never modified.**

## Quick Start

### Installation

**Recommended (one-line install):**
```bash
curl -fsSL https://raw.githubusercontent.com/andrewhughes101/grub/main/install.sh | bash
```

Or with wget:
```bash
wget -qO- https://raw.githubusercontent.com/andrewhughes101/grub/main/install.sh | bash
```

Then add to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.):
```bash
export PATH="$HOME/.grub/bin:$PATH"
```

**Alternative - Manual Installation:**
```bash
# Download latest release
wget https://github.com/andrewhughes101/grub/releases/latest/download/grub-*.tar.gz
tar -xzf grub-*.tar.gz
export PATH="$PWD/grub/bin:$PATH"
```

**Alternative - Clone from source:**
```bash
cd ~/tools
git clone git@github.com:andrewhughes101/grub.git
export PATH="$HOME/tools/grub/bin:$PATH"
```

### SSH Setup

Configure SSH with public/private key authentication. Either use `~/.ssh/config`:

```
Host myserver
  HostName server.example.com
  User myusername
```

Or define connection details in a `host_vars` file (see [Inventory Support](#inventory-support-optional) below) — no `~/.ssh/config` entry required when `ansible_host` and `ansible_user` are set.

### Usage

```bash
cd /path/to/your/repo
grub_client <server> [build_command]
```

**Example:**
```bash
grub_client myserver ./build
```

**With custom repo path:**
```bash
grub_client --repo-path ~/projects/myapp myserver make
```

## VSCode Integration (Optional)

### 1. Configure Settings

Press `Cmd-Shift-P` → "Preferences: Open User Settings (JSON)" and add:

```json
{
  "grub.server": "myserver",
  "grub.client_build_tool": "/Users/you/tools/grub/bin/grub_client",
  "grub.server_root": "/u/user/projects",
  "grub.git_dir": "/opt/git/bin"
}
```

`grub.server_root` and `grub.git_dir` are optional — omit them to use the defaults (`~/dev` and auto-detected platform path respectively).

### 2. Create User Task

Press `Cmd-Shift-P` → "Tasks: Open User Tasks" and add:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "GRUB Build",
      "type": "shell",
      "command": "${config:grub.client_build_tool}",
      "args": [
        "--repo-path", "${workspaceFolder}",
        "--server-root", "${config:grub.server_root}",
        "--git-dir", "${config:grub.git_dir}",
        "${config:grub.server}"
      ],
      "group": {
        "kind": "build",
        "isDefault": true
      }
    }
  ]
}
```

Remove `--server-root` and `--git-dir` lines from `args` if you are not setting those in your VSCode settings.

### 3. Build

Press `Cmd-Shift-B` to run the build. Output streams in real-time to the terminal.

## Options

```
grub_client [options] <server> [build_command]

Options:
  -v, --verbose              Verbose output
  -o, --output               Print stdout/stderr from downloaded files
  -h, --help                 Show help
  --version                  Show version
  --repo-path <path>         Repository path (default: current directory)
  --server-root <path>       Remote root directory (default: ~/dev)
  --git-dir <path>           Git directory on server (default: auto-detect)
  -i, --inventory <file>     Ansible inventory YAML file
  -e, --extra-vars <file>    YAML file of variables to export as env vars during build
  --no-multiplex             Disable OpenSSH connection multiplexing (ControlMaster)
  --clear-cache <server>     Clear cached git directory and multiplex socket for server

Arguments:
  server                     SSH host name (must match ~/.ssh/config Host or inventory host name)
  build_command              Command to run (default: ./build)
```

## Passing Environment Variables to Build Commands

You can pass environment variables to your remote build in multiple ways:

### 1. Inline Command Variables
Variables specified directly in the build command have the highest precedence:

```bash
grub_client myserver TEST=21 ./build
# or with multiple variables
grub_client myserver "FOO=bar BAZ=qux ./build"
```

### 2. Local Client Variables (Unquoted or Double-Quoted)
When unquoted or in double quotes, your local shell expands `$VAR` before passing it to GRUB. GRUB safely quotes the value across SSH so special characters and spaces are preserved:

```bash
grub_client myserver RELEASE_TAG=$VERSION ./build
# or
grub_client myserver "API_KEY=$MY_LOCAL_TOKEN make test"
```

### 3. Remote Server Variables (Single-Quoted)
When single-quoted, the literal variable reference is sent over SSH and evaluated on the remote server environment at runtime:

```bash
grub_client myserver 'PATH=$PATH:/opt/ibm/bin ./build'
```

### 4. Structured Files via `-e` / `--extra-vars`
For passing multiple variables without command-line escaping, use a flat YAML file (see [Extra Vars](#extra-vars-optional) below).

### Build Variable Precedence
When the same environment variable is defined in multiple places for a build, the following precedence applies (highest to lowest):

1. **Inline Command-Line Overrides** (e.g. `grub_client myserver TEST=21 ./build`) — takes precedence over everything
2. **Extra Vars File** (`-e` / `--extra-vars <file>`) — exported into the build subshell environment
3. **Remote Server Environment** — existing environment variables on the remote system

## Inventory Support (Optional)

GRUB can read host configuration from Ansible-compatible YAML files. This lets you share a single inventory between GRUB (local builds) and Ansible (CI/CD).

### Option A — `host_vars/<server>.yml` (auto-discovered)

Place a file named after your server in a `host_vars/` directory in your project:

```yaml
# host_vars/myzos.yml
ansible_host: zos.example.com
ansible_user: myuser
# ansible_ssh_private_key_file: ~/.ssh/id_zos  # optional
grub_server_root: /u/myuser/projects
grub_git_dir: /usr/lpp/IBM/foz/v1r1/bin
```

```bash
grub_client myzos          # picks up host_vars/myzos.yml automatically
```

### Option B — Ansible inventory file (`-i` / `--inventory`)

Use an existing Ansible inventory that covers multiple hosts:

```yaml
# inventory.yml
all:
  hosts:
    myzos:
      ansible_host: zos.example.com
      ansible_user: myuser
      grub_server_root: /u/myuser/projects
      grub_git_dir: /usr/lpp/IBM/foz/v1r1/bin
    mylinux:
      ansible_host: linux.example.com
      ansible_user: devuser
```

```bash
grub_client -i ~/ansible/inventory.yml myzos
# or
grub_client --inventory ~/ansible/inventory.yml myzos
```

### Supported host variables

| Variable | Equivalent to |
|---|---|
| `ansible_host` | SSH `HostName` |
| `ansible_user` | SSH `User` |
| `ansible_ssh_private_key_file` | SSH `IdentityFile` |
| `ansible_port` | SSH `Port` |
| `ansible_ssh_common_args` | Extra SSH options (e.g. `-o ProxyJump=...`) |
| `grub_ssh_multiplex` | Set to `false` to disable `ControlMaster` |
| `grub_server_root` | `--server-root` |
| `grub_git_dir` | `--git-dir` |

### Host and Connection Configuration Precedence
Configuration settings are resolved in the following priority order (highest to lowest):

1. **CLI Arguments** (`--server-root`, `--git-dir`, `--no-multiplex`)
2. **Inventory / host_vars** (`-i <file>` or `host_vars/<server>.yml`)
3. **Cached Git Config** (`~/.gitconfig` cached `git_dir` from prior auto-detection)
4. **SSH Config** (`~/.ssh/config` fallback for hostname, user, identity, port)
5. **Built-in Defaults** (`server_root="~/dev"`, auto-detected `git_dir`, `build_command="./build"`)

See `sample/inventory.yml` and `sample/host_vars/myzos.yml` for templates.

## Extra Vars (Optional)

Pass a flat YAML file of key/value pairs to the remote build as environment variables:

```bash
grub_client -e build_vars.yml myserver
```

```yaml
# build_vars.yml
MY_API_KEY: s3cr3t
BUILD_FLAGS: --release
```

Variables are exported into the build command's environment only. They are:
- **Not visible client-side** — processed locally and transferred as a temp file
- **Not stored in the repo** — the file is deleted from the remote immediately after sourcing
- **Not applied during patch** — only active when your build script runs

Keys must be valid shell identifiers (letters, digits, underscores; must not start with a digit).

See `sample/build_vars.yml` for a template.

## Defaults

- **server_root**: `~/dev` (expands to remote user's home directory)
- **git_dir**: Auto-detected based on platform
  - z/OS: `/usr/lpp/IBM/foz/v1r1/bin`
  - Other: `/usr/bin`
- **build_command**: `./build`

## Environment Variables

- `TMPDIR`: Temporary directory for local and remote files (default: `/tmp`)

## Requirements

- Git installed locally and on server
- SSH with key-based authentication
