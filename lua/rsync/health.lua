local M = {}

local function check_rsync()
    local found = vim.fn.executable("rsync")
    if found == 1 then
        local version_table = vim.fn.json_decode(vim.fn.system("rsync -V -V"))
        local version = version_table["version"]
        vim.health.report_ok(("`rsync` found v%s"):format(version))
    else
        vim.health.report_error(("`rsync` is not installed"):format())
    end
end

local function check_toml()
    local found = vim.fn.executable("luarocks")
    if found == 1 then
        local version = vim.fn.system("luarocks show toml --mversion")
        vim.health.report_ok(("`toml.lua` found v%s"):format(version))
    else
        vim.health.report_error(
            ("`toml` is not installed"):format(),
            { ("Run in shell: `luarocks install toml`"):format() }
        )
    end
end

M.check = function()
    check_rsync()
    check_toml()
end

return M
