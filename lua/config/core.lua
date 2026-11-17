
return function()

    -- ========================================================
    -- MASON
    -- ========================================================

    require('mason').setup()

    -- Installs any of these that are missing, in the background on startup,
    -- so a new computer needs no :MasonInstall. Names are Mason package names.
    require('mason-tool-installer').setup({
        ensure_installed = {
            'clangd',              -- C and C++ (cpp.lua)
            'jdtls',               -- Java (java.lua)
            'lua-language-server', -- Lua (lua.lua)
            'basedpyright',        -- Python types and completion (python.lua)
            'ruff',                -- Python linting and formatting (python.lua)
            'tree-sitter-cli',     -- builds Tree-sitter parsers (below)
            -- Kept at the version this config was set up with: a newer major
            -- version can reject a project's existing checkstyle.xml
            { 'checkstyle', version = 'checkstyle-10.24.0' },
        },
    })

    require('neoscroll').setup()
    require('smear_cursor').setup()

    -- ========================================================
    -- FILE EXPLORER
    -- ========================================================

    require('nvim-tree').setup({
        update_focused_file = { enable = true },
        filters = { dotfiles = false },
    })

    vim.keymap.set('n', '<leader>e', '<Cmd>NvimTreeToggle<CR>',
        { desc = 'Toggle file explorer' })
    vim.keymap.set('n', '<leader>E', '<Cmd>NvimTreeFindFile<CR>',
        { desc = 'Reveal current file in explorer' })

    -- ========================================================
    -- TREESITTER
    -- ========================================================

    local treesitter = require('nvim-treesitter')
    local available_parsers = require('nvim-treesitter.parsers')

    vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
            local filetype = vim.bo[args.buf].filetype
            local lang = vim.treesitter.language.get_lang(filetype)
            if not lang or not available_parsers[lang] then
                return
            end

            local function attach()
                if not vim.api.nvim_buf_is_valid(args.buf)
                    or vim.bo[args.buf].filetype ~= filetype then
                    return
                end

                local ok, err = pcall(vim.treesitter.start, args.buf, lang)
                if not ok then
                    vim.notify(err, vim.log.levels.ERROR)
                    return
                end
                -- Indentation is left to nvim's own per-language rules: they
                -- follow the surrounding code, while Tree-sitter's counts
                -- nesting levels and drifts on code not indented by 4s.
            end

            if vim.list_contains(treesitter.get_installed('parsers'), lang) then
                attach()
            else
                treesitter.install({ lang }):await(function(err, success)
                    if success then
                        vim.schedule(attach)
                    else
                        vim.schedule(function()
                            vim.notify(
                                'Could not install Tree-sitter parser for '
                                    .. lang .. ': ' .. (err or 'installation failed'),
                                vim.log.levels.WARN
                            )
                        end)
                    end
                end)
            end
        end,
    })

    -- ========================================================
    -- LSP CAPABILITIES
    -- ========================================================

    local capabilities =
        require('cmp_nvim_lsp').default_capabilities()

    local cmp = require('cmp')
    cmp.setup({
        mapping = cmp.mapping.preset.insert(),
        sources = cmp.config.sources({
            { name = 'nvim_lsp' },
        }, {
            { name = 'path' },
        }),
    })

    require('nvim-autopairs').setup()
    cmp.event:on('confirm_done',
        require('nvim-autopairs.completion.cmp').on_confirm_done())

    -- Completing a shell command name scans every directory on the slow WSL
    -- PATH and freezes Neovim. This copy of the cmdline source stays quiet
    -- wherever Neovim would complete one: after the ! in :!cmd, :r !cmd,
    -- :w !cmd and :'<,'>!cmd, and after :terminal. Arguments typed after the
    -- command still complete as file names.
    local cmdline_source = require('cmp_cmdline').new()
    function cmdline_source:is_available()
        local before_cursor = vim.fn.getcmdline():sub(1, vim.fn.getcmdpos() - 1)
        return vim.fn.getcompletiontype(before_cursor) ~= 'shellcmd'
    end
    cmp.register_source('cmdline_no_shell', cmdline_source)

    cmp.setup.cmdline(':', {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
            { name = 'path' },
        }, {
            { name = 'cmdline_no_shell', option = { ignore_cmds = { 'Man' } } },
        }),
        matching = { disallow_symbol_nonprefix_matching = false },
    })

    -- ========================================================
    -- AUTOMATIC LANGUAGE CONFIGURATION
    -- ========================================================

    local languages_dir =
        vim.fn.stdpath('config') .. '/lua/config/languages'

    local language_files =
        vim.fn.globpath(languages_dir, '*.lua', false, true)

    for _, file in ipairs(language_files) do
        local language = vim.fn.fnamemodify(file, ':t:r')

        require('config.languages.' .. language)(capabilities)
    end

    -- ========================================================
    -- DIAGNOSTICS
    -- ========================================================

    vim.diagnostic.config({
        virtual_text = {
            prefix = '●',
            spacing = 2,
        },

        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,

        float = {
            border = 'rounded',
            source = true,
        },
    })

    -- ========================================================
    -- QUICK FIX
    -- ========================================================

    -- Apply the server's top suggested fix for the error under the cursor
    vim.keymap.set('n', '<leader>a', function()
        local picked = false
        vim.lsp.buf.code_action({
            context = { only = { 'quickfix' } },
            filter = function()
                if picked then
                    return false
                end
                picked = true
                return true
            end,
            apply = true,
        })
    end, { desc = 'Apply suggested fix' })

    -- ========================================================
    -- FORMAT
    -- ========================================================

    -- Format with the language server; without one, reindent the file using
    -- the language's indent rules. Java sets its own \f (java.lua) that adds
    -- braces first, which takes precedence in Java buffers.
    vim.keymap.set('n', '<leader>f', function()
        if #vim.lsp.get_clients({ bufnr = 0, method = 'textDocument/formatting' }) > 0 then
            vim.lsp.buf.format()
        elseif vim.bo.indentexpr ~= '' or vim.bo.cindent then
            local view = vim.fn.winsaveview()
            vim.cmd('keepjumps normal! gg=G')
            vim.fn.winrestview(view)
        else
            vim.notify('No formatter for ' .. vim.bo.filetype .. ' files',
                vim.log.levels.WARN)
        end
    end, { desc = 'Format file' })

    -- ========================================================
    -- CURSOR MOVEMENT
    -- ========================================================

    -- Held h/l speed and line wrapping (lua/config/cursor.lua)
    require('config.cursor')()

    -- ========================================================
    -- PDF AS TEXT
    -- ========================================================

    -- PDFs store ff, fi, fl, ffi, ffl and st as single "ligature" characters
    -- (U+FB00 to U+FB06), which a terminal squeezes into one cell. Spelt out,
    -- they read normally and searching for "modified" finds them.
    local ligatures = {
        ['\u{FB00}'] = 'ff', ['\u{FB01}'] = 'fi', ['\u{FB02}'] = 'fl',
        ['\u{FB03}'] = 'ffi', ['\u{FB04}'] = 'ffl',
        ['\u{FB05}'] = 'st', ['\u{FB06}'] = 'st',
    }

    -- Open PDFs as read-only text (needs pdftotext from poppler)
    if vim.fn.executable('pdftotext') == 1 then
        vim.api.nvim_create_autocmd('BufReadCmd', {
            group = vim.api.nvim_create_augroup('pdf_as_text', { clear = true }),
            pattern = '*.pdf',
            callback = function(ev)
                local text = vim.fn.systemlist({ 'pdftotext', '-layout', ev.match, '-' })
                for i, line in ipairs(text) do
                    -- The UTF-8 bytes of U+FB00 to U+FB06
                    text[i] = line:gsub('\239\172[\128-\134]', ligatures)
                end
                vim.bo[ev.buf].buftype = 'nofile' -- :w can never write text over the PDF
                vim.bo[ev.buf].modifiable = true
                vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, text)
                vim.bo[ev.buf].modifiable = false
            end,
        })
    end

end
