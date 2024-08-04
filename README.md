# 🚀 Remote Nvim

Adds support for [remote development](https://code.visualstudio.com/docs/remote/remote-overview)
and [devcontainers](https://code.visualstudio.com/docs/devcontainers/containers)
to Neovim (just like VSCode). Read in the [FAQ](#faq) at the end of this document why you would prefer
using remote-nvim instead of SSH into remote + local neovim.

> [!WARNING]
> This plugin has not yet reached maturity. So, breaking changes are expected. Any such change would be
> communicated through [this GitHub discussion](https://github.com/amitds1997/remote-nvim.nvim/discussions/78).
>
> The author appreciates if you can drop by and suggest any changes you would like to see in the plugin
> to improve it further.

## ✨ Features

| Remote mode                   | Current support     |
| ----------------------------- | ------------------- |
| SSH (using password)          | _Fully supported_ ✅ |
| SSH (using SSH key)           | _Fully supported_ ✅ |
| SSH (using `ssh_config` file) | _Fully supported_ ✅ |
| Docker image [^1]             | _Fully supported_ ✅ |
| Docker container [^1]         | _Fully supported_ ✅ |
| Devcontainer [^1]             | _Fully supported_ ✅ |

See [Demos](#-demos) for how to work with your particular use case.

[Remote Tunnels](https://code.visualstudio.com/docs/remote/tunnels)
is a Microsoft-specific features and will not be supported. If
you have an alternative though, I would be happy to integrate it into the plugin.

### Implemented features

- **Offline mode** - If the remote does not have access to GitHub, Neovim release can be locally
  downloaded and then transferred to the remote. For more details, see [Offline mode](#-offline-mode).
- **Alternate install methods** - If Neovim is not available for your OS and/or arch, you can
  build it from source or use Neovim installed globally on remote. Make sure you have the pre-requisites mentioned
  in [BUILD.md](https://github.com/neovim/neovim/blob/master/BUILD.md) already installed on remote so that the
  build process does not break.

#### ✨ Other noice features

- Automatically install and launch Neovim
- No changes to your remote environment
- Can copy over and sync your local Neovim configuration to remote
- Saves your past sessions automatically so you can easily reconnect
- Easily cleanup the remote machine once you are done with a single command

See [#126](https://github.com/amitds1997/remote-nvim.nvim/issues/126) for the list of planned but not yet implemented
features.

## 📜 Requirements

### OS support

| Support level           | OS                         |
| ----------------------- | -------------------------- |
| ✅ **Supported**         | Linux, MacOS, FreeBSD [^2] |
| 🟡 **Not supported yet** | Windows, WSL               |

### Local machine 💻

- OpenSSH client
- Neovim >= 0.9.0 (as `nvim`)
- Binaries
  - `curl`
  - `tar` (optional; if you use compressed uploads)
  - [`devpod`](https://devpod.sh/docs/getting-started/install#optional-install-devpod-cli) >= 0.5.0 (optional;
  if you want to use devcontainer)
- Connectivity to [neovim repo](https://github.com/neovim/neovim) on GitHub

Connectivity to [neovim repo](https://github.com/neovim/neovim) on GitHub is not needed when using
[Offline mode (No GitHub)](#offline-on-remote-and-local-machine) but it comes with
it's own trade offs.

### Remote machine ☁️

- OpenSSH-compliant SSH server
- `bash` shell must be available
- Connectivity to [neovim repo](https://github.com/neovim/neovim) on GitHub
- Binaries
  - `bash`
  - `curl` or `wget`

Connectivity to [neovim repo](https://github.com/neovim/neovim) on GitHub is not needed when using
[Offline mode](#-offline-mode).

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

_Ensure you have [devpod](https://devpod.sh/docs/getting-started/install#optional-install-devpod-cli) >= 0.5.0
installed for any devcontainer-related features to work_

If you use any other plugin manager, ensure that you call `require("remote-nvim").setup()`.

> [!NOTE]
>
> Run `:checkhealth remote-nvim` to ensure necesssary binaries are available. If missing,
> parts of the plugin might be broken.

## ⚙️ Advanced configuration

Below is the default configuration. Set only things that you wish to change in your `setup()` call.
Please read the associated comments before changing the value.

```lua
 {
  -- Configuration for devpod connections
  devpod = {
    binary = "devpod", -- Binary to use for devpod
    docker_binary = "docker", -- Binary to use for docker-related commands
    ---@diagnostic disable-next-line:param-type-mismatch
    ssh_config_path = utils.path_join(utils.is_windows, vim.fn.stdpath("data"), constants.PLUGIN_NAME, "ssh_config"), -- Path where devpod SSH configurations should be stored
    search_style = "current_dir_only", -- How should devcontainers be searched
    -- For dotfiles, see https://devpod.sh/docs/developing-in-workspaces/dotfiles-in-a-workspace for more information
    dotfiles = {
        path = nil, -- Path to your dotfiles which should be copied into devcontainers
        install_script = nil -- Install script that should be called to install your dotfiles
    },
    gpg_agent_forwarding = false, -- Should GPG agent be forwarded over the network
    container_list = "running_only", -- How should docker list containers ("running_only" or "all")
  },
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
      -- There are other values here which can be checked in lua/remote-nvim/init.lua
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
    app_name = "nvim", -- This directly maps to the value NVIM_APPNAME. If you use any other paths for configuration, also make sure to set this.
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

## 🎥 Demos

> [!TIP]
>
> By default, this plugin launches your remote neovim client in a popup window.
> This _mostly_ works fine. For a better experience though, it is recommended
> that you add a custom callback to launch your Neovim client [in a separate
> tab/window for your terminal](https://github.com/amitds1997/remote-nvim.nvim/wiki/Configuration-recipes)
> or [GUI app](https://github.com/amitds1997/remote-nvim.nvim/issues/118#issuecomment-2100529883).

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
<summary><b>Launch current `.devcontainer` based project in a devcontainer</b></summary>

[Launch a local .devcontainer project in a
devcontainer](https://github.com/amitds1997/remote-nvim.nvim/assets/29333147/1a274a93-f1ab-4369-90e6-bbe0efcd71c9)

</details>

<details>
<summary><b>Launch a docker image as a devcontainer</b></summary>

[Launch docker image as a
devcontainer](https://github.com/amitds1997/remote-nvim.nvim/assets/29333147/98352663-a145-4948-93f7-70d5403c7ef4)

</details>

<details>
<summary><b>Attach to a running docker container</b></summary>

[Attach to a running docker
container](https://github.com/amitds1997/remote-nvim.nvim/assets/29333147/4fda15fa-e2ca-45b1-811b-c87472278835)

</details>

<details>
<summary><b>Launch a remote repo as a devcontainer</b></summary>

[Launch git repo in a
devcontainer](https://github.com/amitds1997/remote-nvim.nvim/assets/29333147/5d4b294e-7269-4bbb-a168-cd9dcdb6686e)

</details>

<details>
<summary><b>Launch any git branch in a devcontainer</b></summary>

[Launch git branch in a
devcontainer](https://github.com/amitds1997/remote-nvim.nvim/assets/29333147/ba6c0db9-f3c0-403a-b62d-b1e5ac7762ef)

</details>

<details>
<summary><b>Launch any git commit in a devcontainer</b></summary>

[Launch git commit in a
devcontainer](https://github.com/amitds1997/remote-nvim.nvim/assets/29333147/926b076b-45ec-4603-bd27-13dc270c7e51)

</details>
<details>
<summary><b>Launch PR in a devcontainer</b></summary>

[Launch any git repo-based PR in a
devcontainer](https://github.com/amitds1997/remote-nvim.nvim/assets/29333147/29aaa26b-697b-4ee1-962d-75cc70299ae5)

</details>

<details>
<summary><b>Connect to any existing devpod workspace</b></summary>

[Launch any existing devpod workspace inside a
devcontainer](https://github.com/amitds1997/remote-nvim.nvim/assets/29333147/a43f932e-264a-4819-ab54-83348a82a5b1)

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

## 🥨 Integration with statusline

The plugin sets the variable `vim.g.remote_neovim_host` to `true` on the remote Neovim instance. This can be used to add
useful information regarding the remote system to your statusline.

Here's an example about adding a component in [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) to show the
remote hostname when connected to a remote instance.

```lua
lualine_b = {
    ..., -- other components
    {
        function()
        return vim.g.remote_neovim_host and ("Remote: %s"):format(vim.uv.os_gethostname()) or ""
        end,
        padding = { right = 1, left = 1 },
        separator = { left = "", right = "" },
    },
    ..., -- other componenents
}
```

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
./scripts/neovim_download.sh -v <version> -d <cache-dir> -o <os-type> -a <arch-type> -t <release-type>

# <version> can be stable, nightly or any Neovim release provided like v0.9.4
# <cache-dir> is the path in which the Neovim release and it's checksum should be downloaded. This should be same as the cache_dir plugin configuration value else it won't be
# detected by the plugin. See configuration below.
# <os-type> specifies which OS's binaries should be downloaded. Supported values are "Linux" and "macOS"
# <arch-type> is the host's architecture. Can be `x86_64` or `arm64`
# <release-type> is type of release to download. Can be `binary` or `source`
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

## FAQ

### Why would I use this plugin instead of the usual ssh + nvim?

This plugins provide some additional nice-to have features on top:

- Automatically installs Neovim on remote
- Does not mess with the global configuration and instead just writes everything to a single directory on remote
- Can copy over your local Neovim configuration to remote
- Allows easy re-connection to past sessions
- Makes it easy to clean up remote machine changes once you are done
- It launches Neovim server on the remote server and connects a UI to it locally. 

You can read more in [this Neovim discussion](https://github.com/amitds1997/remote-nvim.nvim/discussions/145)

## 🌟 Credits

**_A big thank you to the amazing Neovim community for Neovim and the plugins! ❤️_**

## 📓 Footnotes

[^1]: _Ensure you have [devpod](https://devpod.sh/docs/getting-started/install#optional-install-devpod-cli) >= 0.5.0 installed for this to work_

[^2]: _Supports building from source or using already installed Neovim on remote host_
