local utils = require("send-to-terminal.utils")
local config = require("send-to-terminal.config")

local M = {}

---Get prompt patterns for a given language
---@param lang string
---@param opts? STTOptions
---@return string[]
function M.get_prompt_patterns(lang, opts)
  opts = opts or config.get()
  local patterns = {}
  local lang_norm = utils.normalize_lang(lang)

  if opts.prompt_patterns then
    if opts.prompt_patterns[lang_norm] then
      for _, p in ipairs(opts.prompt_patterns[lang_norm]) do
        table.insert(patterns, p)
      end
    end
    if opts.prompt_patterns[lang] and lang ~= lang_norm then
      for _, p in ipairs(opts.prompt_patterns[lang]) do
        table.insert(patterns, p)
      end
    end
  end

  -- Default fallback patterns if none found for language
  if #patterns == 0 then
    -- Generic shell & powershell & repl prompts
    patterns = {
      "^%s*>>>%s?",                     -- >>> python prompt
      "^%s*%.%.%.%s?",                  -- ... python continuation
      "^%s*In%s*%[%d+%]:%s?",           -- In [1]: ipython prompt
      "^%s*%[PS%]%s*[^>]*>%s?",         -- [PS] C:\...>
      "^%s*PS%s*[^>]*>%s?",             -- PS C:\...> or PS>
      "^%s*%$%s?",                      -- $ command
      "^%s*❯%s?",                      -- ❯ command
      "^%s*>>%s?",                      -- >> continuation prompt
      "^%s*>%s?",                       -- > general prompt
    }
  end

  return patterns
end

---Get continuation characters/patterns for a language
---@param lang string
---@param opts? STTOptions
---@return string[]
function M.get_continuation_chars(lang, opts)
  opts = opts or config.get()
  local lang_norm = utils.normalize_lang(lang)
  local chars = {}

  if opts.continuation_chars then
    if opts.continuation_chars[lang_norm] then
      for _, c in ipairs(opts.continuation_chars[lang_norm]) do
        table.insert(chars, c)
      end
    end
    if opts.continuation_chars[lang] and lang ~= lang_norm then
      for _, c in ipairs(opts.continuation_chars[lang]) do
        table.insert(chars, c)
      end
    end
  end

  if #chars == 0 then
    if lang_norm == "powershell" then
      chars = { "`", "\\" }
    else
      chars = { "\\" }
    end
  end

  return chars
end

---Check if a line ends with a continuation character (e.g. \ or `) or continuation operator
---@param line string
---@param lang string
---@param opts? STTOptions
---@return boolean
function M.is_line_continued(line, lang, opts)
  local rtrimmed = utils.rtrim(line)
  if rtrimmed == "" then
    return false
  end

  local chars = M.get_continuation_chars(lang, opts)
  for _, char in ipairs(chars) do
    if char == "\\" and rtrimmed:match("\\$") then
      return true
    elseif char == "`" and rtrimmed:match("`$") then
      return true
    end
  end

  local lang_norm = utils.normalize_lang(lang)
  if lang_norm == "powershell" then
    -- PowerShell trailing pipe or logical operators
    if rtrimmed:match("|%s*$") or rtrimmed:match("&&%s*$") or rtrimmed:match("||%s*$")
       or rtrimmed:match("%-and%s*$") or rtrimmed:match("%-or%s*$") or rtrimmed:match(",%s*$") then
      return true
    end
  elseif lang_norm == "bash" or lang_norm == "sh" or lang_norm == "zsh" then
    -- Shell trailing pipe or logical operators
    if rtrimmed:match("|%s*$") or rtrimmed:match("&&%s*$") or rtrimmed:match("||%s*$") then
      return true
    end
  end

  return false
end

---Check if a line matches any prompt pattern
---@param line string
---@param patterns string[]
---@return boolean has_prompt, string stripped_line
function M.match_and_strip_prompt(line, patterns)
  for _, pattern in ipairs(patterns) do
    if line:match(pattern) then
      local stripped = line:gsub(pattern, "", 1)
      return true, stripped
    end
  end
  return false, line
end

---Check if a line is a comment in the given language
---@param line string
---@param lang string
---@return boolean
function M.is_comment_line(line, lang)
  local trimmed = utils.trim(line)
  local lang_norm = utils.normalize_lang(lang)

  if lang_norm == "powershell" or lang_norm == "bash" or lang_norm == "sh"
     or lang_norm == "zsh" or lang_norm == "python" or lang_norm == "r"
     or lang_norm == "ruby" or lang_norm == "julia" then
    return trimmed:sub(1, 1) == "#"
  elseif lang_norm == "lua" or lang_norm == "sql" then
    return trimmed:sub(1, 2) == "--"
  elseif lang_norm == "javascript" or lang_norm == "typescript" or lang_norm == "c" or lang_norm == "cpp" then
    return trimmed:sub(1, 2) == "//"
  end

  return trimmed:sub(1, 1) == "#"
end

---Sanitize and filter lines from a code block or visual selection
---@param raw_lines string[]
---@param lang string
---@param opts? STTOptions
---@return string[]
function M.sanitize_lines(raw_lines, lang, opts)
  opts = opts or config.get()
  if not raw_lines or #raw_lines == 0 then
    return {}
  end

  local patterns = M.get_prompt_patterns(lang, opts)
  local strip_prompts = opts.markdown.strip_prompts
  local filter_output = opts.markdown.filter_output_lines
  local strip_comments = opts.markdown.strip_comments

  -- Step 1: Check if ANY line contains a prompt
  local any_has_prompt = false
  for _, line in ipairs(raw_lines) do
    local has_prompt, _ = M.match_and_strip_prompt(line, patterns)
    if has_prompt then
      any_has_prompt = true
      break
    end
  end

  local cleaned = {}
  local in_continuation = false

  for _, line in ipairs(raw_lines) do
    local has_prompt = false
    local content = line

    if strip_prompts then
      has_prompt, content = M.match_and_strip_prompt(line, patterns)
    end

    if strip_comments and M.is_comment_line(content, lang) then
      -- Skip comment lines if configured
      goto continue
    end

    -- If filter_output is enabled and prompts were present in the block:
    if filter_output and any_has_prompt then
      if has_prompt or in_continuation then
        table.insert(cleaned, content)
        in_continuation = M.is_line_continued(content, lang, opts)
      else
        -- Line has no prompt and is not continuation -> Treated as output line, ignored!
      end
    else
      -- Regular line or block with no prompts at all
      table.insert(cleaned, content)
      in_continuation = M.is_line_continued(content, lang, opts)
    end

    ::continue::
  end

  return cleaned
end

---Wrap text in bracketed paste mode escape sequences
---@param text string
---@return string
function M.wrap_bracketed_paste(text)
  -- Bracketed paste: \27[200~ <text> \27[201~
  return string.format("\27[200~%s\27[201~", text)
end

---Format final payload for sending to terminal backend
---@param lines string[]
---@param opts? STTOptions
---@return string
function M.format_payload(lines, opts)
  opts = opts or config.get()
  if #lines == 0 then
    return ""
  end

  local text = table.concat(lines, "\n")

  if opts.bracketed_paste then
    text = M.wrap_bracketed_paste(text)
  end

  if opts.auto_newline then
    text = text .. "\n"
  end

  return text
end

return M
