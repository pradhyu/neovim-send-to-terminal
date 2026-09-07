local T = require("tests.test_helpers")
local neovim_backend = require("send-to-terminal.backends.neovim")
local state = require("send-to-terminal.state")
local stt = require("send-to-terminal")
local config = require("send-to-terminal.config")

config.setup()
state.reset()

print("\n--- Running Shell Detection & Selection Tests ---")

T.run_test("Detect Shell Type from Title & Name", function()
  -- Create a real terminal channel in headless Neovim
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.b[bufnr].term_title = "pwsh 7.4"

  T.assert_eq(neovim_backend.detect_shell_type(bufnr), "powershell", "Should detect pwsh from term_title")

  vim.b[bufnr].term_title = "/bin/bash -l"
  T.assert_eq(neovim_backend.detect_shell_type(bufnr), "bash", "Should detect /bin/bash from term_title")

  vim.b[bufnr].term_title = "python3"
  T.assert_eq(neovim_backend.detect_shell_type(bufnr), "python", "Should detect python3 from term_title")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

T.run_test("Multiple Matching Terminals & State Selection Caching", function()
  state.reset()

  -- Create two test buffers
  local buf1 = vim.api.nvim_create_buf(false, true)
  local buf2 = vim.api.nvim_create_buf(false, true)

  -- Test state caching and retrieval
  state.set_target_buffer("powershell", buf2)
  T.assert_eq(state.target_buffers["powershell"], buf2, "Target buffer in state should be buf2")

  -- Reset target
  stt.reset_target("powershell")
  T.assert_eq(state.target_buffers["powershell"], nil, "Target buffer should be reset to nil")

  -- Clean up
  vim.api.nvim_buf_delete(buf1, { force = true })
  vim.api.nvim_buf_delete(buf2, { force = true })
end)

T.run_test("Dynamic Shell Switching (set_default_shell)", function()
  state.reset()
  config.setup()

  T.assert_eq(state.get_shell("bash"), "bash", "Initial bash shell should be bash")

  stt.set_default_shell("bash", "zsh")
  T.assert_eq(state.get_shell("bash"), "zsh", "Updated bash shell should be zsh")

  stt.set_default_shell("powershell", "pwsh-preview")
  T.assert_eq(state.get_shell("powershell"), "pwsh-preview", "Updated powershell shell should be pwsh-preview")

  state.reset()
end)
