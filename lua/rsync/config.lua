---@class RsyncConfig
---@field fugitive_sync boolean
---@field sync_on_save boolean
---@field reload_file_after_sync boolean
---@field project_config_path string
---@field on_exit? fun(code: integer, command: string)
---@field on_stderr? fun(code: integer, command: string)

local M = {}

-- TODO allow more configuration options

---@type RsyncConfig
local config = {
    fugitive_sync = false,
    sync_on_save = true,
    reload_file_after_sync = true,
    project_config_path = ".nvim/rsync.toml",
    on_exit = nil,
    on_stderr = nil,
}

---Apply configuration from passed in table
---@param user_defaults table
function M.apply_config(user_defaults)
    if user_defaults == nil or type(user_defaults) ~= "table" then
        return
    end

    for key, value in pairs(user_defaults) do
        config[key] = value
    end
end

---Get current set configuration
---@return RsyncConfig
function M.get_current_config()
    return config
end

return M
