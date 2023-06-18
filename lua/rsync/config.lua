local config = {}
config.values = {
    fugitive_sync = false,
    sync_on_save = true,
    project_config_path = ".nvim/rsync.toml",
}

function config.set_defaults(user_defaults)
    user_defaults = vim.F.if_nil(user_defaults, {})

    for key, value in pairs(user_defaults) do
        config.values[key] = value
    end
end

return config
