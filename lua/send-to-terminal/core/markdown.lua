local utils = require("send-to-terminal.utils")
local sanitizer = require("send-to-terminal.core.sanitizer")

local M = {}

---@class STTInlineCode
---@field text string
---@field start_col integer
---@field end_col integer
---@field line_nr integer

---@class STTCodeFence
---@field lang string
---@field start_line integer (1-indexed, first line of code content)
---@field end_line integer (1-indexed, last line of code content)
---@field fence_start integer (1-indexed, line with opening ```)
---@field fence_end integer (1-indexed, line with closing ```)
---@field lines string[]

---Check if cursor is inside an inline backtick code segment on current line
---@param bufnr integer
---@param winnr integer
---@return STTInlineCode|nil
function M.get_inline_code_at_cursor(bufnr, winnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  winnr = winnr or vim.api.nvim_get_current_win()

  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local line_nr = cursor[1]
  local col = cursor[2] + 1 -- convert to 1-indexed

  local lines = utils.get_buf_lines(bufnr, line_nr, line_nr)
  if #lines == 0 then
    return nil
  end
  local line = lines[1]

  -- Match backticks on the line: `code` or ``code``
  local init = 1
  while init <= #line do
    local s, e, match = line:find("`+([^`]+)`+", init)
    if not s then
      break
    end

    -- Check if cursor column falls within this match
    if col >= s and col <= e then
      local code_text = utils.trim(match)
      return {
        text = code_text,
        start_col = s,
        end_col = e,
        line_nr = line_nr,
      }
    end
    init = e + 1
  end

  return nil
end

---Get fenced code block using regex scan (fast & zero-dependency fallback)
---@param bufnr integer
---@param cursor_line integer
---@return STTCodeFence|nil
local function get_fence_by_scan(bufnr, cursor_line)
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local open_line = nil
  local close_line = nil
  local lang = ""

  -- Search upwards for opening fence
  for l = cursor_line, 1, -1 do
    local line_content = vim.api.nvim_buf_get_lines(bufnr, l - 1, l, false)[1] or ""
    local fence_lang = line_content:match("^%s*```+([%w_%-]+)") or line_content:match("^%s*~~~+([%w_%-]+)")
    local empty_fence = line_content:match("^%s*```+%s*$") or line_content:match("^%s*~~~+%s*$")

    if fence_lang then
      open_line = l
      lang = fence_lang
      break
    elseif empty_fence and l < cursor_line then
      -- Closing fence from an earlier block reached before finding opening fence
      break
    elseif empty_fence and l == cursor_line then
      open_line = l
      lang = ""
      break
    end
  end

  if not open_line then
    return nil
  end

  -- Search downwards for closing fence
  for l = open_line + 1, total_lines do
    local line_content = vim.api.nvim_buf_get_lines(bufnr, l - 1, l, false)[1] or ""
    if line_content:match("^%s*```+%s*$") or line_content:match("^%s*~~~+%s*$") then
      close_line = l
      break
    end
  end

  if not close_line or cursor_line > close_line then
    return nil
  end

  local content_start = open_line + 1
  local content_end = close_line - 1

  if content_start > content_end then
    return {
      lang = lang,
      start_line = content_start,
      end_line = content_end,
      fence_start = open_line,
      fence_end = close_line,
      lines = {},
    }
  end

  local lines = utils.get_buf_lines(bufnr, content_start, content_end)
  return {
    lang = lang,
    start_line = content_start,
    end_line = content_end,
    fence_start = open_line,
    fence_end = close_line,
    lines = lines,
  }
end

---Get fenced code block enclosing cursor
---@param bufnr integer
---@param winnr integer
---@return STTCodeFence|nil
function M.get_code_fence_at_cursor(bufnr, winnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  winnr = winnr or vim.api.nvim_get_current_win()

  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local cursor_line = cursor[1]

  -- Try Treesitter first if available
  if utils.has_treesitter(bufnr) then
    local node = utils.get_node_at_cursor(bufnr, winnr)
    while node do
      local type = node:type()
      if type == "fenced_code_block" or type == "code_block" then
        local srow, _, erow, _ = node:range()
        local fence_start = srow + 1
        local fence_end = erow + 1

        -- Extract language from info_string if present
        local lang = ""
        for child in node:iter_children() do
          if child:type() == "info_string" or child:type() == "language" then
            lang = vim.treesitter.get_node_text(child, bufnr)
            break
          end
        end

        local content_start = fence_start + 1
        local content_end = fence_end - 1

        -- Check closing fence line
        local close_lines = vim.api.nvim_buf_get_lines(bufnr, content_end - 1, content_end, false)
        if close_lines[1] and (close_lines[1]:match("^%s*```") or close_lines[1]:match("^%s*~~~")) then
          content_end = content_end - 1
        end

        local lines = {}
        if content_start <= content_end then
          lines = utils.get_buf_lines(bufnr, content_start, content_end)
        end

        return {
          lang = lang,
          start_line = content_start,
          end_line = content_end,
          fence_start = fence_start,
          fence_end = fence_end,
          lines = lines,
        }
      end
      node = node:parent()
    end
  end

  -- Fallback to regex scanner
  return get_fence_by_scan(bufnr, cursor_line)
end

---Get logical multi-line command at or spanning cursor line
---Handles `\` (POSIX) and ``` ` ``` (PowerShell) continuation lines
---@param bufnr integer
---@param cursor_line integer
---@param lang string
---@param min_line? integer Lower bound (e.g. start of code fence or 1)
---@param max_line? integer Upper bound (e.g. end of code fence or total buffer lines)
---@return integer start_line, integer end_line, string[] lines
function M.get_logical_command_range(bufnr, cursor_line, lang, min_line, max_line)
  min_line = min_line or 1
  max_line = max_line or vim.api.nvim_buf_line_count(bufnr)

  if cursor_line < min_line or cursor_line > max_line then
    return cursor_line, cursor_line, {}
  end

  -- Find beginning of this logical command by walking upwards if previous lines continued into this one
  local cmd_start = cursor_line
  while cmd_start > min_line do
    local prev_lines = utils.get_buf_lines(bufnr, cmd_start - 1, cmd_start - 1)
    if #prev_lines > 0 and sanitizer.is_line_continued(prev_lines[1], lang) then
      cmd_start = cmd_start - 1
    else
      break
    end
  end

  -- Find end of this logical command by walking downwards while lines are continued
  local cmd_end = cursor_line
  while cmd_end <= max_line do
    local cur_lines = utils.get_buf_lines(bufnr, cmd_end, cmd_end)
    if #cur_lines > 0 and sanitizer.is_line_continued(cur_lines[1], lang) then
      cmd_end = cmd_end + 1
    else
      break
    end
  end

  cmd_end = math.min(cmd_end, max_line)
  local lines = utils.get_buf_lines(bufnr, cmd_start, cmd_end)
  return cmd_start, cmd_end, lines
end

return M
