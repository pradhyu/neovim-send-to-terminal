local utils = require("send-to-terminal.utils")
local config = require("send-to-terminal.config")
local sanitizer = require("send-to-terminal.core.sanitizer")
local markdown = require("send-to-terminal.core.markdown")

local M = {}

---@class STTExtractionResult
---@field text string
---@field raw_lines string[]
---@field sanitized_lines string[]
---@field lang string
---@field is_inline boolean
---@field range STTRange

---@class STTRange
---@field bufnr integer
---@field start_row integer (0-indexed)
---@field start_col integer (0-indexed)
---@field end_row integer (0-indexed)
---@field end_col integer (0-indexed)
---@field start_line integer (1-indexed)
---@field end_line integer (1-indexed)

---Extract line or inline code at cursor
---@param bufnr? integer
---@param winnr? integer
---@param opts? STTOptions
---@return STTExtractionResult|nil
function M.extract_line(bufnr, winnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  winnr = winnr or vim.api.nvim_get_current_win()
  opts = opts or config.get()

  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local cursor_line = cursor[1]
  local filetype = utils.get_filetype(bufnr)
  local is_markdown = (filetype == "markdown" or filetype == "md" or filetype == "pandoc" or filetype == "quarto")

  -- Check for inline backtick code in markdown
  if is_markdown and opts.markdown.prefer_inline then
    local inline = markdown.get_inline_code_at_cursor(bufnr, winnr)
    if inline then
      local patterns = sanitizer.get_prompt_patterns("sh", opts)
      local _, clean_text = sanitizer.match_and_strip_prompt(inline.text, patterns)
      return {
        text = clean_text,
        raw_lines = { inline.text },
        sanitized_lines = { clean_text },
        lang = "sh",
        is_inline = true,
        range = {
          bufnr = bufnr,
          start_row = inline.line_nr - 1,
          start_col = inline.start_col - 1,
          end_row = inline.line_nr - 1,
          end_col = inline.end_col,
          start_line = inline.line_nr,
          end_line = inline.line_nr,
        },
      }
    end
  end

  local lang = filetype
  local min_line = 1
  local max_line = vim.api.nvim_buf_line_count(bufnr)

  if is_markdown then
    local fence = markdown.get_code_fence_at_cursor(bufnr, winnr)
    if fence then
      lang = fence.lang ~= "" and fence.lang or "sh"
      min_line = fence.start_line
      max_line = fence.end_line
    end
  end

  -- Get multi-line continued command (supports \ and `)
  local s_line, e_line, lines = markdown.get_logical_command_range(bufnr, cursor_line, lang, min_line, max_line)
  if #lines == 0 then
    return nil
  end

  local sanitized = sanitizer.sanitize_lines(lines, lang, opts)
  if #sanitized == 0 then
    -- Fallback to raw lines if sanitization emptied everything
    sanitized = lines
  end

  return {
    text = table.concat(sanitized, "\n"),
    raw_lines = lines,
    sanitized_lines = sanitized,
    lang = lang,
    is_inline = false,
    range = {
      bufnr = bufnr,
      start_row = s_line - 1,
      start_col = 0,
      end_row = e_line - 1,
      end_col = -1,
      start_line = s_line,
      end_line = e_line,
    },
  }
end

---Extract enclosing block (Markdown code fence or Treesitter node / paragraph)
---@param bufnr? integer
---@param winnr? integer
---@param opts? STTOptions
---@return STTExtractionResult|nil
function M.extract_block(bufnr, winnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  winnr = winnr or vim.api.nvim_get_current_win()
  opts = opts or config.get()

  local filetype = utils.get_filetype(bufnr)
  local is_markdown = (filetype == "markdown" or filetype == "md" or filetype == "pandoc" or filetype == "quarto")

  if is_markdown then
    local fence = markdown.get_code_fence_at_cursor(bufnr, winnr)
    if fence and #fence.lines > 0 then
      local lang = fence.lang ~= "" and fence.lang or "sh"
      local sanitized = sanitizer.sanitize_lines(fence.lines, lang, opts)
      if #sanitized == 0 then
        sanitized = fence.lines
      end

      return {
        text = table.concat(sanitized, "\n"),
        raw_lines = fence.lines,
        sanitized_lines = sanitized,
        lang = lang,
        is_inline = false,
        range = {
          bufnr = bufnr,
          start_row = fence.start_line - 1,
          start_col = 0,
          end_row = fence.end_line - 1,
          end_col = -1,
          start_line = fence.start_line,
          end_line = fence.end_line,
        },
      }
    end
  end

  -- Try Treesitter block / function / statement
  if utils.has_treesitter(bufnr) then
    local node = utils.get_node_at_cursor(bufnr, winnr)
    while node do
      local type = node:type()
      if type:match("function") or type:match("statement") or type:match("block") or type:match("pipeline") then
        local srow, _, erow, _ = node:range()
        local sline = srow + 1
        local eline = erow + 1
        local lines = utils.get_buf_lines(bufnr, sline, eline)
        local sanitized = sanitizer.sanitize_lines(lines, filetype, opts)

        return {
          text = table.concat(sanitized, "\n"),
          raw_lines = lines,
          sanitized_lines = sanitized,
          lang = filetype,
          is_inline = false,
          range = {
            bufnr = bufnr,
            start_row = srow,
            start_col = 0,
            end_row = erow,
            end_col = -1,
            start_line = sline,
            end_line = eline,
          },
        }
      end
      node = node:parent()
    end
  end

  -- Fallback: Paragraph at cursor
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local cursor_line = cursor[1]
  local total_lines = vim.api.nvim_buf_line_count(bufnr)

  local s_line = cursor_line
  while s_line > 1 do
    local l = utils.get_buf_lines(bufnr, s_line - 1, s_line - 1)[1] or ""
    if utils.is_blank(l) then
      break
    end
    s_line = s_line - 1
  end

  local e_line = cursor_line
  while e_line < total_lines do
    local l = utils.get_buf_lines(bufnr, e_line + 1, e_line + 1)[1] or ""
    if utils.is_blank(l) then
      break
    end
    e_line = e_line + 1
  end

  local lines = utils.get_buf_lines(bufnr, s_line, e_line)
  local sanitized = sanitizer.sanitize_lines(lines, filetype, opts)

  return {
    text = table.concat(sanitized, "\n"),
    raw_lines = lines,
    sanitized_lines = sanitized,
    lang = filetype,
    is_inline = false,
    range = {
      bufnr = bufnr,
      start_row = s_line - 1,
      start_col = 0,
      end_row = e_line - 1,
      end_col = -1,
      start_line = s_line,
      end_line = e_line,
    },
  }
end

---Extract visual selection
---@param bufnr? integer
---@param opts? STTOptions
---@return STTExtractionResult|nil
function M.extract_visual(bufnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  opts = opts or config.get()

  local s_pos = vim.fn.getpos("'<")
  local e_pos = vim.fn.getpos("'>")

  local s_line = s_pos[2]
  local s_col = s_pos[3]
  local e_line = e_pos[2]
  local e_col = e_pos[3]

  if s_line == 0 or e_line == 0 or s_line > e_line then
    return nil
  end

  local lines = utils.get_buf_lines(bufnr, s_line, e_line)
  if #lines == 0 then
    return nil
  end

  -- Determine language
  local filetype = utils.get_filetype(bufnr)
  local lang = filetype

  if filetype == "markdown" or filetype == "md" then
    local fence = markdown.get_code_fence_at_cursor(bufnr)
    if fence and fence.lang ~= "" then
      lang = fence.lang
    else
      lang = "sh"
    end
  end

  -- Adjust character boundaries if not line-wise
  local is_char_wise = (vim.fn.visualmode() == "v")
  if is_char_wise then
    if #lines == 1 then
      lines[1] = lines[1]:sub(s_col, e_col)
    else
      lines[1] = lines[1]:sub(s_col)
      lines[#lines] = lines[#lines]:sub(1, e_col)
    end
  end

  local sanitized = sanitizer.sanitize_lines(lines, lang, opts)
  if #sanitized == 0 then
    sanitized = lines
  end

  return {
    text = table.concat(sanitized, "\n"),
    raw_lines = lines,
    sanitized_lines = sanitized,
    lang = lang,
    is_inline = is_char_wise and (#lines == 1),
    range = {
      bufnr = bufnr,
      start_row = s_line - 1,
      start_col = is_char_wise and (s_col - 1) or 0,
      end_row = e_line - 1,
      end_col = is_char_wise and e_col or -1,
      start_line = s_line,
      end_line = e_line,
    },
  }
end

---Extract entire file
---@param bufnr? integer
---@param opts? STTOptions
---@return STTExtractionResult|nil
function M.extract_file(bufnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  opts = opts or config.get()

  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local lines = utils.get_buf_lines(bufnr, 1, total_lines)
  local lang = utils.get_filetype(bufnr)

  local sanitized = sanitizer.sanitize_lines(lines, lang, opts)
  if #sanitized == 0 then
    sanitized = lines
  end

  return {
    text = table.concat(sanitized, "\n"),
    raw_lines = lines,
    sanitized_lines = sanitized,
    lang = lang,
    is_inline = false,
    range = {
      bufnr = bufnr,
      start_row = 0,
      start_col = 0,
      end_row = total_lines - 1,
      end_col = -1,
      start_line = 1,
      end_line = total_lines,
    },
  }
end

---Find the next executable line/position to advance to for step execution
---@param bufnr integer
---@param current_end_line integer
---@param lang string
---@param opts? STTOptions
---@return integer|nil next_line
function M.find_next_executable_line(bufnr, current_end_line, lang, opts)
  opts = opts or config.get()
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local max_line = total_lines
  local filetype = utils.get_filetype(bufnr)

  if filetype == "markdown" or filetype == "md" then
    local fence = markdown.get_code_fence_at_cursor(bufnr)
    if fence then
      max_line = fence.end_line
    end
  end

  for l = current_end_line + 1, max_line do
    local line_content = utils.get_buf_lines(bufnr, l, l)[1] or ""
    local trimmed = utils.trim(line_content)

    -- Skip blank lines
    if not utils.is_blank(trimmed) then
      -- Skip comment lines if configured to strip comments
      if not (opts.markdown.strip_comments and sanitizer.is_comment_line(trimmed, lang)) then
        return l
      end
    end
  end

  return nil
end

return M
