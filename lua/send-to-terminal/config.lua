local M = {}

---@class STTOptions
---@field backend? string Default backend ("auto", "neovim", "snacks", "toggleterm", "tmux", "zellij", "kitty", "wezterm")
---@field terminal? STTTerminalOptions
---@field markdown? STTMarkdownOptions
---@field bracketed_paste? boolean Wrap commands in bracketed paste mode (\x1b[200~ ... \x1b[201~)
---@field auto_newline? boolean Append newline when sending to terminal
---@field highlight? STTHighlightOptions
---@field prompt_patterns? table<string, string[]>
---@field continuation_chars? table<string, string[]>

---@class STTTerminalOptions
---@field auto_open? boolean Automatically open terminal split if none is open
---@field split? string Command to open terminal window (e.g. "botright 15split")
---@field focus_on_send? boolean Jump focus to terminal after sending
---@field shells? table<string, string> Shell command per language (e.g. powershell = "pwsh", bash = "bash")
---@field default_shell? string Default shell command fallback

---@class STTMarkdownOptions
---@field strip_prompts? boolean Automatically strip leading prompts like $, >, PS>, etc.
---@field filter_output_lines? boolean If prompts are detected in a block, filter out lines without prompts
---@field strip_inline_backticks? boolean Extract content from inside `...`
---@field strip_comments? boolean Strip comment lines (# ...)
---@field prefer_inline? boolean When cursor is on inline code in normal text, prioritize running inline code

---@class STTHighlightOptions
---@field enabled? boolean Visual flash highlight on executed code
---@field duration? integer Duration of flash in milliseconds
---@field hl_group? string Highlight group to use for flash (e.g. "IncSearch" or "Visual")

---@type STTOptions
M.defaults = {
  backend = "auto",

  terminal = {
    auto_open = true,
    split = "botright 15split",
    focus_on_send = false,
    shells = {
      powershell = "pwsh",
      pwsh = "pwsh",
      ps1 = "pwsh",
      bash = "bash",
      sh = "sh",
      zsh = "zsh",
      fish = "fish",
      python = "python3",
    },
    default_shell = nil,
  },

  markdown = {
    strip_prompts = true,
    filter_output_lines = true,
    strip_inline_backticks = true,
    strip_comments = false,
    prefer_inline = true,
  },

  bracketed_paste = true,
  auto_newline = true,

  highlight = {
    enabled = true,
    duration = 150,
    hl_group = "IncSearch",
  },

  -- Regex patterns for prompts per filetype/syntax
  prompt_patterns = {
    sh = { "^%s*%$%s?", "^%s*❯%s?", "^%s*#%s?" },
    bash = { "^%s*%$%s?", "^%s*❯%s?", "^%s*#%s?" },
    zsh = { "^%s*%$%s?", "^%s*❯%s?", "^%s*#%s?" },
    fish = { "^%s*%$%s?", "^%s*❯%s?", "^%s*#%s?" },
    ps1 = { "^%s*%[PS%]%s*[^>]*>%s?", "^%s*PS%s*[^>]*>%s?", "^%s*>>%s?" },
    powershell = { "^%s*%[PS%]%s*[^>]*>%s?", "^%s*PS%s*[^>]*>%s?", "^%s*>>%s?" },
    pwsh = { "^%s*%[PS%]%s*[^>]*>%s?", "^%s*PS%s*[^>]*>%s?", "^%s*>>%s?" },
    python = { "^%s*>>>%s?", "^%s*%.%.%.%s?", "^%s*In%s*%[%d+%]:%s?", "^%s*>>%s?" },
    r = { "^%s*>%s?", "^%s*\\+%s?" },
    lua = { "^%s*>%s?" },
    julia = { "^%s*julia>%s?" },
    sql = { "^%s*[%w_]+[>=#]%s?", "^%s*->%s?" },
  },

  -- Line continuation characters per filetype
  continuation_chars = {
    sh = { "\\" },
    bash = { "\\" },
    zsh = { "\\" },
    fish = { "\\" },
    python = { "\\" },
    ps1 = { "`", "\\" },
    powershell = { "`", "\\" },
    pwsh = { "`", "\\" },
  },
}

---@type STTOptions
M.options = vim.deepcopy(M.defaults)

---Merge user options into defaults
---@param user_opts? STTOptions
---@return STTOptions
function M.setup(user_opts)
  if user_opts then
    M.options = vim.tbl_deep_extend("force", M.defaults, user_opts)
  else
    M.options = vim.deepcopy(M.defaults)
  end
  return M.options
end

---Get current active options
---@return STTOptions
function M.get()
  return M.options
end

return M
