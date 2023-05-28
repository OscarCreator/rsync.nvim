local project = require("rsync.project")

describe("project", function()
    describe("no rsync.toml", function()
        it("get_config_table", function()
            assert.equals(project.get_config_table(), nil)
        end)
    end)
end)
