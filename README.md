# Neovim config

## Set up on a new computer

```bash
git clone https://github.com/<your-username>/nvim.git ~/.config/nvim && nvim
```

On Windows (PowerShell), clone into `$env:LOCALAPPDATA\nvim` instead.

On first start:

- **lazy.nvim** installs itself and every plugin, at the versions pinned in `lazy-lock.json`.
- **Mason** installs the language servers and tools in the background: clangd, jdtls,
  lua-language-server, basedpyright, Ruff, tree-sitter CLI and Checkstyle (see `lua/config/core.lua`).
  `:Mason` shows their progress.
- **Tree-sitter** parsers build the first time you open each kind of file.

To install everything up front instead, for example in a setup script:

```bash
nvim --headless +MasonToolsInstallSync +qa
```

### Needs installing first

- Neovim 0.12 or newer. Ubuntu's `apt` version is too old: use a release from
  https://github.com/neovim/neovim/releases (or `brew install neovim`, `winget install Neovim.Neovim`).
- `git`, `curl`, `unzip`, `tar`, `gzip`, which lazy.nvim and Mason use to download things
- A C compiler (`gcc` or `clang`), which builds the Tree-sitter parsers
- Java 21 or newer, for jdtls and Checkstyle
- Python 3 with its `venv` module, which Mason installs basedpyright into
  (Ubuntu leaves `venv` out of Python: it comes in the `python3-venv` package)
- A [Nerd Font](https://www.nerdfonts.com) set as the terminal font, for file icons
- Optional: `pdftotext` (poppler-utils), to open PDFs as text

On Ubuntu/WSL: `sudo apt install git curl unzip tar gzip build-essential openjdk-21-jdk python3-venv poppler-utils`

WakaTime asks for its API key on first start (it is stored in `~/.wakatime.cfg`, outside this repo).

## Keeping computers in sync

- After changing the config: `git add -A && git commit -m "..." && git push`
- On another computer: `git pull`, then `:Lazy restore` if `lazy-lock.json` changed
- To update plugins: `:Lazy update`, then commit the new `lazy-lock.json`
