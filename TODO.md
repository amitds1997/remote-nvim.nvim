# To-do list

- [ ] Add Neovim documentation
- [ ] Add unit tests
- [ ] Add logging
- [ ] Rectify path detection logic
- [ ] Add progress bar notification
- [ ] Add tutorial videos
- [ ] Fix remote system path style detection code
- [ ] Make testing SSH connection async
- [ ] Add EmmyLua annotations
- [ ] Handle Neovim already exists on remote machine scenario
- [ ] If there are additional saved hosts and workspaces, show them too
- [ ] If the neovim version was downloaded and setup more than
a month back, re-install it.
- [ ] Add CHANGELOG
- [ ] Add [selene](https://github.com/Kampfkarren/selene/pull/541) check
in pre-commit once it's available
- Add templates for (example: [Noice.nvim](https://github.com/folke/noice.nvim/tree/main/.github/ISSUE_TEMPLATE))
  - [ ] Bug report
  - [ ] Feature request
- Add Github actions
  - [ ] Add test runner. Example. [Noice.nvim](https://github.com/folke/noice.nvim/blob/main/.github/workflows/ci.yml)
  - [ ] Add documentation step. Example: [Noice.nvim](https://github.com/folke/noice.nvim/blob/main/.github/workflows/ci.yml#L29-L48)
  - [ ] Add release step. Example. [Noice.nvim](https://github.com/folke/noice.nvim/blob/main/.github/workflows/ci.yml)
- Add more commands
  - [ ] `:RemoteNvimCloseTUI` to close current running TUI without closing the server
  - [ ] `:RemoteNvimInfo` to get information about active sessions
  - [ ] `:RemoteNvimCloseSession` to close a chosen host's session
  - [ ] `:RemoteNvimCleanUpHost` to clean up everything installed so far by us
  - [ ] `:RemoteNvimSwitch` should switch b/w active sessions
