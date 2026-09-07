local utils = require("send-to-terminal.utils")
local config = require("send-to-terminal.config")

local M = {}

---@type table<string, integer> Map of lang -> bufnr
M.target_buffers = {}

---@type table<string, string> Map of lang -> custom shell command
M.custom_shells = {}

---Normalize language key for state
---@param lang? string
---@return string
function M.normalize_key(lang)
  if not lang or lang == "" then
    return "default"
  end
  local norm = utils.normalize_lang(lang)
  if norm == "sh" or norm == "zsh" or norm == "fish" then
    return "bash"
  elseif norm == "pwsh" or norm == "ps1" then
    return "powershell"
  end
  return norm
end

---Set target terminal buffer for a specific language
---@param lang? string
---@param bufnr integer
function M.set_target_buffer(lang, bufnr)
  local key = M.normalize_key(lang)
  M.target_buffers[key] = bufnr
end

---Get cached target terminal buffer for a language
---@param lang? string
---@return integer|nil bufnr
function M.get_target_buffer(lang)
  local key = M.normalize_key(lang)
  local bufnr = M.target_buffers[key] or M.target_buffers["default"]
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "terminal" then
    local job_id = vim.b[bufnr].terminal_job_id
    if job_id then
      return bufnr
    end
  end
  -- Invalidated buffer
  M.target_buffers[key] = nil
  return nil
end

---Clear target buffer for language or all
---@param lang? string
function M.clear_target_buffer(lang)
  if lang then
    local key = M.normalize_key(lang)
    M.target_buffers[key] = nil
  else
    M.target_buffers = {}
  end
end

---Set default shell command for a language
---@param lang string
---@param shell_cmd string
function M.set_shell(lang, shell_cmd)
  local key = M.normalize_key(lang)
  M.custom_shells[key] = shell_cmd
end

---Get configured or custom shell command for a language
---@param lang? string
---@param opts? STTOptions
---@return string
function M.get_shell(lang, opts)
  opts = opts or config.get()
  local key = M.normalize_key(lang)

  if M.custom_shells[key] then
    return M.custom_shells[key]
  end

  local term_opts = opts.terminal or {}
  local shells = term_opts.shells or {}

  if shells[key] then
    return shells[key]
  elseif shells[lang] then
    return shells[lang]
  end

  if term_opts.default_shell then
    return term_opts.default_shell
  end

  -- Fallbacks
  if key == "powershell" then
    if vim.fn.executable("pwsh") == 1 then
      return "pwsh"
    elseif vim.fn.executable("powershell.exe") == 1 then
      return "powershell.exe"
    elseif vim.fn.executable("powershell") == 1 then
      return "powershell"
    end
  elseif key == "bash" then
    if vim.fn.executable("bash") == 1 then
      return "bash"
    end
  end

  return vim.o.shell ~= "" and vim.o.shell or (vim.fn.has("win32") == 1 and "cmd.exe" or "sh")
end

---Reset all state
function M.reset()
  M.target_buffers = {}
  M.custom_shells = {}
end

return M
