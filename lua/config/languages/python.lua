return function(capabilities)

    -- What marks the top of a Python project: nvim-lspconfig's markers, plus
    -- a venv folder as the last resort, so a folder holding just a script
    -- and its .venv still counts as a project
    local root_markers = {
        'pyrightconfig.json',
        'pyproject.toml',
        'setup.py',
        'setup.cfg',
        'requirements.txt',
        'Pipfile',
        '.git',
        { '.venv', 'venv' },
    }

    -- The project's virtual environment, so imports of installed packages
    -- resolve. A venv activated before starting nvim is already on PATH.
    local function venv_python(root)
        if not root or vim.env.VIRTUAL_ENV then
            return nil
        end
        local bin = vim.fn.has('win32') == 1 and '/Scripts/python.exe' or '/bin/python'
        for _, name in ipairs({ '.venv', 'venv' }) do
            local python = root .. '/' .. name .. bin
            if vim.fn.executable(python) == 1 then
                return python
            end
        end
        return nil
    end

    -- ========================================================
    -- TYPE CHECKING AND COMPLETION (BASEDPYRIGHT)
    -- ========================================================

    vim.lsp.config('basedpyright', {
        capabilities = capabilities,
        root_markers = root_markers,
        before_init = function(_, config)
            local python = venv_python(config.root_dir)
            if python then
                -- Changed in place: the client holds this same settings table
                config.settings.python = vim.tbl_extend('force',
                    config.settings.python or {}, { pythonPath = python })
            end
        end,
        settings = {
            basedpyright = {
                -- Ruff sorts imports (below)
                disableOrganizeImports = true,
                analysis = {
                    -- Pyright's usual checks. basedpyright's own default
                    -- flags nearly every untyped line. A project's
                    -- pyproject.toml or pyrightconfig.json still overrides it.
                    typeCheckingMode = 'standard',
                },
            },
        },
    })

    vim.lsp.enable('basedpyright')

    -- ========================================================
    -- LINTING AND FORMATTING (RUFF)
    -- ========================================================

    -- Ruff's language server lints as you type and formats with \f (below).
    -- It picks up a project's [tool.ruff] settings or ruff.toml.
    vim.lsp.config('ruff', {
        capabilities = capabilities,
        on_init = function(client)
            -- basedpyright's hover shows types and docs; Ruff's would only
            -- show lint rule descriptions
            client.server_capabilities.hoverProvider = false
        end,
    })

    vim.lsp.enable('ruff')

    -- Sorts and groups the imports at the top of the file. Waits for the
    -- edit, so formatting straight after works on the sorted imports.
    local function sort_imports(buf, ruff)
        local params = {
            textDocument = { uri = vim.uri_from_bufnr(buf) },
            range = {
                start = { line = 0, character = 0 },
                ['end'] = { line = 0, character = 0 },
            },
            context = { only = { 'source.organizeImports.ruff' }, diagnostics = {} },
        }
        local response = ruff:request_sync('textDocument/codeAction', params, 2000, buf)
        local action = response and response.result and response.result[1]
        -- Ruff leaves the edit out of the action until it is asked for
        if action and not action.edit then
            response = ruff:request_sync('codeAction/resolve', action, 2000, buf)
            action = response and response.result
        end
        if action and action.edit then
            vim.lsp.util.apply_workspace_edit(action.edit, ruff.offset_encoding)
        end
    end

    -- ========================================================
    -- INDENTATION
    -- ========================================================

    -- Indent as Ruff formats, so \f leaves freshly typed code where it is:
    -- one level (not nvim's two) inside brackets and after a \ line break,
    -- and a closing bracket on its own line back under the line that opened it
    vim.g.python_indent = {
        open_paren = 'shiftwidth()',
        continue = 'shiftwidth()',
        closed_paren_align_last_line = false,
    }

    -- ========================================================
    -- RUN AND TEST
    -- ========================================================

    -- The project's venv Python, or else the one on PATH (Windows' python3
    -- can be a stub that opens the Microsoft Store)
    local function python_for(root)
        local python = venv_python(root)
        if python then
            return python
        end
        if vim.fn.has('win32') == 0 and vim.fn.executable('python3') == 1 then
            return 'python3'
        end
        return 'python'
    end

    -- Saves every changed file, then runs cmd in a terminal along the bottom.
    -- Typing goes to the program, for input(); once it ends, a key closes it.
    local function run_in_terminal(cmd, cwd)
        if vim.fn.executable(cmd[1]) == 0 then
            vim.notify('Python not found: ' .. cmd[1], vim.log.levels.ERROR)
            return
        end
        vim.cmd('silent! wall')
        vim.cmd('botright 15new')
        vim.fn.jobstart(cmd, { term = true, cwd = cwd })
        vim.cmd('startinsert')
    end

    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'python',
        callback = function(args)
            -- \f: sort imports, then format with Ruff. Overrides the general
            -- \f from core.lua, as C's and Java's \f do.
            vim.keymap.set('n', '<leader>f', function()
                local ruff = vim.lsp.get_clients({ bufnr = args.buf, name = 'ruff' })[1]
                if not ruff then
                    vim.notify('Ruff is not ready yet', vim.log.levels.WARN)
                    return
                end
                sort_imports(args.buf, ruff)
                vim.lsp.buf.format({ bufnr = args.buf, name = 'ruff' })
            end, { buffer = args.buf, desc = 'Sort imports and format with Ruff' })

            -- \gr: run this file, from nvim's current folder like :!python3 %
            vim.keymap.set('n', '<leader>gr', function()
                local file = vim.api.nvim_buf_get_name(args.buf)
                if file == '' then
                    vim.notify('Save the file before running it', vim.log.levels.WARN)
                    return
                end
                local root = vim.fs.root(args.buf, root_markers)
                run_in_terminal({ python_for(root), file }, vim.fn.getcwd())
            end, { buffer = args.buf, desc = 'Run this Python file' })

            -- \gt: run the project's tests, as \gt does for Gradle in Java.
            -- pytest when the project has it, else the standard unittest.
            vim.keymap.set('n', '<leader>gt', function()
                local root = vim.fs.root(args.buf, root_markers) or vim.fn.getcwd()
                local python = python_for(root)
                local runner = 'unittest'
                if vim.fn.executable(python) == 1 and vim.system({
                    python, '-c',
                    'import importlib.util, sys; sys.exit(not importlib.util.find_spec("pytest"))',
                }):wait().code == 0 then
                    runner = 'pytest'
                end
                run_in_terminal({ python, '-m', runner }, root)
            end, { buffer = args.buf, desc = 'Run Python tests' })
        end,
    })

end
