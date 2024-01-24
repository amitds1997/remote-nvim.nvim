# TO-DO List

## Unresolved issues

1. Correct way to handle Neovim existing on remote machine
2. Correct way to handle detaching the Remote Neovim server from the remote instance
3. Add CONTRIBUTING.md

## To do

- Add tests for the added code
- Check progressview behaviour on different relatives and split/popup
- Save configuration only after we have successfully established connection e.g.
  do a failed connection and it still creates workspace
- Update README.md
  - Mention that when changing `progress_view` params, respect nui documentation
  - Add info about ":RemoteInfo"
  - Add how ":RemoteStart" behaves
    - Explain the 4 choices that you have
    - Explain local client launch behaviour when server is not running
  - Add more information about callback
  - Add deprecated to heading of ":RemoteSessionInfo"
