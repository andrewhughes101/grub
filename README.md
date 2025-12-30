# GRUB: Git Remote User Build

Build your local git repository on a remote server without modifying your local working directory.

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

**On your local machine:**
```bash
cd ~/tools
git clone git@github.com:MikeFultonDev/grub.git
export PATH="$HOME/tools/grub/bin:$PATH"
```

### SSH Setup

Configure SSH with public/private key authentication. Add to `~/.ssh/config`:

```
Host myserver
  HostName server.example.com
  User myusername
```

### Usage

```bash
cd /path/to/your/repo
grub_client <server_root> <ssh_host> <git_path> [build_command]
```

**Example:**
```bash
grub_client /home/user/repos myserver /usr/bin ./build
```

**With custom repo path:**
```bash
grub_client --repo-path ~/projects/myapp /home/user/repos myserver /usr/bin make
```

## VSCode Integration (Optional)

### 1. Create User Task

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

### 2. Configure Settings

Press `Cmd-Shift-P` → "Preferences: Open User Settings (JSON)" and add:

```json
{
  "grub.server": "myserver",
  "grub.client_build_tool": "/Users/you/tools/grub/bin/grub_client"
}
```

Optional settings (if you need to override defaults):
```json
{
  "grub.server": "myserver",
  "grub.client_build_tool": "/Users/you/tools/grub/bin/grub_client",
  "grub.server_root": "/u/user/projects",
  "grub.git_dir": "/opt/git/bin"
}
```

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

Arguments:
  server                     SSH host from ~/.ssh/config
  build_command              Command to run (default: ./build)
```

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
- Bash on server
