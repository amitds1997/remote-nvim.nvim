# TO-DO List

## Backlog

- [ ] Add Neovim documentation
- [ ] Add unit tests
- [ ] Add tutorial videos
- [ ] Add CHANGELOG
- [ ] Add [selene](https://github.com/Kampfkarren/selene/pull/541) check in
pre-commit once it's available
- [ ] Add correct error handling
- [ ] Find why there are extra whitespaces in commands run in SSH
- [ ] Decide if and how we should cancel previous jobs when starting new jobs?
If we should cancel, why does the current logic not work with port forwarding job?
- [ ] Add auto completion for the commands
- [ ] Add check to ensure that minimum neovim version is there
- [ ] Restructure plugin folders and move around code to recommended folders
- [ ] Add full screen client running capabilities
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
  - [ ] `:RemoteNvimLocal` to switch to the local and hide every remote session running

## Planned

- [ ] If there are additional saved hosts and workspaces, show them too
- [ ] Add logging
- [ ] Add scripts to do checks
- [ ] Add progress bar notification
- [ ] Handle Neovim already exists on remote machine scenario (just
symlink the right version)
- [ ] Fix issue where launching too soon makes the TUI crash

## In progress

- [ ] Fix telescope things
