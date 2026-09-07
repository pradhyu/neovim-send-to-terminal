local T = require("tests.test_helpers")
local sanitizer = require("send-to-terminal.core.sanitizer")
local config = require("send-to-terminal.config")

config.setup()

print("\n--- Running Sanitizer & Multi-line Tests ---")

T.run_test("POSIX Prompt Stripping ($)", function()
  local input = { "$ npm install", "$ npm start" }
  local output = sanitizer.sanitize_lines(input, "sh")
  T.assert_eq(output, { "npm install", "npm start" }, "Should strip $ prompts")
end)

T.run_test("PowerShell Prompt Stripping (PS C:\\> and >>)", function()
  local input = { "PS C:\\Users\\user> Get-Service", "PS /home/user> Stop-Process -Name pwsh", ">> Write-Host 'done'" }
  local output = sanitizer.sanitize_lines(input, "powershell")
  T.assert_eq(output, { "Get-Service", "Stop-Process -Name pwsh", "Write-Host 'done'" }, "Should strip PS prompts")
end)

T.run_test("Python Prompt Stripping (>>> and ...)", function()
  local input = { ">>> def hello():", "...     return 'world'", ">>> hello()" }
  local output = sanitizer.sanitize_lines(input, "python")
  T.assert_eq(output, { "def hello():", "    return 'world'", "hello()" }, "Should strip Python >>> and ... prompts")
end)

T.run_test("Interleaved Output Filtering (Bash)", function()
  local input = {
    "$ git status",
    "On branch main",
    "nothing to commit",
    "$ git pull",
  }
  local output = sanitizer.sanitize_lines(input, "sh")
  T.assert_eq(output, { "git status", "git pull" }, "Should strip command output lines")
end)

T.run_test("Interleaved Output Filtering with Backslash Line Continuation (Bash)", function()
  local input = {
    "$ docker run -d \\",
    "  --name test \\",
    "  nginx:alpine",
    "Status: Downloaded newer image for nginx:alpine",
    "$ docker ps",
  }
  local output = sanitizer.sanitize_lines(input, "bash")
  T.assert_eq(output, {
    "docker run -d \\",
    "  --name test \\",
    "  nginx:alpine",
    "docker ps",
  }, "Should preserve multi-line continuation lines while stripping output")
end)

T.run_test("PowerShell Backtick Line Continuation (`) with Interleaved Output", function()
  local input = {
    "PS C:\\> Get-ChildItem `",
    "    -Path C:\\Projects `",
    "    -Recurse",
    "Directory: C:\\Projects",
    "Mode     Name",
    "----     ----",
    "d----    neovim-send-to-terminal",
    "PS C:\\> Test-Path C:\\Projects",
  }
  local output = sanitizer.sanitize_lines(input, "powershell")
  T.assert_eq(output, {
    "Get-ChildItem `",
    "    -Path C:\\Projects `",
    "    -Recurse",
    "Test-Path C:\\Projects",
  }, "Should preserve PowerShell backtick continuation and strip command output")
end)

T.run_test("PowerShell Trailing Pipe (|) Continuation", function()
  local input = {
    "PS C:\\> Get-Process |",
    "    Where-Object CPU -gt 10",
  }
  local output = sanitizer.sanitize_lines(input, "pwsh")
  T.assert_eq(output, {
    "Get-Process |",
    "    Where-Object CPU -gt 10",
  }, "Should recognize trailing pipe continuation in PowerShell")
end)

T.run_test("Bracketed Paste Mode Wrapping", function()
  local wrapped = sanitizer.wrap_bracketed_paste("hello world")
  T.assert_eq(wrapped, "\27[200~hello world\27[201~", "Should wrap in ESC[200~ ... ESC[201~")
end)

T.run_test("Plain Script without Prompts (Preserves all lines)", function()
  local input = {
    "Write-Output 'Start'",
    "Get-Location",
    "Write-Output 'End'",
  }
  local output = sanitizer.sanitize_lines(input, "powershell")
  T.assert_eq(output, input, "Should keep all lines when no prompts exist")
end)
