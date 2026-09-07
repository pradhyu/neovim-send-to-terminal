# 🚀 neovim-send-to-terminal

> The most intuitive, context-aware, and intelligent "Send to Terminal / REPL" plugin for Neovim.

Send commands and code snippets from Markdown documentation, PowerShell scripts, shell files, Python REPLs, and codebuffers directly into your terminal—with **smart prompt stripping**, **interleaved output filtering**, **multi-line continuation awareness (`\`, ``` ` ```, `|`)**, and **bracketed paste support**.

---

## ✨ Key Features

- 🎯 **Smart Markdown Execution**:
  - **Inline Code**: Cursor inside `` `cargo test` `` executes just the command without surrounding backticks or prose.
  - **Prompt Stripping**: Automatically strips `$ `, `❯ `, `% `, `PS C:\...>`, `PS /path>`, `>> `, `>>> `, `... `, `In [1]: `, etc.
  - **Interleaved Output Filtering**: Automatically distinguishes between command lines and command output in tutorials/READMEs, executing only the commands.
- 📋 **Automatic Outcome Recording & Execution History**:
  - Automatically captures the terminal output / outcome of executed commands.
  - Keeps full metadata: exact markdown / file path, line numbers, timestamp, language, command text, and output.
  - **Auto-copy to Clipboard**: Automatically copies the clean terminal outcome (with ANSI color codes stripped) to your system clipboard (`"+"`).
- 🔍 **Interactive History Viewer & Float Modal**:
  - `:SendToTerminal history` (`<leader>sh`): Browse past execution logs.
  - `:SendToTerminal last` (`<leader>sl`): Instantly popup a float modal showing the last command and its terminal outcome (press `y` to copy output, `c` to copy command, `q` to close).
- 🧠 **Smart Script & Shell Detection**:
  - Automatically identifies whether code is PowerShell (`pwsh`), Bash (`sh`/`bash`), or Python.
  - Automatically routes code to matching open terminal buffers (e.g. PowerShell blocks to `pwsh` terminals, Bash blocks to `bash` terminals).
- 🎛️ **Multi-Terminal Buffer Selection & Switching**:
  - If multiple PowerShell or Bash terminal buffers are open, cleanly prompts you (`vim.ui.select`) to pick which terminal to send to.
  - Remembers your selection per language and lets you re-select or reset at any time (`:SendToTerminal select`, `:SendToTerminal reset`).
- 🔄 **Dynamic Default Shell Switching**:
  - Switch the default shell anytime with `:SendToTerminal set_shell <lang> <cmd>` (e.g., `:SendToTerminal set_shell bash zsh` or `:SendToTerminal set_shell powershell pwsh`).
- ⚡ **Multi-Line Continuation Support**:
  - **POSIX / Python**: Trailing backslash (`\`) line continuations.
  - **PowerShell**: Trailing backtick (``` ` ```) line continuations, trailing pipes (`|`), and operators (`-and`, `-or`, `&&`, `||`).
  - Spans multi-line continuation statements as a single atomic unit.
- 🛡️ **Bracketed Paste Mode**:
  - Wraps payloads in `\x1b[200~ ... \x1b[201~` to prevent shells (`pwsh`, `zsh`, `fish`, `bash`) and REPLs (`ipython`, `python`) from indenting cascades or executing prematurely.
- 🔌 **Universal Backends**:
  - Built-in Neovim `:terminal` (auto-detects open terminal splits or spawns new ones).
  - `Snacks.terminal` / `toggleterm.nvim`.
  - Terminal multiplexers: `tmux`, `zellij`, `kitty`, `wezterm`.
  - Auto-detection mode (`backend = "auto"`) adapts to your current environment.
- ⏭️ **Step-Through Mode**:
  - `send_step`: Executes the current command (including all its continuations) and automatically advances your cursor to the next executable line.
- 💡 **Visual Flash Feedback**:
  - Highlights the exact range sent to the terminal before execution.

---

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "pkshrestha/neovim-send-to-terminal", -- or local path
  cmd = { "SendToTerminal" },
  keys = {
    { "<leader>ss", "<cmd>SendToTerminal line<cr>", desc = "Send line / inline command" },
    { "<leader>sb", "<cmd>SendToTerminal block<cr>", desc = "Send current code block" },
    { "<leader>sn", "<cmd>SendToTerminal step<cr>", desc = "Send and step to next" },
    { "<leader>sf", "<cmd>SendToTerminal file<cr>", desc = "Send entire file" },
    { "<leader>st", "<cmd>SendToTerminal select<cr>", desc = "Select / change target terminal" },
    { "<leader>sh", "<cmd>SendToTerminal history<cr>", desc = "Show execution history" },
    { "<leader>sl", "<cmd>SendToTerminal last<cr>", desc = "Show last outcome float" },
    { "<leader>so", "<cmd>SendToTerminal copy_output<cr>", desc = "Copy last outcome to clipboard" },
    { "<leader>s", "<cmd>SendToTerminal visual<cr>", mode = "v", desc = "Send visual selection" },
    { "<leader>sm", function() require("send-to-terminal").send_motion() end, desc = "Send motion" },
  },
  opts = {
    backend = "auto", -- "auto" | "neovim" | "snacks" | "toggleterm" | "tmux" | "zellij" | "kitty" | "wezterm"
    bracketed_paste = true,
    history = {
      enabled = true,
      copy_output_to_clipboard = true, -- Automatically copy outcome to clipboard
      notify_on_copy = true,
    },
    markdown = {
      strip_prompts = true,
      filter_output_lines = true,
      strip_inline_backticks = true,
      prefer_inline = true,
    },
    terminal = {
      auto_open = true,
      split = "botright 15split",
      shells = {
        powershell = "pwsh", -- or "powershell.exe"
        bash = "bash",
        zsh = "zsh",
        python = "python3",
      },
    },
  },
}
```

---

## ⚙️ Configuration & Options

```lua
require("send-to-terminal").setup({
  -- Backend selection: "auto", "neovim", "snacks", "toggleterm", "tmux", "zellij", "kitty", "wezterm"
  backend = "auto",

  -- Execution history & outcome recording
  history = {
    enabled = true,
    max_entries = 100,
    copy_output_to_clipboard = true, -- Auto-copy terminal output to system clipboard (+)
    capture_output = true,          -- Capture output from terminal buffer
    capture_timeout = 1000,         -- Milliseconds to wait for output
    notify_on_copy = true,
  },

  -- Native Neovim terminal settings
  terminal = {
    auto_open = true,            -- Automatically open terminal split if none is open
    split = "botright 15split",  -- Command used to open terminal
    focus_on_send = false,       -- Stay in current buffer or switch focus to terminal
    shells = {
      powershell = "pwsh",
      bash = "bash",
      zsh = "zsh",
      python = "python3",
    },
    default_shell = nil,         -- Default fallback shell
  },

  -- Markdown specific settings
  markdown = {
    strip_prompts = true,        -- Strip $, >, PS>, etc.
    filter_output_lines = true,  -- If prompts are found, skip output lines in documentation blocks
    strip_inline_backticks = true,
    strip_comments = false,
    prefer_inline = true,        -- Prioritize inline backtick execution if cursor is on it
  },

  -- Wrap commands in bracketed paste mode (\x1b[200~ ... \x1b[201~)
  bracketed_paste = true,
  auto_newline = true,

  -- Visual flash highlight
  highlight = {
    enabled = true,
    duration = 150,              -- Duration in milliseconds
    hl_group = "IncSearch",
  },

  -- Regex patterns for prompts per filetype
  prompt_patterns = {
    sh = { "^%s*%$%s?", "^%s*❯%s?", "^%s*#%s?" },
    bash = { "^%s*%$%s?", "^%s*❯%s?", "^%s*#%s?" },
    zsh = { "^%s*%$%s?", "^%s*❯%s?", "^%s*#%s?" },
    ps1 = { "^%s*%[PS%]%s*[^>]*>%s?", "^%s*PS%s*[^>]*>%s?", "^%s*>>%s?" },
    powershell = { "^%s*%[PS%]%s*[^>]*>%s?", "^%s*PS%s*[^>]*>%s?", "^%s*>>%s?" },
    pwsh = { "^%s*%[PS%]%s*[^>]*>%s?", "^%s*PS%s*[^>]*>%s?", "^%s*>>%s?" },
    python = { "^%s*>>>%s?", "^%s*%.%.%.%s?", "^%s*In%s*%[%d+%]:%s?", "^%s*>>%s?" },
    r = { "^%s*>%s?", "^%s*\\+%s?" },
    lua = { "^%s*>%s?" },
  },

  -- Line continuation characters
  continuation_chars = {
    sh = { "\\" },
    bash = { "\\" },
    python = { "\\" },
    ps1 = { "`", "\\" },
    powershell = { "`", "\\" },
    pwsh = { "`", "\\" },
  },
})
```

---

## 💡 Examples & Use Cases

### 1. PowerShell Multi-line Continuations & Prompts
```powershell
PS C:\> Get-ChildItem `
    -Path C:\Projects `
    -Filter *.ps1 `
    -Recurse
```
- **Executing current line / step (`<leader>ss` or `<leader>sn`)**: Automatically detects the trailing backtick (`` ` ``) and sends all 4 lines together as one command, cleanly stripping `PS C:\>`.

### 2. Documentation with Interleaved Output
```bash
$ git status
On branch main
nothing to commit, working tree clean
$ git pull
```
- **Executing block (`<leader>sb`)**: Detects `$ ` prompts and automatically filters out the output text `On branch main...`, running only `git status` and `git pull`!

### 3. Inline Backticks in Markdown Prose
```markdown
You can initialize the database with `npm run db:migrate` before starting.
```
- Placing your cursor on `npm run db:migrate` and running `<leader>ss` sends only `npm run db:migrate` without the backticks.

---

## 📂 Interactive Example Files

Check out the interactive markdown demo files in the [`examples/`](./examples/) folder:
- [PowerShell Demo (`examples/powershell_demo.md`)](./examples/powershell_demo.md) - Backtick continuations (`` ` ``), pipelines (`|`), here-strings (`@"..."@`), and prompt stripping (`PS C:\>`).
- [Bash & Zsh Demo (`examples/bash_zsh_demo.md`)](./examples/bash_zsh_demo.md) - Prompt stripping (`$ `, `❯ `), backslash continuations (`\`), heredocs, and output filtering.
- [Python & IPython REPL Demo (`examples/python_repl_demo.md`)](./examples/python_repl_demo.md) - Prompt stripping (`>>> `, `... `, `In [1]: `) with indentation preservation.
- [Polyglot Multi-Shell Demo (`examples/polyglot_demo.md`)](./examples/polyglot_demo.md) - Polyglot markdown notebook routing commands to matching terminal backends.

---

## 🧪 Testing

Run headless unit tests locally:
```bash
nvim --headless -u NONE -c "luafile tests/run_tests.lua"
```

---

## 📄 License

MIT License.
# neovim-send-to-terminal
