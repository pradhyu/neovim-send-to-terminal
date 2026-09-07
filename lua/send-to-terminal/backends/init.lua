local config = require("send-to-terminal.config")
local utils = require("send-to-terminal.utils")

local M = {}

local backends = {
  neovim = require("send-to-terminal.backends.neovim"),
  snacks = require("send-to-terminal.backends.snacks"),
  toggleterm = require("send-to-terminal.backends.toggleterm"),
  tmux = require("send-to-terminal.backends.tmux"),
  zellij = require("send-to-terminal.backends.zellij"),
  kitty = require("send-to-terminal.backends.kitty"),
  wezterm = require("send-to-terminal.backends.wezterm"),
}

---Register a custom backend
---@param name string
---@param backend_module table
function M.register(name, backend_module)
  backends[name] = backend_module
end

---Get auto-detected backend name
---@return string
function M.auto_detect()
  if vim.env.TMUX and backends.tmux.is_available() then
    return "tmux"
  elseif vim.env.ZELLIJ and backends.zellij.is_available() then
    return "zellij"
  elseif vim.env.KITTY_WINDOW_ID and backends.kitty.is_available() then
    return "kitty"
  elseif vim.env.WEZTERM_PANE and backends.wezterm.is_available() then
    return "wezterm"
  end

  -- Default to native neovim terminal
  return "neovim"
end

---Get the active backend adapter
---@param backend_name? string
---@return table|nil
function M.get_backend(backend_name)
  local opts = config.get()
  local name = backend_name or opts.backend or "auto"

  if type(name) == "function" then
    return {
      send = name,
      is_available = function() return true end,
    }
  end

  if name == "auto" then
    name = M.auto_detect()
  end

  local backend = backends[name]
  if not backend then
    utils.notify(string.format("Unknown backend '%s', falling back to 'neovim'", tostring(name)), vim.log.levels.WARN)
    return backends.neovim
  end

  return backend
end

---Send text through the resolved backend
---@param text string
---@param opts? STTOptions
---@return boolean success
function M.send(text, opts)
  opts = opts or config.get()
  local backend = M.get_backend(opts.backend)
  if not backend then
    utils.notify("No valid terminal backend found.", vim.log.levels.ERROR)
    return false
  end

  return backend.send(text, opts)
end

return M
