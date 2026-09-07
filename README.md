# 🚀 neovim-send-to-terminal

> The most intuitive, context-aware, and intelligent "Send to Terminal / REPL" plugin for Neovim.

Send commands and code snippets from Markdown documentation, PowerShell scripts, shell files, Python REPLs, and codebuffers directly into your terminal—with **smart prompt stripping**, **interleaved output filtering**, **multi-line continuation awareness (`\`, ``` ` ```, `|`)**, and **bracketed paste support**.

---

## ✨ Key Features

- 🎯 **Smart Markdown Execution**:
  - **Inline Code**: Cursor inside `` `cargo test` `` executes just the command without surrounding backticks or prose.
  - **Prompt Stripping**: Automatically strips `$ `, `❯ `, `% `, `PS C:\...>`, `PS /path>`, `>> `, `>>> `, `... `, `In [1]: `, etc.
  - **Interleaved Output Filtering**: Automatically distinguishes between command lines and command output in tutorials/READMEs, executing only the commands.
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
    { "<leader>s", "<cmd>SendToTerminal visual<cr>", mode = "v", desc = "Send visual selection" },
    { "<leader>sm", function() require("send-to-terminal").send_motion() end, desc = "Send motion" },
  },
  opts = {
    backend = "auto", -- "auto" | "neovim" | "snacks" | "toggleterm" | "tmux" | "zellij" | "kitty" | "wezterm"
    bracketed_paste = true,
    markdown = {
      strip_prompts = true,
      filter_output_lines = true,
      strip_inline_backticks = true,
      prefer_inline = true,
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

  -- Native Neovim terminal settings
  terminal = {
    auto_open = true,            -- Automatically open terminal split if none is open
    split = "botright 15split",  -- Command used to open terminal
    focus_on_send = false,       -- Stay in current buffer or switch focus to terminal
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

## 🧪 Testing

Run headless unit tests locally:
```bash
nvim --headless -u NONE -c "luafile tests/run_tests.lua"
```

---

## 📄 License

MIT License.
