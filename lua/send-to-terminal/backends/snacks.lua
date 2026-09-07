local utils = require("send-to-terminal.utils")

local M = {}

---Check if Snacks.terminal is available
---@return boolean
function M.is_available()
  return _G.Snacks ~= nil and _G.Snacks.terminal ~= nil
end

---Send text via Snacks.terminal
---@param text string
---@param opts? STTOptions
---@return boolean success
function M.send(text, opts)
  if not M.is_available() then
    utils.notify("Snacks.terminal is not available.", vim.log.levels.ERROR)
    return false
  end

  local term = _G.Snacks.terminal.get(nil, { create = true })
  if term and term.job_id then
    vim.fn.chansend(term.job_id, text)
    return true
  end

  utils.notify("Failed to get Snacks terminal job ID.", vim.log.levels.ERROR)
  return false
end

return M
