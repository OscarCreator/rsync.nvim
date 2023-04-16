
local config = {}
config.values = {}

-- https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/config.lua
function config.set_defaults(user_defaults)
    user_defaults = vim.F.if_nil(user_defaults, {})

    for key, value in pairs(user_defaults) do
        config.values[key] = value
    end
end

return
