local M = {}

---Trim whitespace from ends of string
---@param s string
---@return string
function M.trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

---Trim trailing whitespace only
---@param s string
---@return string
function M.rtrim(s)
  return (s:gsub("%s+$", ""))
end

---Split string by lines
---@param text string
---@return string[]
function M.split_lines(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    table.insert(lines, line)
  end
  if #lines > 0 and lines[#lines] == "" then
    table.remove(lines)
  end
  return lines
end

---Check if a string is empty or blank
---@param s string
---@return boolean
function M.is_blank(s)
  return s:match("^%s*$") ~= nil
end

---Get filetype of current buffer or fallback
---@param bufnr? integer
---@return string
function M.get_filetype(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.bo[bufnr].filetype or ""
end

---Get lines from buffer (1-indexed inclusive)
---@param bufnr integer
---@param start_line integer
---@param end_line integer
---@return string[]
function M.get_buf_lines(bufnr, start_line, end_line)
  return vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
end

---Normalize language names from code fences (e.g., 'ps1' -> 'powershell', 'shell' -> 'sh', 'py' -> 'python')
---@param lang string
---@return string
function M.normalize_lang(lang)
  lang = (lang or ""):lower():match("^%s*([^%s{]+)") or ""
  local aliases = {
    ["powershell"] = "powershell",
    ["pwsh"] = "powershell",
    ["ps1"] = "powershell",
    ["posh"] = "powershell",
    ["bash"] = "bash",
    ["sh"] = "sh",
    ["zsh"] = "zsh",
    ["fish"] = "fish",
    ["py"] = "python",
    ["python"] = "python",
    ["python3"] = "python",
    ["ipython"] = "python",
    ["rb"] = "ruby",
    ["ruby"] = "ruby",
    ["js"] = "javascript",
    ["javascript"] = "javascript",
    ["ts"] = "typescript",
    ["typescript"] = "typescript",
    ["lua"] = "lua",
    ["r"] = "r",
    ["jl"] = "julia",
    ["julia"] = "julia",
  }
  return aliases[lang] or lang
end

---Check if Treesitter is available and has a parser for the buffer
---@param bufnr? integer
---@return boolean
function M.has_treesitter(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  return ok and parser ~= nil
end

---Get Treesitter node at cursor
---@param bufnr? integer
---@param winnr? integer
---@return TSNode|nil
function M.get_node_at_cursor(bufnr, winnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  winnr = winnr or vim.api.nvim_get_current_win()
  if not M.has_treesitter(bufnr) then
    return nil
  end

  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local row = cursor[1] - 1
  local col = cursor[2]

  local ok, node = pcall(vim.treesitter.get_node, {
    bufnr = bufnr,
    pos = { row, col },
    ignore_injections = false,
  })

  if ok and node then
    return node
  end
  return nil
end

---Notify user with standard plugin prefix
---@param msg string
---@param level? integer
function M.notify(msg, level)
  level = level or vim.log.levels.INFO
  vim.notify(string.format("[send-to-terminal] %s", msg), level)
end

return M
