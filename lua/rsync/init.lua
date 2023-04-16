local toml = require("toml")
local path = require("plenary.path")

local M = {}

-- TODO make sure you only do syncing on at a time. Is there is a sync, wait for it to finish
-- before trying triggering sync again.

local rsync_nvim = vim.api.nvim_create_augroup(
    "rsync_nvim",
    { clear = true }
)

local get_config = function ()
    local file_path = ".nvim/rsync.toml"
    local config_file_path = vim.fn.findfile(file_path, ".;")
    if vim.fn.len(config_file_path) > 0 then
        -- convert to absolute
        config_file_path = path:new(config_file_path):absolute()
        local succeeded, table = pcall(toml.decodeFromFile, config_file_path)
        if succeeded then
            local project_path = string.sub(config_file_path, 1, -string.len(file_path))
            table['project_path'] = project_path
            return table
        else
            error("Could not decode rsync.toml")
        end
    end
end

-- TODO move to separate file
local sync_project = function (source_path, destination_path)
    -- todo execute rsync command
    vim.b.rsync_status = nil
    local command = 'rsync -varze -f\':- .gitignore\' -f\'- .nvim\' ' .. source_path .. ' ' .. destination_path
    local res = vim.fn.jobstart(command, {
        on_stderr = function (id, output, _)
            -- skip when function reports no error
            if vim.inspect(output) ~= vim.inspect({ "" }) then
                -- TODO print save output to temporary log file
                vim.api.nvim_err_writeln("Error executing: " .. command)
            end
        end,

        -- job done executing
        on_exit = function (j, code, _)
            vim.b.rsync_status = code
            if code ~= 0 then
                vim.api.nvim_err_writeln("rsync execute with result code: " .. code)
            end
        end,
        stdout_buffered = true,
        stderr_buffered = true
    })

    if res == -1 then
        error("Could not execute rsync. Make sure that rsync in on your path")
    elseif res == 0 then
        print("Invalid command: " .. command)
    end
end

vim.api.nvim_create_autocmd({"BufEnter"}, {
    callback = function()
        -- only initialize once per buffer
        if vim.b.rsync_init == nil then
            local config = get_config()
            if config ~= nil then
                vim.api.nvim_create_autocmd({"BufWritePost"}, {
                    callback = function()
                        sync_project(config['project_path'], config['remote_path'])
                    end,
                    group = rsync_nvim,
                    buffer = vim.api.nvim_get_current_buf()
                })
                -- try to initialize if no config file was present at start
                vim.b.rsync_init = 1
            end
        end
    end,
    group = rsync_nvim,
})


-- sync all files from remote
vim.api.nvim_create_user_command("RsyncDown", function ()
    local config = get_config()
    if config ~= nil then
        sync_project(config['remote_path'], config['project_path'])
    else
        vim.api.nvim_err_writeln("Could not find rsync.toml")
    end
end, {})


-- Return status of syncing
M.status = function()
    if vim.b.rsync_status == nil then
        return "Syncing files"
    elseif vim.b.rsync_status ~= 0 then
        return "Failed to sync"
    else
        return "Up to date"
    end
end

M.setup = function(user_config)
    require('rsync.config').set_defaults(user_config)
end

return M
