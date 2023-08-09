# 🚀 Remote Nvim - Remote development in Neovim

**remote-nvim.nvim** brings the [Remote development using SSH](https://code.visualstudio.com/docs/remote/ssh)
in VSCode to Neovim. If you use this plugin along with [devpod](https://github.com/loft-sh/devpod),
this also enables Dev Containers development natively from Neovim using this
plugin.

Plugin has been tested to work on Linux and MacOS. WSL and Windows support is
planned (Author does not currently have access to Windows machine so contributions
are welcome).

🚧 **This plugin is still experimental. Breaking changes are expected (not a
lot though).** 🚧

## 📜 Requirements

### On your local machine 💻

1. An OpenSSH client.
2. Neovim >= 0.8.0
3. Binaries: **curl**
4. Following plugins:
    1. [nui.nvim](https://github.com/MunifTanjim/nui.nvim) - For UI elements
    2. [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - For standard
    functions
    3. [nvim-notify](https://github.com/rcarriga/nvim-notify) - For progress notifications
    4. [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) -
    For telescope extension (also the current default setup UI)

### On your remote machine ☁️

1. A running OpenSSH compliant server
2. Access to internet (to download Neovim)
3. Binaries: **curl** or **wget**; **tar** (if your remote machine is MacOS)

## ✨ Features

- [x] Automatic installation of Neovim on remote
- [x] Automatic copying over your local Neovim configuration
- [x] Remember past sessions so that we can easily connect back to them
- [x] Control over how to launch your local client
- [x] Support for password-based SSH authentication
- [x] Automatic syncing of your local Neovim config on next run (or not, if you
so choose!)
- [x] Support to pick up hosts from your SSH configs
- [x] Support to clean up everything on your remote
- [x] Support for dev containers (using [devpod](https://github.com/loft-sh/devpod))
- [ ] Remote development inside Docker container
- [ ] Complete installation over SSH (without using internet on remote;
basically download locally and copy over the installation over SSH)

## 📥 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
   "amitds1997/remote-nvim.nvim",
   dependencies = {
       "nvim-lua/plenary.nvim",
       "MunifTanjim/nui.nvim",
       "rcarriga/nvim-notify",
       -- This would be an optional dependency eventually
       "nvim-telescope/telescope.nvim",
   }
}
```

After installation, run `:checkhealth remote-nvim` to verify that you have everything
you need.

## ⚙️ Configuration

These are the default values. Alter them as needed for your personal use.

```lua
{
  -- Configuration for SSH connections made using this plugin
  ssh_config = {
  -- Binary with this name would be searched on your runtime path and would be
  -- used to run SSH commands. Rename this if your SSH binary is something else
    ssh_binary = "ssh",
    -- Similar to `ssh_binary`, but for copying over files onto remote server
    scp_binary = "scp",
    -- All your SSH config file paths.
    ssh_config_file_paths = { "$HOME/.ssh/config" },
    -- This helps the plugin to understand when the underlying binary expects
    -- input from user. This is useful for password-based authentication and
    -- key-based authentication.
    -- Explanation for each prompt:
    -- match - string - This would be matched with the SSH output to decide if
    -- SSH is waiting for input. This is a plain match (not a regex one)
    -- type - string - Takes two values "secret" or "plain". "secret" indicates
    -- that the value you would enter is a secret and should not be logged into
    -- your input history
    -- input_prompt - string - What is the input prompt that should be shown to
    -- user when this match happens
    -- value_type - string - Takes two values "static" and "dynamic". "static"
    -- means that the value can be cached for the same prompt for future commands
    -- (e.g. your password) so that you do not have to keep typing it again and
    -- again. This is retained in-memory and is not logged anywhere. When you
    -- close the editor, it is cleared from memory. "dynamic" is for something
    -- like MFA codes which change every time.
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
  -- Installation script location on local machine (If you have your own custom
  -- installation script and you do not want to use the packaged install script.
  -- It should accept the same inputs as the packaged install script though)
  neovim_install_script_path = util.path_join(util.is_windows,
  util.get_package_root(), "scripts", "neovim_install.sh"),
  -- Where should everything that Remote Neovim does on remote be stored. By
  -- default, it stores everything inside ~/.remote-nvim so as long as you
  -- delete that folder, you essentially wipe out everything that remote-nvim
  -- has over there.
  remote_neovim_install_home = util.path_join(util.is_windows, "~", ".remote-nvim"),
  -- Where is your personal Neovim config stored?
  neovim_user_config_path = vim.fn.stdpath("config"),
  local_client_config = {
    -- modify this function to override how your client launches
    -- function should accept two arguments function(local_port, workspace_config)
    -- local_port is the port on which the remote server is available locally
    -- workspace_config contains the workspace config. For all attributes present
    -- in it, see WorkspaceConfig in ./lua/remote-nvim/config.lua.
    callback = nil,
    -- [Subject to change]: These values may be subject to change, so there
    -- might be a breaking change. Right now, it uses the [plenary.nvim#win_float.percentage_range_window](https://github.com/nvim-lua/plenary.nvim/blob/267282a9ce242bbb0c5dc31445b6d353bed978bb/lua/plenary/window/float.lua#L138C25-L138C25)
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

## 📌 Usage

Following user commands are available.

### RemoteStart

Used to setup/start session on a remote host. It can optionally take an input as
one of your earlier saved host configuration to make start faster. If ran without
an option, it launched a Telescope extension that guides you towards creating a
remote session.

### RemoteStop

The plugin allows you to stop the remote server that was launched on a host.
Takes an argument from any of the running sessions.

### RemoteLog

See the plugin log file to see what the plugin is doing. It does not log much,
until you drop to the debug level. To start logging in debug level, start your
Neovim instance as `REMOTE_NVIM_LOG_LEVEL="debug" nvim`

### RemoteSessionInfo

Provides you a view of all your currently running sessions. In case, you decided
not to start a client, the connection string that can be used to connect to any
of the running remote servers also shows up on this info box.

### RemoteCleanup

If you decide that you want to clean up remote neovim from a host or are in a
situation where you need to start afresh, you can use this command. It takes as
an argument input the remote host that you want to cleanup. Once you cleanup, it
deletes the local saved configuration for the host, so next time, you can start
afresh.

### RemoteConfigDel

Sometimes, you are working on a remote instance and that remote instance is no
longer there. And you have this one config just left in there that keeps nagging
you. This takes any number of arguments where each argument is a saved workspace
configuration that you want to delete from your local. Think of this as your
Remote Neovim sweeping broom.

## ⚠️ Caveats

- Just because how Neovim server and client currently work, it is not possible
to deterministically close a TUI so in case you do a `:q`, the server and the
client both die. You can read the [discussion here](https://github.com/neovim/neovim/issues/23093)
to figure out your own way forward to just close a TUI or else just relaunch the
session using `:RemoteStart`. It should be fast, after setup, if you are on a
good network.
- When we launch the remote server, it is associated with the Neovim instance it
is launched from. Closing that Neovim instance would close the server as well.
- This plugin does not introduce any changes in your PATH variables on remote
server. Instead it runs with by modifying the `XDG_*` variables when launching
your remote Neovim instance so that your entire data is contained inside your
remote neovim folder. So, take care when using any operations that depend on it.
- Sometimes, our Neovim configurations are buggy and when your client launches,
you would see a fresh, clean Neovim installation (assuming you copied your
Neovim config over). This is no fault with the plugin. Run `:messages` to see
what went wrong. Usually, `git` or some other important binary is not available
on the remote in some docker systems.

## Credits

I have learnt a lot from all the different plugins; and want to extend a thank
you to all the plugin authors. You all are awesome ❤️

The package structure, CIs have been borrowed with some modifications from the
[lazy.nvim](https://github.com/folke/lazy.nvim/) plugin.
