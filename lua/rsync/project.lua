local rsync_nvim = require("rsync_nvim")
local path = require("plenary.path")
local log = require("rsync.log")
local config = require("rsync.config")

---@class RsyncProjectStatus
---@field code integer last exit code
---@field state FileSyncStates current state of syncing
---@field job_id integer job id of current sync, default -1

---@class RsyncProjectConfig
---@field project_path string path to the root of the project
---@field file RsyncProjectStatus
---@field project RsyncProjectStatus

local project = {}

---@type RsyncProjectConfig[]
_RsyncProjectConfigs = _RsyncProjectConfigs or {}

local config_path = config.get_current_config().project_config_path

---Try find a config file.
---@return string?, string? # absolute path, or config not found error
local function get_config_file()
    local config_file_path = vim.fn.findfile(config_path, ".;")
    if vim.fn.len(config_file_path) > 0 then
        config_file_path = path:new(config_file_path):absolute()
        return config_file_path
    end
    return nil, "config file not found"
end

---Get project path from config file path.
---@param config_file_path string a path to the config file
---@return string # the project path
local function get_project_path(config_file_path)
    local project_path = string.sub(config_file_path, 1, -(1 + string.len(config_path)))
    return project_path
end

---Get config from file path.
---@param config_file_path string the path to the config file
---@return table? # config table or could not decode rsync.toml error
local function get_config(config_file_path)
    local succeeded, table = pcall(rsync_nvim.decode_toml, config_file_path)
    if succeeded then
        return table
    else
        error("Could not decode rsync.toml")
        log.error(string.format("get_config, could not decode '%s'", config_file_path))
    end
end

---Get project config if present
---@return RsyncProjectConfig?
function project.get_config_table()
    local config_file_path = get_config_file()
    -- if project does not contain config file
    if config_file_path == nil then
        return nil
    end
    -- if config already initialize
    local project_path = get_project_path(config_file_path)
    local table = _RsyncProjectConfigs[project_path]
    if table ~= nil then
        return table
    end

    -- decode config file and save to global table
    local project_table = get_config(config_file_path)
    if project_table ~= nil then
        project_table.project_path = project_path
        project_table.status = {
            file = {
                code = 0,
                state = FileSyncStates.DONE,
                job_id = -1,
            },
            project = {
                code = 0,
                state = FileSyncStates.DONE,
                job_id = -1,
            },
        }

        -- use the default value if ignorefile_paths is not specified in project config
        project_table.ignorefile_paths = project_table.ignorefile_paths or { ".gitignore" }
        _RsyncProjectConfigs[project_path] = project_table
        return project_table
    end
end

---Reload project config
function project.reload_config()
    local config_file_path = get_config_file()
    if config_file_path == nil then
        vim.api.nvim_err_writeln("Could not find rsync.toml")
        return
    end
    local project_path = get_project_path(config_file_path)
    -- reload
    _RsyncProjectConfigs[project_path] = nil
    project.get_config_table()
end

---Run passed function if project config is found
---@param fn fun(table) fuction to call if config is found
---@param report_error boolean? report error if nil or true
function project:run(fn, report_error)
    local config_table = project.get_config_table()
    if config_table == nil then
        if report_error == nil or report_error then
            vim.api.nvim_err_writeln("Could not find rsync.toml")
        end
        return
    end

    fn(config_table)
end

return project
