local toml = require("toml")
local path = require("plenary.path")

local config = {}
config.values = {}

-- https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/config.lua
function config.set_defaults(user_defaults)
    user_defaults = vim.F.if_nil(user_defaults, {})

    for key, value in pairs(user_defaults) do
        config.values[key] = value
    end
end

function config.get_project()
    local file_path = ".nvim/rsync.toml"
    local config_file_path = vim.fn.findfile(file_path, ".;")
    if vim.fn.len(config_file_path) > 0 then
        -- convert to absolute
        config_file_path = path:new(config_file_path):absolute()
        local succeeded, table = pcall(toml.decodeFromFile, config_file_path)
        if succeeded then
            local project_path = string.sub(config_file_path, 1, -string.len(file_path))
            table["project_path"] = project_path
            return table
        else
            error("Could not decode rsync.toml")
        end
    end
end

return config
