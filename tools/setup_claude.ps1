# New-computer setup for bowling-diary (run once per computer).
#   powershell -ExecutionPolicy Bypass -File C:\workspace\bowling-diary\tools\setup_claude.ps1
# 1) commit e-mail = GitHub noreply address (public repo)
# 2) add the "continue bowling" note (tools/claude-global.md) to ~/.claude/CLAUDE.md
# Safe to run again: it replaces the old block instead of adding a second one.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

git -C $repo config user.email 273581171+sunboys20@users.noreply.github.com
Write-Host "commit e-mail: $(git -C $repo config user.email)"

$snippet = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'claude-global.md'), [Text.Encoding]::UTF8).Trim()
$dir = Join-Path $HOME '.claude'
$file = Join-Path $dir 'CLAUDE.md'
New-Item -ItemType Directory -Force $dir | Out-Null
$old = ''
if (Test-Path $file) { $old = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8) }
$pattern = '(?s)<!-- bowling-diary:start -->.*?<!-- bowling-diary:end -->'
if ($old -match $pattern) {
  $new = [regex]::Replace($old, $pattern, { param($m) $snippet })
} elseif ($old.Trim()) {
  $new = $old.TrimEnd() + "`r`n`r`n" + $snippet + "`r`n"
} else {
  $new = $snippet + "`r`n"
}
[IO.File]::WriteAllText($file, $new, (New-Object Text.UTF8Encoding($false)))
Write-Host "updated: $file"
