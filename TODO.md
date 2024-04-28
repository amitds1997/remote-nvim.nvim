# TO-DO List

## Unresolved issues

1. Correct way to handle Neovim existing on remote machine
2. Correct way to handle detaching the Remote Neovim server from the remote instance
3. Add CONTRIBUTING.md
4. Fix when user clicks out of the box when selecting if to launch local client and then it is stuck
   with saying "Neovim server is already running". Check if this also occurs during earlier choices.
5. Allow selector which also allows user input

## Backlog

1. Add CI runs for the complete workflow run in Ubuntu, MacOS Intel, MacOS M1
2. Create single form for everything
   - Provide option to pass `--recreate` for devpod based solutions

## Devcontainer TO DO List

### To do

- Better picker preview description for all devpod selectors (E.g.: This workspace was created from
  branch 'abc' in remote repo: `xyz`)
- Update README
  - Add new demos
  - Add new dependency information
  - Add steps to set things up
- Add tests for
  - Plain substitute function
  - Entire devpod codebase

### In progress

- Add auto-detection of devcontainer directory if present and popping up devcontainer question
