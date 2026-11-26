param([string]$Skill = "deploy-data-clerk", [switch]$Global)
$ErrorActionPreference = "Stop"
$Repo = if ($env:DATA_CLERK_SKILLS_REPO) { $env:DATA_CLERK_SKILLS_REPO } else { "Bohdan-Meshcheriakov/data-clerk-skills" }
$Ref = if ($env:DATA_CLERK_SKILLS_REF) { $env:DATA_CLERK_SKILLS_REF } else { "main" }

if ($Skill -notin "deploy-data-clerk", "human-touch") { Write-Error "unknown skill '$Skill' (use: deploy-data-clerk | human-touch)" }
if ($Skill -eq "deploy-data-clerk" -and -not (Test-Path .git)) { Write-Error "run this from the root of your app's git repository" }

function Add-Pointer($Heading, $Needle, $Text) {
  foreach ($f in "AGENTS.md", "CLAUDE.md") {
    if (-not (Test-Path $f) -or -not (Select-String -Path $f -SimpleMatch $Needle -Quiet)) {
      [IO.File]::AppendAllText((Join-Path (Get-Location) $f), "`n## $Heading`n`n$Text`n")
    }
  }
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("dcs-" + [guid]::NewGuid())
New-Item -ItemType Directory $tmp | Out-Null
try {
  if ($env:DATA_CLERK_SKILLS_SRC) {
    $src = Join-Path $env:DATA_CLERK_SKILLS_SRC "skills\$Skill"
  } else {
    Write-Host "==> fetching $Repo@$Ref"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $zip = Join-Path $tmp "src.zip"
    Invoke-WebRequest -UseBasicParsing -Uri "https://codeload.github.com/$Repo/zip/$Ref" -OutFile $zip
    Expand-Archive $zip -DestinationPath $tmp
    $found = Get-ChildItem $tmp -Recurse -Directory | Where-Object { $_.FullName -match "[\\/]skills[\\/]$Skill$" } | Select-Object -First 1
    if (-not $found) { Write-Error "skill not found in archive" }
    $src = $found.FullName
  }

  if ($Skill -eq "human-touch") {
    $project = (-not $Global) -and (Test-Path .git)
    $Dest = if ($env:HUMANTOUCH_SKILL_DIR) { $env:HUMANTOUCH_SKILL_DIR } elseif ($project) { ".claude\skills\human-touch" } else { Join-Path $HOME ".claude\skills\human-touch" }
    if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }
    New-Item -ItemType Directory -Force $Dest | Out-Null
    Copy-Item -Recurse -Force (Join-Path $src "*") $Dest
    if ($project) {
      $rel = $Dest -replace '\\', '/'
      Add-Pointer "Human Touch" "human-touch/SKILL.md" "To have real people check something you can't be sure of (approvals before risky actions, labels, ratings, native-speaker text checks, web checks), read ``$rel/SKILL.md``."
    }
    Write-Host "==> Human Touch skill installed in $Dest"
    Write-Host "    next: read $Dest\SKILL.md, section `"Getting access`", and connect (your human approves once in the browser)"
    return
  }

  $Dest = "deploy-data-clerk"
  New-Item -ItemType Directory -Force $Dest | Out-Null
  Copy-Item -Force (Join-Path $src "SKILL.md") (Join-Path $Dest "SKILL.md")
  foreach ($d in "references", "scripts", "assets") {
    $t = Join-Path $Dest $d
    if (Test-Path $t) { Remove-Item -Recurse -Force $t }
    Copy-Item -Recurse (Join-Path $src $d) $t
  }
  Copy-Item -Force (Join-Path $src "..\..\LICENSE") (Join-Path $Dest "LICENSE")
  $proj = Join-Path $Dest "PROJECT.md"
  if (-not (Test-Path $proj)) { Copy-Item (Join-Path $src "assets\PROJECT.md") $proj }

  $stubDir = ".claude\skills\$Skill"
  New-Item -ItemType Directory -Force $stubDir | Out-Null
  $lines = Get-Content (Join-Path $src "SKILL.md")
  $end = [Array]::IndexOf($lines[1..($lines.Length - 1)], "---") + 1
  $front = ($lines[0..$end] -join "`n")
  $body = "`n`nThe full skill lives in the repo at ``deploy-data-clerk/SKILL.md``. Read that file now and follow it; its ``references/``, ``scripts/`` and ``assets/`` are next to it.`n"
  [IO.File]::WriteAllText((Join-Path $stubDir "SKILL.md"), $front + $body)

  Add-Pointer "Hosting" "deploy-data-clerk/SKILL.md" 'Deploying, env vars/secrets (sops), database migrations, backups and hosting: this app runs on Data Clerk. Read `deploy-data-clerk/SKILL.md` before any of that work.'

  Write-Host "==> installed into $Dest\ (PROJECT.md kept if it existed)"
  Write-Host "    next: fill in $Dest\PROJECT.md with the values from your Data Clerk operator,"
  Write-Host "    then: powershell -NoProfile -ExecutionPolicy Bypass -File .\$Dest\scripts\install-tools.ps1 -Key <your-project.key>"
} finally {
  Remove-Item -Recurse -Force $tmp
}
