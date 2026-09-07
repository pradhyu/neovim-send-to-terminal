local utils = require("send-to-terminal.utils")

local M = {}

---Check if toggleterm is available
---@return boolean
function M.is_available()
  local ok, _ = pcall(require, "toggleterm")
  return ok
end

---Send text via toggleterm
---@param text string
---@param opts? STTOptions
---@return boolean success
function M.send(text, opts)
  local ok, toggleterm = pcall(require, "toggleterm")
  if not ok then
    utils.notify("toggleterm.nvim is not installed.", vim.log.levels.ERROR)
    return false
  end

  local ok_send, _ = pcall(function()
    toggleterm.send_lines_to_terminal("single_line", false, { args = { [1] = text } })
  end)

  if not ok_send then
    -- Fallback to terminal manager
    local ok_terms, terms = pcall(require, "toggleterm.terminal")
    if ok_terms and terms.get_all then
      local all_terms = terms.get_all()
      if #all_terms > 0 and all_terms[1].job_id then
        vim.fn.chansend(all_terms[1].job_id, text)
        return true
      end
    end
  end

  return true
end

return M
