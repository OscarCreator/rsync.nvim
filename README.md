# rsync.nvim

Asynchronously transfer your files with `rsync` on save.

## Dependencies

- cargo

## Installation

```lua
use {'OscarCreator/rsync.nvim', run = 'make'
    requires = {
        {'nvim-lua/plenary.nvim'}
    }
}
```

## Commands

Name      | Action
----------|-------
RsyncDown | Sync all files from remote to local folder (1)
RsyncUp   | Sync all files from local to remote folder (1)

(1): Files which are excluded are, everything in .gitignore and .nvim folder.
