local helpers = require("tests.rsync_helper")

describe("rsync", function()
    before_each(function()
        helpers.create_workspace()
        helpers.mkdir(".nvim")
    end)

    after_each(function()
        helpers.cleanup_workspace()
        -- Needed to have reliable coverage
        if os.getenv("TEST_COV") then
            require("luacov.runner").save_stats()
        end
    end)

    describe("au", function()
        it("RsyncLog", function()
            vim.cmd.RsyncLog()
            local file_name = vim.fn.expand("%:t")
            assert.equals(file_name, "rsync.log")
        end)

        it("RsyncCancelJob", function()
            local status, err = pcall(vim.cmd.RsyncCancelJob)
            assert.equals(status, false)
            assert.equals(err, "Vim:Could not find rsync.toml")
        end)

        it("RsyncConfig", function()
            local status, err = pcall(vim.cmd.RsyncConfig)
            assert.equals(status, true)
            assert.equals(err, "")
        end)

        it("RsyncProjectConfig", function()
            helpers.write_file(".nvim/rsync.toml", { 'remote_path = "' .. helpers.dest .. '/"' })
            helpers.write_file("test.c", { "eueueu" })
            helpers.assert_file_not_copied("test.c")

            local status, err = pcall(vim.cmd.RsyncProjectConfig)
            assert.equals(status, true)
            assert.equals(err, "")
        end)

        it("RsyncProjectConfig reload", function()
            local project = require("rsync.project")

            -- create an initial rsync.toml with a path
            helpers.write_file(".nvim/rsync.toml", { 'remote_path = "path1"' })
            assert.equals(project.get_config_table().remote_path, "path1")

            -- change the path, and reload the config
            helpers.write_file(".nvim/rsync.toml", { 'remote_path = "path2"' })
            local status, err = pcall(vim.cmd.RsyncProjectConfig, "reload")
            assert.equals(status, true)
            assert.equals(err, "")
            assert.equals(project.get_config_table().remote_path, "path2")
        end)

        it("RsyncProjectConfig delete", function()
            local project = require("rsync.project")

            -- create an initial rsync.toml with a path
            helpers.write_file(".nvim/rsync.toml", { 'remote_path = "path1"' })
            assert.equals(project.get_config_table().remote_path, "path1")

            -- delete config and reload the config
            helpers.delete_file(".nvim/rsync.toml")
            local status, err = pcall(vim.cmd.RsyncProjectConfig, "reload")
            assert.equals(status, false)
            assert.equals(err, "Vim:Could not find rsync.toml")
            assert.equals(project.get_config_table(), nil)
        end)

        it("RsyncProjectConfig unknown subcommand", function()
            local status, err = pcall(vim.cmd.RsyncProjectConfig, "eueu")
            assert.equals(status, false)
            assert.equals(err, "Vim:Unknown subcommand: 'eueu'")
        end)

        it("RsyncSaveSync unknown subcommand", function()
            local status, err = pcall(vim.cmd.RsyncSaveSync, "eueu")
            assert.equals(status, false)
            assert.equals(err, "Vim:Unknown subcommand: 'eueu'")
        end)
    end)

    describe("missing rsync.toml", function()
        it("status returns empty string", function()
            helpers.write_file("test.c", { "eueueu" })
            local status, err = pcall(vim.cmd.w)
            assert.equals(status, false)
            assert(string.match(err, "Could not find rsync.toml"), "Did not print out missing rsync.toml")
            assert.equals(require("rsync").status(), "")
        end)
    end)

    describe("setup config", function()
        it("fugitive_sync", function()
            require("rsync").setup({ fugitive_sync = true })
        end)
    end)

    describe("files", function()
        local function setup(code)
            helpers.write_file(".nvim/rsync.toml", { 'remote_path = "' .. helpers.dest .. '/"' })
            helpers.write_file("test.c", { "eueueu" })
            helpers.assert_file_not_copied("test.c")

            code()
        end

        describe("not copied", function()
            require("rsync").setup({ sync_on_save = false })
            it("on save", function()
                setup(function()
                    -- this triggers autocommand
                    vim.cmd.w()
                    assert.equals(require("rsync").status(), "Sync succeeded")
                    helpers.wait_sync()
                    assert.equals(require("rsync").status(), "Sync succeeded")
                    helpers.assert_file_not_copied("test.c")
                end)
            end)

            -- restore default
            require("rsync").setup({ sync_on_save = true })

            it("on RsyncCancelJob all", function()
                setup(function()
                    vim.cmd.w()
                    assert.equals(require("rsync").status(), "Syncing up files")
                    vim.cmd.RsyncCancelJob("all")
                    helpers.wait_sync()
                    assert.equals(require("rsync").status(), "Sync cancelled")
                end)
            end)

            it("on RsyncCancelJob file", function()
                setup(function()
                    vim.cmd.RsyncUpFile()
                    vim.cmd.RsyncCancelJob("file")
                    helpers.wait_sync_file()
                    helpers.assert_file_not_copied("test.c")
                end)
            end)

            it("on RsyncCancelJob project", function()
                setup(function()
                    vim.cmd.w()
                    vim.cmd.RsyncCancelJob("project")
                    helpers.wait_sync()
                    helpers.assert_file_not_copied("test.c")
                end)
            end)
        end)

        describe("copied", function()
            it("on RsyncCancelJob file not cancelling project sync", function()
                setup(function()
                    vim.cmd.w()
                    assert.equals(require("rsync").status(), "Syncing up files")
                    vim.cmd.RsyncCancelJob("file")
                    helpers.wait_sync()
                    assert.equals(require("rsync").status(), "Sync succeeded")
                    helpers.assert_file("test.c")
                end)
            end)

            it("on RsyncCancelJob project not cancelling file sync", function()
                setup(function()
                    vim.cmd.RsyncUpFile()
                    vim.cmd.RsyncCancelJob("project")
                    helpers.wait_sync_file()
                    helpers.assert_file("test.c")
                end)
            end)

            it("on save", function()
                setup(function()
                    -- this triggers autocommand
                    vim.cmd.w()
                    assert.equals(require("rsync").status(), "Syncing up files")
                    helpers.wait_sync()
                    assert.equals(require("rsync").status(), "Sync succeeded")
                    helpers.assert_file("test.c")
                end)
            end)

            it("on save after toggling RsyncSaveSync", function()
                setup(function()
                    -- this triggers autocommand
                    local status, err = pcall(vim.cmd.RsyncSaveSync)
                    assert.equals(status, false)
                    assert.equals(err, "Wrong number of arguments")

                    status, err = pcall(vim.cmd.RsyncSaveSync, "disable")
                    assert.equals(status, true)
                    vim.cmd.w()
                    helpers.wait_sync()
                    helpers.assert_file_not_copied("test.c")

                    status, err = pcall(vim.cmd.RsyncSaveSync, "enable")
                    assert.equals(status, true)
                    vim.cmd.w()
                    helpers.wait_sync()
                    helpers.assert_file("test.c")

                    helpers.write_file("test2.d", { "12345" })
                    status, err = pcall(vim.cmd.RsyncSaveSync, "toggle")
                    assert.equals(status, true)
                    vim.cmd.w()
                    helpers.wait_sync()
                    helpers.assert_file_not_copied("test2.d")

                    status, err = pcall(vim.cmd.RsyncSaveSync, "toggle")
                    assert.equals(status, true)
                    vim.cmd.w()
                    helpers.wait_sync()
                    helpers.assert_file("test2.d")
                end)
            end)

            it("reschedule save", function()
                setup(function()
                    -- this triggers autocommand
                    vim.cmd.w()
                    vim.cmd.w()
                    vim.cmd.w()
                    vim.cmd.w()
                    assert.equals(require("rsync").status(), "Syncing up files")
                    helpers.wait_sync()
                    assert.equals(require("rsync").status(), "Sync succeeded")
                    helpers.assert_file("test.c")
                end)
            end)

            it("RsyncDown is aborted", function()
                setup(function()
                    -- this triggers autocommand
                    vim.cmd.w()
                    local status, err = pcall(vim.cmd.RsyncDown)
                    assert.equals(status, false)
                    assert.equals(err, "Vim:Could not sync down, due to sync up still running")
                    assert.equals(require("rsync").status(), "Syncing up files")
                    helpers.wait_sync()
                    assert.equals(require("rsync").status(), "Sync succeeded")
                    helpers.assert_file("test.c")
                end)
            end)

            it("on RsyncUp", function()
                setup(function()
                    vim.cmd.RsyncUp()
                    helpers.wait_sync()
                    helpers.assert_file("test.c")
                end)
            end)

            it("RsyncDownFile is aborted", function()
                setup(function()
                    vim.cmd.RsyncUpFile()
                    local status, err = pcall(vim.cmd.RsyncDownFile)
                    assert.equals(status, false)
                    assert.equals(err, "Vim:File still syncing up")

                    helpers.wait_sync_file()
                    helpers.assert_file("test.c")
                end)
            end)

            it("RsyncDownFile in sub-folder", function()
                setup(function()
                    helpers.mkdir("build")
                    -- current active file
                    helpers.write_file("build/aabb.txt", { "obobob12" })
                    helpers.mkdir_remote("")
                    helpers.mkdir_remote("build")
                    helpers.write_remote_file("build/aabb.txt", { "121212" })

                    -- change pwd to build folder
                    vim.cmd.cd("build")
                    vim.cmd.RsyncDownFile()

                    helpers.wait_sync_file()
                    helpers.assert_file("build/aabb.txt")
                end)
            end)

            it("RsyncUpFile is aborted", function()
                setup(function()
                    vim.cmd.RsyncUpFile()
                    local status, err = pcall(vim.cmd.RsyncUpFile)
                    assert.equals(status, false)
                    assert.equals(err, "Vim:File still syncing up")

                    helpers.wait_sync_file()
                    helpers.assert_file("test.c")
                end)
            end)

            it("on RsyncUpFile inside folder", function()
                setup(function()
                    vim.cmd.w()
                    helpers.wait_sync()
                    helpers.assert_file("test.c")

                    helpers.mkdir("sub")
                    helpers.write_file("sub/second_test.tt", { "labbal" })
                    -- this is needed due to rsync will not create remote directories
                    -- if they do not exist
                    helpers.mkdir_remote("sub")
                    -- make sure you don't have to be in project root
                    vim.cmd.cd("sub")
                    vim.cmd.RsyncUpFile()

                    helpers.wait_sync_file()
                    helpers.assert_file("sub/second_test.tt")
                end)
            end)

            it("on RsyncUpFile inside not exsisting remote folder", function()
                setup(function()
                    helpers.mkdir("sub")
                    helpers.write_file("sub/second_test.tt", { "labbal" })

                    vim.cmd.RsyncUpFile()
                    helpers.wait_sync_file()
                    helpers.assert_file("sub/second_test.tt")
                    helpers.assert_file_not_copied("test.c")
                end)
            end)
        end)

        describe("hooks", function()
            it("success, on_exit called, on_error not called", function()
                setup(function()
                    local res_code = -1
                    local res_data = ""
                    require("rsync").setup({
                        on_exit = function(code, command)
                            res_code = code
                        end,
                        on_stderr = function(data, command)
                            res_data = data
                        end,
                    })

                    vim.cmd.w()

                    helpers.wait_sync()
                    assert.equals(res_code, 0)
                    assert.equals(res_data[1], "")

                    -- restore default
                    require("rsync").setup({ on_exit = function(_, _) end, on_error = function(_, _) end })
                end)
            end)

            it("error, on_exit called, on_error called", function()
                -- use an unreachable host to produce an error
                helpers.write_file(".nvim/rsync.toml", { 'remote_path = "ureachable@host:/tmp/rsync_test"' })

                local res_code = -1
                local res_data = ""
                require("rsync").setup({
                    on_exit = function(code, _)
                        res_code = code
                    end,
                    on_stderr = function(data, _)
                        res_data = data
                    end,
                })

                vim.cmd.w()

                helpers.wait_sync()
                assert.equals(res_code, 255)
                local has_error, _ = string.find(res_data[1], "ssh: Could not resolve hostname host")
                assert.equals(has_error, 1)

                -- restore default
                require("rsync").setup({ on_exit = function(_, _) end, on_error = function(_, _) end })
            end)
        end)
    end)

    describe("files re-ignored", function()
        local filters = {
            { "*.txt", "!should_ignore.txt", "!log.txt" },
            { "*.txt", "!should_ignore.txt", "!build/log.txt" },
            { "!build/log.txt", "*.txt", "!should_ignore.txt" },
            { "!should_ignore.txt", "!build/*", "*.txt" },
            { "should_ignore.txt", "!*.txt" },
            { "!*.txt", "should_ignore.txt" },
            { "!should*", "*.txt", "!build" },
        }
        describe("down", function()
            local function setup(key, filter, code)
                helpers.write_file(".nvim/rsync.toml", { 'remote_path = "' .. helpers.dest .. '/"' })
                helpers.write_file(".gitignore", filter)

                helpers.mkdir_remote("")
                helpers.write_remote_file("should_ignore.txt", { "this file\nshould not be synced" })
                helpers.write_remote_file("test.c", { "eueueu" })
                helpers.mkdir_remote("build")
                helpers.write_remote_file("build/log.txt", { "logging data" })

                helpers.assert_on_remote_only("test.c")
                helpers.assert_on_remote_only("should_ignore.txt")
                helpers.assert_on_remote_only("build/log.txt")

                code()

                helpers.assert_file("test.c")
                helpers.assert_file("should_ignore.txt")
                if key == 7 then
                    -- this pattern in unique
                    helpers.assert_on_remote_only("build/log.txt")
                else
                    helpers.assert_file("build/log.txt")
                end
            end

            for k, filter in pairs(filters) do
                it("on RsyncDown key:" .. k, function()
                    setup(k, filter, function()
                        vim.cmd.RsyncDown()
                        helpers.wait_sync()
                    end)
                end)
            end
        end)
        describe("up", function()
            local function setup(key, filter, code)
                helpers.write_file(".nvim/rsync.toml", { 'remote_path = "' .. helpers.dest .. '/"' })
                helpers.write_file(".gitignore", filter)
                helpers.write_file("should_ignore.txt", { "this file\nshould not be synced" })
                helpers.write_file("test.c", { "eueueu" })
                helpers.mkdir("build")
                helpers.write_file("build/log.txt", { "logging data" })

                helpers.assert_file_not_copied("test.c")
                helpers.assert_file_not_copied("should_ignore.txt")
                helpers.assert_file_not_copied("build/log.txt")

                code()

                helpers.assert_file("test.c")
                helpers.assert_file("should_ignore.txt")
                if key == 7 then
                    -- this pattern in unique
                    helpers.assert_file_not_copied("build/log.txt")
                else
                    helpers.assert_file("build/log.txt")
                end
            end
            for k, filter in pairs(filters) do
                it("on save key:" .. k, function()
                    setup(k, filter, function()
                        -- this triggers autocommand
                        vim.cmd.w()
                        helpers.wait_sync()
                    end)
                end)

                it("on RsyncUp key:" .. k, function()
                    setup(k, filter, function()
                        vim.cmd.RsyncUp()
                        helpers.wait_sync()
                    end)
                end)
            end
        end)
    end)

    describe("files ignored", function()
        local function setup_with_gitignore(code)
            helpers.write_file(".nvim/rsync.toml", { 'remote_path = "' .. helpers.dest .. '/"' })
            helpers.write_file(".gitignore", { "should_ignore.txt" })
            helpers.write_file("should_ignore.txt", { "this file\nshould not be synced" })
            helpers.write_file("test.c", { "eueueu" })

            helpers.assert_file_not_copied("test.c")
            helpers.assert_file_not_copied("should_ignore.txt")

            code()

            helpers.assert_file("test.c")
            helpers.assert_file_not_copied("should_ignore.txt")
        end

        it("on save", function()
            setup_with_gitignore(function()
                -- this triggers autocommand
                vim.cmd.w()
                helpers.wait_sync()
            end)
        end)

        it("on RsyncUp", function()
            setup_with_gitignore(function()
                vim.cmd.RsyncUp()
                helpers.wait_sync()
            end)
        end)

        it("on RsyncUp with gitignore comments", function()
            setup_with_gitignore(function()
                -- Overwrite .gitignore w/ added comments
                helpers.write_file(".gitignore", { "# Comment 1",  "should_ignore.txt", "# Another comment" })
                vim.cmd.RsyncUp()
                helpers.wait_sync()
            end)
        end)

        it("on RsyncUpFile", function()
            setup_with_gitignore(function()
                helpers.write_file("second_test.tt", { "labbal" })
                vim.cmd.e("test.c")
                vim.cmd.RsyncUpFile()
                helpers.wait_sync_file()
                helpers.assert_file_not_copied("second_test.tt")
            end)
        end)

        it("on RsyncUpFile with filepath", function()
            setup_with_gitignore(function()
                helpers.write_file("second_test.tt", { "labbal" })
                vim.cmd.e("second_test.tt")
                vim.cmd.RsyncUpFile("test.c")
                helpers.wait_sync_file()
                helpers.assert_file_not_copied("second_test.tt")
            end)
        end)

        local function setup_with_multiple_ignore_files(code)
            helpers.write_file(
                ".nvim/rsync.toml",
                { 'remote_path = "' .. helpers.dest .. '/"', 'ignorefile_paths = [ ".gitignore.1", ".gitignore.2" ]' }
            )
            helpers.write_file(".gitignore.1", { "local_should_ignore_1.txt", "remote_should_ignore_1.txt" })
            helpers.write_file(".gitignore.2", { "local_should_ignore_2.txt", "remote_should_ignore_2.txt" })
            helpers.write_file("local_should_ignore_1.txt", { "this file\nshould not be synced" })
            helpers.write_file("local_should_ignore_2.txt", { "this file\nshould not be synced" })
            helpers.write_file("local.c", { "eueueu" })
            helpers.mkdir_remote("")
            helpers.write_remote_file("remote_should_ignore_1.txt", { "this file\nshould not be synced" })
            helpers.write_remote_file("remote_should_ignore_2.txt", { "this file\nshould not be synced" })
            helpers.write_remote_file("remote.c", { "eueueu" })

            helpers.assert_file_not_copied("local.c")
            helpers.assert_file_not_copied("local_should_ignore_1.txt")
            helpers.assert_file_not_copied("local_should_ignore_2.txt")

            helpers.assert_on_remote_only("remote.c")
            helpers.assert_on_remote_only("remote_should_ignore_1.txt")
            helpers.assert_on_remote_only("remote_should_ignore_2.txt")

            code()
        end

        it("on RsyncUp (multiple ignore files)", function()
            setup_with_multiple_ignore_files(function()
                vim.cmd.RsyncUp()
                helpers.wait_sync()

                helpers.assert_file("local.c")
                helpers.assert_file_not_copied("local_should_ignore_1.txt")
                helpers.assert_file_not_copied("local_should_ignore_2.txt")
            end)
        end)

        it("on RsyncDown (multiple ignore files)", function()
            setup_with_multiple_ignore_files(function()
                vim.cmd.RsyncDown()
                helpers.wait_sync()

                helpers.assert_file("remote.c")
                helpers.assert_on_remote_only("remote_should_ignore_1.txt")
                helpers.assert_on_remote_only("remote_should_ignore_2.txt")
            end)
        end)

        local function setup_with_default_ignore_files(code)
            helpers.write_file(".nvim/rsync.toml", { 'remote_path = "' .. helpers.dest .. '/"' })

            -- .gitignore at project root is read by default
            helpers.write_file(".gitignore", { "local_should_ignore.txt", "remote_should_ignore.txt" })
            helpers.write_file("local_should_ignore.txt", { "this file\nshould not be synced" })
            helpers.mkdir_remote("")
            helpers.write_remote_file("remote_should_ignore.txt", { "this file\nshould not be synced" })
            helpers.assert_file_not_copied("local_should_ignore.txt")
            helpers.assert_on_remote_only("remote_should_ignore.txt")

            code()
        end

        it("on RsyncUp (default ignore file)", function()
            setup_with_default_ignore_files(function()
                vim.cmd.RsyncUp()
                helpers.wait_sync()

                helpers.assert_file_not_copied("local_should_ignore.txt")
            end)
        end)
        it("on RsyncDown (default ignore file)", function()
            setup_with_default_ignore_files(function()
                vim.cmd.RsyncDown()
                helpers.wait_sync()

                helpers.assert_on_remote_only("remote_should_ignore.txt")
            end)
        end)

        local function setup_with_no_ignore_files(code)
            -- ignorefile_paths is explicitly set to none
            helpers.write_file(
                ".nvim/rsync.toml",
                { 'remote_path = "' .. helpers.dest .. '/"', "ignorefile_paths = []" }
            )

            -- this ignore file is not honored
            helpers.write_file(".gitignore", { "local_should_sync.txt", "remote_should_sync.txt" })
            helpers.write_file("local_should_sync.txt", { "this file\nshould be synced" })
            helpers.mkdir_remote("")
            helpers.write_remote_file("remote_should_sync.txt", { "this file\nshould be synced" })

            helpers.assert_file_not_copied("local_should_sync.txt")
            helpers.assert_on_remote_only("remote_should_sync.txt")

            code()
        end

        it("on RsyncUp (explicitly none ignore files)", function()
            setup_with_no_ignore_files(function()
                vim.cmd.RsyncUp()
                helpers.wait_sync()
                helpers.assert_file("local_should_sync.txt")
            end)
        end)

        it("on RsyncDown (explicitly none ignore files)", function()
            setup_with_no_ignore_files(function()
                vim.cmd.RsyncDown()
                helpers.wait_sync()
                helpers.assert_file("remote_should_sync.txt")
            end)
        end)
    end)

    local function setup_with_remote_includes(config)
        helpers.write_file(".nvim/rsync.toml", config)

        helpers.write_file(".gitignore", { "remote_file*" })
        helpers.write_file("test.c", { "eueueu" })
        helpers.assert_file_not_copied("test.c")

        vim.cmd.w()
        helpers.wait_sync()

        helpers.assert_file("test.c")
    end

    describe("files deleted", function()
        it("on remote", function()
            setup_with_remote_includes({
                'remote_path = "' .. helpers.dest .. '/"',
                'remote_includes = ["remote_file.h"]',
            })
            -- add files to remote (not part of .gitignore))
            helpers.write_file("to_be_deleted.md", { "does not matter", "really." })
            helpers.write_remote_file("remote_file.h", { "this file should be able to sync down" })
            helpers.assert_on_remote_only("remote_file.h")
            helpers.write_remote_file("remote_file_2.t", { "some nonsense" })
            helpers.assert_on_remote_only("remote_file_2.t")

            vim.cmd.w()
            helpers.wait_sync()

            -- delete the file locally
            helpers.delete_file("to_be_deleted.md")

            -- switch file
            vim.cmd.e("test.c")
            -- sync up
            vim.cmd.w()
            helpers.wait_sync()

            -- sync down does not remove file
            helpers.assert_file_delete("to_be_deleted.md")
            helpers.assert_on_remote_only("remote_file_2.t")
            helpers.assert_on_remote_only("remote_file.h")
            helpers.assert_file("test.c")

            -- down sync still works
            vim.cmd.RsyncDown()
            assert.equals(require("rsync").status(), "Syncing down files")
            helpers.wait_sync()

            --
            helpers.assert_file_delete("to_be_deleted.md")
            helpers.assert_files({ "remote_file.h", "test.c" })
            helpers.assert_on_remote_only("remote_file_2.t")
        end)
    end)

    describe("remote includes", function()
        it("synced with RsyncDownFile", function()
            setup_with_remote_includes({
                'remote_path = "' .. helpers.dest .. '/"',
                'remote_includes = ["remote_file.h"]',
            })
            helpers.write_remote_file("remote_file.h", { "this file should be able to sync down" })
            helpers.assert_on_remote_only("remote_file.h")

            -- sync down file
            vim.cmd.RsyncDown()
            helpers.wait_sync()

            -- edit remote file
            local remote_text = { "some other content", "which is replaced" }
            helpers.write_remote_file("remote_file.h", remote_text)

            vim.cmd.e("remote_file.h")
            local buf = vim.api.nvim_get_current_buf()
            vim.cmd.RsyncDownFile()
            -- Rsync Up/Down File is aborted
            local status, err = pcall(vim.cmd.RsyncUpFile)
            assert.equals(status, false)
            assert.equals(err, "Vim:File still syncing down")
            local status, err = pcall(vim.cmd.RsyncDownFile)
            assert.equals(status, false)
            assert.equals(err, "Vim:File still syncing down")

            -- open another file just to check that buffer
            -- is update even if it not is the current.
            vim.cmd.e("test.c")
            -- this should update buffer after sync is done
            helpers.wait_sync_file()

            local lines = vim.api.nvim_buf_get_lines(buf, 0, 2, false)
            assert(vim.deep_equal(lines, remote_text), "found:" .. vim.inspect(lines))
        end)

        it("synced with RsyncDownFile file", function()
            setup_with_remote_includes({
                'remote_path = "' .. helpers.dest .. '/"',
                'remote_includes = ["remote_file.h"]',
            })
            helpers.write_remote_file("remote_file.h", { "this file should be able to sync down" })
            helpers.write_remote_file("remote_file_2.h", { "this file should also be able to sync down" })
            helpers.assert_on_remote_only("remote_file.h")
            helpers.assert_on_remote_only("remote_file_2.h")

            -- sync down file
            vim.cmd.RsyncDown()
            helpers.wait_sync()

            -- edit remote file
            local remote_text = { "some other content", "which is replaced" }
            local remote_text_2 = { "some other content in second file", "which is replaced" }
            helpers.write_remote_file("remote_file.h", remote_text)
            helpers.write_remote_file("remote_file_2.h", remote_text_2)

            vim.cmd.e("remote_file.h")
            vim.cmd.RsyncDownFile("remote_file_2.h")
            -- Rsync Up/Down File is aborted
            local status, err = pcall(vim.cmd.RsyncUpFile)
            assert.equals(status, false)
            assert.equals(err, "Vim:File still syncing down")
            local status, err = pcall(vim.cmd.RsyncDownFile)
            assert.equals(status, false)
            assert.equals(err, "Vim:File still syncing down")

            -- open another file just to check that buffer
            -- is update even if it not is the current.
            vim.cmd.e("test.c")
            -- this should update buffer after sync is done
            helpers.wait_sync_file()

            vim.cmd.e("remote_file_2.h")
            local buf = vim.api.nvim_get_current_buf()
            local lines = vim.api.nvim_buf_get_lines(buf, 0, 2, false)
            assert(vim.deep_equal(lines, remote_text_2), "found:" .. vim.inspect(lines))
        end)

        it("synced with RsyncDown", function()
            setup_with_remote_includes({
                'remote_path = "' .. helpers.dest .. '/"',
                'remote_includes = ["remote_file.h"]',
            })
            helpers.write_remote_file("remote_file.h", { "this file should be able to sync down" })
            helpers.assert_on_remote_only("remote_file.h")

            vim.cmd.RsyncDown()
            helpers.wait_sync()

            helpers.assert_files({ "test.c", "remote_file.h" })
        end)

        it("RsyncUp is aborted", function()
            setup_with_remote_includes({
                'remote_path = "' .. helpers.dest .. '/"',
                'remote_includes = ["remote_file.h"]',
            })
            helpers.write_remote_file("remote_file.h", { "this file should be able to sync down" })
            helpers.assert_on_remote_only("remote_file.h")

            vim.cmd.RsyncDown()
            local status, err = pcall(vim.cmd.RsyncUp)
            assert.equals(status, false)
            assert.equals(err, "Vim:Could not sync up, due to sync down still running")

            helpers.wait_sync()

            helpers.assert_files({ "test.c", "remote_file.h" })
        end)

        it("synced with RsyncDown multiple files", function()
            setup_with_remote_includes({
                'remote_path = "' .. helpers.dest .. '/"',
                'remote_includes = ["remote_file.h", "remote_file_2"]',
            })
            helpers.write_remote_file("remote_file.h", { "this file should be able to sync down" })
            helpers.assert_on_remote_only("remote_file.h")
            helpers.write_remote_file("remote_file_2", { "second file", "with a bunch of text" })
            helpers.assert_on_remote_only("remote_file_2")

            vim.cmd.RsyncDown()
            helpers.wait_sync()

            helpers.assert_files({ "test.c", "remote_file.h", "remote_file_2" })
        end)

        it("synced with RsyncDown cancelled", function()
            setup_with_remote_includes({
                'remote_path = "' .. helpers.dest .. '/"',
                'remote_includes = ["remote_file.h", "remote_file_2"]',
            })
            helpers.write_remote_file("remote_file.h", { "this file should be able to sync down" })
            helpers.assert_on_remote_only("remote_file.h")

            vim.cmd.RsyncDown()
            vim.cmd.RsyncCancelJob()
            helpers.wait_sync()

            helpers.assert_on_remote_only("remote_file.h")
            assert.equals(require("rsync").status(), "Sync cancelled")
        end)
    end)
end)
