-- Add repo root to package.path and runtimepath
local cwd = vim.fn.getcwd()
package.path = cwd .. "/lua/?.lua;" .. cwd .. "/lua/?/init.lua;" .. cwd .. "/?.lua;" .. package.path
vim.opt.runtimepath:append(cwd)

local T = require("tests.test_helpers")

require("tests.sanitizer_spec")
require("tests.markdown_spec")
require("tests.stepper_and_backend_spec")
require("tests.shell_detection_and_selection_spec")
require("tests.history_spec")

print("\n==========================================")
print(string.format("Test Summary: %d passed, %d failed", T.passed, T.failed))
print("==========================================\n")

if T.failed > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("qall!")
end
