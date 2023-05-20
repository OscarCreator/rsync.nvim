# rsync.nvim

Asynchronously transfer your files with `rsync` on save.

## Dependencies

- cargo
- rsync

## Installation

```lua
use {'OscarCreator/rsync.nvim', run = 'make'
    requires = {
        {'nvim-lua/plenary.nvim'}
    }
}
```

## Usage

**rsync.nvim** looks for `nvim/rsync.toml` in the root of your project.

The current options available:

```toml
# this is the path to the remote. Can be either a local/remote filepath.
remote_path = "../copy/"
# or if using ssh
remote_path = "user@host:/home/user/path/"

# specifying a file(s) which should be synced "down" but are on .gitignore.
# this is a workaround to sync down files which are included on .gitignore
remote_includes = "build.log"
# or using an array if multiple files are needed.
remote_includes = ["build.log", "build/generated.json"]
```

## Commands

Name          | Action
--------------|-------
RsyncDown     | Sync all files from remote* to local folder.
RsyncDownFile | Sync current file from remote to local folder.
RsyncUp       | Sync all files from local* to remote folder.
RsyncUpFile   | Sync current file from local to remote. This requires rsync version >= 3.2.3

*: Files which are excluded are, everything in .gitignore and .nvim folder.
