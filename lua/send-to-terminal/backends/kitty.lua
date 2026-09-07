local utils = require("send-to-terminal.utils")

local M = {}

---Check if kitty remote control is available
---@return boolean
function M.is_available()
  return vim.env.KITTY_WINDOW_ID ~= nil and vim.fn.executable("kitty") == 1
end

---Send text via kitty @ send-text
---@param text string
---@param opts? STTOptions
---@return boolean success
function M.send(text, opts)
  if not M.is_available() then
    utils.notify("kitty window not detected or kitty command not found.", vim.log.levels.ERROR)
    return false
  end

  local match_target = (opts and opts.kitty and opts.kitty.target) or "recent:1"
  vim.fn.system({ "kitty", "@", "send-text", "--match", match_target, text })
  return true
end

return M
