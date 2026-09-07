local config = require("send-to-terminal.config")

local M = {}

local ns_id = vim.api.nvim_create_namespace("send_to_terminal_hl")

---Flash highlight a range of lines or characters in buffer
---@param bufnr integer
---@param start_row integer (0-indexed)
---@param start_col integer (0-indexed)
---@param end_row integer (0-indexed)
---@param end_col integer (0-indexed)
---@param opts? STTOptions
function M.flash_range(bufnr, start_row, start_col, end_row, end_col, opts)
  opts = opts or config.get()
  local hl_opts = opts.highlight or {}
  if hl_opts.enabled == false then
    return
  end

  local hl_group = hl_opts.hl_group or "IncSearch"
  local duration = hl_opts.duration or 150

  -- Clear any previous highlights in namespace for this buffer
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  -- Use extmarks for precise highlighting
  for row = start_row, end_row do
    local scol = (row == start_row) and start_col or 0
    local ecol = (row == end_row) and end_col or -1

    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, row, scol, {
      end_row = row,
      end_col = (ecol == -1) and nil or ecol,
      hl_group = hl_group,
      hl_eol = (ecol == -1),
      priority = 200,
    })
  end

  -- Set timer to clear the highlight
  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    end
  end, duration)
end

---Flash highlight lines (1-indexed inclusive)
---@param bufnr integer
---@param start_line integer (1-indexed)
---@param end_line integer (1-indexed)
---@param opts? STTOptions
function M.flash_lines(bufnr, start_line, end_line, opts)
  local start_row = math.max(0, start_line - 1)
  local end_row = math.max(0, end_line - 1)
  M.flash_range(bufnr, start_row, 0, end_row, -1, opts)
end

return M
