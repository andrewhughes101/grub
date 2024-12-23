# grub: git remote user build

The git remote user build requires code on both the client and server, consisting of:

- [grub_client](bin/grub_client): a script to drive a git remote user build from your desktop.
- [grub_server](bin/grub_server): a script driven by *grub_client* on the target server.
- [grub_server.bash](bin/grub_server.bash): a helper script driven by *grub_server* on the target server.
- [tasks.json](sample/tasks.json): a sample *tasks.json* that you can optionally use for a VSCode repository build task.

## Installation

You need to install grub on the client(s) and server(s) that you want to do remote builds with.
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
- Set your GRUB variables for VSCode
  - Copy the contents of [grub_variables.json](sample/grub_variables.json) into the clipboard (`Cmd-a` then `Cmd-c`)
  - Cmd-Shift-P to bring up preferences, then choose *Tasks: Open User Settings (JSON)* and paste the variables into your user settings file. You will need to edit the variables to reflect the parameters you want to pass to `grub_client`
- For each repository that you want to run *grub* on:
  - Copy the sample [tasks.json](sample/tasks.json) into the root directory of your repository.
  - Cmd-Shift-P to bring up preferences, then choose *Tasks: Configure default build task* and choose GRUB as the default build task.

On your z/OS userid:

- `cd $HOME/tools`
- `git clone git@github.com:MikeFultonDev/grub.git`
