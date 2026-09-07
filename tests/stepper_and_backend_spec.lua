local T = require("tests.test_helpers")
local stt = require("send-to-terminal")
local backends = require("send-to-terminal.backends")
local config = require("send-to-terminal.config")

config.setup()

print("\n--- Running Stepper & Backend Tests ---")

T.run_test("Custom Backend Registration & Payload Delivery", function()
  local last_sent = nil
  backends.register("mock", {
    is_available = function() return true end,
    send = function(text, opts)
      last_sent = text
      return true
    end,
  })

  config.setup({
    backend = "mock",
    bracketed_paste = false,
    auto_newline = false,
  })

  stt.send_text("echo 'hello world'")
  T.assert_eq(last_sent, "echo 'hello world'", "Custom backend should receive text")
end)

T.run_test("Step-through Cursor Advancement (PowerShell multi-line `)", function()
  local last_payload = nil
  backends.register("test_mock", {
    is_available = function() return true end,
    send = function(text, opts)
      last_payload = text
      return true
    end,
  })

  config.setup({
    backend = "test_mock",
    bracketed_paste = false,
    auto_newline = false,
  })

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].filetype = "markdown"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "```powershell",
    "PS C:\\> Write-Host 'Step 1' `",
    "    -ForegroundColor Green",
    "",
    "PS C:\\> Write-Host 'Step 2'",
    "```",
  })
  local winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winnr, bufnr)

  -- Cursor on line 2 (first step with continuation)
  vim.api.nvim_win_set_cursor(winnr, { 2, 0 })

  -- Execute step 1
  stt.send_step()

  T.assert_eq(last_payload, "Write-Host 'Step 1' `\n    -ForegroundColor Green", "Step 1 should send full continued command")

  -- Cursor should have automatically advanced past blank line 4 to line 5 (Write-Host 'Step 2')
  local new_cursor = vim.api.nvim_win_get_cursor(winnr)
  T.assert_eq(new_cursor[1], 5, "Cursor should advance to line 5 for Step 2")

  -- Execute step 2
  stt.send_step()
  T.assert_eq(last_payload, "Write-Host 'Step 2'", "Step 2 should send second command")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)
