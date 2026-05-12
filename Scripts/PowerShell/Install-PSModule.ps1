# Copyright (c) 2026 Chavatte Security
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.
#
# Security Revision: i18n Dictionary Implementation & Module Dependency Fix

function Install-PSModule {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$FunctionName,

    [Parameter(Mandatory = $true)]
    [string]$SourceScriptPath
  )

  $localeScript = Join-Path $PSScriptRoot "Get-Locale.ps1"
  if (Test-Path $localeScript) { . $localeScript; $L = Get-Locale } else { $L = @{} }

  Write-Host ($L["InstMod_Title"] -f $FunctionName) -ForegroundColor Cyan

  try {
    if (-not (Test-Path -Path $SourceScriptPath -PathType Leaf)) {
      Write-Host ($L["InstMod_ErrSrc"] -f $SourceScriptPath) -ForegroundColor Red
      return
    }

    $userModulePath = ($env:PSModulePath -split ';') | Where-Object { $_ -like "*$($env:USERPROFILE)*" } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($userModulePath)) {
      Write-Host $L["InstMod_ErrPath"] -ForegroundColor Red
      return
    }

    $targetModuleDir = Join-Path -Path $userModulePath -ChildPath $FunctionName
    if (-not (Test-Path -Path $targetModuleDir)) {
      New-Item -ItemType Directory -Path $targetModuleDir -Force | Out-Null
    }

    $targetModuleFile = Join-Path -Path $targetModuleDir -ChildPath "$FunctionName.psm1"
    Get-Content -Path $SourceScriptPath -Raw | Set-Content -Path $targetModuleFile -Encoding UTF8

    $sourceLocalesDir = Join-Path $PSScriptRoot "Locales"
    Copy-Item -Path $localeScript -Destination $targetModuleDir -Force
    if (Test-Path $sourceLocalesDir) {
      Copy-Item -Path $sourceLocalesDir -Destination $targetModuleDir -Recurse -Force
    }
        
    Write-Host ($L["InstMod_Succ"] -f $FunctionName) -ForegroundColor Green
    Write-Host $L["InstMod_Use"] -ForegroundColor Green
  }
  catch {
    Write-Host ($L["InstMod_Fatal"] -f $_.Exception.Message) -ForegroundColor Red
  }
}