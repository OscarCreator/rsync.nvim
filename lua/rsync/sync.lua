---
-- Syncing functionality

local project = require("rsync.project")

local sync = {}

local function run_sync(command, project_path, on_start, on_exit)
    local res = vim.fn.jobstart(command, {
        on_stderr = function(_, output, _)
            -- skip when function reports no error
            if vim.inspect(output) ~= vim.inspect({ "" }) then
                -- TODO print save output to temporary log file
                vim.api.nvim_err_writeln("Error executing: " .. command)
            end
        end,

        -- job done executing
        on_exit = function(_, code, _)
            _RsyncProjectConfigs[project_path]["sync_status"] = { code = code, progress = "exit" }
            if code == 0 then
                if on_exit ~= nil then
                    on_exit()
                end
            else
                vim.api.nvim_err_writeln("rsync execute with result code: " .. code)
            end
        end,
        stdout_buffered = true,
        stderr_buffered = true,
    })

    if res == -1 then
        error("Could not execute rsync. Make sure that rsync in on your path")
    elseif res == 0 then
        print("Invalid command: " .. command)
    else
        on_start(res)
    end
end

local function sync_project(source_path, destination_path, project_path)
    local command = "rsync -varz --delete -f':- .gitignore' -f'- .nvim' " .. source_path .. " " .. destination_path
    run_sync(command, project_path, function(res)
        _RsyncProjectConfigs[project_path]["sync_status"] = { progress = "start", state = "sync_up", job_id = res }
    end)
end

local function sync_remote(source_path, destination_path, include_extra, project_path, on_exit)
    local filters = ""
    if type(include_extra) == "table" then
        local filter_template = "-f'+ %s' "
        for _, value in pairs(include_extra) do
            filters = filters .. filter_template:format(value)
        end
    elseif type(include_extra) == "string" then
        filters = "-f'+ " .. include_extra .. "' "
    end

    local command = "rsync -varz "
        .. filters
        .. "-f':- .gitignore' -f'- .nvim' "
        .. source_path
        .. " "
        .. destination_path
    run_sync(command, project_path, function(res)
        _RsyncProjectConfigs[project_path]["sync_status"] = { progress = "start", state = "sync_down", job_id = res }
    end, on_exit)
end

function sync.sync_up()
    local config_table = project.get_config_table()
    if config_table ~= nil then
        if config_table["sync_status"]["progress"] == "start" then
            if config_table["sync_status"]["state"] ~= "sync_up" then
                vim.api.nvim_err_writeln("Could not sync down, due to sync down still running")
                return
            else
                -- todo convert to jobwait + lua coroutines
                vim.fn.jobstop(config_table["sync_status"]["job_id"])
            end
        end
        sync_project(config_table["project_path"], config_table["remote_path"], config_table["project_path"])
    else
        vim.api.nvim_err_writeln("Could not find rsync.toml")
    end
end

function sync.sync_up_file(filename)
    local config_table = project.get_config_table()

    -- TODO redo to not need to copy this
    if config_table ~= nil then
        if config_table["sync_status"]["progress"] == "start" then
            if config_table["sync_status"]["state"] ~= "sync_down" then
                vim.api.nvim_err_writeln("Could not sync down, due to sync still running")
                return
            else
                -- todo convert to jobwait + lua coroutines
                vim.fn.jobstop(config_table["sync_status"]["job_id"])
            end
        end

        local full = vim.fn.expand("%:p")
        local name = vim.fn.expand("%:t")
        local path = require("plenary.path")

        local relative_path = path:new(full):make_relative(config_table["project_path"])
        local rpath_no_filename = string.sub(relative_path, 1, - (1 + string.len(name)))

        local command = "rsync -az --mkpath " .. config_table["project_path"] .. filename .. " " .. config_table["remote_path"] .. rpath_no_filename
        local project_path = config_table["project_path"]
        run_sync(command, project_path, function(res)
            _RsyncProjectConfigs[project_path]["sync_status"] = { progress = "start", state = "sync_up", job_id = res }
        end)
    else
        vim.api.nvim_err_writeln("Could not find rsync.toml")
    end
end

function sync.sync_down()
    local config_table = project.get_config_table()

    if config_table ~= nil then
        if config_table["sync_status"]["progress"] == "start" then
            if config_table["sync_status"]["state"] ~= "sync_down" then
                vim.api.nvim_err_writeln("Could not sync down, due to sync still running")
                return
            else
                -- todo convert to jobwait + lua coroutines
                vim.fn.jobstop(config_table["sync_status"]["job_id"])
            end
        end
        sync_remote(
            config_table["remote_path"],
            config_table["project_path"],
            config_table["remote_includes"],
            config_table["project_path"]
        )
    else
        vim.api.nvim_err_writeln("Could not find rsync.toml")
    end
end

function sync.sync_down_file(file)
    local buf = vim.api.nvim_get_current_buf()
    local config_table = project.get_config_table()

    if config_table ~= nil then
        if config_table["sync_status"]["progress"] == "start" then
            if config_table["sync_status"]["state"] ~= "sync_down" then
                vim.api.nvim_err_writeln("Could not sync down, due to sync still running")
                return
            else
                -- todo convert to jobwait + lua coroutines
                vim.fn.jobstop(config_table["sync_status"]["job_id"])
            end
        end
        sync_remote(
            config_table["remote_path"] .. file,
            file,
            {},
            config_table["project_path"],
            function()
                vim.api.nvim_buf_call(buf, function()
                    vim.cmd.e()
                end)
            end
        )
    else
        vim.api.nvim_err_writeln("Could not find rsync.toml")
    end
end

return sync
