
return function(capabilities)

    -- ========================================================
    -- JAVA LANGUAGE SERVER (JDTLS)
    -- ========================================================

    local function project_root(bufnr)
        local filename = vim.api.nvim_buf_get_name(bufnr)

        if filename == '' then
            return
        end

        return vim.fs.root(bufnr, {
            'settings.gradle',
            'settings.gradle.kts',
            'gradlew',
            'gradlew.bat',
            'mvnw',
            'pom.xml',
            'build.gradle',
            'build.gradle.kts',
            '.git',
        }) or vim.fs.dirname(filename)
    end

    local function java_root(bufnr, on_dir)
        local root = project_root(bufnr)
        if root then
            on_dir(root)
        end
    end

    vim.lsp.config('jdtls', {
        capabilities = capabilities,
        root_dir = java_root,
    })

    vim.lsp.enable('jdtls')

    -- ========================================================
    -- GRADLE ROOT DETECTION
    -- ========================================================

    local function gradle_root()
        return vim.fs.root(0, {
            'settings.gradle',
            'settings.gradle.kts',
            'gradlew',
            'gradlew.bat',
        }) or vim.fs.root(0, {
            'build.gradle',
            'build.gradle.kts',
        }) or vim.fn.getcwd()
    end

    -- ========================================================
    -- CHECKSTYLE LINTER
    -- ========================================================

    local lint = require('lint')

    lint.linters_by_ft.java = { 'checkstyle' }

    -- Mason installs the jar (core.lua). Looked up on each run, since Mason
    -- may still be installing it when this file loads on a new computer.
    local function checkstyle_jar()
        return vim.fn.glob(
            vim.fn.stdpath('data') .. '/mason/packages/checkstyle/*-all.jar',
            false, true
        )[1]
    end

    local function checkstyle_config(root)
        local candidates = {
            root .. '/config/checkstyle/checkstyle.xml',
            root .. '/checkstyle.xml',
            root .. '/config/checkstyle.xml',
        }

        for _, path in ipairs(candidates) do
            if vim.fn.filereadable(path) == 1 then
                return path
            end
        end

        return nil
    end

    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'java',
        callback = function(args)
            local root = project_root(args.buf)
            local config = root and checkstyle_config(root)
            if config then
                local xml = table.concat(vim.fn.readfile(config), '\n')
                local indentation = xml:match(
                    '<module%s+name%s*=%s*["\']Indentation["\'][^>]*>(.-)</module>'
                )
                local property = indentation and indentation:match(
                    '<property%s+[^>]-name%s*=%s*["\']basicOffset["\'][^>]*/>'
                )
                local width = property and tonumber(property:match(
                    'value%s*=%s*["\'](%d+)["\']'
                ))
                if width and width > 0 then
                    vim.bo[args.buf].shiftwidth = width
                    vim.bo[args.buf].softtabstop = width
                    vim.bo[args.buf].expandtab = true
                end
            end

            vim.keymap.set('n', '<leader>f', function()
                local clients = vim.lsp.get_clients({
                    bufnr = args.buf,
                    name = 'jdtls',
                    method = 'textDocument/formatting',
                })
                if #clients == 0 then
                    vim.notify('JDTLS formatting is not ready yet', vim.log.levels.WARN)
                    return
                end

                local ok, parser = pcall(vim.treesitter.get_parser, args.buf, 'java')
                if ok then
                    local root = parser:parse()[1]:root()
                    if not root:has_error() then
                        local edits = {}
                        local function wrap(body)
                            if not body or body:type() == 'block' or body:has_error() then
                                return
                            end
                            local sr, sc, er, ec = body:range()
                            edits[#edits + 1] = { sr, sc, '{ ', #edits + 1 }
                            edits[#edits + 1] = { er, ec, ' }', #edits + 1 }
                        end

                        local function visit(node)
                            local kind = node:type()
                            if kind == 'if_statement' then
                                wrap(node:field('consequence')[1])
                                local alternative = node:field('alternative')[1]
                                if alternative and alternative:type() ~= 'if_statement' then
                                    wrap(alternative)
                                end
                            elseif kind == 'for_statement'
                                or kind == 'enhanced_for_statement'
                                or kind == 'while_statement'
                                or kind == 'do_statement' then
                                wrap(node:field('body')[1])
                            end
                            for child in node:iter_children() do
                                visit(child)
                            end
                        end

                        visit(root)
                        table.sort(edits, function(a, b)
                            if a[1] ~= b[1] then return a[1] > b[1] end
                            if a[2] ~= b[2] then return a[2] > b[2] end
                            return a[4] < b[4]
                        end)
                        for _, edit in ipairs(edits) do
                            vim.api.nvim_buf_set_text(args.buf,
                                edit[1], edit[2], edit[1], edit[2], { edit[3] })
                        end
                    else
                        vim.notify('Skipping braces: Java has syntax errors', vim.log.levels.WARN)
                    end
                else
                    vim.notify('Skipping braces: Java parser unavailable', vim.log.levels.WARN)
                end

                vim.lsp.buf.format({ bufnr = args.buf, name = 'jdtls', timeout_ms = 10000 })
            end, { buffer = args.buf, desc = 'Add Java braces and format with JDTLS' })
        end,
    })

    -- Use the existing SARIF parser.
    lint.linters.checkstyle.cmd = 'java'
    lint.linters.checkstyle.ignore_exitcode = true
    local parse_sarif = lint.linters.checkstyle.parser
    lint.linters.checkstyle.parser = function(output, bufnr, cwd)
        -- Checkstyle emits file:/ URIs; nvim-lint expects file:/// URIs.
        local normalized = output:gsub('("uri"%s*:%s*"file:)/([^/])', '%1///%2')
        return parse_sarif(normalized, bufnr, cwd)
    end

    -- ========================================================
    -- RUN CHECKSTYLE
    -- ========================================================

    local function run_checkstyle(show_errors)
        if vim.bo.filetype ~= 'java' then
            return
        end

        local root = project_root(0)
        local config = root and checkstyle_config(root)
        local jar = checkstyle_jar()

        if not config
            or not jar
            or vim.fn.executable('java') ~= 1 then

            if show_errors then
                vim.notify(
                    'Checkstyle requires Java, '
                    .. 'the Mason checkstyle package '
                    .. '(see :Mason), and a '
                    .. 'project Checkstyle XML.',
                    vim.log.levels.WARN
                )
            end

            return
        end

        lint.try_lint('checkstyle', {
            cwd = root,
            wrap_linter = function(linter)
                linter.args = {
                    '-Dconfig_loc=' .. vim.fn.fnamemodify(config, ':h'),
                    '-jar',
                    jar,
                    '-f',
                    'sarif',
                    '-c',
                    config,
                }
                return linter
            end,
        })
    end

    -- Run automatically on save.
    vim.api.nvim_create_autocmd('BufWritePost', {
        pattern = '*.java',
        callback = function()
            run_checkstyle(false)
        end,
    })

    -- Run manually.
    vim.api.nvim_create_user_command(
        'JavaCheckstyle',
        function()
            run_checkstyle(true)
        end,
        {
            desc = 'Check current Java file with Checkstyle',
        }
    )

    -- ========================================================
    -- GRADLE COMMAND
    -- ========================================================

    vim.api.nvim_create_user_command('Gradle', function(opts)

        local root = gradle_root()
        local is_windows = vim.fn.has('win32') == 1

        local wrapper =
            root .. (is_windows and '/gradlew.bat' or '/gradlew')

        local command

        if vim.fn.filereadable(wrapper) == 1 then

            if is_windows then
                command = {
                    'cmd.exe',
                    '/d',
                    '/c',
                    wrapper,
                }

            elseif vim.fn.executable(wrapper) == 1 then
                command = { wrapper }

            else
                command = { 'sh', wrapper }
            end

        elseif vim.fn.executable('gradle') == 1 then
            command = { 'gradle' }

        else
            vim.notify(
                'Neither Gradle wrapper nor '
                .. 'gradle executable found',
                vim.log.levels.ERROR
            )
            return
        end

        vim.list_extend(command, opts.fargs)

        vim.cmd('botright 15split')

        vim.fn.termopen(command, {
            cwd = root,
        })

        vim.cmd('startinsert')

    end, {
        nargs = '+',
        desc = 'Run Gradle tasks from project root',
    })

    -- ========================================================
    -- GRADLE KEYBINDINGS
    -- ========================================================

    vim.keymap.set(
        'n', '<leader>gb', '<Cmd>Gradle build<CR>'
    )

    vim.keymap.set(
        'n', '<leader>gt', '<Cmd>Gradle test<CR>'
    )

    vim.keymap.set(
        'n', '<leader>gc', '<Cmd>Gradle checkstyleMain<CR>'
    )

    vim.keymap.set(
        'n', '<leader>gC', '<Cmd>Gradle check<CR>'
    )

end
