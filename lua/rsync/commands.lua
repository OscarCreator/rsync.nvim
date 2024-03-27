local project = require("rsync.project")
local sync = require("rsync.sync")
local config = require("rsync.config")

local log = require("rsync.log")

local commands = {}

---@param rsync_nvim integer
function commands.setup(rsync_nvim)
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
                        if config.get_current_config().sync_on_save then
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

    -- change sync_on_save
    vim.api.nvim_create_user_command("RsyncSaveSync", function(opts)
        local cmd = opts.fargs[1]

        if cmd == "disable" then
            config.get_current_config().sync_on_save = false
        elseif cmd == "toggle" then
            config.get_current_config().sync_on_save = not config.get_current_config().sync_on_save
        elseif cmd == "enable" then
            config.get_current_config().sync_on_save = true
        else
            vim.api.nvim_err_writeln(string.format("Unknown subcommand: '%s'", cmd))
        end
    end, {
        nargs = 1,
        complete = function(ArgLead, CmdLine, CursorPos)
            return { "disable", "toggle", "enable" }
        end,
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
        local file_path = opts.fargs[1] or vim.fn.expand("%:p")
        sync.sync_down_file(file_path)
    end, {
        nargs = "?",
        complete = "file",
    })

    vim.api.nvim_create_user_command("RsyncUpFile", function(opts)
        local file_path = opts.fargs[1] or vim.fn.expand("%:p")
        sync.sync_up_file(file_path)
    end, {
        nargs = "?",
        complete = "file",
    })

    vim.api.nvim_create_user_command("RsyncLog", function()
        local log_file = string.format("%s/%s.log", vim.api.nvim_call_function("stdpath", { "cache" }), log.plugin)
        vim.cmd.tabe(log_file)
    end, {})

    vim.api.nvim_create_user_command("RsyncConfig", function()
        print(vim.inspect(config.get_current_config()))
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
end

return commands
