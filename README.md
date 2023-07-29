# Remote Neovim 

**remote-nvim.nvim** enables Neovim to be used for remote development using SSH. It targets Linux, MacOS and WSL.

It aims to bring near feature-parity with [Remote development using SSH - VS Code](https://code.visualstudio.com/docs/remote/ssh).

🚧 This plugin is under active development and is not yet ready for use.  🚧

## Prerequisites

* Neovim >= 0.8.0

## Caveats

- We change the XDG_CONFIG_HOME env variable (only for the launched Neovim server) so any XDG_CONFIG_HOME based stuff you do from inside Neovim would have to be adjusted accordingly.

## Future goals

- [ ] Add support for remote development directly within a docker container
