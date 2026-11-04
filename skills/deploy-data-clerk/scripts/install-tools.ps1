param(
  [string]$Key = ""
)

$ErrorActionPreference = "Stop"
$SopsVersion = "3.13.3"
$MinSops = [version]"3.9.0"
$Pinned = @{
  "amd64" = "a4a9a398858fe8b2ef72d9686d930bf7c5cece9be74ad83ac3b53cfdd70e6b1c"
  "arm64" = "7f936a0d08edbeba3eb8f50bad1fe71eba83a140a80dfd17051f3bdb4facb08a"
}

function Say($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "!! $m" -ForegroundColor Yellow }
function Die($m) { Write-Host "xx $m" -ForegroundColor Red; exit 1 }

function Get-SopsVersion {
  $cmd = Get-Command sops -ErrorAction SilentlyContinue
  if (-not $cmd) { return $null }
  $out = (& sops --version 2>$null | Select-Object -First 1)
  if ($out -match 'sops (\d+\.\d+\.\d+)') { return [version]$Matches[1] }
  return $null
}

function Install-SopsBinary {
  $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
  $want = $Pinned[$arch]
  $url = "https://github.com/getsops/sops/releases/download/v$SopsVersion/sops-v$SopsVersion.$arch.exe"
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("sops-" + [guid]::NewGuid() + ".exe")
  Say "downloading sops v$SopsVersion ($arch) from github.com/getsops/sops"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $tmp
  $got = (Get-FileHash -Algorithm SHA256 $tmp).Hash.ToLower()
  if ($got -ne $want) {
    Remove-Item $tmp -Force
    Die "checksum mismatch for sops (expected $want, got $got) - not installing"
  }
  Say "checksum verified"
  $dest = Join-Path $env:LOCALAPPDATA "Programs\sops"
  New-Item -ItemType Directory -Force $dest | Out-Null
  Move-Item -Force $tmp (Join-Path $dest "sops.exe")
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if (-not ($userPath -split ';' | Where-Object { $_ -eq $dest })) {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$dest", "User")
    Warn "added $dest to your user PATH - open a new terminal for other windows to see it"
  }
  $env:Path = "$env:Path;$dest"
}

function Ensure-Sops {
  $have = Get-SopsVersion
  if ($have -and $have -ge $MinSops) { Say "sops $have already installed"; return }
  if ($have) { Warn "sops $have is too old (need $MinSops+)" }
  if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Say "installing sops with Scoop"
    if ($have) { scoop update sops } else { scoop install sops }
  } else {
    Install-SopsBinary
  }
  $have = Get-SopsVersion
  if (-not $have -or $have -lt $MinSops) { Die "sops install did not work; see references/setup-tools.md" }
  Say "sops $have ready"
}

function Check-Tool($name, $hint) {
  if (Get-Command $name -ErrorAction SilentlyContinue) { Say "$name found" } else { Warn "$name not found - $hint" }
}

function Install-Key($src) {
  if (-not (Test-Path $src)) { Die "key file not found: $src" }
  $secret = Get-Content $src | Where-Object { $_ -match '^AGE-SECRET-KEY-1[0-9A-Z]+$' } | Select-Object -First 1
  if (-not $secret) { Die "$src does not look like an age key file (no AGE-SECRET-KEY line)" }
  $dest = if ($env:SOPS_AGE_KEY_FILE) { $env:SOPS_AGE_KEY_FILE } else { Join-Path $env:APPDATA "sops\age\keys.txt" }
  New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
  if ((Test-Path $dest) -and (Select-String -Path $dest -SimpleMatch $secret -Quiet)) {
    Say "key already installed in $dest"
  } else {
    $content = (Get-Content $src -Raw) -replace "`r`n", "`n"
    if (Test-Path $dest) { $content = "`n" + $content }
    [IO.File]::AppendAllText($dest, $content)
    Say "key added to $dest"
  }
  $acl = New-Object Security.AccessControl.FileSecurity
  $acl.SetAccessRuleProtection($true, $false)
  $me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
  $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($me, "FullControl", "Allow")))
  Set-Acl -Path $dest -AclObject $acl
  Warn "save a backup of $src in a password manager, then delete the downloaded copy"
}

function Test-Decrypt {
  foreach ($f in @("deploy-data-clerk/secrets.env", "deploy/secrets.env")) {
    if (Test-Path $f) {
      Say "test decrypt of $f (key names only):"
      $names = & sops decrypt $f 2>$null
      if ($LASTEXITCODE -eq 0) {
        $names | ForEach-Object { "    " + ($_ -split '=', 2)[0] }
        Say "secrets are readable - all set"
      } else {
        Warn "could not decrypt $f - is the right key installed? (run again with -Key <file>)"
      }
      return
    }
  }
}

Ensure-Sops
Check-Tool git "install it: scoop install git (or https://git-scm.com)"
Check-Tool gh "optional, to watch deploys: scoop install gh"
if ($Key) { Install-Key $Key }
Test-Decrypt
if (-not $env:EDITOR) { Warn 'for "sops <file>" set an editor: $env:EDITOR = "notepad"' }
