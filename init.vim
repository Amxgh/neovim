
" Disable netrw in favour of nvim-tree
let g:loaded_netrw = 1
let g:loaded_netrwPlugin = 1

" ============================================================
" VUNDLE PLUGIN MANAGER
" ============================================================

" Vundle must load before Lua modules configure plugins.
if has('win32')
    set shellslash
    let s:bundle_dir = stdpath('data') . '/bundle'
else
    let s:bundle_dir = expand('~/.vim/bundle')
endif

execute 'set runtimepath+=' . fnameescape(s:bundle_dir . '/Vundle.vim')
call vundle#begin(s:bundle_dir)

" Plugin manager
Plugin 'VundleVim/Vundle.vim'

" Productivity
Plugin 'wakatime/vim-wakatime'
Plugin 'tpope/vim-fugitive'
Plugin 'kylechui/nvim-surround'

" Appearance
Plugin 'folke/tokyonight.nvim'
Plugin 'karb94/neoscroll.nvim'
Plugin 'sphamba/smear-cursor.nvim'

" File explorer
Plugin 'nvim-tree/nvim-tree.lua'
Plugin 'nvim-tree/nvim-web-devicons'

" Syntax highlighting
Plugin 'nvim-treesitter/nvim-treesitter', {'branch': 'main'}
Plugin 'OXY2DEV/markview.nvim'

" Language servers and linting
Plugin 'neovim/nvim-lspconfig'
Plugin 'mason-org/mason.nvim'
Plugin 'mfussenegger/nvim-lint'

" Autocompletion
Plugin 'windwp/nvim-autopairs'
Plugin 'hrsh7th/nvim-cmp'
Plugin 'hrsh7th/cmp-nvim-lsp'
Plugin 'hrsh7th/cmp-cmdline'
Plugin 'hrsh7th/cmp-path'

call vundle#end()

" ============================================================
" FILETYPE AND SYNTAX HIGHLIGHTING
" ============================================================

" Enable filetype detection and indentation
filetype plugin indent on

" Enable syntax highlighting for all languages
syntax enable

" Enable true-color terminal support
set termguicolors

" Dark background
set background=dark

" ============================================================
" EDITOR SETTINGS
" ============================================================

set autoindent
set smartindent
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4

" Command-line completion
set wildmenu
set wildmode=longest:full,full

" One status bar for the whole screen, so windows split one above the other
" are divided by a thin line in the split-line colour (c.border in the theme)
set laststatus=3

" ============================================================
" LUA CONFIGURATION
" ============================================================

lua require('config.core')()

" ============================================================
" COLORSCHEME
" ============================================================

" TokyoNight with a true-black background for OLED (colors/tokyonight-oled.lua)
colorscheme tokyonight-oled
