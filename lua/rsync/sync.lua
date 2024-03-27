---
--- Syncing functionality
--- Sync up/down file commands is separate from project syncing and can not be run together.
--- Sync up/down commands are separate form file syncing and can not be run together.

local project = require("rsync.project")
local log = require("rsync.log")
local config = require("rsync.config")
local path = require("plenary.path")

---@enum FileSyncStates
FileSyncStates = {
    DONE = 0,
    STOPPED = 1,
    SYNC_UP_FILE = 2,
    SYNC_DOWN_FILE = 3,
}

---@enum ProjectSyncStates
ProjectSyncStates = {
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

            if config.get_current_config().on_stderr ~= nil then
                config.get_current_config().on_stderr(output, command)
            end
        end,

        -- job done executing
        on_exit = function(_, code, _)
            on_exit(code)
            if code ~= 0 then
                log.info(string.format("safe_sync command: '%s', on_exit with code = '%s'", command, code))
            end

            if config.get_current_config().on_exit ~= nil then
                config.get_current_config().on_exit(code, command)
            end
        end,
        stdout_buffered = true,
        stderr_buffered = true,
        -- run from project root
        cwd = project.get_config_table().project_path,
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

local function create_filters(filter_paths)
    local include = " "
    local exclude = " "
    for _, p in ipairs(filter_paths) do
        p = vim.fn.expand(p)
        local f = io.open(p, "r")

        if f ~= nil then
            for line in f:lines() do
                if line:sub(1, 1) == "!" then
                    include = include .. "--include='" .. line:sub(2, -1) .. "' "
                else
                    exclude = exclude .. "--exclude='" .. line .. "' "
                end
            end
        end
    end
    return include, exclude
end

--- Creates valid rsync command to sync up
--- @param project_path string the path to project
--- @param destination_path string the destination path which files will be synced to
--- @param ignorefile_paths table the paths to ignore files
--- @return string #valid rsync command
local function compose_sync_up_command(project_path, destination_path, ignorefile_paths)
    -- TODO have command be a separate type

    -- read ignore files append lines without ! with --include
    local include, exclude = create_filters(ignorefile_paths)

    return "rsync -varz --delete" .. include .. exclude .. "-f'- .nvim' " .. project_path .. " " .. destination_path
end

--- Sync project to remote
function sync.sync_up(report_error)
    project:run(function(config_table)
        local current_status = config_table.status.project

        if current_status.state == ProjectSyncStates.SYNC_DOWN then
            vim.api.nvim_err_writeln("Could not sync up, due to sync down still running")
            return
        elseif current_status.state == ProjectSyncStates.SYNC_UP then
            _RsyncProjectConfigs[config_table.project_path].status.project.state = ProjectSyncStates.STOPPED

            vim.fn.jobstop(current_status.job_id)
        end
        local command =
            compose_sync_up_command(config_table.project_path, config_table.remote_path, config_table.ignorefile_paths)
        safe_sync(command, function(res)
            project:run(function(project_config)
                _RsyncProjectConfigs[project_config.project_path].status.project.state = ProjectSyncStates.SYNC_UP
                _RsyncProjectConfigs[project_config.project_path].status.project.job_id = res
            end)
        end, function(code)
            -- ignore stopped job. (SIGTERM or SIGKILL)
            if code == 143 or code == 137 then
                project:run(function(project_config)
                    _RsyncProjectConfigs[project_config.project_path].status.project.state = ProjectSyncStates.STOPPED
                    _RsyncProjectConfigs[project_config.project_path].status.project.code = code
                    _RsyncProjectConfigs[project_config.project_path].status.project.job_id = -1
                end)
                return
            end
            if code ~= 0 then
                log.error(string.format("on_exit called with code: '%d'", code))
            end

            project:run(function(project_config)
                _RsyncProjectConfigs[project_config.project_path].status.project.state = ProjectSyncStates.DONE
                _RsyncProjectConfigs[project_config.project_path].status.project.code = code
                _RsyncProjectConfigs[project_config.project_path].status.project.job_id = -1
            end)
        end)
    end, report_error)
end

--- Sync file to remote
--- @param filename string path to file to sync
function sync.sync_up_file(filename)
    project:run(function(config_table)
        -- do not allow starting if another command still running
        local current_status = config_table.status.file
        if current_status.state ~= FileSyncStates.DONE then
            if current_status.state == FileSyncStates.SYNC_UP_FILE then
                vim.api.nvim_err_writeln("File still syncing up")
            elseif current_status.state == FileSyncStates.SYNC_DOWN_FILE then
                vim.api.nvim_err_writeln("File still syncing down")
            end
            -- TODO give a second try

            return
        end

        -- TODO move to function
        local name = vim.fn.expand("%:t")

        local relative_path = path:new(filename):make_relative(config_table["project_path"])
        local rpath_no_filename = string.sub(relative_path, 1, -(1 + string.len(name)))

        local command = "rsync -az --mkpath "
            .. config_table.project_path
            .. relative_path
            .. " "
            .. config_table.remote_path
            .. rpath_no_filename

        safe_sync(command, function(channel_id)
            project:run(function(project_config)
                _RsyncProjectConfigs[project_config.project_path].status.file.state = FileSyncStates.SYNC_UP_FILE
                _RsyncProjectConfigs[project_config.project_path].status.file.job_id = channel_id
            end)
        end, function(code)
            project:run(function(project_config)
                _RsyncProjectConfigs[project_config.project_path].status.file.state = FileSyncStates.DONE
                _RsyncProjectConfigs[project_config.project_path].status.file.job_id = -1
                _RsyncProjectConfigs[project_config.project_path].status.file.code = code
            end)
        end)
    end)
end

--- Creates valid rsync command to sync down
--- @param remote_includes table|string file path's to sync down but are ignored
--- @param project_path string the path to project
--- @param destination_path string the destination path which files will be synced from
--- @param ignorefile_paths table the paths to ignore files
--- @return string #valid rsync command
local function compose_sync_down_command(remote_includes, project_path, destination_path, ignorefile_paths)
    local filters = ""
    if type(remote_includes) == "table" then
        local filter_template = "-f'+ %s' "
        for _, value in pairs(remote_includes) do
            filters = filters .. filter_template:format(value)
        end
    elseif type(remote_includes) == "string" then
        filters = "-f'+ " .. remote_includes .. "' "
    end

    local include, exclude = create_filters(ignorefile_paths)

    local command = "rsync -varz "
        .. filters
        .. include
        .. exclude
        .. "-f'- .nvim' "
        .. destination_path
        .. " "
        .. project_path
    return command
end

--- Sync project from remote
function sync.sync_down()
    project:run(function(config_table)
        local current_status = config_table.status.project

        if current_status.state == ProjectSyncStates.SYNC_UP then
            vim.api.nvim_err_writeln("Could not sync down, due to sync up still running")
            return
        elseif current_status.state == ProjectSyncStates.SYNC_DOWN then
            _RsyncProjectConfigs[config_table.project_path].status.project.state = ProjectSyncStates.STOPPED
            vim.fn.jobstop(current_status.job_id)
        end
        local command = compose_sync_down_command(
            config_table.remote_includes,
            config_table.project_path,
            config_table.remote_path,
            config_table.ignorefile_paths
        )
        safe_sync(command, function(res)
            project:run(function(project_config)
                _RsyncProjectConfigs[project_config.project_path].status.project.state = ProjectSyncStates.SYNC_DOWN
                _RsyncProjectConfigs[project_config.project_path].status.project.job_id = res
            end)
        end, function(code)
            -- ignore stopped job.
            if code == 143 or code == 137 then
                project:run(function(project_config)
                    _RsyncProjectConfigs[project_config.project_path].status.project.state = ProjectSyncStates.STOPPED
                    _RsyncProjectConfigs[project_config.project_path].status.project.code = code
                    _RsyncProjectConfigs[project_config.project_path].status.project.job_id = -1
                end)
                return
            end
            if code ~= 0 then
                log.error(string.format("on_exit called with code: '%d'", code))
            end

            project:run(function(project_config)
                _RsyncProjectConfigs[project_config.project_path].status.project.state = ProjectSyncStates.DONE
                _RsyncProjectConfigs[project_config.project_path].status.project.code = code
                _RsyncProjectConfigs[project_config.project_path].status.project.job_id = -1
            end)
        end)
    end)
end

--- Creates valid rsync command to sync down file
--- @param file_path string the path to file
--- @param project_path string the path to project
--- @param destination_path string the destination path which file will be synced from
--- @return string #valid rsync command
local function compose_sync_down_file_command(file_path, project_path, destination_path)
    local relative_path = path:new(file_path):make_relative(project_path)
    local command = "rsync -varz " .. destination_path .. relative_path .. " " .. file_path
    return command
end

--- Sync file from remote
--- @param filename string path to file to sync
function sync.sync_down_file(filename)
    project:run(function(config_table)
        local buf = vim.api.nvim_get_current_buf()
        local current_status = config_table.status.file
        if current_status.state ~= FileSyncStates.DONE then
            if current_status.state == FileSyncStates.SYNC_UP_FILE then
                vim.api.nvim_err_writeln("File still syncing up")
            elseif current_status.state == FileSyncStates.SYNC_DOWN_FILE then
                vim.api.nvim_err_writeln("File still syncing down")
            end
            -- TODO give a second try
            return
        end
        local command = compose_sync_down_file_command(filename, config_table.project_path, config_table.remote_path)
        safe_sync(command, function(channel_id)
            project:run(function(project_config)
                _RsyncProjectConfigs[project_config.project_path].status.file.state = FileSyncStates.SYNC_DOWN_FILE
                _RsyncProjectConfigs[project_config.project_path].status.file.job_id = channel_id
            end)
        end, function(code)
            project:run(function(project_config)
                _RsyncProjectConfigs[project_config.project_path].status.file.state = FileSyncStates.DONE
                _RsyncProjectConfigs[project_config.project_path].status.file.job_id = -1
                _RsyncProjectConfigs[project_config.project_path].status.file.code = code
                if config.get_current_config().reload_file_after_sync then
                    vim.api.nvim_buf_call(buf, function()
                        vim.cmd.e()
                    end)
                end
            end)
        end)
    end)
end

return sync
