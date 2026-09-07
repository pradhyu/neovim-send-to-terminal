if vim.g.loaded_send_to_terminal == 1 then
  return
end
vim.g.loaded_send_to_terminal = 1

local stt = require("send-to-terminal")

local subcommands = {
  line = function(args) stt.send_line() end,
  block = function(args) stt.send_block() end,
  visual = function(args) stt.send_visual() end,
  step = function(args) stt.send_step() end,
  file = function(args) stt.send_file() end,
  motion = function(args) stt.send_motion() end,
  select = function(args) stt.select_terminal(args[2]) end,
  select_terminal = function(args) stt.select_terminal(args[2]) end,
  reset = function(args) stt.reset_target(args[2]) end,
  reset_target = function(args) stt.reset_target(args[2]) end,
  set_shell = function(args)
    if #args < 3 then
      vim.notify("[send-to-terminal] Usage: :SendToTerminal set_shell <lang> <shell_cmd>", vim.log.levels.WARN)
      return
    end
    stt.set_default_shell(args[2], args[3])
  end,
  history = function(args) stt.show_history() end,
  last = function(args) stt.show_last_output() end,
  show_last = function(args) stt.show_last_output() end,
  copy_output = function(args) stt.copy_last_output() end,
  copy_command = function(args) stt.copy_last_command() end,
  paste_output = function(args) stt.paste_last_output() end,
  clear_history = function(args) stt.clear_history() end,
}

vim.api.nvim_create_user_command("SendToTerminal", function(opts)
  local arg = opts.fargs[1] or "line"
  local handler = subcommands[arg]
  if handler then
    handler(opts.fargs)
  else
    vim.notify(string.format("[send-to-terminal] Unknown subcommand: %s", arg), vim.log.levels.ERROR)
  end
end, {
  nargs = "*",
  range = true,
  complete = function(arg_lead, cmd_line, cursor_pos)
    local parts = vim.split(cmd_line, "%s+")
    if #parts <= 2 then
      local items = {
        "line", "block", "visual", "step", "file", "motion",
        "select", "set_shell", "reset",
        "history", "last", "show_last", "copy_output", "copy_command", "paste_output", "clear_history",
      }
      local matches = {}
      for _, item in ipairs(items) do
        if item:find("^" .. arg_lead) then
          table.insert(matches, item)
        end
      end
      return matches
    elseif #parts == 3 and (parts[2] == "select" or parts[2] == "set_shell" or parts[2] == "reset") then
      local langs = { "powershell", "pwsh", "bash", "sh", "zsh", "fish", "python" }
      local matches = {}
      for _, l in ipairs(langs) do
        if l:find("^" .. arg_lead) then
          table.insert(matches, l)
        end
      end
      return matches
    end
    return {}
  end,
  desc = "Send code snippets, manage terminal targets, or inspect execution history",
})
