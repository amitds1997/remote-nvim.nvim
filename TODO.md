# TO-DO List

## Backlog

### Noice to have

- [ ] Add Neovim documentation
- [ ] Add unit tests
- [ ] Add [selene](https://github.com/Kampfkarren/selene/pull/541) check in
pre-commit once it's available
- Add templates for (example: [Noice.nvim](https://github.com/folke/noice.nvim/tree/main/.github/ISSUE_TEMPLATE))
  - [ ] Bug report
  - [ ] Feature request
- Add Github actions
  - [ ] Add test runner. Example. [Noice.nvim](https://github.com/folke/noice.nvim/blob/main/.github/workflows/ci.yml)
  - [ ] Add documentation step. Example: [Noice.nvim](https://github.com/folke/noice.nvim/blob/main/.github/workflows/ci.yml#L29-L48)
  - [ ] Add release step. Example. [Noice.nvim](https://github.com/folke/noice.nvim/blob/main/.github/workflows/ci.yml)

### Must do

- [ ] Add tutorial videos
- [ ] Add CHANGELOG
- [ ] Add correct error handling
- [ ] Add auto completion for the commands
- [ ] Add check to ensure that minimum neovim version is there
- [ ] Restructure plugin folders and move around code to recommended folders
- [ ] Add full screen client running capabilities
- Add more commands
  - [ ] `:RemoteNvimCloseTUI` to close current running TUI without closing the server
  - [ ] `:RemoteNvimInfo` to get information about active sessions
  - [ ] `:RemoteNvimCloseSession` to close a chosen host's session
  - [ ] `:RemoteNvimCleanUpHost` to clean up everything installed so far by us
  - [ ] `:RemoteNvimSwitch` should switch b/w active sessions
  - [ ] `:RemoteNvimLocal` to switch to the local and hide every remote session running

## Planned

- [ ] Add logging
- [ ] Add scripts to do checks
- [ ] Add progress bar notification
- [ ] Handle Neovim already exists on remote machine scenario (just
symlink the right version)
- [ ] Fix issue where launching too soon makes the TUI crash

## In progress

- [ ] If there are additional saved hosts and workspaces, show them too
