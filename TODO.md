# TO-DO List

## Unresolved issues

1. Correct way to handle Neovim existing on remote machine
2. Correct way to handle detaching the Remote Neovim server from the remote instance

## Backlog

### Noice to have

- [ ] Add Neovim documentation
- [ ] Add unit tests
- [ ] Add pre-commit hook for [selene](https://github.com/Kampfkarren/selene/pull/541)
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

## Planned

- [ ] Add `plenary.curl` like error notification
- [ ] Embrace plenary.nvim for common operations like opening configuration file
in config handler and ssh parser

## In progress

- Add commands:
  - [ ] `:RemoteInfo` - Launched pop-up should show following details: Remote OS,
  Local port, Remote port, Remote Neovim version, workspace ID
