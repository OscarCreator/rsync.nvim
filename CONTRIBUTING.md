# Contributing to rsync.nvim

## Getting started

Do you want to help but unsure what to do?

- Feel free to come with you own ideas on how to improve the plugin. 
  If you choose to do this then make sure to get your changes to tested and lint checks passing. 
- You can take a look at the open [issues](https://github.com/OscarCreator/rsync.nvim/issues) and
  see if there is something which you can help with.
- Improve the current state of the plugin by proving more tests, improve documentation and
  refactor code for better readability.

## Tools

The following tools are used for the project:
- [luacheck](https://github.com/mpeterv/luacheck) for linting
- [stylua](https://github.com/JohnnyMorganz/StyLua) for linting
- [cargo](https://www.rust-lang.org/tools/install) for linting and building rust lib 
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) for testing
- [luacov](https://github.com/lunarmodules/luacov), [luacov-console](https://github.com/spacewander/luacov-console) 
    and optionally [luacov-lcov](https://github.com/daurnimator/luacov-reporter-lcov)
    if you want lcov instead of luacov reports. These are needed to run tests with code coverage

Before you can run tests make sure you have built the rust source with `make build`
after that is done then you are all set.

To create a good PR follow this list:

- Linters passing with `make -k lint`
- Have tests passing with `make test`
- Add tests if new functionality is added
