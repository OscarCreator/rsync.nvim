local M = {}

local function check_rsync()
    local found = vim.fn.executable("rsync")
    if found == 1 then
        local version_json = vim.fn.system("rsync -V -V")
        if vim.v.shell_error == 0 then
            local version_table = vim.fn.json_decode(version_json)
            local version = version_table["version"]
            vim.health.report_ok(("`rsync` found v%s"):format(version))
        else
            -- old way of retrieving version
            local version_text = vim.fn.system("rsync --version")
            local _, _, version = string.find(version_text, "^([^\n]+)\n")
            if version == nil then
                vim.health.report_warn(("`rsync` is installed but could not get version"):format())
            else
                vim.health.report_ok(("`rsync` found %s"):format(version))
            end
        end
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
        vim.health.report_error(("`cargo` is not installed"):format(), { ("Install cargo"):format() })
    end
end

M.check = function()
    check_rsync()
    check_cargo()
end

return M
