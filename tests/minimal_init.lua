local cur_path = vim.fn.expand("%:p:h")
vim.env.RSYNC_ROOT = cur_path

if os.getenv("TEST_COV") then
    require("luacov")
end

vim.opt.rtp:append(".")
-- for github action
vim.opt.rtp:append("plenary.nvim")
