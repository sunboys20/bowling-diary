<#
  Bowling diary site on server2 (static files only, port 8892).
  Run ON server2 in an admin PowerShell:
    powershell -ExecutionPolicy Bypass -File C:\workspace\bowling-diary\tools\setup_server2.ps1          # show plan only
    powershell -ExecutionPolicy Bypass -File C:\workspace\bowling-diary\tools\setup_server2.ps1 -Apply   # do it
  Later updates: git -C C:\workspace\bowling-diary pull   (no Apache restart needed)
#>
param(
  [switch]$Apply,
  [int]$Port = 8892,
  [string]$SitePath = 'C:\workspace\bowling-diary',
  [string]$Repo = 'https://github.com/sunboys20/bowling-diary.git',
  [string]$ApacheConf = 'C:\xampp\apache\conf\httpd.conf'
)
$ErrorActionPreference = 'Stop'
function Step($t) { Write-Host "`n== $t" -ForegroundColor Cyan }
function Ok($t)   { Write-Host "  OK   $t" -ForegroundColor Green }
function Plan($t) { Write-Host "  PLAN $t" -ForegroundColor Yellow }

Step "1. Is this server2?"
if ($env:COMPUTERNAME -ne 'server2') { Write-Host "  This PC is '$env:COMPUTERNAME'. Run this only on server2." -ForegroundColor Red; exit 1 }
Ok "server2"

Step "2. Get the app files ($SitePath)"
if (Test-Path (Join-Path $SitePath '.git')) {
  if ($Apply) { git -C $SitePath pull --ff-only; Ok "pulled latest" } else { Plan "git -C $SitePath pull --ff-only" }
} elseif (Test-Path $SitePath) {
  Write-Host "  $SitePath exists but is not a git folder. Move it away first." -ForegroundColor Red; exit 1
} else {
  if ($Apply) { git clone $Repo $SitePath; Ok "cloned" } else { Plan "git clone $Repo $SitePath" }
}

Step "3. Apache: add port $Port"
$sp = $SitePath -replace '\\', '/'
$vhost = @"

# ===== Bowling diary site ($Port) - bowling-diary\tools\setup_server2.ps1 =====
Listen $Port
<VirtualHost *:$Port>
    DocumentRoot "$sp"
    <Directory "$sp">
        Options -Indexes
        AllowOverride None
        Require all granted
    </Directory>
    # static files only: never run PHP here, never serve the git folder or tools
    php_admin_flag engine off
    <LocationMatch "^/(\.git|tools)(/|$)">
        Require all denied
    </LocationMatch>
    <Files "sw.js">
        Header set Cache-Control "no-cache"
    </Files>
    ErrorLog "logs/bowling-error.log"
</VirtualHost>
# ===== Bowling diary site end =====
"@
$conf = Get-Content $ApacheConf -Raw
if ($conf -match "(?m)^\s*Listen\s+$Port\s*$") { Ok "httpd.conf already has Listen $Port (not added)" }
elseif ($Apply) {
  $bak = "$ApacheConf.before_bowling_$(Get-Date -Format yyyyMMdd_HHmmss)"
  Copy-Item $ApacheConf $bak; Ok "backup: $bak"
  Add-Content -Path $ApacheConf -Value $vhost; Ok "added to the end of httpd.conf"
}
else { Plan "append to the end of httpd.conf (after a backup):"; Write-Host $vhost -ForegroundColor DarkGray }
if ($conf -notmatch "(?m)^\s*LoadModule\s+headers_module") { Write-Host "  NOTE mod_headers is off: remove the <Files sw.js> block or enable headers_module" -ForegroundColor Yellow }

Step "4. Then"
Write-Host @"
  1) C:\xampp\apache\bin\httpd.exe -t                (Syntax OK)
  2) XAMPP Control Panel -> Apache Stop / Start
  3) check ERP first:  http://localhost:8888/login.php , http://localhost:8889/login.php
  4) check bowling:    http://localhost:$Port/
  5) office PCs:       New-NetFirewallRule -DisplayName "Bowling $Port" -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow
  6) from outside (only if wanted): iptime router -> port forward $Port -> 192.168.0.15:$Port
"@
