local T = require("tests.test_helpers")
local history = require("send-to-terminal.core.history")
local stt = require("send-to-terminal")
local config = require("send-to-terminal.config")
local backends = require("send-to-terminal.backends")

print("\n--- Running History & Output Capture Tests ---")

T.run_test("Strip ANSI Escape Sequences & Carriage Returns", function()
  local colored = "\27[32m[SUCCESS]\27[0m Process completed.\r\n"
  local cleaned = history.strip_ansi(colored)
  T.assert_eq(cleaned, "[SUCCESS] Process completed.\n", "Should strip ANSI color codes and carriage returns")
end)

T.run_test("Format Commented Output with Language Prefixes", function()
  -- PowerShell output formatting
  local ps_output = "Handles  NPM(K)  ProcessName\n-------  ------  -----------\n    658      41  pwsh"
  local ps_commented = history.format_commented_output(ps_output, "powershell")
  T.assert_eq(ps_commented, {
    "# Handles  NPM(K)  ProcessName",
    "# -------  ------  -----------",
    "#     658      41  pwsh",
  }, "Should prefix powershell output lines with # ")

  -- Lua output formatting
  local lua_output = "result = 42\ntrue"
  local lua_commented = history.format_commented_output(lua_output, "lua")
  T.assert_eq(lua_commented, {
    "-- result = 42",
    "-- true",
  }, "Should prefix lua output lines with -- ")

  -- Strip command echo from terminal stream if present
  local echoed_output = "Get-Process pwsh\nHandles  ProcessName\n    658  pwsh"
  local stripped_echo = history.format_commented_output(echoed_output, "powershell", "Get-Process pwsh")
  T.assert_eq(stripped_echo, {
    "# Handles  ProcessName",
    "#     658  pwsh",
  }, "Should strip command echo from first line of output")
end)

T.run_test("Paste Commented Output into Buffer Below Command", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].filetype = "markdown"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "```powershell",
    "PS C:\\> Get-Service sshd",
    "```",
    "",
    "Next section...",
  })

  local output = "Status   Name               DisplayName\n------   ----               -----------\nRunning  sshd               OpenSSH SSH Server"
  local ok = history.paste_commented_output_to_buffer(bufnr, 2, output, "powershell", "Get-Service sshd")
  T.assert_true(ok, "Should succeed pasting output to buffer")

  local new_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  T.assert_eq(new_lines, {
    "```powershell",
    "PS C:\\> Get-Service sshd",
    "# Status   Name               DisplayName",
    "# ------   ----               -----------",
    "# Running  sshd               OpenSSH SSH Server",
    "```",
    "",
    "Next section...",
  }, "Should insert commented output lines right below the command inside markdown code block")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

T.run_test("History Entry Creation & Metadata Recording", function()
  history.clear()
  local entry = history.add_entry({
    file = "/home/user/docs/setup.md",
    line_start = 12,
    line_end = 15,
    lang = "powershell",
    command = "Get-ChildItem -Recurse",
  })

  T.assert_true(entry ~= nil, "Should create history entry")
  T.assert_eq(entry.file, "/home/user/docs/setup.md", "Should record file name")
  T.assert_eq(entry.line_start, 12, "Should record start line")
  T.assert_eq(entry.line_end, 15, "Should record end line")
  T.assert_eq(entry.lang, "powershell", "Should record language")
  T.assert_eq(entry.command, "Get-ChildItem -Recurse", "Should record exact command")
  T.assert_eq(entry.status, "running", "Initial status should be running")

  -- Update output
  history.update_output(entry.id, "\27[33mDirectory: /home/user\27[0m")
  T.assert_eq(entry.output, "Directory: /home/user", "Output should be updated and cleaned")
  T.assert_eq(entry.status, "completed", "Status should transition to completed")

  local last = history.get_last_entry()
  T.assert_eq(last.id, entry.id, "get_last_entry should return latest entry")
end)

T.run_test("Clipboard Copying of Outcome & Command", function()
  history.clear()
  local entry = history.add_entry({
    file = "/tmp/test.sh",
    line_start = 1,
    line_end = 1,
    lang = "bash",
    command = "echo 'Hello World'",
  })
  history.update_output(entry.id, "Hello World\n", { history = { copy_output_to_clipboard = false } })

  -- Test copy output
  history.copy_last_output()
  T.assert_eq(vim.fn.getreg("+"), "Hello World", "Clipboard '+' should contain last outcome")

  -- Test copy command
  history.copy_last_command()
  T.assert_eq(vim.fn.getreg("+"), "echo 'Hello World'", "Clipboard '+' should contain last command")
end)

T.run_test("History Max Entries Limit", function()
  history.clear()
  config.setup({
    history = {
      enabled = true,
      max_entries = 3,
      copy_output_to_clipboard = false,
    },
  })

  for i = 1, 5 do
    history.add_entry({
      file = "test.md",
      command = "cmd " .. tostring(i),
    })
  end

  T.assert_eq(#history.entries, 3, "History entries should be capped at max_entries (3)")
  T.assert_eq(history.entries[1].command, "cmd 5", "First entry in queue should be most recent")
  T.assert_eq(history.entries[3].command, "cmd 3", "Oldest kept entry should be cmd 3")
end)

T.run_test("End-to-End Execution Flow with History Logging", function()
  history.clear()
  local captured_text = nil

  backends.register("hist_mock", {
    is_available = function() return true end,
    send = function(text, opts, lang, on_done, entry_id)
      captured_text = text
      if on_done then on_done(true) end
      return true
    end,
  })

  config.setup({
    backend = "hist_mock",
    bracketed_paste = false,
    auto_newline = false,
    history = {
      enabled = true,
      copy_output_to_clipboard = false,
    },
  })

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].filetype = "markdown"
  vim.api.nvim_buf_set_name(bufnr, "/home/user/workspace/README.md")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "```powershell",
    "PS C:\\> Stop-Process -Name pwsh",
    "```",
  })
  local winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_win_set_cursor(winnr, { 2, 5 })

  stt.send_line()

  local last = history.get_last_entry()
  T.assert_true(last ~= nil, "Should record history on send_line")
  T.assert_eq(last.file, "/home/user/workspace/README.md", "Should record source markdown path")
  T.assert_eq(last.command, "Stop-Process -Name pwsh", "Should record clean command")
  T.assert_eq(last.lang, "powershell", "Should record language as powershell")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)
