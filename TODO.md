# TO-DO List

## Backlog

### Noice to have

- [ ] Add Neovim documentation
- [ ] Add unit tests
- [ ] Add pre-commit hook for [selene](https://github.com/Kampfkarren/selene/pull/541)
- [ ] Handle Neovim already exists on remote machine
- Add templates for (example: [Noice.nvim](https://github.com/folke/noice.nvim/tree/main/.github/ISSUE_TEMPLATE))
  - [ ] Bug report
  - [ ] Feature request
- Add Github actions
  - [ ] Add test runner. Example. [Noice.nvim](https://github.com/folke/noice.nvim/blob/main/.github/workflows/ci.yml)
  - [ ] Add documentation step. Example: [Noice.nvim](https://github.com/folke/noice.nvim/blob/main/.github/workflows/ci.yml#L29-L48)
  - [ ] Add release step. Example. [Noice.nvim](https://github.com/folke/noice.nvim/blob/main/.github/workflows/ci.yml)
- Add more commands
  - [ ] `:RemoteNvimCloseTUI` to close current running TUI without closing the server
  - [ ] `:RemoteNvimLocal` to switch to the local and hide every remote session running

### Must do

- [ ] Add tutorial videos
- [ ] Add CHANGELOG
- [ ] Restructure plugin folders and move around code to recommended folders
- [ ] Add full screen client running capabilities

## Planned

- [ ] Add `plenary.curl` like error notification
- [ ] Embrace plenary.nvim for common operations like opening configuration file
in config handler and ssh parser

## In progress

- Add commands:
  - [ ] `:RemoteCleanup` - (Autocomplete should show all known host configs from
  the file) Clean up the host
  - [ ] `:RemoteInfo` - Launched pop-up should show following details: Remote OS,
  Local port, Remote port, Remote Neovim version, workspace ID
  - [ ] `:RemoteCloseTUIs` - (Autocomplete shows options for active servers) Close
  all running TUIs
  - [x] `:RemoteStart` - Launch remote workspace
  - [ ] `:RemoteStop` - (Autocomplete should show active servers) Close remote port
  forwarding server
  - [x] `:RemoteLog` - Show log file
