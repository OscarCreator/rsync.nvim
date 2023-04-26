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

local function check_cargo()
    local found = vim.fn.executable("cargo")
    if found == 1 then
        local version = vim.fn.system("cargo -V")
        vim.health.report_ok(("`cargo` found %s"):format(version))
    else
        vim.health.report_error(
            ("`cargo` is not installed"):format(),
            { ("Install cargo"):format() }
        )
    end
end

M.check = function()
    check_rsync()
    check_cargo()
end

return M
