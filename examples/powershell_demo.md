# ⚡ PowerShell Interactive Demo

This file demonstrates how `neovim-send-to-terminal` handles **PowerShell** commands, prompts, backtick line continuations, and automated outcome capturing.

---

## 1. Single Command with Prompt Stripping

Place cursor on the line below and press `<leader>ss` (or `:SendToTerminal line`):

```powershell
PS C:\Projects\demo> Get-Host | Select-Object Name, Version
```

*Expected behavior:* The prompt `PS C:\Projects\demo> ` is automatically stripped, sending only `Get-Host | Select-Object Name, Version` to the active `pwsh` terminal. If `paste_output_to_buffer` is enabled, the output is commented and inserted below.

---

## 2. Multi-Line Command with Backtick Continuations (`` ` ``)

Place cursor on line 1 of the command block below and press `<leader>ss` (or step through with `<leader>sn`):

```powershell
Get-ChildItem `
    -Path $HOME `
    -Filter *.json `
    -Recurse `
    -ErrorAction SilentlyContinue | Select-Object -First 5
```

*Expected behavior:* The plugin detects the trailing grave-accent backtick (`` ` ``) line continuation character and executes all 5 lines together as a single unified atomic command.

---

## 3. PowerShell Pipeline Continuations (`|`)

```powershell
Get-Process |
    Where-Object CPU -gt 1 |
    Sort-Object CPU -Descending |
    Select-Object -First 5 ProcessName, Id, CPU
```

---

## 4. PowerShell Here-Strings

```powershell
$config = @"
{
  "name": "neovim-send-to-terminal",
  "version": "1.0.0",
  "features": ["powershell", "bash", "bracketed-paste"]
}
"@
$config | ConvertFrom-Json
```

---

## 5. Documentation with Interleaved Output

Run the entire block below using `<leader>sb` (or `:SendToTerminal block`):

```powershell
PS C:\> Test-Path $HOME
True
PS C:\> $env:SHELL
/bin/bash
PS C:\> Write-Host 'PowerShell is Awesome!' -ForegroundColor Cyan
```

*Expected behavior:* The plugin detects the `PS C:\>` prompts and automatically filters out the output lines (`True`, `/bin/bash`), running only the valid commands!

---

## 6. Inline Code in Prose

You can quickly check active modules by running `Get-Module` or see your current location with `Get-Location`.

*Expected behavior:* Place cursor inside `` `Get-Module` `` or `` `Get-Location` `` and press `<leader>ss` to run just the inline command.
