# GRUB: git remote user build

The git remote user build requires code on both the client and server, consisting of:

- [grub_client](bin/grub_client): a script to drive a git remote user build from your desktop.
- [grub_server](bin/grub_server): a script driven by *GRUB_client* on the target server.
- [grub_server.bash](bin/grub_server.bash): a helper script driven by *GRUB_server* on the target server.
- [tasks.json](sample/tasks.json): a sample *tasks.json* that you can optionally use for a VSCode repository build task.
- [grub_variables.json](sample/grub_variables.json): a sample set of environment variables that you can optionally set up for a VSCode repository build task.

## Installation

You need to install GRUB on the client(s) and server(s) that you want to do remote builds with.
For example:

- you have a Mac desktop and want to perform a remote build to your personal userid on z/OS
- your Mac desktop *root* tools directory is *$HOME/Documents/tools*
- your z/OS userid *root* tools directory is *$HOME/tools*

On your Mac:

- `cd $HOME/Documents/tools`
- `git clone git@github.com:MikeFultonDev/grub.git`
- Run `$HOME/Documents/tools/bin/grub_client` with no parameters to see the syntax of `grub_client`

On your Mac, set up VSCode default build (Optional):

- Launch VSCode
- For each repository that you want to run *GRUB* on:
  - Copy the sample [tasks.json](sample/tasks.json) into the *.vscode* directory of your repository. You may need to create the *.vscode* directory if you haven't done any VSCode customization of your repository yet.
  - `Cmd-Shift-P` to bring up preferences, then choose *Tasks: Configure default build task* and choose GRUB as the default build task. You should be able to use this task as-is.
  The task gets the GRUB variables from your preferences and combines it with some parameters it determines, such as the client directory and repo, and then calls the `grub_client` script.
- Set your GRUB variables for VSCode
  - Copy the contents of [grub_variables.json](sample/grub_variables.json) into the clipboard (`Cmd-a` then `Cmd-c`)
  - `Cmd-Shift-P` to bring up preferences, then choose *Tasks: Open User Settings (JSON)* and paste the variables into your user settings file. You will need to edit the variables to reflect the parameters you want to pass to `grub_client`
    - *grub.server_root* is the root directory on your z/OS system that you want to clone your repository to.
    - *grub.server* is the ssh `Host` specification. See *ssh host specification* below for more details.
    - *grub.client_build_tool* is the absolute path to [grub_client](bin/grub_client) on your Desktop.
    - *grub.server_build_tool* is the absolute path to [grub_server](bin/grub_server) on your server.
    - *grub.server_git_dir* is the absolute path to the `git` program on your server.

On your z/OS userid:

- `cd $HOME/tools`
- `git clone git@github.com:MikeFultonDev/grub.git`

## Running GRUB from the command-line

- After installation, you can run the GRUB client:
  - by adding the GRUB `bin` directory to your PATH and then issuing: `grub_client <parameters>`
  - by running `grub_client` directly, e.g. `<GRUB-directory>/grub_client <parameters>`
- This will perform the following steps:
  - use *git* to synchronize the files to the server
  - run the remote build process on the server
  - transfer the output and errors to temporary files on your desktop

## Running GRUB from VSCode

- After installation
  - Open a file from the repository you want to build in VSCode
  - On a Mac, `Cmd-Shift-B` will launch the build and you can see the results in the terminal, as described in *Running GRUB from the command-line*.
  - On completion, you can hover over the output file name or the error file name, `Cmd-Left-Click` and the file will be shown in your editor.

## ssh host specification

GRUB uses an ssh Host specification to describe the userid and server to connect to. GRUB requires that the ssh `Host` specification includes at least a `HostName` and `User` specification, defined in your `.ssh/config` file in your `$HOME` directory. For example, if you wanted to create a host called `fultonm_zos`, where your userid is `fultonm`, and your server is `zos.ibm.com`, then you would have a section in your `.ssh/config` file as follows:

```(config)
Host fultonm_zos
  HostName zos.ibm.com
  User fultonm
```

It is strongly recommended that you configure a public/private key for communicating with the
server so that you won't be prompted for a password when connecting to the server.
