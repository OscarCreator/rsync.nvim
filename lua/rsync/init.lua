local toml = require("toml")

-- TODO save 

local M = {}

-- TODO make sure you only do syncing on at a time. Is there is a sync, wait for it to finish
-- before trying triggering sync again.

local rsync_nvim = vim.api.nvim_create_augroup(
    "rsync_nvim",
    { clear = true }
)

local get_config = function ()
    local config_file_path = vim.fn.findfile(".nvim/rsync.toml", ".;")
    if vim.fn.len(config_file_path) > 0 then
        local succeeded, table = pcall(toml.decodeFromFile, config_file_path)
        if succeeded then
            return table
        else
            print("Error decoding file")
        end
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
                        M.sync_project('.', config['remote_path'])
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

M.sync_project = function (local_path, remote_path)
    -- todo execute rsync command
    vim.b.rsync_status = nil
    local res = vim.fn.jobstart('rsync -varze --filter=\':- .gitignore\' ' .. local_path .. ' ' .. remote_path, {
        on_stdout = function (id, output, _)
            -- TODO save output
            --print("output" .. vim.inspect(output))
        end,
        on_stderr = function (id, output, _)
            -- skip when function reports no error
            if vim.inspect(output) ~= vim.inspect({ "" }) then
                -- TODO print output
                --print("error:" .. vim.inspect(output))
                --vim.b.rsync_status = 1
            end
        end,

        -- job done executing
        on_exit = function (j, code, _)
            vim.b.rsync_status = code
            print("exit:" .. vim.inspect(code))
        end,
        stdout_buffered = true,
        stderr_buffered = true
    })

    if res == -1 then
        print("command not executable")
    elseif res == 0 then
        print("invalid arguments")
    else
        print("success")
    end
end

M.status = function()

end

M.setup = function(user_config)
    require('rsync.config').set_defaults(user_config)
end

return M
