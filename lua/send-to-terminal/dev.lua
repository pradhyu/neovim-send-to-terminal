local utils = require("send-to-terminal.utils")

local M = {}

---Hot-reload all loaded modules of send-to-terminal
---@param verbose? boolean
---@return integer count Number of reloaded modules
function M.reload(verbose)
  local count = 0
  for pkg, _ in pairs(package.loaded) do
    if pkg:match("^send%-to%-terminal") then
      package.loaded[pkg] = nil
      count = count + 1
      if verbose then
        print(string.format("[send-to-terminal] Unloaded module: %s", pkg))
      end
    end
  end

  local ok, stt = pcall(require, "send-to-terminal")
  if ok then
    stt.setup()
    utils.notify(string.format("Hot-reloaded %d send-to-terminal modules successfully!", count))
  else
    vim.notify(string.format("[send-to-terminal] Reload error: %s", tostring(stt)), vim.log.levels.ERROR)
  end

  return count
end

return M
