[![codecov](https://codecov.io/gh/OscarCreator/rsync.nvim/branch/master/graph/badge.svg?token=GYELY6KJZ6)](https://codecov.io/gh/OscarCreator/rsync.nvim)

# rsync.nvim
Asynchronously transfer your files with `rsync` on save.

![output](https://github.com/OscarCreator/rsync.nvim/assets/53407525/c5c402bd-98ac-4899-9ce0-ebf27db28d29)

## Dependencies

- [cargo](https://www.rust-lang.org/tools/install)
- rsync

## Installation

```lua
use {
    'OscarCreator/rsync.nvim',
    run = 'make',
    requires = {'nvim-lua/plenary.nvim'}
    config = function()
        require("rsync").setup({
            -- triggers sync when git repo was changed
            fugitive_sync = true
        })
    end
}
```

## Usage

**rsync.nvim** looks for `.nvim/rsync.toml` file by default in the root of
your project. The path can also be set with the `project_config_path`
key in the plugin configuration.

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

Name               | Action
-------------------|-------
RsyncDown          | Sync all files from remote* to local folder.
RsyncDownFile      | Sync current file from remote to local folder.
RsyncUp            | Sync all files from local* to remote folder.
RsyncUpFile        | Sync current file from local to remote. This requires rsync version >= 3.2.3
RsyncLog           | Open log file for rsync.nvim.
RsyncConfig        | Print out user config.
RsyncProjectConfig | Print out current project config.

*: Files which are excluded are, everything in .gitignore and .nvim folder.

## Configuration

Global configuration settings with the default values

```lua
{
    -- triggers `RsyncUp` when fugitive thinks something might have changed in the repo.
    fugitive_sync = false,
    -- triggers `RsyncUp` when you save a file.
    sync_on_save = true
    -- the path to the project configuration
    project_config_path = ".nvim/rsync.toml"
    -- called when the rsync command exits, provides the exit code and the used command
    on_exit = function(code, command)
    end,
    -- called when the rsync command prints to stderr, provides the data and the used command
    on_error = function(data, command)
    end,
}
```

