local T = require("tests.test_helpers")
local markdown = require("send-to-terminal.core.markdown")
local extractor = require("send-to-terminal.core.extractor")
local config = require("send-to-terminal.config")

config.setup()

print("\n--- Running Markdown & Extractor Tests ---")

T.run_test("Inline Backtick Detection at Cursor", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].filetype = "markdown"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "To build the project, run `cargo build --release` and check results.",
  })
  local winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winnr, bufnr)

  -- Place cursor on column 30 (inside `cargo build --release`)
  vim.api.nvim_win_set_cursor(winnr, { 1, 30 })

  local inline = markdown.get_inline_code_at_cursor(bufnr, winnr)
  T.assert_true(inline ~= nil, "Should find inline code at cursor")
  T.assert_eq(inline.text, "cargo build --release", "Should extract exact inline text")

  local res = extractor.extract_line(bufnr, winnr)
  T.assert_true(res ~= nil, "Extractor should return inline result")
  T.assert_true(res.is_inline, "Should mark as inline")
  T.assert_eq(res.text, "cargo build --release", "Should match extracted command")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

T.run_test("Fenced Code Block Extraction (PowerShell)", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].filetype = "markdown"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "# PowerShell Guide",
    "",
    "```powershell",
    "PS C:\\> Get-ChildItem `",
    "    -Filter *.ps1 `",
    "    -Recurse",
    "PS C:\\> Write-Host 'Done'",
    "```",
    "",
    "More markdown text here.",
  })
  local winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winnr, bufnr)

  -- Place cursor inside code block on line 4 (Get-ChildItem)
  vim.api.nvim_win_set_cursor(winnr, { 4, 5 })

  local fence = markdown.get_code_fence_at_cursor(bufnr, winnr)
  T.assert_true(fence ~= nil, "Should detect code fence")
  T.assert_eq(fence.lang, "powershell", "Should detect powershell language")
  T.assert_eq(fence.start_line, 4, "Start line of content should be 4")
  T.assert_eq(fence.end_line, 7, "End line of content should be 7")

  -- Test extracting current logical command (line 4 with ` continuation across lines 4-6)
  local line_res = extractor.extract_line(bufnr, winnr)
  T.assert_true(line_res ~= nil, "Should extract logical command")
  T.assert_eq(line_res.sanitized_lines, {
    "Get-ChildItem `",
    "    -Filter *.ps1 `",
    "    -Recurse",
  }, "Should extract multi-line backtick continued command as a single unit")

  -- Test extracting entire block
  local block_res = extractor.extract_block(bufnr, winnr)
  T.assert_true(block_res ~= nil, "Should extract block")
  T.assert_eq(block_res.sanitized_lines, {
    "Get-ChildItem `",
    "    -Filter *.ps1 `",
    "    -Recurse",
    "Write-Host 'Done'",
  }, "Should extract entire block stripped of PS prompts")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

T.run_test("Fenced Code Block Extraction with Interleaved Output (Bash)", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].filetype = "markdown"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "```bash",
    "$ git status",
    "On branch main",
    "$ git commit -m 'Initial commit'",
    "[main (root-commit) 1234567] Initial commit",
    "$ git push -u origin main",
    "```",
  })
  local winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_win_set_cursor(winnr, { 2, 2 })

  local block_res = extractor.extract_block(bufnr, winnr)
  T.assert_true(block_res ~= nil, "Should extract block")
  T.assert_eq(block_res.sanitized_lines, {
    "git status",
    "git commit -m 'Initial commit'",
    "git push -u origin main",
  }, "Should extract only commands and filter out all output lines in markdown fence")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)
