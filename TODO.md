# TO-DO List

## Unresolved issues

1. Correct way to handle Neovim existing on remote machine
2. Correct way to handle detaching the Remote Neovim server from the remote instance
3. Add CONTRIBUTING.md

## Backlog

1. Use `plenary.async`
- Add CONTRIBUTING.md
- Add better logic to handle unique configuration IDs for same host
- Improve version detection in Neovim version selection menu
- Handle passing `--recreate` as and when necessary. This is especially needed
- Handle scenario when:
  - User neovim configuration path does not exist
  - SSH configuration path does not exist
- Log more information per workspace configuration
  - Plugin version (which version was used to publish this configuration)
  - Time of creation

## Devcontainer TODO

- Implement cleanup functions for devpod based operations

- One window for all options

  - Provide option to pass `--recreate` for devpod based solutions

- Testing

  - Add tests for the new function

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

- Progress viewer

  - Improve section headers in the ProgressView window
  - Add RemoteLogToggle function (handle mount and unmount correctly)
  - Add scrolling behavior for Log window, if on last line, auto scroll else pause
  - Output useful messages when required like "Remote server launched and accessible
    at port XYZ"

## In progress
