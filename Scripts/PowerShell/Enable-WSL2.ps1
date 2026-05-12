# Copyright (c) 2026 Chavatte Security
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.
#
# Security Revision: Dynamic i18n implementation

function Enable-WSL2 {
  [CmdletBinding()]
  param()

  $localeScript = Join-Path $PSScriptRoot "Get-Locale.ps1"
  if (Test-Path $localeScript) { . $localeScript; $L = Get-Locale } else { $L = @{} }

  Write-Host $L["EWSL_TitleReq"] -ForegroundColor Cyan

  $osInfo = Get-ComputerInfo | Select-Object OsName, OsVersion, OsArchitecture
  $buildNumber = [System.Environment]::OSVersion.Version.Build

  Write-Host $L["EWSL_CheckOS"] -ForegroundColor Yellow
  if ($buildNumber -lt 19041) {
    Write-Host ($L["EWSL_ErrOS"] -f $osInfo.OsName, $buildNumber) -ForegroundColor Red
    Write-Host $L["EWSL_InfoOSReq"] -ForegroundColor Yellow
    exit 1
  }
  Write-Host ($L["EWSL_SuccOS"] -f $osInfo.OsName, $buildNumber) -ForegroundColor Green

  try {
    Write-Host $L["EWSL_CheckFeat"] -ForegroundColor Yellow
    $vmEnabled = (Get-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform").State -eq "Enabled"
    $wslEnabled = (Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux").State -eq "Enabled"
        
    if (-not $vmEnabled -or -not $wslEnabled) {
      Write-Host $L["EWSL_EnableFeat"] -ForegroundColor Yellow
      Write-Host $L["EWSL_WarnRestart"] -ForegroundColor Yellow
      Write-Host $L["EWSL_WaitMin"] -ForegroundColor Yellow
      
      if (-not $vmEnabled) {
        Write-Host $L["EWSL_EnVMP"] -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart -ErrorAction Stop | Out-Null
        Write-Host $L["EWSL_SuccVMP"] -ForegroundColor Green
      }
      else {
        Write-Host $L["EWSL_AlrVMP"] -ForegroundColor Green
      }

      if (-not $wslEnabled) {
        Write-Host $L["EWSL_EnWSLF"] -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart -ErrorAction Stop | Out-Null
        Write-Host $L["EWSL_SuccWSLF"] -ForegroundColor Green
      }
      else {
        Write-Host $L["EWSL_AlrWSLF"] -ForegroundColor Green
      }
            
      Write-Host $L["EWSL_SuccAllFeat"] -ForegroundColor Green
      Write-Host $L["EWSL_InfoRestart"] -ForegroundColor Yellow
      
      $choice = $null
      while ($choice -notmatch '^[sSyYnN]$') {
        $choice = Read-Host $L["EWSL_PromptRest"]
        if ($choice -notmatch '^[sSyYnN]$') {
          Write-Host $L["EWSL_WarnInvalid"] -ForegroundColor Yellow
        }
      }

      if ($choice -match '^[sSyY]') {
        Write-Host $L["EWSL_RestComp"] -ForegroundColor Yellow
        Restart-Computer -Force
      }
      else {
        Write-Host $L["EWSL_InfoManRest"] -ForegroundColor Yellow
        exit 0
      }
    }
    else {
      Write-Host $L["EWSL_SuccAllAlr"] -ForegroundColor Green
    }
  }
  catch {
    Write-Host ($L["EWSL_ErrEnFeat"] -f $_.Exception.Message) -ForegroundColor Red
    exit 1
  }

  try {
    Write-Host $L["EWSL_TitleConf"] -ForegroundColor Cyan

    $wslInstalled = $false
    try {
      $null = wsl --status 2>$null
      $wslInstalled = $?
    }
    catch {
      $wslInstalled = $false
    }

    if (-not $wslInstalled) {
      Write-Host $L["EWSL_InfoNoCore"] -ForegroundColor Yellow
      Write-Host $L["EWSL_InstCore"] -ForegroundColor Yellow
      Write-Host $L["EWSL_WaitMin"] -ForegroundColor Yellow
      Write-Host $L["EWSL_InfoLink"] -ForegroundColor Yellow
      wsl --install --no-distribution | Out-Null
      if ($LASTEXITCODE -ne 0) {
        Write-Host ($L["EWSL_ErrWslInst"] -f $LASTEXITCODE) -ForegroundColor Red
        Write-Host $L["EWSL_InfoReqRest"] -ForegroundColor Yellow
        exit 1
      }
      Write-Host $L["EWSL_SuccCore"] -ForegroundColor Green
    }
    else {
      Write-Host $L["EWSL_InfoDetWSL"] -ForegroundColor Yellow
      Write-Host $L["EWSL_UpdCore"] -ForegroundColor Yellow
      Write-Host $L["EWSL_WaitMin"] -ForegroundColor Yellow
      wsl --update | Out-Null
      if ($LASTEXITCODE -ne 0) {
        Write-Host ($L["EWSL_WarnUpdCode"] -f $LASTEXITCODE) -ForegroundColor Yellow
      }
      else {
        Write-Host $L["EWSL_SuccUpd"] -ForegroundColor Green
      }
    }

    Write-Host $L["EWSL_SetDef2"] -ForegroundColor Yellow
    wsl --set-default-version 2 | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Write-Host ($L["EWSL_ErrSetDef"] -f $LASTEXITCODE) -ForegroundColor Red
      Write-Host $L["EWSL_InfoChkBios"] -ForegroundColor Yellow
      exit 1
    }
    Write-Host $L["EWSL_SuccSetDef"] -ForegroundColor Green
        
  }
  catch {
    Write-Host ($L["EWSL_ErrConfWSL"] -f $_.Exception.Message) -ForegroundColor Red
    Write-Host $L["EWSL_InfoTryAgn"] -ForegroundColor Yellow
    Write-Host $L["EWSL_InfoLink"] -ForegroundColor Yellow
    exit 1
  }
  
  Write-Host $L["EWSL_TitleStat"] -ForegroundColor Cyan
  Write-Host $L["EWSL_CheckStat"] -ForegroundColor Yellow
  try {
    $wslStatusOutput = wsl --status
    if ($LASTEXITCODE -ne 0) {
      Write-Host ($L["EWSL_WarnStat"] -f $LASTEXITCODE) -ForegroundColor Yellow
      Write-Host $L["EWSL_InfoWinVer"] -ForegroundColor Yellow
      Write-Host $L["EWSL_InfoTryAlt"] -ForegroundColor Yellow
      $defaultVersionCheck = (wsl --list --verbose) | Select-String "^\*\s"
      if ($defaultVersionCheck -match "VERSION\s+2") {
        Write-Host $L["EWSL_SuccVer2Alt"] -ForegroundColor Green
      }
      else {
        Write-Host $L["EWSL_WarnNoConf2"] -ForegroundColor Yellow
      }
    }
    else {
      if ($wslStatusOutput -match "2") {
        Write-Host $L["EWSL_SuccVer2"] -ForegroundColor Green
      }
      else {
        Write-Host $L["EWSL_WarnNot2"] -ForegroundColor Yellow
        Write-Host $L["EWSL_InfoChkOut"] -ForegroundColor Yellow
      }
    }
  }
  catch {
    Write-Host ($L["EWSL_ErrChkStat"] -f $_.Exception.Message) -ForegroundColor Red
    exit 1
  }
  Write-Host $L["EWSL_SuccFinal"] -ForegroundColor Green
}