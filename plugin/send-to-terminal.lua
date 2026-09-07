if vim.g.loaded_send_to_terminal == 1 then
  return
end
vim.g.loaded_send_to_terminal = 1

local subcommands = {
  line = function() require("send-to-terminal").send_line() end,
  block = function() require("send-to-terminal").send_block() end,
  visual = function() require("send-to-terminal").send_visual() end,
  step = function() require("send-to-terminal").send_step() end,
  file = function() require("send-to-terminal").send_file() end,
  motion = function() require("send-to-terminal").send_motion() end,
}

vim.api.nvim_create_user_command("SendToTerminal", function(opts)
  local arg = opts.fargs[1] or "line"
  local handler = subcommands[arg]
  if handler then
    handler()
  else
    vim.notify(string.format("[send-to-terminal] Unknown subcommand: %s", arg), vim.log.levels.ERROR)
  end
end, {
  nargs = "?",
  range = true,
  complete = function(arg_lead, cmd_line, cursor_pos)
    local items = { "line", "block", "visual", "step", "file", "motion" }
    local matches = {}
    for _, item in ipairs(items) do
      if item:find("^" .. arg_lead) then
        table.insert(matches, item)
      end
    end
    return matches
  end,
  desc = "Send code snippets or commands to terminal",
})
