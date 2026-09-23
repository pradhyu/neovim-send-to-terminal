local M = {}

M.passed = 0
M.failed = 0

function M.assert_eq(actual, expected, message)
  if vim.deep_equal(actual, expected) then
    M.passed = M.passed + 1
  else
    M.failed = M.failed + 1
    local err_msg = string.format("FAIL: %s\n  Expected: %s\n  Actual:   %s",
      message or "Assertion failed",
      vim.inspect(expected),
      vim.inspect(actual))
    print(err_msg)
    error(err_msg)
  end
end

function M.assert_true(val, message)
  M.assert_eq(val, true, message)
end

function M.assert_false(val, message)
  M.assert_eq(val, false, message)
end

function M.assert_not_nil(val, message)
  M.assert_true(val ~= nil, message or "Expected value to not be nil")
end

function M.run_test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    print(string.format("  ✓ %s", name))
  else
    print(string.format("  ✗ %s\n    %s", name, tostring(err)))
  end
end

return M
