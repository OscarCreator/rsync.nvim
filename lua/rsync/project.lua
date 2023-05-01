---
-- Project config functions

local rsync_nvim = require("rsync_nvim")
local path = require("plenary.path")

local project = {}

_RsyncProjectConfigs = _RsyncProjectConfigs or {}

local config_path = ".nvim/rsync.toml"

--- try find a config file.
-- @return string, or nil
-- @return absolute path, or config not found error
local get_config_file = function()
    local config_file_path = vim.fn.findfile(config_path, ".;")
    if vim.fn.len(config_file_path) > 0 then
        config_file_path = path:new(config_file_path):absolute()
        return config_file_path
    end
    return nil, "config file not found"
end

--- get project path from config file path.
-- @param config_file_path a path to the config file
-- @return the project path
local get_project_path = function(config_file_path)
    -- TODO maybe add 2 to sub length
    local project_path = string.sub(config_file_path, 1, -string.len(config_path))
    return project_path
end

--- get config from file path.
-- @param config_file_path the path to the config file
-- @return string, or error
-- @return a table with config, could not decode rsync.toml error
local get_config = function(config_file_path)
    local succeeded, table = pcall(rsync_nvim.decode_toml, config_file_path)
    if succeeded then
        return table
    else
        error("Could not decode rsync.toml")
    end
end

--- get project config if present
-- @return table, nil
-- @return table with config, nil if not found
project.get_config_table = function()
    local config_file_path = get_config_file()
    -- if project does not contain config file
    if config_file_path == nil then
        return
    end
    -- if config already initialize
    local project_path = get_project_path(config_file_path)
    local table = _RsyncProjectConfigs[project_path]
    if table ~= nil then
        return table
    end

    -- decode config file and save to global table
    table = get_config(config_file_path)
    if table ~= nil then
        table["project_path"] = project_path
        _RsyncProjectConfigs[project_path] = table
        return table
    end
end

-- TODO get project paths, local, remote

return project
