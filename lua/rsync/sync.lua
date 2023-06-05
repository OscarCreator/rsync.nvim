---
-- Syncing functionality

-- sync up/down file = own syncs and statuses, no status need to be shown
--  opt.file.start_window - time window to wait if an sync is in progress, default = 0
--      
-- sync up/down = should not be able run with each other
--
--

local project = require("rsync.project")
local log = require("rsync.log")

SyncState = {
    DONE = 0,
    STOPPED = 1,
    SYNC_UP_FILE = 2,
    SYNC_DOWN_FILE = 3,
}

ProjectSyncState = {
    DONE = 0,
    STOPPED = 1,
    SYNC_UP = 2,
    SYNC_DOWN = 3,
}

local sync = {}

--- Tries to start job and repors errors if any where found
local function safe_sync(command, on_start, on_exit)
    local res = vim.fn.jobstart(command, {
        on_stderr = function(_, output, _)
            -- skip when function reports empty error
            if vim.inspect(output) ~= vim.inspect({ "" }) then
                log.info(string.format("safe_sync command: '%s', on_stderr: '%s'", command, vim.inspect(output)))
            end
        end,

        -- job done executing
        on_exit = function(_, code, _)
            on_exit(code)
            if code ~= 0 then
                log.info(string.format("safe_sync command: '%s', on_exit with code ~= '%s'", command, code))
            end
        end,
        stdout_buffered = true,
        stderr_buffered = true,
    })

    if res == -1 then
        log.error(string.format("safe_sync command: '%s', Could not execute rsync", command))
        error("Could not execute rsync. Make sure that rsync in on your path")
    elseif res == 0 then
        log.error(string.format("safe_sync command: '%s', Invalid command", command))
    else
        on_start(res)
    end
end


--- Creates valid rsync command to sync up
--- @param project_path string the path to project
--- @param destination_path string the destination path which files will be synced to
--- @return string #valid rsync command
local function compose_sync_up_command(project_path, destination_path)
    -- TODO change depending on plugin options
    -- TODO have command be a separate type
    return "rsync -varz --delete -f':- .gitignore' -f'- .nvim' " .. project_path .. " " .. destination_path
end

--- Sync project to remote
function sync.sync_up()
    project:run(function(config_table)
        local current_status = config_table.status.project

        if current_status.state == ProjectSyncState.SYNC_DOWN then
            vim.api.nvim_err_writeln("Could not sync up, due to sync down still running")
            return
        elseif current_status.state == ProjectSyncState.SYNC_UP then
            _RsyncProjectConfigs[config_table.project_path].status.project.state = ProjectSyncState.STOPPED

            --table.insert(_RsyncProjectConfigs[config_table.project_path].status.project.stopped[current_status.job_id], true)
            vim.fn.jobstop(current_status.job_id)
        end
        local command = compose_sync_up_command(config_table.project_path, config_table.remote_path)
        safe_sync(command, function(res)
            _RsyncProjectConfigs[config_table.project_path].status.project.state = ProjectSyncState.SYNC_UP
            _RsyncProjectConfigs[config_table.project_path].status.project.job_id = res
        end, function(code)
            -- TODO move state updating to separate module

            -- TODO maybe use global array as state
            --if _RsyncProjectConfigs[config_table.project_path].status.project.stopped[current_status.job_id] == true then
            --    _RsyncProjectConfigs[config_table.project_path].status.project.stopped[current_status.job_id]

            -- ignore stopped job. (SIGTERM or SIGKILL)
            if code == 143 or code == 137 then
                return
            end
            if code ~= 0 then
                log.error(string.format("on_exit called with code: '%d'", code))
            end

            _RsyncProjectConfigs[config_table.project_path].status.project.state = ProjectSyncState.DONE
            _RsyncProjectConfigs[config_table.project_path].status.project.code = code
            _RsyncProjectConfigs[config_table.project_path].status.project.job_id = -1

        end)
    end)
end




--- Sync file to remote
--- @param filename string path to file to sync
function sync.sync_up_file(filename)
    project:run(function(config_table)
        -- do not allow starting if another command still running
        local current_status = config_table.status.file
        if current_status.state ~= SyncState.DONE then
            -- TODO give a second try
            vim.api.nvim_err_writeln("File still syncing up")
            return
        end

        -- TODO move to function
        local full = vim.fn.expand("%:p")
        local name = vim.fn.expand("%:t")
        local path = require("plenary.path")

        local relative_path = path:new(full):make_relative(config_table["project_path"])
        local rpath_no_filename = string.sub(relative_path, 1, -(1 + string.len(name)))

        local command = "rsync -az --mkpath "
        .. config_table["project_path"]
        .. filename
        .. " "
        .. config_table["remote_path"]
        .. rpath_no_filename
        local project_path = config_table.project_path

        safe_sync(command, function(channel_id)
            _RsyncProjectConfigs[project_path].status.file.state = SyncState.SYNC_UP_FILE
            _RsyncProjectConfigs[project_path].status.file.job_id = channel_id
        end, function(code)
            _RsyncProjectConfigs[project_path].status.file.state = SyncState.DONE
            _RsyncProjectConfigs[project_path].status.file.job_id = -1
            _RsyncProjectConfigs[project_path].status.file.code = code
        end)
    end)
end

--- Creates valid rsync command to sync down
--- @param remote_includes table|string file path's to sync down but are ignored 
--- @param project_path string the path to project
--- @param destination_path string the destination path which files will be synced from
--- @return string #valid rsync command
local function compose_sync_down_command(remote_includes, project_path, destination_path)
    local filters = ""
    if type(remote_includes) == "table" then
        local filter_template = "-f'+ %s' "
        for _, value in pairs(remote_includes) do
            filters = filters .. filter_template:format(value)
        end
    elseif type(remote_includes) == "string" then
        filters = "-f'+ " .. remote_includes .. "' "
    end

    local command = "rsync -varz "
        .. filters
        .. "-f':- .gitignore' -f'- .nvim' "
        .. destination_path
        .. " "
        .. project_path
    return command
    --run_sync(command, project_path, function(res)
        --_RsyncProjectConfigs[project_path]["sync_status"] = { progress = "start", state = "sync_down", job_id = res }
    --end, on_exit)
end

function sync.sync_down()
    project:run(function(config_table)
        local current_status = config_table.status.project

        if current_status.state == ProjectSyncState.SYNC_UP then
            vim.api.nvim_err_writeln("Could not sync down, due to sync up still running")
            return
        elseif current_status.state == ProjectSyncState.SYNC_DOWN then
            _RsyncProjectConfigs[config_table.project_path].status.project.state = ProjectSyncState.STOPPED
            vim.fn.jobstop(current_status.job_id)
        end
        local command = compose_sync_down_command(config_table.remote_includes, config_table.project_path, config_table.remote_path)
        safe_sync(command, function(res)
            _RsyncProjectConfigs[config_table.project_path].status.project.state = ProjectSyncState.SYNC_DOWN
            _RsyncProjectConfigs[config_table.project_path].status.project.job_id = res
        end, function(code)
            -- ignore stopped job.
            if code == 143 or code == 137 then
                return
            end
            if code ~= 0 then
                log.error(string.format("on_exit called with code: '%d'", code))
            end

            _RsyncProjectConfigs[config_table.project_path].status.project.state = ProjectSyncState.DONE
            _RsyncProjectConfigs[config_table.project_path].status.project.code = code
            _RsyncProjectConfigs[config_table.project_path].status.project.job_id = -1
        end)
    end)
end

--- Creates valid rsync command to sync down file
--- @param file_path string the path to file
--- @param project_path string the path to project
--- @param destination_path string the destination path which file will be synced from
--- @return string #valid rsync command
local function compose_sync_down_file_command(file_path, project_path, destination_path)

    -- TODO appending may not always work
    local command = "rsync -varz "
        .. destination_path .. file_path
        .. " "
        .. project_path .. file_path
    return command
end

function sync.sync_down_file(file)
    project:run(function(config_table)
        local buf = vim.api.nvim_get_current_buf()
        local current_status = config_table.status.file
        if current_status.state ~= SyncState.DONE then
            -- TODO give a second try
            vim.api.nvim_err_writeln("File still syncing down")
            return
        end
        local command = compose_sync_down_file_command(file, config_table.project_path, config_table.remote_path)
        safe_sync(command, function (channel_id)
            _RsyncProjectConfigs[config_table.project_path].status.file.state = SyncState.SYNC_DOWN_FILE
            _RsyncProjectConfigs[config_table.project_path].status.file.job_id = channel_id
        end, function(code)
            _RsyncProjectConfigs[config_table.project_path].status.file.state = SyncState.DONE
            _RsyncProjectConfigs[config_table.project_path].status.file.job_id = -1
            _RsyncProjectConfigs[config_table.project_path].status.file.code = code
            vim.api.nvim_buf_call(buf, function()
                vim.cmd.e()
            end)
        end)
    end)
end

return sync
