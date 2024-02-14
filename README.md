# 🚀 Remote Nvim

Adds support for [remote development](https://code.visualstudio.com/docs/remote/remote-overview)
and [devcontainers](https://code.visualstudio.com/docs/devcontainers/containers)
to Neovim (just like VSCode).

_**This plugin has not yet reached maturity. So, breaking changes are expected. Any such change would be
communicated through [this GitHub discussion](https://github.com/amitds1997/remote-nvim.nvim/discussions/78).**_

## ✨ Features

| Remote mode                   | Current support                                                               |
| ----------------------------- | ----------------------------------------------------------------------------- |
| SSH (using password)          | _Fully supported_ ✅                                                           |
| SSH (using SSH key)           | _Fully supported_ ✅                                                           |
| SSH (using `ssh_config` file) | _Fully supported_ ✅                                                           |
| Docker image                  | _In progress_ ([#66](https://github.com/amitds1997/remote-nvim.nvim/pull/66)) |
| Docker container              | _In progress_ ([#66](https://github.com/amitds1997/remote-nvim.nvim/pull/66)) |
| Devcontainer                  | _In progress_ ([#66](https://github.com/amitds1997/remote-nvim.nvim/pull/66)) |

[Remote Tunnels](https://code.visualstudio.com/docs/remote/tunnels)
is a Microsoft-specific features and will not be supported. If
you have an alternative though, I would be happy to integrate it into the plugin.

### Implemented features

- **Offline mode** - If the remote does not have access to GitHub, Neovim release can be locally
  downloaded and then transferred to the remote. For more details, see [Offline mode](#-offline-mode).

### Planned features

- **Dynamic port forwarding** - I already have a clear path to implementing this,
  but waiting for complete support for devcontainers to be present and then
  integrate this. For tracking, see [#77](https://github.com/amitds1997/remote-nvim.nvim/issues/77).
  For more feature details, see [similar implementation in
  VSCode](https://code.visualstudio.com/docs/devcontainers/containers#_temporarily-forwarding-a-port).

<details>
<summary><b>✨ Other noice features</b></summary>

- Automatically install and launch Neovim
- No changes to your remote environment
- Can copy over and sync your local Neovim configuration to remote
- Saves your past sessions automatically so you can easily reconnect
- Easily cleanup the remote machine once you are done with a single command

</details>

## 📜 Requirements

### OS support

| Support level                     | OS                                                                      |
| --------------------------------- | ----------------------------------------------------------------------- |
| ✅ **Supported**                   | Linux, MacOS                                                            |
| 🚧 **In progress**                 | FreeBSD ([#71](https://github.com/amitds1997/remote-nvim.nvim/pull/71)) |
| 🟡 **Planned but not implemented** | Windows, WSL                                                            |

### Local machine 💻

- OpenSSH client
- Neovim >= 0.9.0 (as `nvim`)
- Binaries: `tar` (if you use compressed uploads)

Following are also needed unless you are working with [Offline mode (No GitHub)](#offline-on-remote-and-local-machine):

- Binaries: `curl`
- Connectivity to [neovim repo](https://github.com/neovim/neovim) on GitHub

### Remote machine ☁️

- OpenSSH-compliant SSH server
- `bash` shell must be available

Following are also needed unless you are working with [Offline mode](#-offline-mode):

- Binaries: `curl` or `wget`
- Connectivity to [neovim repo](https://github.com/neovim/neovim) on GitHub

## 📥 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
   "amitds1997/remote-nvim.nvim",
   version = "*", -- Pin to GitHub releases
   dependencies = {
       "nvim-lua/plenary.nvim", -- For standard functions
       "MunifTanjim/nui.nvim", -- To build the plugin UI
       "nvim-telescope/telescope.nvim", -- For picking b/w different remote methods
   },
   config = true,
}
```

If you use any other plugin manager, ensure that you call `require("remote-nvim").setup()`.

<details>
<summary><b>⚙️ Advanced configuration</b></summary>

Below is the default configuration. Please read the associated comments before changing the value.

```lua
 {
  -- Configuration for SSH connections
  ssh_config = {
    ssh_binary = "ssh", -- Binary to use for running SSH command
    scp_binary = "scp", -- Binary to use for running SSH copy commands
    ssh_config_file_paths = { "$HOME/.ssh/config" }, -- Which files should be considered to contain the ssh host configurations. NOTE: `Include` is respected in the provided files.

    -- These are useful for password-based SSH authentication.
    -- It provides parsing pattern for the plugin to detect that an input is requested.
    -- Each element contains the following attributes:
    -- match - The string to match (plain matching is done)
    -- type - Supports two values "plain"|"secret". Secret means when you provide the value, it should not be stored in the completion history of Neovim.
    -- value - Default value for the prompt
    -- value_type - "static"|"dynamic". For things like password, it would be needed for each new connection that the plugin initiates which could be obtrusive.
    -- So, we save the value (only for current session's interval) to ease the process. If set to "dynamic", we do not save the value even for the session. You have to provide a fresh value each time.
    ssh_prompts = {
      {
        match = "password:",
        type = "secret",
        value_type = "static",
        value = "",
      },
      {
        match = "continue connecting (yes/no/[fingerprint])?",
        type = "plain",
        value_type = "static",
        value = "",
      },
    },
  },

  -- Path to the script that would be copied to the remote and called to ensure that neovim gets installed.
  -- Default path is to the plugin's own ./scripts/neovim_install.sh file.
  neovim_install_script_path = utils.path_join(
    utils.is_windows,
    vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h"),
    "scripts",
    "neovim_install.sh"
  ),

  -- Modify the UI for the plugin's progress viewer.
  -- type can be "split" or "popup". All options from https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/popup and https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/split are supported.
  -- Note that some options like "border" are only available for "popup".
  progress_view = {
    type = "popup",
  },


  -- Offline mode configuration. For more details, see the "Offline mode" section below.
  offline_mode = {
    -- Should offline mode be enabled?
    enabled = false,
    -- Do not connect to GitHub at all. Not even to get release information.
    no_github = false,
    -- What path should be looked at to find locally available releases
    cache_dir = utils.path_join(utils.is_windows, vim.fn.stdpath("cache"), constants.PLUGIN_NAME, "version_cache"),
  },

  -- Remote configuration
  remote = {
    -- List of directories that should be copied over
    copy_dirs = {
      -- What to copy to remote's Neovim config directory
      config = {
        base = vim.fn.stdpath("config"), -- Path from where data has to be copied
        dirs = "*", -- Directories that should be copied over. "*" means all directories. To specify a subset, use a list like {"lazy", "mason"} where "lazy", "mason" are subdirectories
        -- under path specified in `base`.
        compression = {
          enabled = false, -- Should compression be enabled or not
          additional_opts = {} -- Any additional options that should be used for compression. Any argument that is passed to `tar` (for compression) can be passed here as separate elements.
        },
      },
      -- What to copy to remote's Neovim data directory
      data = {
        base = vim.fn.stdpath("data"),
        dirs = {},
        compression = {
          enabled = true,
        },
      },
      -- What to copy to remote's Neovim cache directory
      cache = {
        base = vim.fn.stdpath("cache"),
        dirs = {},
        compression = {
          enabled = true,
        },
      },
      -- What to copy to remote's Neovim state directory
      state = {
        base = vim.fn.stdpath("state"),
        dirs = {},
        compression = {
          enabled = true,
        },
      },
    },
  },

  -- You can supply your own callback that should be called to create the local client. This is the default implementation.
  -- Two arguments are passed to the callback:
  -- port: Local port at which the remote server is available
  -- workspace_config: Workspace configuration for the host. For all the properties available, see https://github.com/amitds1997/remote-nvim.nvim/blob/main/lua/remote-nvim/providers/provider.lua#L4
  -- A sample implementation using WezTerm tab is at: https://github.com/amitds1997/remote-nvim.nvim/wiki/Configuration-recipes
  client_callback = function(port, _)
    require("remote-nvim.ui").float_term(("nvim --server localhost:%s --remote-ui"):format(port), function(exit_code)
      if exit_code ~= 0 then
        vim.notify(("Local client failed with exit code %s"):format(exit_code), vim.log.levels.ERROR)
      end
    end)
  end,

  -- Plugin log related configuration [PREFER NOT TO CHANGE THIS]
  log = {
    -- Where is the log file
    filepath = utils.path_join(utils.is_windows, vim.fn.stdpath("state"), ("%s.log"):format(constants.PLUGIN_NAME)),
    -- Level of logging
    level = "info",
    -- At what size, should we truncate the logs
    max_size = 1024 * 1024 * 2, -- 2MB
  },
}
```

</details>

> [!NOTE]
> Run `:checkhealth remote-nvim.nvim` to ensure necesssary binaries are available. If missing,
> parts of the plugin might be broken.

## 🎥 Demos

<details>
<summary><b>How to connect to saved host using SSH config file</b></summary>

[Remote with SSH
config file](https://github.com/amitds1997/remote-nvim.nvim/assets/29333147/6cd2f3fc-3dcc-482f-a6ae-373084d36ca5)

</details>

<details>
<summary><b>How to connect to SSH server with password based auth</b></summary>

[Remote with
password](https://github.com/amitds1997/remote-nvim.nvim/assets/29333147/be9bfc0c-6a7c-4304-a68d-3b75256afea6)

</details>

<details>
<summary><b>Stop running Neovim server</b></summary>

This continues from the _How to connect to saved host using SSH config file_ demo above.

[Stop running remote Neovim
session](https://github.com/amitds1997/remote-nvim.nvim/assets/29333147/b2603583-c80a-41e5-b94e-9e80c56d557c)

Alternatively, just exit from the Neovim instance using which you launched the server.

</details>

<details>
<summary><b>Get information about any Remote Neovim launched session</b></summary>

[Get information about Remote
Neovim session](https://github.com/amitds1997/remote-nvim.nvim/assets/29333147/ceb24934-a132-4d0c-8172-7ba58679c467)

</details>

<details>
<summary><b>Delete this plugin's created resources from the remote machine</b></summary>

This deletes the resources created during the _How to connect to saved host using SSH config file_ demo above.

[Delete all resources created by
this plugin](https://github.com/amitds1997/remote-nvim.nvim/assets/29333147/3896dda5-b73f-47e4-8e56-72f661e1a623)

</details>

<details>
<summary><b>Delete saved configuration about a remote host</b></summary>

We disabled connectivity to the host we connected to in _How to connect to SSH server with password based auth_
to replicate this scenario.

[Delete saved remote
configuration](https://github.com/amitds1997/remote-nvim.nvim/assets/29333147/a7f2a9b0-3d04-4c7b-9cea-4fa2a2efdf15)

</details>

<details>
<summary><b><i>Youtube video going over an older version of the plugin</i></b></summary>

[![Tutorial for remote-nvim.nvim plugin v0.0.1](http://img.youtube.com/vi/5qbDq1lGEx4/0.jpg)
](http://www.youtube.com/watch?v=5qbDq1lGEx4 "Remote development on Neovim using
remote-nvim.nvim")

</details>

All these demos use a custom callback that I use to launch Neovim [in a separate Wezterm
tab](https://github.com/amitds1997/remote-nvim.nvim/wiki/Configuration-recipes).

## 🤖 Available commands

| Command            | What does it do?                                                                                                                                            |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `:RemoteStart`     | Connect to a remote instance. If remote neovim server is already running, allows users to launch local client?                                              |
| `:RemoteStop`      | Stop running Neovim server and close session                                                                                                                |
| `:RemoteInfo`      | Get information about any sessions created in the current Neovim run. Opens up the Progress Viewer.                                                         |
| `:RemoteCleanup`   | Delete workspace and/or entire remote neovim setup from the remote instance. Also, cleanups the configuration for the remote resource.                      |
| `:RemoteConfigDel` | Delete record of remote instance that no longer exists from saved session records. Prefer `:RemoteCleanup` if you can still connect to the remote instance. |
| `:RemoteLog`       | Open the plugin log file. This is most useful when debugging. `:RemoteInfo` should surface all information needed. If not, open an issue.                   |

For demos about the commands, see the [demos](#-demos) section.

## 📴 Offline mode

There are two types of offline modes available:

1. Offline on remote
2. Offline on remote and local machine

The plugin connects to [neovim/neovim](https://github.com/neovim/neovim) repo on GitHub twice. First time, it tries to
fetch the latest releases available for Neovim that can be installed to the remote. The second time, on the
remote machine, it connects to download the Neovim release.

### Offline on remote

On enabling this, Neovim release will be downloaded locally and then copied over to the remote. Plugin would
connect to GitHub once to get the list of Neovim versions available. To enable this,

```lua
require("remote-nvim").setup({
  -- Add your other configuration parameters as usual
  offline_mode = {
    enabled = true,
    no_github = false,
  },
})
```

### Offline on remote and local machine

On enabling this, GitHub will not be connected with at all. This is useful for scenarions when you face connection
issues with GitHub. _**This is an advanced scenario so make sure that you actually need it**_.

It assumes that you already have Neovim releases available locally along with their checksum files. Note that, _release
names are expected to follow a certain pattern._ So, please use the provided script to download releases and drop them
in the cache directory where the plugin would read from. If no releases are available, the plugin would not be able to
proceed further.

**Steps for downloading releases:** This command is run from the plugin's root. You can run it from anywhere as long as
you have the correct path to the script. Adjust script path as per where the plugin gets installed on your system.
Alternatively, you can also clone the repo at a separate location and run this script from inside the cloned repo.

```bash
./scripts/neovim_download.sh -v <version> -d <cache-dir> -o <os-type>

# <version> can be stable, nightly or any Neovim release provided like v0.9.4
# <cache-dir> is the path in which the Neovim release and it's checksum should be downloaded. This should be same as the cache_dir plugin configuration value else it won't be
# detected by the plugin. See configuration below.
# <os-type> specifies which OS's binaries should be downloaded. Supported values are "Linux" and "macOS"
```

To enable this,

```lua
require("remote-nvim").setup({
  -- Add your other configuration parameters as usual
  offline_mode = {
    enabled = true,
    no_github = true,
    -- Add this only if you want to change the path where the Neovim releases are downloaded/located.
    -- Default location is the output of :lua= vim.fn.stdpath("cache") .. "/remote-nvim.nvim/version_cache"
    -- cache_dir = <custom-path>,
  },
})
```

#### Copying additional directories to remote neovim

Above process would prevent the plugin (remote-nvim.nvim) from connecting to GitHub, but nothing is stopping the
plugins defined in your configuration from connecting to the internet. To prevent this, you can copy your other
Neovim directories onto the remote to prevent at least your plugin manager from doing so since all your dependencies
would already be in their right locations. Note: _some plugins such as nvim-treesitter might still connect to the
internet and there is nothing this plugin can do to restrict that (and neither does this plugin aim to do that)_.
In such cases, you have 3 alternatives:

1. Turn off the plugin
2. Make configuration changes (if possible) for it to not connect to internet
3. Find an alternative to that plugin

To turn off the plugin only on remote instances, one simple condition would be to check if Neovim is running in
`headless` mode (That's how this plugin launches your remote neovim instance).

With that out of the way, let's focus on how you can copy additional Neovim directories onto remote.

```lua
require("remote-nvim").setup({
  remote = {
    copy_dirs = {
      data = {
        base = vim.fn.stdpath("data"), -- Path from where data has to be copied. You can choose to copy entire path or subdirectories inside using `dirs`
        dirs = { "lazy" }, -- Directories inside `base` to copy over. If this is set to string "*"; it means entire `base` should be copied over
        compression = {
          enabled = true, -- Should data be compressed before uploading
          additional_opts = { "--exclude-vcs" }, -- Any arguments that can be passed to `tar` for compression can be specified here to improve your compression
        },
      },
      -- cache = {
      --   base = vim.fn.stdpath("cache"),
      --   dirs = {},
      --   compression = {
      --     enabled = true,
      --   },
      -- },
      -- state = {
      --   base = vim.fn.stdpath("state"),
      --   dirs = {},
      --   compression = {
      --     enabled = true,
      --   },
      -- },
    },
  },
})
```

The above configuration indicates that the `lazy` directory inside your Neovim `data` directory should be copied over
onto the remote in it's `data` directory. You can similarly specify what should be copied inside the `data`, `state`,
`cache` or `config` directory on remote.

If specified directories are going to contain a lot of data, it's _highly recommended_ to enable compression when
uploading by setting `compression.enabled` to `true` for those particular uploads.

## ⚠️ Caveats

- Launched neovim server is bound to the Neovim instance from which it is launched. If you close the instance,
  the remote Neovim server will also get closed. This has been done to ensure proper cleanup of launched sessions
  and prevent orphan Neovim servers.
- The current implementation launches a headless server on the remote machine and then launches a TUI to connect
  to it. This means that if you quit the TUI using regular operations, the server also gets closed. If you just want
  to close the TUI, that is currently not possible. You can read more in [this Neovim
  discussion](https://github.com/neovim/neovim/issues/23093).
- Neovim versions `< v0.9.2` are incompatible with versions `>= v0.9.2` due to a breaking UI change introduced in
  `v0.9.2`. For more information, read the [release notes for
  v0.9.2](https://github.com/neovim/neovim/releases/tag/v0.9.2).

## 🌟 Credits

**_A big thank you to the amazing Neovim community for Neovim and the plugins! ❤️_**
