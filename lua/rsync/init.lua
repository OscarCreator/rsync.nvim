local M = {}

local rsync_nvim = vim.api.nvim_create_augroup("rsync_nvim", { clear = true })

local project = require("rsync.project")
local sync = require("rsync.sync")

vim.api.nvim_create_autocmd({ "BufEnter" }, {
    callback = function()
        -- only initialize once per buffer
        if vim.b.rsync_init == nil then
            -- get config as table if present
            local config_table = project.get_config_table()
            if config_table == nil then
                return
            end
            vim.api.nvim_create_autocmd({ "BufWritePost" }, {
                callback = function()
                    sync.sync_up()
                end,
                group = rsync_nvim,
                buffer = vim.api.nvim_get_current_buf(),
            })
            vim.b.rsync_init = 1
        end
    end,
    group = rsync_nvim,
})

-- sync all files from remote
vim.api.nvim_create_user_command("RsyncDown", function()
    sync.sync_down()
end, {})

-- sync all files to remote
vim.api.nvim_create_user_command("RsyncUp", function()
    sync.sync_up()
end, {})

vim.api.nvim_create_user_command("RsyncDownFile", function()
    local file = vim.fn.expand("%")
    sync.sync_down_file(file)
end, {})

vim.api.nvim_create_user_command("RsyncUpFile", function()
    local file_relative = vim.fn.expand("%:.")
    sync.sync_up_file(file_relative)
end, {})

--- get current sync status of project
M.status = function()
    local config_table = project.get_config_table()
    if config_table == nil then
        return ""
    end

    local progress = config_table["sync_status"]["progress"]
    local code = config_table["sync_status"]["code"]
    if progress == "start" then
        return "Syncing files"
    elseif progress == "exit" then
        if code == 0 then
            return "Up to date"
        else
            return "Failed to sync"
        end
    end
end

--- get current project config
function M.config()
    return project.get_config_table()
end

-- TODO
function M.setup(user_config)
    require("rsync.config").set_defaults(user_config)
end

return M
