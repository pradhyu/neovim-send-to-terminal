local utils = require("send-to-terminal.utils")

local M = {}

---Check if tmux is running and available
---@return boolean
function M.is_available()
  return vim.env.TMUX ~= nil and vim.fn.executable("tmux") == 1
end

---Send text to tmux pane
---@param text string
---@param opts? STTOptions
---@return boolean success
function M.send(text, opts)
  if not M.is_available() then
    utils.notify("tmux session not detected or tmux command not found.", vim.log.levels.ERROR)
    return false
  end

  local target = (opts and opts.tmux and opts.tmux.target) or "{last}"

  -- Use tmux load-buffer and paste-buffer or send-keys
  -- load-buffer + paste-buffer preserves exact characters without shell escaping issues
  local tmpfile = vim.fn.tempname()
  local f = io.open(tmpfile, "w")
  if f then
    f:write(text)
    f:close()
    vim.fn.system(string.format("tmux load-buffer %s && tmux paste-buffer -p -t %s", vim.fn.shellescape(tmpfile), vim.fn.shellescape(target)))
    os.remove(tmpfile)
    return true
  else
    -- Fallback to send-keys
    vim.fn.system(string.format("tmux send-keys -t %s %s", vim.fn.shellescape(target), vim.fn.shellescape(text)))
    return true
  end
end

return M
