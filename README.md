# rsync.nvim

Asynchronously transfer your files with `rsync` on save.

## Dependencies

- toml.lua

    ```
    luarocks install toml
    ```

## Installation

```lua
use {'OscarCreator/rsync.nvim',
    requires = {
        {'nvim-lua/plenary.nvim'}
    }
}
```

## Commands

Name      | Action
----------|-------
RsyncDown | Sync all files from remote to local folder (1)

(1): Files which are excluded are, everything in .gitignore and .nvim folder.
