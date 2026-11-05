
-- ============================================================
-- PLUGINS (lazy.nvim)
-- ============================================================

-- On a new computer, lazy.nvim installs itself and then every plugin below
-- on the first start, at the exact versions recorded in lazy-lock.json.
-- :Lazy shows the plugins, :Lazy update moves them to newer versions and
-- records those in lazy-lock.json (commit it), and :Lazy restore goes back
-- to the recorded versions. The plugins are configured in core.lua.

local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
    local out = vim.fn.system({
        'git', 'clone', '--filter=blob:none', '--branch=stable',
        'https://github.com/folke/lazy.nvim.git', lazypath,
    })
    if vim.v.shell_error ~= 0 then
        error('Could not install lazy.nvim (is git installed?):\n' .. out)
    end
end
vim.opt.runtimepath:prepend(lazypath)

require('lazy').setup({
    -- Productivity
    'wakatime/vim-wakatime',
    'tpope/vim-fugitive',
    'kylechui/nvim-surround',

    -- Appearance
    'folke/tokyonight.nvim',
    'karb94/neoscroll.nvim',
    'sphamba/smear-cursor.nvim',

    -- File explorer
    'nvim-tree/nvim-tree.lua',
    'nvim-tree/nvim-web-devicons',

    -- Syntax highlighting
    { 'nvim-treesitter/nvim-treesitter', branch = 'main', build = ':TSUpdate' },
    'OXY2DEV/markview.nvim',

    -- Language servers and linting
    'neovim/nvim-lspconfig',
    'mason-org/mason.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    'mfussenegger/nvim-lint',

    -- Autocompletion
    'windwp/nvim-autopairs',
    'hrsh7th/nvim-cmp',
    'hrsh7th/cmp-nvim-lsp',
    'hrsh7th/cmp-cmdline',
    'hrsh7th/cmp-path',
}, {
    -- None of these plugins need LuaRocks
    rocks = { enabled = false },
    -- Don't announce every save of a config file
    change_detection = { notify = false },
})
