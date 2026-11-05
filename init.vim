
" Disable netrw in favour of nvim-tree
let g:loaded_netrw = 1
let g:loaded_netrwPlugin = 1

" ============================================================
" PLUGINS
" ============================================================

" lazy.nvim installs itself and the plugins on first start
" (lua/config/plugins.lua). Plugins must load before Lua modules configure them.
lua require('config.plugins')

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
