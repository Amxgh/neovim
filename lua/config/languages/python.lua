return function(capabilities)

    -- ========================================================
    -- TYPE CHECKING AND COMPLETION (BASEDPYRIGHT)
    -- ========================================================

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

    vim.lsp.config('basedpyright', {
        capabilities = capabilities,
        -- nvim-lspconfig's markers, plus a venv folder as the last resort, so
        -- a folder holding just a script and its .venv still counts as a project
        root_markers = {
            'pyrightconfig.json',
            'pyproject.toml',
            'setup.py',
            'setup.cfg',
            'requirements.txt',
            'Pipfile',
            '.git',
            { '.venv', 'venv' },
        },
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

    -- Ruff's language server lints as you type and formats with \f (core.lua).
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

    -- Sort and group the imports at the top of the file
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'python',
        callback = function(args)
            vim.keymap.set('n', '<leader>i', function()
                vim.lsp.buf.code_action({
                    context = { only = { 'source.organizeImports.ruff' }, diagnostics = {} },
                    apply = true,
                })
            end, { buffer = args.buf, desc = 'Organize Python imports with Ruff' })
        end,
    })

end
