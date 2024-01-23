# TO-DO List

## Unresolved issues

1. Correct way to handle Neovim existing on remote machine
2. Correct way to handle detaching the Remote Neovim server from the remote instance

## Backlog

- Add CONTRIBUTING.md

## To do

- ProgressView
  - Add custom highlight groups and link it to default highlight groups
  - Add autoscrolling to ProgressView, autoscroll if on last line else don't scroll
  - Clean up progressview code
  - Add tests
  - Update README.md with correct steps
- Save configuration only after we have successfully established connection e.g.
  do a failed connection and it still creates workspace
- When you previously chose to not launch a client and you re-run `:RemoteStart`,
  allow choice to launch a client.
