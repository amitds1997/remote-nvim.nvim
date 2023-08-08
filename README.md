# Remote Neovim

**remote-nvim.nvim** enables Neovim to be used for remote development using SSH.

* Target platform(s): Linux, MacOS and WSL
* Initial goal is to fully support Linux and MacOS. Support for WSL would
come after that.

**Aim:** to bring near feature-parity with [Remote development using SSH - VS Code](https://code.visualstudio.com/docs/remote/ssh).

🚧 **This plugin is still experimental. Things might break.** 🚧

## 🎁 Features

* Automatically install Neovim on remote server accessible over SSH
* Brings devcontainers to Neovim, when used together with [devpod](https://github.com/loft-sh/devpod)
* Copies over your Neovim configuration and starts Neovim with it, so that it
behaves just like local
* Remembers your remote sessions; so you can start right away

## ☑️ Prerequisites

### On local machine

* Neovim >= 0.8.0
* An `OpenSSH` client
* Binaries: `curl`

### On remote machine

* `bash` shell
* Internet access
* Binaries: `curl` or `wget`, `tar` (if on MacOS)

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "amitds1997/remote-nvim.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      -- This would eventually be turned into an optional dependency
      "nvim-telescope/telescope.nvim",
    }
}
```

### [packer](https://github.com/wbthomason/packer.nvim)

```lua
use { "amitds1997/remote-nvim.nvim" }
```

## ⚙️ Configuration

These are the default configurations that `remote-nvim.nvim` starts with:

```lua
{
  ssh_config = {
    ssh_binary = "ssh",
    scp_binary = "scp",
    ssh_config_file_paths = { "$HOME/.ssh/config" },
    ssh_prompts = {
      {
        match = "password:",
        type = "secret",
        input_prompt = "Enter password: ",
        value_type = "static",
        value = "",
      },
      {
        match = "continue connecting (yes/no/[fingerprint])?",
        type = "plain",
        input_prompt = "Do you want to continue connection (yes/no)? ",
        value_type = "static",
        value = "",
      },
    },
  },
  neovim_install_script_path = util.path_join(util.is_windows,
  util.get_package_root(), "scripts", "neovim_install.sh"),
  remote_neovim_install_home = util.path_join(util.is_windows, "~", ".remote-nvim"),
  neovim_user_config_path = vim.fn.stdpath("config"),
  local_client_config = {
    -- modify this function to override how your client launches
    -- function should accept two arguments function(local_port, workspace_config)
    -- local_port is the port on which the remote server is available locally
    -- workspace_config contains the workspace config. For all attributes present
    -- in it, see WorkspaceConfig in ./lua/remote-nvim/config.lua.
    callback = nil,
    default_client_config = {
      col_percent = 0.9,
      row_percent = 0.9,
      win_opts = {
        winblend = 5,
      },
      border_opts = {
        topleft = "╭",
        topright = "╮",
        top = "─",
        left = "│",
        right = "│",
        botleft = "╰",
        botright = "╯",
        bot = "─",
      },
    },
  },

}
```

## Caveats

* Launched remote server is associated with the launching instance. Closing
that instance would close the remote server as well.
* We change the XDG_CONFIG_HOME env variable (only for the launched
Neovim server) so any XDG_CONFIG_HOME based stuff you do from inside
Neovim would have to be adjusted accordingly.
* Sometimes, some executables are not available and when the client starts,
you would see bare bones Neovim. Run `:messages` to check what happened.

## Future goals

* [ ] Remote development inside docker container. This should be possible
already with this plugin, if you use [devpod](https://github.com/loft-sh/devpod).
