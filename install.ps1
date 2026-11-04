$ErrorActionPreference = "Stop"
$Repo = if ($env:DATA_CLERK_SKILLS_REPO) { $env:DATA_CLERK_SKILLS_REPO } else { "Bohdan-Meshcheriakov/data-clerk-skills" }
$Ref = if ($env:DATA_CLERK_SKILLS_REF) { $env:DATA_CLERK_SKILLS_REF } else { "main" }
$Dest = "deploy-data-clerk"
$Skill = "deploy-data-clerk"

if (-not (Test-Path .git)) { Write-Error "run this from the root of your app's git repository" }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("dcs-" + [guid]::NewGuid())
New-Item -ItemType Directory $tmp | Out-Null
try {
  Write-Host "==> fetching $Repo@$Ref"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $zip = Join-Path $tmp "src.zip"
  Invoke-WebRequest -UseBasicParsing -Uri "https://codeload.github.com/$Repo/zip/$Ref" -OutFile $zip
  Expand-Archive $zip -DestinationPath $tmp
  $src = Get-ChildItem $tmp -Recurse -Directory | Where-Object { $_.FullName -match "[\\/]skills[\\/]$Skill$" } | Select-Object -First 1
  if (-not $src) { Write-Error "skill not found in archive" }
  $src = $src.FullName

  New-Item -ItemType Directory -Force $Dest | Out-Null
  Copy-Item -Force (Join-Path $src "SKILL.md") (Join-Path $Dest "SKILL.md")
  foreach ($d in "references", "scripts", "assets") {
    $t = Join-Path $Dest $d
    if (Test-Path $t) { Remove-Item -Recurse -Force $t }
    Copy-Item -Recurse (Join-Path $src $d) $t
  }
  $proj = Join-Path $Dest "PROJECT.md"
  if (-not (Test-Path $proj)) { Copy-Item (Join-Path $src "assets\PROJECT.md") $proj }

  $stubDir = ".claude\skills\$Skill"
  New-Item -ItemType Directory -Force $stubDir | Out-Null
  $lines = Get-Content (Join-Path $src "SKILL.md")
  $end = [Array]::IndexOf($lines[1..($lines.Length - 1)], "---") + 1
  $front = ($lines[0..$end] -join "`n")
  $body = "`n`nThe full skill lives in the repo at ``deploy-data-clerk/SKILL.md``. Read that file now and follow it; its ``references/``, ``scripts/`` and ``assets/`` are next to it.`n"
  [IO.File]::WriteAllText((Join-Path $stubDir "SKILL.md"), $front + $body)

  $pointer = 'Deploying, env vars/secrets (sops), database migrations, backups and hosting: this app runs on Data Clerk. Read `deploy-data-clerk/SKILL.md` before any of that work.'
  foreach ($f in "AGENTS.md", "CLAUDE.md") {
    if (-not (Test-Path $f) -or -not (Select-String -Path $f -SimpleMatch "deploy-data-clerk/SKILL.md" -Quiet)) {
      [IO.File]::AppendAllText((Join-Path (Get-Location) $f), "`n## Hosting`n`n$pointer`n")
    }
  }

  Write-Host "==> installed into $Dest\ (PROJECT.md kept if it existed)"
  Write-Host "    next: fill in $Dest\PROJECT.md with the values from your Data Clerk operator,"
  Write-Host "    then: powershell -NoProfile -ExecutionPolicy Bypass -File .\$Dest\scripts\install-tools.ps1 -Key <your-project.key>"
} finally {
  Remove-Item -Recurse -Force $tmp
}
