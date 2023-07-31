# Remote Neovim 

**remote-nvim.nvim** enables Neovim to be used for remote development using SSH.
* Target platform(s): Linux, MacOS and WSL
* Initial goal is to fully support Linux and MacOS. Support for WSL would come after that.

**Aim:** to bring near feature-parity with [Remote development using SSH - VS Code](https://code.visualstudio.com/docs/remote/ssh).

**🚧 This plugin is under active development and is not yet ready for use.  🚧**

## 🎁 Features

* Automatically install Neovim on remote server accessible over SSH
* Brings devcontainers to Neovim, when used together with [devpod](https://github.com/loft-sh/devpod)
* Copies over your Neovim configuration and starts Neovim with it, so that it behaves just like local
* Remembers your remote sessions; so you can start right away

## ☑️ Prerequisites

### On local machine
* Neovim >= 0.8.0
* An `OpenSSH` client

### On remote machine

* `bash` shell
* Access to internet
* Binaries: `curl` or `wget`, `tar` (if on MacOS)

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{ "amitds1997/remote-nvim.nvim", opts = {} }
```

### [packer](https://github.com/wbthomason/packer.nvim)

```lua
use { "amitds1997/remote-nvim.nvim" }
```

## ⚙️ Configuration

TBD

## Caveats

* We change the XDG_CONFIG_HOME env variable (only for the launched Neovim server) so any XDG_CONFIG_HOME based stuff you do from inside Neovim would have to be adjusted accordingly.

## Future goals

* [ ] Remote development inside docker container. This should be possible already with this plugin, if you use [devpod](https://github.com/loft-sh/devpod)
