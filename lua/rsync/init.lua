local rsync_nvim = vim.api.nvim_create_augroup("rsync_nvim", { clear = true })
require("rsync.commands").setup(rsync_nvim)

local project = require("rsync.project")
local sync = require("rsync.sync")
local config = require("rsync.config")

local rsync = {}

--- get current sync status of project
function rsync.status()
    local config_table = project.get_config_table()
    if config_table == nil then
        return ""
    end

    local state = config_table.status.project.state
    local code = config_table.status.project.code
    if state == ProjectSyncStates.SYNC_DOWN then
        return "Syncing down files"
    elseif state == ProjectSyncStates.SYNC_UP then
        return "Syncing up files"
    elseif state == ProjectSyncStates.STOPPED then
        return "Sync cancelled"
    elseif state == ProjectSyncStates.DONE then
        if code == 0 then
            return "Sync succeeded"
        else
            return "Sync failed"
        end
    end
end

--- get current project config
---@return table | nil
function rsync.config()
    return project.get_config_table()
end

--- Setup global user defined configuration
---@param user_config RsyncConfig
function rsync.setup(user_config)
    config.apply_config(user_config)

    if config.get_current_config().fugitive_sync then
        vim.api.nvim_create_autocmd({ "User" }, {
            pattern = "FugitiveChanged",
            callback = function()
                sync.sync_up(false)
            end,
            group = rsync_nvim,
        })
    end
end

return rsync
