local utils = require("send-to-terminal.utils")
local config = require("send-to-terminal.config")
local state = require("send-to-terminal.state")

local M = {}

---@class STTTerminalInfo
---@field bufnr integer
---@field job_id integer
---@field winnr integer|nil
---@field name string
---@field title string
---@field shell string ("powershell", "bash", "python", "node", "unknown")

---Identify shell category of a terminal buffer
---@param bufnr integer
---@return string
function M.detect_shell_type(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr):lower()
  local title = (vim.b[bufnr].term_title or ""):lower()
  local combined = name .. " " .. title

  if combined:match("pwsh") or combined:match("powershell") then
    return "powershell"
  elseif combined:match("bash") or combined:match("/bin/sh") or combined:match("zsh") or combined:match("fish") then
    return "bash"
  elseif combined:match("python") or combined:match("ipython") then
    return "python"
  elseif combined:match("node") or combined:match("ts%-node") then
    return "javascript"
  elseif combined:match("cmd%.exe") then
    return "cmd"
  end

  return "unknown"
end

---Inspect and return metadata for a terminal buffer
---@param bufnr integer
---@return STTTerminalInfo|nil
function M.get_terminal_info(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "terminal" then
    return nil
  end

  local job_id = vim.b[bufnr].terminal_job_id
  if not job_id then
    return nil
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  local title = vim.b[bufnr].term_title or vim.fn.fnamemodify(name, ":t")
  local shell_type = M.detect_shell_type(bufnr)

  -- Find visible window if any
  local winnr = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
      winnr = win
      break
    end
  end

  return {
    bufnr = bufnr,
    job_id = job_id,
    winnr = winnr,
    name = name,
    title = title,
    shell = shell_type,
  }
end

---Get all currently active terminal buffers
---@return STTTerminalInfo[]
function M.get_all_terminals()
  local terms = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local info = M.get_terminal_info(buf)
    if info then
      table.insert(terms, info)
    end
  end
  return terms
end

---Find terminal candidates that match the requested language
---@param lang? string
---@return STTTerminalInfo[]
function M.find_terminals_for_lang(lang)
  local key = state.normalize_key(lang)
  local all_terms = M.get_all_terminals()
  local matching = {}

  for _, term in ipairs(all_terms) do
    if key == "powershell" and term.shell == "powershell" then
      table.insert(matching, term)
    elseif (key == "bash" or key == "sh") and (term.shell == "bash" or term.shell == "unknown") then
      table.insert(matching, term)
    elseif key == "python" and (term.shell == "python" or term.shell == "bash" or term.shell == "unknown") then
      table.insert(matching, term)
    end
  end

  -- If no specific shell matches were found, return all open terminals
  if #matching == 0 then
    return all_terms
  end

  return matching
end

---Open a new terminal window / split with specific shell command
---@param shell_cmd string
---@param opts? STTOptions
---@return integer bufnr, integer job_id, integer winnr
function M.open_terminal(shell_cmd, opts)
  opts = opts or config.get()
  local split_cmd = (opts.terminal and opts.terminal.split) or "botright 15split"
  local origin_win = vim.api.nvim_get_current_win()

  vim.cmd(split_cmd)
  vim.cmd("terminal " .. (shell_cmd or ""))

  local term_win = vim.api.nvim_get_current_win()
  local term_buf = vim.api.nvim_get_current_buf()
  local job_id = vim.b[term_buf].terminal_job_id

  if not (opts.terminal and opts.terminal.focus_on_send) then
    vim.api.nvim_set_current_win(origin_win)
  end

  return term_buf, job_id, term_win
end

---Prompt user to select a terminal buffer from list
---@param terminals STTTerminalInfo[]
---@param lang string
---@param callback fun(term: STTTerminalInfo|nil)
function M.select_terminal_prompt(terminals, lang, callback)
  local key = state.normalize_key(lang)
  vim.ui.select(terminals, {
    prompt = string.format("Select terminal buffer for [%s]:", key:upper()),
    format_item = function(item)
      local win_info = item.winnr and string.format(" (Win #%d)", item.winnr) or ""
      local shell_tag = item.shell:upper()
      return string.format("[Buf #%d] %s: %s%s (PID: %d)", item.bufnr, shell_tag, item.title, win_info, item.job_id)
    end,
  }, function(choice)
    if choice then
      state.set_target_buffer(lang, choice.bufnr)
      utils.notify(string.format("Selected terminal buffer #%d for %s", choice.bufnr, key))
    end
    callback(choice)
  end)
end

---Interactive command to manually choose/change the target terminal buffer
---@param lang? string
---@param callback? fun(bufnr: integer|nil)
function M.interactive_select_terminal(lang, callback)
  local terms = M.get_all_terminals()
  if #terms == 0 then
    utils.notify("No active terminal buffers found.", vim.log.levels.WARN)
    if callback then callback(nil) end
    return
  end

  local target_lang = lang or "default"
  M.select_terminal_prompt(terms, target_lang, function(choice)
    if callback then
      callback(choice and choice.bufnr or nil)
    end
  end)
end

---Resolve which terminal to send to (with auto-detection, cached target, or interactive selection)
---@param lang string
---@param opts STTOptions
---@param callback fun(bufnr: integer|nil, job_id: integer|nil, winnr: integer|nil)
function M.resolve_terminal(lang, opts, callback)
  -- Step 1: Check if there's already a valid cached target for this language
  local cached_buf = state.get_target_buffer(lang)
  if cached_buf then
    local info = M.get_terminal_info(cached_buf)
    if info then
      callback(info.bufnr, info.job_id, info.winnr)
      return
    end
  end

  -- Step 2: Find all terminals matching language
  local matching = M.find_terminals_for_lang(lang)

  if #matching == 0 then
    -- No matching terminal exists
    if opts.terminal and opts.terminal.auto_open then
      local shell_cmd = state.get_shell(lang, opts)
      local buf, job_id, win = M.open_terminal(shell_cmd, opts)
      state.set_target_buffer(lang, buf)
      callback(buf, job_id, win)
    else
      utils.notify(string.format("No active terminal found for '%s' and auto_open is disabled.", lang), vim.log.levels.WARN)
      callback(nil, nil, nil)
    end
  elseif #matching == 1 then
    -- Exactly one matching terminal -> Auto-select and cache
    local term = matching[1]
    state.set_target_buffer(lang, term.bufnr)
    callback(term.bufnr, term.job_id, term.winnr)
  else
    -- Multiple matching terminals -> Prompt user to choose
    M.select_terminal_prompt(matching, lang, function(choice)
      if choice then
        callback(choice.bufnr, choice.job_id, choice.winnr)
      else
        callback(nil, nil, nil)
      end
    end)
  end
end

---Check if native neovim terminal is available
---@return boolean
function M.is_available()
  return true
end

---Send text to Neovim terminal backend
---@param text string
---@param opts? STTOptions
---@param lang? string
---@param on_done? fun(success: boolean)
function M.send(text, opts, lang, on_done)
  opts = opts or config.get()
  lang = lang or "sh"

  M.resolve_terminal(lang, opts, function(buf, job_id, win)
    if not job_id then
      if on_done then on_done(false) end
      return
    end

    -- Send via chansend
    vim.fn.chansend(job_id, text)

    if opts.terminal and opts.terminal.focus_on_send and win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_set_current_win(win)
    end

    if on_done then on_done(true) end
  end)
end

return M
