local utils = require("send-to-terminal.utils")

local M = {}

---Check if wezterm CLI is available
---@return boolean
function M.is_available()
  return vim.env.WEZTERM_PANE ~= nil and vim.fn.executable("wezterm") == 1
end

---Send text via wezterm cli send-text
---@param text string
---@param opts? STTOptions
---@return boolean success
function M.send(text, opts)
  if not M.is_available() then
    utils.notify("wezterm pane not detected or wezterm command not found.", vim.log.levels.ERROR)
    return false
  end

  local pane_id = (opts and opts.wezterm and opts.wezterm.pane_id) or nil
  local cmd = { "wezterm", "cli", "send-text", "--no-paste" }
  if pane_id then
    table.insert(cmd, "--pane-id")
    table.insert(cmd, tostring(pane_id))
  end
  table.insert(cmd, text)

  vim.fn.system(cmd)
  return true
end

return M
