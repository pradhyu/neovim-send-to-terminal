# neovim-send-to-terminal (Specification & Architecture)

> **Vision**: The most intuitive, context-aware, and intelligent "Send to Terminal / REPL" plugin for Neovim. Effortlessly run commands and code snippets from Markdown, source code, and documentation into any terminal backend without manual copy-pasting or clean-up.

---

## 1. Executive Summary & Motivations

### The Problem
Existing Neovim plugins like `vim-slime`, `iron.nvim`, `toggleterm.nvim`, and `sniprun` either:
1. **Blindly send raw text** without understanding markdown context (leaving leading `$`, command output, backticks, or trailing prompts attached).
2. **Require tedious manual selections** to avoid copying output lines or comments embedded in READMEs and tutorials.
3. **Lack modern Treesitter integration** for contextual boundaries (e.g. running an entire fenced block vs. inline command vs. a single logical statement).
4. **Lock users into specific terminal backends** or require complex manual setup for multiplexers (`tmux`, `zellij`, `kitty`, `wezterm`, native `:terminal`).

### The Solution: `neovim-send-to-terminal`
A zero-friction, modular Neovim plugin with:
- **Intelligent Markdown Parser**: Automatically handles prompt stripping (`$`, `❯`, `>>>`), inline backticks, fenced code block extraction, and interleaved command vs. output detection.
- **Bracketed Paste & Sanitization Pipeline**: Prevents garbled multi-line pasting, auto-indent issues, and partial execution in shells/REPLs.
- **Universal Backend Engine**: Works seamlessly with Neovim `:terminal`, `snacks.terminal`, `toggleterm`, `tmux`, `zellij`, `kitty`, `wezterm`, etc.
- **Step-through Execution**: Run line-by-line or command-by-command with auto-advancing cursor, accompanied by subtle visual flash feedback.

---

## 2. Inspirations & Comparative Analysis

| Feature / Inspiration | `vim-slime` | `iron.nvim` | `toggleterm` | `markdown-exec` / `runme` | **Our Vision (`send-to-terminal`)** |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Markdown Inline Backtick Run** | ❌ No | ❌ No | ❌ No | ⚠️ CLI/Notebook-centric | ✅ **Yes (auto-detects cursor inside `` `cmd` ``)** |
| **Strip Shell/REPL Prompts (`$`, `>>>`)** | ❌ Raw text | ⚠️ Limited | ❌ No | ❌ No | ✅ **Smart heuristic + regex clean-up** |
| **Filter Out Interleaved Output** | ❌ No | ❌ No | ❌ No | ❌ No | ✅ **Intelligent output filtering** |
| **Treesitter Block & Node Awareness** | ❌ Regex/Vim | ✅ Language AST | ❌ Text only | ⚠️ Custom parser | ✅ **Full Treesitter & Markdown integration** |
| **Bracketed Paste Mode Support** | ⚠️ Plugin-dependent | ⚠️ Partial | ⚠️ Partial | N/A | ✅ **Native bracketed paste wrapping** |
| **Multi-Backend (Native, Tmux, Kitty, etc.)** | ✅ Many backends | ⚠️ Neovim-centric | ⚠️ Neovim-centric | ❌ N/A | ✅ **Pluggable adapter architecture** |
| **Visual Flash / Highlight Feedback** | ❌ No | ⚠️ Limited | ❌ No | ❌ N/A | ✅ **Smooth visual feedback** |
| **Step-Through Mode (Advance on Run)** | ⚠️ Manual keymap | ⚠️ REPL line | ❌ No | ⚠️ UI-based | ✅ **Interactive execution stepper** |

---

## 3. Core Feature Specifications

### 3.1 Smart Markdown Extraction
When invoked inside a Markdown file (`ft=markdown`):

1. **Inline Code Execution**:
   - Cursor on `` `curl https://api.example.com` `` inside standard paragraph text.
   - Action: Extracts only the text inside the backticks, cleans leading whitespace/prompts, and sends it.

2. **Fenced Code Blocks (```` ```bash ... ``` ````)**:
   - **Full Block Run**: Run all commands inside the current fenced code block.
   - **Current Line / Sub-command**: Run only the command under the cursor.
   - **Prompt Stripping**:
     - Strips `$ `, `❯ `, `% `, `> `, `C:\> `, `# ` (when preceded by root/prompt patterns).
     - Example:
       ```bash
       $ sudo apt update
       $ sudo apt install -y ripgrep
       ```
       Sends: `sudo apt update` then `sudo apt install -y ripgrep`.
   - **Interleaved Output Stripping**:
     - Example from documentation:
       ```bash
       $ git status
       On branch main
       Your branch is up to date with 'origin/main'.
       $ git pull
       ```
       If prompt stripping mode is enabled, it automatically filters out lines that are not prefixed with the command prompt, executing only `git status` and `git pull`!

3. **Multi-line Continuation & Heredoc Preservation**:
   - **POSIX Shells / Python / C**: Lines ending in backslash `\` are automatically grouped as a single logical statement.
   - **PowerShell**: Lines ending in backtick ``` ` ``` (grave accent line continuation) or trailing operators (`|`, `,`, `&&`, `||`, `-and`, `-or`) are automatically grouped as a single logical statement.
   - **Unclosed Delimiters**: Blocks with open `(`, `[`, `{`, `@(`, `@{` are preserved and sent together.
   - **Heredocs & Here-Strings**:
     - POSIX: `cat << 'EOF' ... EOF`
     - PowerShell: `@" ... "@` and `@' ... '@` here-strings.

---

### 3.2 General Code, REPL & PowerShell Features
When invoked inside programming language files or REPLs (`powershell`/`pwsh`, `python`, `lua`, `sh`, `r`, `julia`, `sql`, etc.):

1. **PowerShell First-Class Support**:
   - Strips `PS > `, `PS C:\...>`, `PS /path>`, `PS [1]: `, `[PS] > `, and continuation prompt `>> `.
   - Detects PowerShell backtick continuation (`` ` ``) and multi-line here-strings (`@" ... "@`, `@' ... '@`).
   - Supports single-line `#` and multi-line `<# ... #>` comment stripping/handling.
2. **Prompt Sanitization**:
   - Shells: Strips `$ `, `❯ `, `% `, `# `
   - PowerShell: Strips `PS [^>]*>%s*`, `^%s*>>%s*`
   - Python/IPython: Strips `>>> `, `... `, `In [1]: `
   - R / Julia: Strips `> `, `+ `
3. **Treesitter Statement / Function Target**:
   - Send current Treesitter node (e.g. statement, function definition, scriptblock, pipeline).
4. **Visual Selection & Operator**:
   - Works as standard Vim operator (`<leader>t{motion}`) and in visual mode (`v` / `V`).

---

### 3.3 Terminal Backends (Pluggable Architecture)

Each backend implements a simple interface:
```lua
---@class Backend
---@field send fun(text: string, opts?: table): boolean
---@field is_available fun(): boolean
---@field focus? fun(): nil
```

Supported Out-of-the-Box Backends:
1. **`neovim` (Default)**:
   - Uses `vim.fn.chansend(job_id, text)`.
   - Auto-discovers any open terminal buffer or dedicated terminal window (e.g. bash, zsh, pwsh, powershell.exe).
   - Can auto-open a terminal split/floating window if none exists.
2. **`snacks` / `toggleterm`**:
   - Hooks directly into `Snacks.terminal` or `toggleterm.nvim` if detected.
3. **`tmux`**:
   - Runs `tmux send-keys -t <target> ...`.
   - Auto-targets the last active pane or prompts for pane selection.
4. **`zellij`**:
   - Runs `zellij action write-chars ...`.
5. **`wezterm`**:
   - Runs `wezterm cli send-text ...`.
6. **`kitty`**:
   - Uses `kitty @ send-text ...`.
7. **`custom`**:
   - User-defined lua function `function(text, context) ... end`.

---

### 3.4 Bracketed Paste & Execution Modes

- **Bracketed Paste Mode**: Wrap payload in `\x1b[200~` and `\x1b[201~` to prevent shells (pwsh, zsh, fish, bash) and REPLs (ipython, ptpython) from indenting lines or executing prematurely on newline characters.
- **Append Newline Option**: Configurable per language/backend (send `<CR>` or leave text in prompt).
- **Execution Stepping**:
  - `send_and_step()`: Send the command (including all continued lines `\` or ``` ` ```), then advance cursor to the next executable line/command block.

---

## 4. Proposed User API & Keybindings

### 4.1 Default Keymap Suggestions
```lua
-- Normal mode
vim.keymap.set("n", "<leader>tt", "<cmd>SendToTerminal line<cr>", { desc = "Send current line / inline code" })
vim.keymap.set("n", "<leader>tb", "<cmd>SendToTerminal block<cr>", { desc = "Send current block (markdown / treesitter)" })
vim.keymap.set("n", "<leader>tn", "<cmd>SendToTerminal step<cr>", { desc = "Send and step to next" })
vim.keymap.set("n", "<leader>tf", "<cmd>SendToTerminal file<cr>", { desc = "Send entire file" })
vim.keymap.set("n", "<leader>ts", "<cmd>SendToTerminal select<cr>", { desc = "Select / switch target terminal" })
vim.keymap.set("n", "<leader>th", "<cmd>SendToTerminal history<cr>", { desc = "Show execution history" })
vim.keymap.set("n", "<leader>tl", "<cmd>SendToTerminal last<cr>", { desc = "Show last outcome popup" })
vim.keymap.set("n", "<leader>to", "<cmd>SendToTerminal copy_output<cr>", { desc = "Copy last outcome to clipboard" })
vim.keymap.set("n", "<leader>tp", "<cmd>SendToTerminal paste_output<cr>", { desc = "Paste commented outcome below cursor" })
vim.keymap.set("n", "<leader>tR", "<cmd>SendToTerminal reload<cr>", { desc = "Hot-reload send-to-terminal" })

-- Visual mode
vim.keymap.set("v", "<leader>t", "<cmd>SendToTerminal visual<cr>", { desc = "Send visual selection" })
```

### 4.2 Configuration Options Schema
```lua
require("send-to-terminal").setup({
  -- Default backend: "neovim" | "snacks" | "toggleterm" | "tmux" | "zellij" | "kitty" | "wezterm" | "auto"
  backend = "auto",

  -- Terminal targeting options
  terminal = {
    -- For native neovim backend
    auto_open = true,            -- Open terminal split if none is open
    split = "botright 15split",  -- Command to open terminal
    focus_on_send = false,       -- Stay in current buffer or jump to terminal
  },

  -- Markdown specific settings
  markdown = {
    strip_prompts = true,        -- Strip $, >, >>>, PS >, etc.
    filter_output_lines = true,  -- If prompts are present, skip lines without prompts (output)
    strip_inline_backticks = true,
    strip_comments = false,
  },

  -- Bracketed paste mode (recommended true for modern shells/REPLs including pwsh)
  bracketed_paste = true,

  -- Visual flash highlight
  highlight = {
    enabled = true,
    duration = 150,              -- milliseconds
    hl_group = "IncSearch",
  },

  -- Custom prompt patterns per filetype
  prompt_patterns = {
    sh = { "^%s*%$%s+", "^%s*❯%s+", "^%s*#%s+" },
    bash = { "^%s*%$%s+", "^%s*❯%s+", "^%s*#%s+" },
    zsh = { "^%s*%$%s+", "^%s*❯%s+", "^%s*#%s+" },
    ps1 = { "^%s*PS%s*[^>]*>%s*", "^%s*%[PS%]%s*[^>]*>%s*", "^%s*>>%s*" },
    powershell = { "^%s*PS%s*[^>]*>%s*", "^%s*%[PS%]%s*[^>]*>%s*", "^%s*>>%s*" },
    pwsh = { "^%s*PS%s*[^>]*>%s*", "^%s*%[PS%]%s*[^>]*>%s*", "^%s*>>%s*" },
    python = { "^%s*>>%s*", "^%s*>>>%s*", "^%s*%.%.%.%s*", "^%s*In%s*%[%d+%]:%s*" },
    r = { "^%s*>%s+", "^%s*\\+%s+" },
    lua = { "^%s*>%s+" },
  },

  -- Line continuation characters per filetype/shell
  continuation_chars = {
    sh = { "\\" },
    bash = { "\\" },
    zsh = { "\\" },
    python = { "\\" },
    ps1 = { "`", "\\" },
    powershell = { "`", "\\" },
    pwsh = { "`", "\\" },
  },
})
```

---

## 5. Project Directory Structure

```
neovim-send-to-terminal/
├── .github/
│   └── workflows/
│       └── ci.yml
├── lua/
│   └── send-to-terminal/
│       ├── init.lua              # Main entry point & setup
│       ├── config.lua            # Default options & configuration merge
│       ├── core/
│       │   ├── extractor.lua     # Content extraction (line, visual, treesitter, markdown)
│       │   ├── markdown.lua      # Smart markdown parser (code fence, inline, prompt & output cleaner)
│       │   ├── sanitizer.lua     # Prompt stripping, bracketed paste wrapping, comment handling
│       │   └── highlighter.lua   # Visual flash / feedback on executed ranges
│       ├── backends/
│       │   ├── init.lua          # Backend router & auto-detection
│       │   ├── neovim.lua        # Built-in :terminal (chansend)
│       │   ├── snacks.lua        # Snacks.terminal integration
│       │   ├── toggleterm.lua    # toggleterm.nvim integration
│       │   ├── tmux.lua          # tmux send-keys
│       │   ├── zellij.lua        # zellij action write-chars
│       │   ├── kitty.lua         # kitty @ send-text
│       │   └── wezterm.lua       # wezterm cli send-text
│       └── utils.lua             # General helper utilities
├── plugin/
│   └── send-to-terminal.lua      # User commands (:SendToTerminal)
├── tests/
│   ├── markdown_spec.lua         # Unit tests for markdown & prompt extraction
│   ├── sanitizer_spec.lua        # Unit tests for sanitizer
│   └── extractor_spec.lua       # Unit tests for node/range extraction
├── SPEC.md                       # This specification document
├── README.md                     # Plugin documentation & quickstart
└── LICENSE                       # MIT License
```

---

## 6. Implementation Milestones

1. **Phase 1: Architecture & Core Engine**
   - Setup directory structure, configuration schema, and utility helpers.
   - Implement `sanitizer.lua` (prompt detection & stripping, interleaved output filtering, bracketed paste).
   - Implement `markdown.lua` and `extractor.lua` (treesitter + regex fallback for code fences and inline backticks).

2. **Phase 2: Terminal Backends & Feedback**
   - Implement `neovim.lua` (native channel send, terminal auto-discovery, auto-spawn).
   - Implement multiplexers (`tmux.lua`, `zellij.lua`, `kitty.lua`, `wezterm.lua`, `snacks.lua`).
   - Implement `highlighter.lua` (flash effect on sent code).

3. **Phase 3: Commands, Operator Mappings & Stepper**
   - Implement `:SendToTerminal` command with subcommands (`line`, `block`, `inline`, `visual`, `step`, `file`).
   - Implement standard operator pending mode (`g@` motion binding).
   - Implement step-through mode.

4. **Phase 4: Automated Testing & Documentation**
   - Unit tests using `plenary.busted` or `mini.test` for sanitization, prompt stripping, markdown blocks.
   - Comprehensive README with GIFs/examples, LazyVim recipe, and plugin manager setup.
