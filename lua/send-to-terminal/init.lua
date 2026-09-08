local config = require("send-to-terminal.config")
local utils = require("send-to-terminal.utils")
local state = require("send-to-terminal.state")
local history = require("send-to-terminal.core.history")
local extractor = require("send-to-terminal.core.extractor")
local sanitizer = require("send-to-terminal.core.sanitizer")
local highlighter = require("send-to-terminal.core.highlighter")
local backends = require("send-to-terminal.backends")

local M = {}

---Initialize plugin with user options
---@param opts? STTOptions
function M.setup(opts)
  local cfg = config.setup(opts)
  if cfg.keymaps then
    local km = cfg.keymaps
    if km.send_line then
      vim.keymap.set("n", km.send_line, function() M.send_line() end, { desc = "Send line / inline command" })
    end
    if km.send_block then
      vim.keymap.set("n", km.send_block, function() M.send_block() end, { desc = "Send current code block" })
    end
    if km.send_step then
      vim.keymap.set("n", km.send_step, function() M.send_step() end, { desc = "Send and step to next" })
    end
    if km.send_file then
      vim.keymap.set("n", km.send_file, function() M.send_file() end, { desc = "Send entire file" })
    end
    if km.send_visual then
      vim.keymap.set("v", km.send_visual, function() M.send_visual() end, { desc = "Send visual selection" })
    end
    if km.send_motion then
      vim.keymap.set("n", km.send_motion, function() M.send_motion() end, { desc = "Send motion" })
    end
    if km.select_terminal then
      vim.keymap.set("n", km.select_terminal, function() M.select_terminal() end, { desc = "Select target terminal" })
    end
    if km.show_last then
      vim.keymap.set("n", km.show_last, function() M.show_last_output() end, { desc = "Show last outcome float" })
    end
    if km.show_history then
      vim.keymap.set("n", km.show_history, function() M.show_history() end, { desc = "Show execution history" })
    end
    if km.copy_output then
      vim.keymap.set("n", km.copy_output, function() M.copy_last_output() end, { desc = "Copy last outcome to clipboard" })
    end
    if km.paste_output then
      vim.keymap.set("n", km.paste_output, function() M.paste_last_output() end, { desc = "Paste last output into buffer" })
    end
  end
end

---Send arbitrary text string to terminal backend
---@param text string
---@param opts? STTOptions
---@param lang? string
---@param on_done? fun(success: boolean)
---@return boolean success
function M.send_text(text, opts, lang, on_done)
  opts = opts or config.get()
  lang = lang or "sh"
  local lines = utils.split_lines(text)
  local payload = sanitizer.format_payload(lines, opts)

  local cur_buf = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(cur_buf)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local entry = history.add_entry({
    src_bufnr = cur_buf,
    file = file_path ~= "" and file_path or "[buffer]",
    line_start = cursor[1],
    line_end = cursor[1],
    lang = lang,
    command = text,
  })

  return backends.send(payload, opts, lang, on_done, entry and entry.id or nil)
end

---Execute an extraction result (highlight, format, send, record history)
---@param result STTExtractionResult|nil
---@param opts? STTOptions
---@param on_done? fun(success: boolean)
---@return boolean success
local function execute_result(result, opts, on_done)
  opts = opts or config.get()
  if not result or not result.text or result.text == "" then
    if on_done then on_done(false) end
    return false
  end

  -- Flash visual highlight
  local range = result.range
  if range then
    if result.is_inline then
      highlighter.flash_range(range.bufnr, range.start_row, range.start_col, range.end_row, range.end_col, opts)
    else
      highlighter.flash_lines(range.bufnr, range.start_line, range.end_line, opts)
    end
  end

  -- Record execution in history
  local src_buf = (range and range.bufnr) or vim.api.nvim_get_current_buf()
  local src_file = vim.api.nvim_buf_get_name(src_buf)
  local entry = history.add_entry({
    src_bufnr = src_buf,
    file = src_file ~= "" and src_file or "[buffer]",
    line_start = (range and range.start_line) or 1,
    line_end = (range and range.end_line) or 1,
    lang = result.lang,
    command = result.text,
  })

  -- Format payload with bracketed paste & newlines
  local payload = sanitizer.format_payload(result.sanitized_lines, opts)

  local done_called = false
  local function done_wrapper(status)
    if not done_called then
      done_called = true
      if on_done then on_done(status) end
    end
  end

  -- Send via backend with language detection and history capture
  local ok = backends.send(payload, opts, result.lang, done_wrapper, entry and entry.id or nil)
  if ok and not done_called then
    done_wrapper(true)
  end
  return ok
end

---Send current line or inline backtick command
---@param opts? STTOptions
---@return boolean
function M.send_line(opts)
  opts = opts or config.get()
  local res = extractor.extract_line(nil, nil, opts)
  if not res then
    utils.notify("Nothing to send on current line.", vim.log.levels.INFO)
    return false
  end
  return execute_result(res, opts)
end

---Send enclosing block (fenced code block or Treesitter node)
---@param opts? STTOptions
---@return boolean
function M.send_block(opts)
  opts = opts or config.get()
  local res = extractor.extract_block(nil, nil, opts)
  if not res then
    utils.notify("No enclosing code block found.", vim.log.levels.INFO)
    return false
  end
  return execute_result(res, opts)
end

---Send visual selection
---@param opts? STTOptions
---@return boolean
function M.send_visual(opts)
  opts = opts or config.get()
  local res = extractor.extract_visual(nil, opts)
  if not res then
    utils.notify("No visual selection to send.", vim.log.levels.INFO)
    return false
  end
  return execute_result(res, opts)
end

---Send current command and advance cursor to next command
---@param opts? STTOptions
---@return boolean
function M.send_step(opts)
  opts = opts or config.get()
  local bufnr = vim.api.nvim_get_current_buf()
  local winnr = vim.api.nvim_get_current_win()

  local res = extractor.extract_line(bufnr, winnr, opts)
  if not res then
    utils.notify("Nothing to send at cursor.", vim.log.levels.INFO)
    return false
  end

  return execute_result(res, opts, function(ok)
    if ok and res.range then
      local next_line = extractor.find_next_executable_line(bufnr, res.range.end_line, res.lang, opts)
      if next_line then
        vim.api.nvim_win_set_cursor(winnr, { next_line, 0 })
      end
    end
  end)
end

---Send entire buffer
---@param opts? STTOptions
---@return boolean
function M.send_file(opts)
  opts = opts or config.get()
  local res = extractor.extract_file(nil, opts)
  if not res then
    utils.notify("Buffer is empty.", vim.log.levels.INFO)
    return false
  end
  return execute_result(res, opts)
end

---Operatorfunc callback for motion execution (`g@`)
---@param motion_type string
function M.opfunc(motion_type)
  local bufnr = vim.api.nvim_get_current_buf()
  local s_pos = vim.fn.getpos("'[")
  local e_pos = vim.fn.getpos("']")

  local s_line = s_pos[2]
  local s_col = s_pos[3]
  local e_line = e_pos[2]
  local e_col = e_pos[3]

  if s_line == 0 or e_line == 0 then
    return
  end

  local lines = utils.get_buf_lines(bufnr, s_line, e_line)
  local lang = utils.get_filetype(bufnr)
  local is_char = (motion_type == "char")

  if is_char then
    if #lines == 1 then
      lines[1] = lines[1]:sub(s_col, e_col)
    else
      lines[1] = lines[1]:sub(s_col)
      lines[#lines] = lines[#lines]:sub(1, e_col)
    end
  end

  local opts = config.get()
  local sanitized = sanitizer.sanitize_lines(lines, lang, opts)
  local res = {
    text = table.concat(sanitized, "\n"),
    raw_lines = lines,
    sanitized_lines = sanitized,
    lang = lang,
    is_inline = is_char and (#lines == 1),
    range = {
      bufnr = bufnr,
      start_row = s_line - 1,
      start_col = is_char and (s_col - 1) or 0,
      end_row = e_line - 1,
      end_col = is_char and e_col or -1,
      start_line = s_line,
      end_line = e_line,
    },
  }

  execute_result(res, opts)
end

---Trigger operator motion
function M.send_motion()
  vim.go.operatorfunc = "v:lua.require'send-to-terminal'.opfunc"
  vim.api.nvim_feedkeys("g@", "n", false)
end

---Interactively select or switch the target terminal buffer
---@param lang? string
---@param callback? fun(bufnr: integer|nil)
function M.select_terminal(lang, callback)
  local neovim_backend = require("send-to-terminal.backends.neovim")
  neovim_backend.interactive_select_terminal(lang, callback)
end

---Change the default shell command for a language (e.g. powershell -> pwsh, bash -> zsh)
---@param lang string
---@param shell_cmd string
function M.set_default_shell(lang, shell_cmd)
  state.set_shell(lang, shell_cmd)
  utils.notify(string.format("Default shell for '%s' set to '%s'", lang, shell_cmd))
end

---Reset cached target terminal buffer selections
---@param lang? string
function M.reset_target(lang)
  state.clear_target_buffer(lang)
  if lang then
    utils.notify(string.format("Reset target terminal buffer for '%s'", lang))
  else
    utils.notify("Reset all target terminal buffers.")
  end
end

---Get current target terminal buffer for a language
---@param lang? string
---@return integer|nil
function M.get_target_buffer(lang)
  return state.get_target_buffer(lang)
end

---Explicitly set target terminal buffer for a language
---@param lang string
---@param bufnr integer
function M.set_target_buffer(lang, bufnr)
  state.set_target_buffer(lang, bufnr)
  utils.notify(string.format("Target terminal for '%s' bound to buffer #%d", lang, bufnr))
end

---Show interactive execution history UI
function M.show_history()
  history.show_history_ui()
end

---Show floating window with the last execution outcome
function M.show_last_output()
  history.show_last_output()
end

---Copy output/outcome of last command to clipboard
function M.copy_last_output()
  history.copy_last_output()
end

---Copy last command to clipboard
function M.copy_last_command()
  history.copy_last_command()
end

---Paste the last command's outcome as commented lines below cursor
---@param opts? STTOptions
function M.paste_last_output(opts)
  history.paste_last_output_to_current_buffer(opts)
end

---Toggle automatic pasting of commented output below command in buffer
---@param enabled? boolean
---@return boolean new_state
function M.toggle_paste_output(enabled)
  local new_val = config.toggle_paste_output(enabled)
  utils.notify(string.format("Auto paste output to buffer: %s", new_val and "ON" or "OFF"))
  return new_val
end

---Toggle history tracking
---@param enabled? boolean
---@return boolean new_state
function M.toggle_history(enabled)
  local new_val = config.toggle_history(enabled)
  utils.notify(string.format("History tracking: %s", new_val and "ON" or "OFF"))
  return new_val
end

---Toggle automatic copying of outcome to clipboard
---@param enabled? boolean
---@return boolean new_state
function M.toggle_copy_output(enabled)
  local new_val = config.toggle_copy_output(enabled)
  utils.notify(string.format("Auto copy outcome to clipboard: %s", new_val and "ON" or "OFF"))
  return new_val
end

---Display current configuration and terminal target status
function M.status()
  local opts = config.get()
  local hist_opts = opts.history or {}
  local lines = {
    "=== send-to-terminal Status ===",
    string.format("  Backend:                 %s", opts.backend or "auto"),
    string.format("  History Tracking:        %s", hist_opts.enabled and "ON" or "OFF"),
    string.format("  Auto Paste Output:       %s", hist_opts.paste_output_to_buffer and "ON" or "OFF"),
    string.format("  Auto Copy to Clipboard:  %s", hist_opts.copy_output_to_clipboard and "ON" or "OFF"),
    string.format("  Bracketed Paste:         %s", opts.bracketed_paste and "ON" or "OFF"),
    string.format("  History Total Entries:   %d", #history.entries),
  }
  print(table.concat(lines, "\n"))
  utils.notify(table.concat(lines, "\n"))
end

---Clear execution history
function M.clear_history()
  history.clear()
end

---Get all history records
---@return STTHistoryEntry[]
function M.get_history()
  return history.entries
end

return M
