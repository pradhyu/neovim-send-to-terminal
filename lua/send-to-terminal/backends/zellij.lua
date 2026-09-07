local utils = require("send-to-terminal.utils")

local M = {}

---Check if zellij is running and available
---@return boolean
function M.is_available()
  return vim.env.ZELLIJ ~= nil and vim.fn.executable("zellij") == 1
end

---Send text to zellij session
---@param text string
---@param opts? STTOptions
---@return boolean success
function M.send(text, opts)
  if not M.is_available() then
    utils.notify("zellij session not detected or zellij command not found.", vim.log.levels.ERROR)
    return false
  end

  -- zellij action write-chars <text>
  vim.fn.system({ "zellij", "action", "write-chars", text })
  return true
end

return M
