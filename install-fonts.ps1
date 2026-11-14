<#
  DevOps Toolbox - terminal fonts for YOUR Windows machine (the SSH client side).
  Installs CaskaydiaMono Nerd Font + JetBrainsMono Nerd Font per-user (no admin) and can
  set one as the Windows Terminal default.

  One-liner (PowerShell):
    irm https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-fonts.ps1 | iex

  From a downloaded file:
    .\install-fonts.ps1 [-SetDefault jetbrains|cascadia|none] [-DryRun]
  With the one-liner, preset the choice via:  $env:TOOLBOX_FONT = 'jetbrains'
#>
param(
  [ValidateSet('ask', 'jetbrains', 'cascadia', 'none')][string]$SetDefault = 'ask',
  [switch]$DryRun
)

$OK = [string][char]0x2714; $GO = [string][char]0x279C; $WARN = [string][char]0x26A0; $DOWN = [string][char]0x2193
$SKIP = [string][char]0x25CB; $TO = [string][char]0x2192; $DOT = [string][char]0x00B7; $ELL = [string][char]0x2026
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # makes Invoke-WebRequest much faster on PS 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
if ($SetDefault -eq 'ask' -and $env:TOOLBOX_FONT) { $SetDefault = $env:TOOLBOX_FONT }
if ($env:TOOLBOX_FONTS_DRYRUN -eq '1') { $DryRun = $true }

$Fonts = @(
  @{ Key = 'cascadia';  Zip = 'CascadiaMono';  Family = 'CaskaydiaMono Nerd Font Mono';  Pattern = 'CaskaydiaMonoNerdFontMono-*.ttf' },
  @{ Key = 'jetbrains'; Zip = 'JetBrainsMono'; Family = 'JetBrainsMono Nerd Font Mono'; Pattern = 'JetBrainsMonoNerdFontMono-*.ttf' }
)
$FontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$RegPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

function Say($icon, $color, $msg) { Write-Host "  $icon " -ForegroundColor $color -NoNewline; Write-Host $msg }

Write-Host ''
Write-Host "  DEVOPS TOOLBOX $($DOT) terminal fonts" -ForegroundColor Cyan
Write-Host '  ============================================================' -ForegroundColor DarkCyan
Say "$($GO)" Cyan "Installing for user $env:USERNAME $($TO) $FontDir"
if ($DryRun) { Say "$($WARN)" Yellow 'Dry run: downloading and listing only, nothing is installed.' }
Write-Host ''

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("toolbox-fonts-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp | Out-Null
if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $FontDir | Out-Null }

try {
  foreach ($f in $Fonts) {
    $url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$($f.Zip).zip"
    $zip = Join-Path $tmp "$($f.Zip).zip"
    Say "$($DOWN)" DarkGray "$($f.Family)  ($url)"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    $dir = Join-Path $tmp $f.Zip
    Expand-Archive -Path $zip -DestinationPath $dir -Force
    $ttfs = Get-ChildItem -Path $dir -Recurse -Filter $f.Pattern
    if (-not $ttfs) { throw "No files matching $($f.Pattern) in $($f.Zip).zip" }

    $n = 0
    foreach ($t in $ttfs) {
      $dest = Join-Path $FontDir $t.Name
      $name = ($t.BaseName -replace '-', ' ') + ' (TrueType)'
      if ($DryRun) { $n++; continue }
      try {
        Copy-Item -Path $t.FullName -Destination $dest -Force
      } catch {
        # file in use by a running app -> already installed, keep the existing copy
        if (-not (Test-Path $dest)) { throw }
      }
      New-ItemProperty -Path $RegPath -Name $name -Value $dest -PropertyType String -Force | Out-Null
      $n++
    }
    $verb = 'installed'; if ($DryRun) { $verb = 'would install' }
    Say "$($OK)" Green ("{0,-30} {1} {2} styles" -f $f.Family, $verb, $n)
  }
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

# -- Windows Terminal default font ----------------------------------------------
$wtFiles = @(
  "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
  "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
  "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
) | Where-Object { Test-Path $_ }

Write-Host ''
if ($wtFiles) {
  if ($SetDefault -eq 'ask') {
    Write-Host '  Set the Windows Terminal default font?' -ForegroundColor Cyan
    Write-Host '    [1] JetBrainsMono Nerd Font Mono'
    Write-Host '    [2] CaskaydiaMono Nerd Font Mono'
    Write-Host '    [3] Leave Windows Terminal unchanged'
    $a = Read-Host '  Choice [1]'
    switch ($a) { '2' { $SetDefault = 'cascadia' } '3' { $SetDefault = 'none' } default { $SetDefault = 'jetbrains' } }
  }
  if ($SetDefault -ne 'none') {
    $family = ($Fonts | Where-Object { $_.Key -eq $SetDefault }).Family
    foreach ($wt in $wtFiles) {
      if ($DryRun) { Say "$($SKIP)" DarkGray "would set font.face = '$family' in $wt"; continue }
      try {
        $raw = Get-Content -Raw -Path $wt -Encoding UTF8
        $json = $raw | ConvertFrom-Json
        if (-not $json.profiles) { throw 'no profiles section' }
        if ($json.profiles -is [array]) { throw 'legacy profiles array' }
        if (-not $json.profiles.defaults) {
          $json.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force
        }
        $d = $json.profiles.defaults
        if ($d.font) {
          if ($d.font.PSObject.Properties['face']) { $d.font.face = $family }
          else { $d.font | Add-Member -NotePropertyName face -NotePropertyValue $family }
        } else {
          $d | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{ face = $family }) -Force
        }
        Copy-Item $wt "$wt.toolbox-backup" -Force
        $out = ConvertTo-Json -InputObject $json -Depth 64
        [IO.File]::WriteAllText($wt, $out, (New-Object Text.UTF8Encoding $false))
        Say "$($OK)" Green "Windows Terminal font $($TO) $family  (backup: settings.json.toolbox-backup)"
      } catch {
        Say "$($WARN)" Yellow "Could not edit $wt automatically ($($_.Exception.Message))."
        Say ' ' Gray  "Set it by hand: Settings $($TO) Defaults $($TO) Appearance $($TO) Font face $($TO) $family"
      }
    }
  }
} else {
  Say "$($SKIP)" DarkGray 'Windows Terminal not found; set the font in your SSH client manually (see below).'
}

Write-Host ''
Write-Host '  ============================================================' -ForegroundColor DarkCyan
Write-Host '  Done. Restart your terminal, then pick the font where needed:' -ForegroundColor Cyan
Write-Host "    Windows Terminal  Settings $($TO) Defaults $($TO) Appearance $($TO) Font face"
Write-Host "    PuTTY             Window $($TO) Appearance $($TO) Font $($TO) Change$($ELL)"
Write-Host '    VS Code terminal  "terminal.integrated.fontFamily": "JetBrainsMono Nerd Font Mono"'
Write-Host "    MobaXterm         Settings $($TO) Terminal $($TO) Font"
Write-Host ''
