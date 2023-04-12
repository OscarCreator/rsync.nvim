
local M = {}

-- TODO make sure you only do syncing on at a time. Is there is a sync, wait for it to finish
-- before trying triggering sync again.

local rsync_nvim = vim.api.nvim_create_augroup(
    "rsync_nvim",
    { clear = true }
)

-- configure current buffer with aucmd for syncing 
local configure_sync = function()

    -- check for config file
    -- if defined then create autocmd
    -- TODO check if au group already exist for buffer, then don't do anything
    if true then
        vim.api.nvim_create_autocmd({"BufWritePost"}, {
            callback = function()
                M.sync_project()
            end,
            group = rsync_nvim,
            buffer = vim.api.nvim_get_current_buf()
        })
    end
end

local get_config_file = function ()
    local config_file = vim.fn.findfile(".rsyncrc", ".;")
    if vim.fn.len(config_file) > 0 then
        return config_file
    end
end

vim.api.nvim_create_autocmd({"BufEnter"}, {
    callback = function()
        if get_config_file() ~= nil then
            -- only configure if autocmd not already defined
            if vim.b.rsync_init == nil then
                configure_sync()
            end
        end
        vim.b.rsync_init = 1
    end,
    group = rsync_nvim,
})

M.sync_project = function ()
    -- todo execute rsync command
    local res = vim.fn.jobstart('ls', {
        -- job id, output, "stdout"
        -- triggered on per line
        on_stdout = function (c, d, n)
            print("output" .. vim.inspect(d) .. n)
        end,
        on_stderr = function (c, d, n)
            -- skip when function reports no error
            if vim.inspect(d) ~= vim.inspect({ "" }) then
                print("error:" .. vim.inspect(d) .. " " .. n)
            end
        end,

        -- job done executing
        -- job id, exit code, event type
        on_exit = function (j, c, t)
            print("exit:" .. vim.inspect(c))
        end,
        stdout_buffered = true,
        stderr_buffered = true
    })
end

return M
