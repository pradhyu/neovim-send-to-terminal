local utils = require("send-to-terminal.utils")
local config = require("send-to-terminal.config")

local M = {}

---Find an active terminal buffer in Neovim
---@return integer|nil bufnr, integer|nil job_id, integer|nil winnr
function M.find_terminal()
  -- Check current window first
  local cur_buf = vim.api.nvim_get_current_buf()
  if vim.bo[cur_buf].buftype == "terminal" then
    local job_id = vim.b[cur_buf].terminal_job_id
    if job_id then
      return cur_buf, job_id, vim.api.nvim_get_current_win()
    end
  end

  -- Check all visible windows in current tabpage
  local cur_win = vim.api.nvim_get_current_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == "terminal" then
      local job_id = vim.b[buf].terminal_job_id
      if job_id then
        return buf, job_id, win
      end
    end
  end

  -- Check all loaded buffers (even if not visible in current tab)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "terminal" then
      local job_id = vim.b[buf].terminal_job_id
      if job_id then
        return buf, job_id, nil
      end
    end
  end

  return nil, nil, nil
end

---Open a new terminal window / split
---@param opts? STTOptions
---@return integer bufnr, integer job_id, integer winnr
function M.open_terminal(opts)
  opts = opts or config.get()
  local split_cmd = (opts.terminal and opts.terminal.split) or "botright 15split"

  -- Save current window
  local origin_win = vim.api.nvim_get_current_win()

  -- Create split and start terminal
  vim.cmd(split_cmd)
  vim.cmd("terminal")

  local term_win = vim.api.nvim_get_current_win()
  local term_buf = vim.api.nvim_get_current_buf()
  local job_id = vim.b[term_buf].terminal_job_id

  -- Restore focus if focus_on_send is false
  if not (opts.terminal and opts.terminal.focus_on_send) then
    vim.api.nvim_set_current_win(origin_win)
  end

  return term_buf, job_id, term_win
end

---Check if native neovim terminal is available
---@return boolean
function M.is_available()
  return true
end

---Send text to Neovim terminal backend
---@param text string
---@param opts? STTOptions
---@return boolean success
function M.send(text, opts)
  opts = opts or config.get()
  local buf, job_id, win = M.find_terminal()

  if not job_id then
    if opts.terminal and opts.terminal.auto_open then
      buf, job_id, win = M.open_terminal(opts)
    else
      utils.notify("No active terminal found and auto_open is disabled.", vim.log.levels.WARN)
      return false
    end
  end

  if not job_id then
    utils.notify("Failed to obtain terminal job ID.", vim.log.levels.ERROR)
    return false
  end

  -- Send via chansend
  vim.fn.chansend(job_id, text)

  if opts.terminal and opts.terminal.focus_on_send and win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end

  return true
end

return M
