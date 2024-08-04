# Contributing

Thanks for contributing to `remote-nvim.nvim`. Your help means a lot!

You can make contributions in the following ways:

- **Mention it** to others if it has helped enhance/improve your workflow.
- **Create GitHub issues** so that we know what we should work on building/fixing next.
- **Raise PR** to fix bugs, improve documentation, add features, etc. The list goes on.
- **Participate** in issues and discussions.

## Getting started

If you are setting the repo up, run `make install-hooks` to install the pre-commit hooks. These hooks should take care
of most meta-things needed. Please make sure that the pre-commit checks and tests pass before raising the PR. In case,
something is unclear, please raise the PR and we can take care of it then!

### Pre-requisites

- LuaLS (LSP server)
- [lazydev.nvim](https://github.com/folke/lazydev.nvim/)
- pre-commit

Steps:

1. Run `make install-hooks`: Installs all necessary pre-commit hooks. Post setup, it should take care of all meta-things
   like formatting, linting, etc.
2. Setup [lazydev.nvim](https://github.com/folke/lazydev.nvim/). If this is not your thing, setup
   [.luarc.json](https://github.com/amitds1997/remote-nvim.nvim/blob/2d5158a/.luarc.json) file at the root
   of the project.

Once setup, make your changes!

### Testing

If you make any code changes, please add relevant test(s) post that. Once done,
run `make clean-test` to run the tests. Make sure that the tests pass before creating the PR.

### Commit message guidelines

- For any features, bugs, etc. please use conventional commit message format. This helps in
  automatic changelog generations.
- For any minor changes that is not code related, it is OK if you do not use conventional commits.

### Other information

- Help file is generated from the README (which is not an ideal solution, but it helps reduce the workload). So,
  update the README, if documentation needs to be updated.

## Credits

This documentation is heavily plaguarized from the `mini.nvim` CONTRIBUTING.md. So, thanks!
