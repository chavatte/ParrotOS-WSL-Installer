# Copyright (c) 2026 Chavatte Security
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.
#
# Security Revision: i18n Dictionary Implementation

function Show-Logo {
  [CmdletBinding()]
  param (
    [string]$LogoFilePath
  )

  if (-not (Test-Path -Path $LogoFilePath -PathType Leaf)) {
    return
  }

  $localeScript = Join-Path $PSScriptRoot "Get-Locale.ps1"
  if (Test-Path $localeScript) { . $localeScript; $L = Get-Locale } else { $L = @{} }

  try {
    Clear-Host
    $terminalWidth = $Host.UI.RawUI.WindowSize.Width
    if ($terminalWidth -lt 80) {
      Write-Warning $L["ShowLogo_WarnWidth"]
    }
    else {
      $mensagem = Get-Content -Path $LogoFilePath -Raw
      $logoWidth = ($mensagem -split "`n" | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
      $logoSpacingValue = ($terminalWidth - $logoWidth) / 2
      if ($logoSpacingValue -lt 0) { $logoSpacingValue = 0 }
      $espacamento = " " * $logoSpacingValue

      ($mensagem -split "`r`n") | ForEach-Object { Write-Host ($espacamento + $_) -ForegroundColor DarkGreen }
    }
    
    $title = $L["ShowLogo_Title"]
    $titleSpacingValue = ($terminalWidth - $title.Length) / 2
    if ($titleSpacingValue -lt 0) { $titleSpacingValue = 0 }
    $titleSpacing = " " * $titleSpacingValue
    Write-Host ($titleSpacing + $title) -ForegroundColor Cyan

    $infoLines = @(
      $L["ShowLogo_Info1"],
      $L["ShowLogo_Info2"],
      $L["ShowLogo_Info3"],
      $L["ShowLogo_Info4"]
    )

    Write-Host
    foreach ($line in $infoLines) {
      $lineSpacingValue = ($terminalWidth - $line.Length) / 2
      if ($lineSpacingValue -lt 0) { $lineSpacingValue = 0 }
      $spacing = " " * $lineSpacingValue
      Write-Host ($spacing + $line) -ForegroundColor White
    }
    Write-Host

    Read-Host -Prompt $L["ShowLogo_Prompt"]
  }
  catch {
    Write-Warning ($L["ShowLogo_WarnErr"] -f $_.Exception.Message)
  }
}