local M = {}

local rsync_nvim = vim.api.nvim_create_augroup("rsync_nvim", { clear = true })

local project = require("rsync.project")
local sync = require("rsync.sync")
local config = require("rsync.config")
local log = require("rsync.log")

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
                    if config.values.sync_on_save then
                        sync.sync_up()
                    end
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

vim.api.nvim_create_user_command("RsyncDownFile", function(opts)
    local file_relative = opts.fargs[1] or vim.fn.expand("%:.")
    sync.sync_down_file(file_relative)
end, {
    nargs = "?",
    complete = "file",
})

vim.api.nvim_create_user_command("RsyncUpFile", function(opts)
    local file_relative = opts.fargs[1] or vim.fn.expand("%:.")
    sync.sync_up_file(file_relative)
end, {
    nargs = "?",
    complete = "file",
})

vim.api.nvim_create_user_command("RsyncLog", function()
    local log_file = string.format("%s/%s.log", vim.api.nvim_call_function("stdpath", { "cache" }), log.plugin)
    vim.cmd.tabe(log_file)
end, {})

vim.api.nvim_create_user_command("RsyncConfig", function()
    print(vim.inspect(config.values))
end, {})

vim.api.nvim_create_user_command("RsyncProjectConfig", function(opts)
    local cmd = opts.fargs[1] or "show"
    if cmd == "show" then
        print(vim.inspect(project.get_config_table()))
    elseif cmd == "reload" then
        project.reload_config()
    else
        vim.api.nvim_err_writeln(string.format("Unknown subcommand: '%s'", cmd))
    end
end, {
    nargs = "?",
    complete = function(ArgLead, CmdLine, CursorPos)
        return { "show", "reload" }
    end,
})

vim.api.nvim_create_user_command("RsyncCancelJob", function(opts)
    local to_stop = opts.fargs[1] or "all"
    if to_stop == "file" or to_stop == "all" then
        project:run(function(config_table)
            vim.fn.jobstop(config_table.status.file.job_id)
        end)
    end
    if to_stop == "project" or to_stop == "all" then
        project:run(function(config_table)
            vim.fn.jobstop(config_table.status.project.job_id)
        end)
    end
end, {
    nargs = "?",
    complete = function(ArgLead, _, _)
        local options = { "file", "project", "all" }
        local res = {}

        -- return matching arguments only
        for _, v in pairs(options) do
            if string.match(v, ArgLead) then
                table.insert(res, v)
            end
        end
        return res
    end,
})

--- get current sync status of project
M.status = function()
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
function M.config()
    return project.get_config_table()
end

--- Setup global user defined configuration
function M.setup(user_config)
    config.set_defaults(user_config)

    if config.values.fugitive_sync then
        vim.api.nvim_create_autocmd({ "User" }, {
            pattern = "FugitiveChanged",
            callback = function()
                sync.sync_up(false)
            end,
            group = rsync_nvim,
        })
    end
end

return M
