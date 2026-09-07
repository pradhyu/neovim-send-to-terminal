local utils = require("send-to-terminal.utils")
local config = require("send-to-terminal.config")

local M = {}

---@class STTHistoryEntry
---@field id integer
---@field timestamp string
---@field src_bufnr integer|nil
---@field file string
---@field line_start integer
---@field line_end integer
---@field lang string
---@field command string
---@field output string
---@field status string ("running"|"completed")

---@type STTHistoryEntry[]
M.entries = {}
local next_id = 1

---Strip ANSI escape sequences and carriage returns from terminal text
---@param text string
---@return string
function M.strip_ansi(text)
  if not text or text == "" then
    return ""
  end

  local cleaned = text
    -- Remove CSI escape sequences: \27[...[a-zA-Z]
    :gsub("\27%[[0-9;?]*[a-zA-Z]", "")
    -- Remove OSC escape sequences: \27]...(\a or \27\)
    :gsub("\27%]%d+;[^\a\27]*[\a\27\\]", "")
    -- Remove alternate character set codes: \27(B etc.
    :gsub("\27%([a-zA-Z]", "")
    -- Remove carriage returns
    :gsub("\r", "")

  return cleaned
end

---Determine the appropriate comment prefix for a language
---@param lang string
---@param opts? STTOptions
---@return string
function M.get_comment_prefix(lang, opts)
  opts = opts or config.get()
  local hist_opts = opts.history or {}
  if hist_opts.comment_prefix then
    return hist_opts.comment_prefix
  end

  local norm = utils.normalize_lang(lang)
  if norm == "powershell" or norm == "pwsh" or norm == "ps1" or norm == "bash"
     or norm == "sh" or norm == "zsh" or norm == "fish" or norm == "python"
     or norm == "r" or norm == "ruby" or norm == "julia" then
    return "# "
  elseif norm == "lua" or norm == "sql" then
    return "-- "
  elseif norm == "javascript" or norm == "typescript" or norm == "c" or norm == "cpp"
     or norm == "rust" or norm == "go" or norm == "java" then
    return "// "
  end

  return "# "
end

---Format output lines with language-specific comment characters
---@param output string
---@param lang string
---@param command? string
---@param opts? STTOptions
---@return string[]
function M.format_commented_output(output, lang, command, opts)
  local prefix = M.get_comment_prefix(lang, opts)
  local raw_lines = utils.split_lines(output)
  local commented = {}

  -- Check if first line echoes the command itself (common in terminal streams)
  local start_idx = 1
  if #raw_lines > 0 and command and command ~= "" then
    local first_line = utils.trim(raw_lines[1])
    local first_cmd_line = utils.trim(utils.split_lines(command)[1] or "")
    if first_line == first_cmd_line or first_line:match(vim.pesc(first_cmd_line) .. "$") then
      start_idx = 2
    end
  end

  for i = start_idx, #raw_lines do
    local l = raw_lines[i]
    if utils.is_blank(l) then
      table.insert(commented, utils.rtrim(prefix))
    else
      table.insert(commented, prefix .. l)
    end
  end

  return commented
end

---Paste commented output lines directly below the executed command in buffer
---@param bufnr integer
---@param line_end integer (1-indexed line after which to insert)
---@param output string
---@param lang string
---@param command? string
---@param opts? STTOptions
---@return boolean success
function M.paste_commented_output_to_buffer(bufnr, line_end, output, lang, command, opts)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) or not vim.bo[bufnr].modifiable then
    return false
  end

  local commented_lines = M.format_commented_output(output, lang, command, opts)
  if #commented_lines == 0 then
    return false
  end

  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local insert_idx = math.min(line_end, total_lines)

  vim.api.nvim_buf_set_lines(bufnr, insert_idx, insert_idx, false, commented_lines)

  -- Flash highlight the newly inserted output lines
  local highlighter = require("send-to-terminal.core.highlighter")
  highlighter.flash_lines(bufnr, insert_idx + 1, insert_idx + #commented_lines, opts)

  return true
end

---Add a new history entry
---@param data table
---@return STTHistoryEntry
function M.add_entry(data)
  local opts = config.get()
  local hist_opts = opts.history or {}
  if hist_opts.enabled == false then
    return nil
  end

  local entry = {
    id = next_id,
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    src_bufnr = data.src_bufnr,
    file = data.file or "[buffer]",
    line_start = data.line_start or 1,
    line_end = data.line_end or 1,
    lang = data.lang or "sh",
    command = data.command or "",
    output = data.output or "",
    status = data.status or "running",
  }
  next_id = next_id + 1

  table.insert(M.entries, 1, entry)

  -- Limit max entries
  local max_entries = hist_opts.max_entries or 100
  while #M.entries > max_entries do
    table.remove(M.entries)
  end

  return entry
end

---Update output for a history entry and optionally paste/copy
---@param entry_id integer
---@param raw_output string
---@param opts? STTOptions
function M.update_output(entry_id, raw_output, opts)
  opts = opts or config.get()
  local hist_opts = opts.history or {}
  local cleaned = M.strip_ansi(raw_output)

  for _, entry in ipairs(M.entries) do
    if entry.id == entry_id then
      entry.output = utils.trim(cleaned)
      entry.status = "completed"

      if entry.output ~= "" then
        -- Auto-copy to clipboard if enabled
        if hist_opts.copy_output_to_clipboard then
          M.copy_to_clipboard(entry.output, hist_opts.notify_on_copy)
        end

        -- Auto-paste commented output below command in buffer if enabled
        if hist_opts.paste_output_to_buffer and entry.src_bufnr then
          M.paste_commented_output_to_buffer(entry.src_bufnr, entry.line_end, entry.output, entry.lang, entry.command, opts)
        end
      end
      break
    end
  end
end

---Copy text to system clipboard and default register
---@param text string
---@param notify? boolean
function M.copy_to_clipboard(text, notify)
  if not text or text == "" then
    return
  end
  vim.fn.setreg("+", text)
  vim.fn.setreg('"', text)
  if notify ~= false then
    local lines = utils.split_lines(text)
    utils.notify(string.format("Outcome copied to clipboard! (%d line%s)", #lines, #lines == 1 and "" or "s"))
  end
end

---Capture output from terminal buffer after execution
---@param term_bufnr integer
---@param start_line_count integer
---@param entry_id integer
---@param opts? STTOptions
function M.capture_terminal_output(term_bufnr, start_line_count, entry_id, opts)
  opts = opts or config.get()
  local hist_opts = opts.history or {}
  if not hist_opts.capture_output then
    return
  end

  local timeout = hist_opts.capture_timeout or 1000

  -- Debounced check after execution
  vim.defer_fn(function()
    if not vim.api.nvim_buf_is_valid(term_bufnr) then
      return
    end

    local cur_line_count = vim.api.nvim_buf_line_count(term_bufnr)
    if cur_line_count >= start_line_count then
      local lines = vim.api.nvim_buf_get_lines(term_bufnr, math.max(0, start_line_count - 1), cur_line_count, false)
      local raw_text = table.concat(lines, "\n")
      M.update_output(entry_id, raw_text, opts)
    end
  end, timeout)
end

---Get the latest execution history entry
---@return STTHistoryEntry|nil
function M.get_last_entry()
  return M.entries[1]
end

---Copy the last command's outcome/output to clipboard
function M.copy_last_output()
  local entry = M.get_last_entry()
  if not entry or entry.output == "" then
    utils.notify("No output found in recent execution history.", vim.log.levels.WARN)
    return
  end
  M.copy_to_clipboard(entry.output, true)
end

---Copy the last executed command to clipboard
function M.copy_last_command()
  local entry = M.get_last_entry()
  if not entry or entry.command == "" then
    utils.notify("No recent command found in history.", vim.log.levels.WARN)
    return
  end
  M.copy_to_clipboard(entry.command, true)
end

---Paste the last command's outcome as commented lines below current line
---@param opts? STTOptions
function M.paste_last_output_to_current_buffer(opts)
  local entry = M.get_last_entry()
  if not entry or entry.output == "" then
    utils.notify("No output available to paste.", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur_line = cursor[1]

  M.paste_commented_output_to_buffer(bufnr, cur_line, entry.output, entry.lang, entry.command, opts)
  utils.notify("Pasted commented output below cursor.")
end

---Open a floating window to inspect full details of a history entry
---@param entry STTHistoryEntry
function M.show_entry_float(entry)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"

  local lines = {
    "# 📋 Execution Record #" .. tostring(entry.id),
    "",
    "- **🕒 Timestamp:** " .. entry.timestamp,
    "- **📄 File:** `" .. entry.file .. "` (Lines " .. tostring(entry.line_start) .. "-" .. tostring(entry.line_end) .. ")",
    "- **💻 Language:** `" .. entry.lang .. "`",
    "- **⚡ Status:** `" .. entry.status:upper() .. "`",
    "",
    "## ⌨️ Command",
    "```" .. entry.lang,
  }

  for _, line in ipairs(utils.split_lines(entry.command)) do
    table.insert(lines, line)
  end
  table.insert(lines, "```")
  table.insert(lines, "")
  table.insert(lines, "## 📤 Output / Outcome")
  table.insert(lines, "```")

  if entry.output and entry.output ~= "" then
    for _, line in ipairs(utils.split_lines(entry.output)) do
      table.insert(lines, line)
    end
  else
    table.insert(lines, "(No output captured yet or blank output)")
  end
  table.insert(lines, "```")
  table.insert(lines, "")
  table.insert(lines, "──────── (Press 'y' to copy output, 'c' to copy command, 'p' to paste below, 'q' to close) ────────")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- Calculate float dimensions
  local width = math.min(90, vim.o.columns - 4)
  local height = math.min(#lines + 2, vim.o.lines - 6)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Send to Terminal History ",
    title_pos = "center",
  })

  -- Keybindings inside float
  local function set_key(key, fn)
    vim.keymap.set("n", key, fn, { buffer = buf, nowait = true, silent = true })
  end

  set_key("q", function() pcall(vim.api.nvim_win_close, win, true) end)
  set_key("<Esc>", function() pcall(vim.api.nvim_win_close, win, true) end)
  set_key("y", function()
    M.copy_to_clipboard(entry.output, true)
  end)
  set_key("c", function()
    M.copy_to_clipboard(entry.command, true)
  end)
  set_key("p", function()
    pcall(vim.api.nvim_win_close, win, true)
    local cur_buf = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    M.paste_commented_output_to_buffer(cur_buf, cursor[1], entry.output, entry.lang, entry.command)
  end)
end

---Show floating window with the most recent execution outcome
function M.show_last_output()
  local entry = M.get_last_entry()
  if not entry then
    utils.notify("No execution history available yet.", vim.log.levels.WARN)
    return
  end
  M.show_entry_float(entry)
end

---Interactive history selection UI
function M.show_history_ui()
  if #M.entries == 0 then
    utils.notify("Execution history is empty.", vim.log.levels.INFO)
    return
  end

  vim.ui.select(M.entries, {
    prompt = "Execution History (Select to view outcome):",
    format_item = function(item)
      local cmd_preview = item.command:gsub("\n", " "):sub(1, 40)
      local filename = vim.fn.fnamemodify(item.file, ":t")
      return string.format("[%s] %s:%d [%s] -> %s", item.timestamp:sub(12), filename, item.line_start, item.lang:upper(), cmd_preview)
    end,
  }, function(choice)
    if choice then
      M.show_entry_float(choice)
    end
  end)
end

---Clear all history records
function M.clear()
  M.entries = {}
  utils.notify("Execution history cleared.")
end

return M
