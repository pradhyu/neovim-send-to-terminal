# 🌐 Polyglot Multi-Shell Demo

This document demonstrates how `neovim-send-to-terminal` automatically detects the language of each code fence and routes commands to the corresponding terminal buffer (`powershell` -> `pwsh`, `bash` -> `bash`, `python` -> `python3`, `lua` -> `lua`).

---

## 1. PowerShell Code Block

Cursor inside the block below will route to your **PowerShell** terminal session:

```powershell
Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$PSVersionTable.PSVersion
```

---

## 2. Bash / Zsh Code Block

Cursor inside the block below will route to your **Bash/Zsh** terminal session:

```bash
echo "System Hostname: $(hostname)"
echo "Active User: $(whoami)"
```

---

## 3. Python Code Block

Cursor inside the block below will route to your **Python** terminal session:

```python
import platform
print(f"Running on Python {platform.python_version()}")
```

---

## 4. Lua Code Block

Cursor inside the block below will route to your **Lua** terminal session:

```lua
local info = { name = "send-to-terminal", lang = "lua" }
print("Lua version: " .. _VERSION .. " - Plugin: " .. info.name)
```
