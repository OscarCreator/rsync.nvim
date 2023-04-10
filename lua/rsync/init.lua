
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
                -- TODO sync
                -- print("syncing with rsync")
            end,
            group = rsync_nvim,
            buffer = vim.api.nvim_get_current_buf()
        })
    end
end

vim.api.nvim_create_autocmd({"BufEnter"}, {
    callback = function()
        -- only configure if autocmd not already defined
        -- TOOD check if we are in a config project
        if vim.b.init == nil then
            configure_sync()
        end
        vim.b.init = 1
    end,
    group = rsync_nvim,
})

