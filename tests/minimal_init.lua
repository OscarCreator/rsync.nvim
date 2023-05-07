local cur_path = vim.fn.expand("%:p:h")
vim.env.RSYNC_ROOT = cur_path

vim.opt.rtp:append(".")
-- for github action
vim.opt.rtp:append("plenary.nvim")
