# TO-DO List

## Unresolved issues

1. Correct way to handle Neovim existing on remote machine
2. Correct way to handle detaching the Remote Neovim server from the remote instance
3. Add CONTRIBUTING.md
4. Fix when user clicks out of the box when selecting if to launch local client and then it is stuck
   with saying "Neovim server is already running". Check if this also occurs during earlier choices.

## Backlog

1. Use `plenary.async`
2. Add CI runs for the complete workflow run in Ubuntu, MacOS Intel, MacOS M1
3. Create single form for everything
   - Provide option to pass `--recreate` for devpod based solutions

## Devcontainer TO DO List

### Done

- Handle scenario when (upload paths are checked for existence)
  - User neovim configuration path does not exist
  - SSH configuration path does not exist

### To do

- Add tests for
  - Plain substitute function
  - Entire devpod codebase
- Add auto-detection of devcontainer directory if present and popping up devcontainer question
- Implement cleanup functions for devpod based operations
- Docker image
  - Stop container as we close up Neovim
  - When running `:RemoteStop`, ask users if they want to also close the container
  - Should we also clean the configuration then(??)
  - For this should we launch the container and then re-set the unique host ID to the container (???)
  - In initial selector, allow selecting from existing images or type your own
- Better picker preview description for all devpod selectors (E.g.: This workspace was created from
  branch 'abc' in remote repo: `xyz`)

### In progress

- Make vim.fn.system calls async
