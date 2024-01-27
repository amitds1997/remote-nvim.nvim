# TO-DO List

## Unresolved issues

1. Correct way to handle Neovim existing on remote machine
2. Correct way to handle detaching the Remote Neovim server from the remote instance
3. Add CONTRIBUTING.md

## Backlog

- Use `plenary.async`

## Devcontainer TODO

- Add better logic to handle unique configuration IDs for same host
- Implement cleanup functions for devpod based operations
- One window for all options
  - Provide option to pass `--recreate` for devpod based solutions
- Add tests for the new function
- Handle scenario when:
  - User neovim configuration path does not exist
  - SSH configuration path does not exist
- Make things async
  - Convert coroutine logic into util
  - Replace vim.fn.system with async version
  - Replace vim.fn.systemlist with async version
- Launch option selector
  - Add better information in the preview window Example: This workspace was created
    from branch 'abc' in remote repo: `xyz`
- Image/container selector
  - Switch to telescope pickers
  - For image, allow choosing from existing images, else also allow manual input.
- Log more information per workspace configuration
  - Plugin version (which version was used to publish this configuration)
  - Time of creation
- Fix when user clicks out of the box when selecting if to launch local client and then it is stuck
  with saying "Neovim server is already running". Check if this also occurs during earlier choices.
