# Copyright (c) 2026 Chavatte Security
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.
#
# Security Revision: Implemented Auto-Elevation & Dynamic Registry Path Discovery

<#
.SYNOPSIS
    [EN] Completely uninstalls the ParrotOS WSL distribution, including folders and modules.
    [PT] Desinstala de forma completa a distribuição ParrotOS do WSL, incluindo pastas e módulos.

.DESCRIPTION
    [EN] This command performs a secure and complete uninstallation.
    [PT] Este comando realiza uma desinstalação completa e segura.
#>
function Uninstall-ParrotWSL {
  [CmdletBinding()]
  param(
    [string]$DistroName = "ParrotOS",
    [string]$InstallPath = "",
    [switch]$Force
  )

  $localeScript = Join-Path $PSScriptRoot "Get-Locale.ps1"
  if (Test-Path $localeScript) { . $localeScript; $L = Get-Locale } else { $L = @{} }

  if ([string]::IsNullOrWhiteSpace($InstallPath)) {
    try {
      $distroReg = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\*" -ErrorAction SilentlyContinue | Where-Object { $_.DistributionName -eq $DistroName }
      if ($null -ne $distroReg -and -not [string]::IsNullOrWhiteSpace($distroReg.BasePath)) {
        $InstallPath = $distroReg.BasePath -replace '^\\\\\?\\', ''
      }
      else {
        $InstallPath = "$env:SystemDrive\WSL_Distros\$DistroName"
      }
    }
    catch {
      $InstallPath = "$env:SystemDrive\WSL_Distros\$DistroName"
    }
  }

  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  
  if (-not $isAdmin) {
    Write-Host $L["Uninst_NoAdmin"] -ForegroundColor Yellow
    Write-Host $L["Uninst_ReqUAC"] -ForegroundColor Cyan
      
    $myArgs = @("-DistroName", "`"$DistroName`"", "-InstallPath", "`"$InstallPath`"")
    if ($Force) { $myArgs += "-Force" }
  
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"") + $myArgs
  
    try {
      Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
      exit 0 
    }
    catch {
      Write-Host $L["Uninst_UACError"] -ForegroundColor Red
      exit 1
    }
  }

  Write-Host $L["Uninst_Title"] -ForegroundColor Cyan
  Write-Host $L["Uninst_Audit"] -ForegroundColor Yellow
    
  $distroExists = $false
  if ((wsl --list --quiet) -contains $DistroName) {
    $distroExists = $true
    Write-Host ($L["Uninst_DistroFound"] -f $DistroName) -ForegroundColor Green
  }
  else {
    Write-Host ($L["Uninst_DistroNotFound"] -f $DistroName) -ForegroundColor DarkGray
  }

  $dirExists = $false
  if (Test-Path -Path $InstallPath -PathType Container) {
    $dirExists = $true
    Write-Host ($L["Uninst_DirFound"] -f $InstallPath) -ForegroundColor Green
  }
  else {
    Write-Host ($L["Uninst_DirNotFound"] -f $InstallPath) -ForegroundColor DarkGray
  }

  $connectModuleDir = $null
  $connectModuleExists = $false
  $uninstallModuleDir = $null
  $uninstallModuleExists = $false

  $userModulePath = ($env:PSModulePath -split ';') | Where-Object { $_ -like "*$($env:USERPROFILE)*" } | Select-Object -First 1
  if ($userModulePath) {
    $connectModuleDir = Join-Path -Path $userModulePath -ChildPath "Connect-ParrotGUI"
    if (Test-Path -Path $connectModuleDir) {
      $connectModuleExists = $true
      Write-Host $L["Uninst_ModConnFound"] -ForegroundColor Green
    }

    $uninstallModuleDir = Join-Path -Path $userModulePath -ChildPath "Uninstall-ParrotWSL"
    if (Test-Path -Path $uninstallModuleDir) {
      $uninstallModuleExists = $true
      Write-Host $L["Uninst_ModUninstFound"] -ForegroundColor Green
    }
  }

  if (-not ($distroExists -or $dirExists -or $connectModuleExists -or $uninstallModuleExists)) {
    Write-Host $L["Uninst_Clean"] -ForegroundColor Green
    return
  }

  if (-not $Force) {
    Write-Host $L["Uninst_WarnCrit"] -ForegroundColor Red
    $confirmation = Read-Host $L["Uninst_Confirm"]
    if ($confirmation -notmatch '^[sSyY]') {
      Write-Host $L["Uninst_Abort"] -ForegroundColor Cyan
      return
    }
  }

  Write-Host $L["Uninst_Exec"] -ForegroundColor Yellow

  if ($distroExists) {
    try {
      Write-Host ($L["Uninst_TermInst"] -f $DistroName) -ForegroundColor DarkGray
      wsl --terminate $DistroName 2>$null
      Write-Host $L["Uninst_UnregVHDX"] -ForegroundColor Yellow
      wsl --unregister $DistroName | Out-Null
      Write-Host $L["Uninst_DistroRem"] -ForegroundColor Green
    }
    catch {
      Write-Host ($L["Uninst_ErrDistroRem"] -f $_.Exception.Message) -ForegroundColor Red
    }
  }

  if ($dirExists) {
    try {
      Write-Host ($L["Uninst_DelDir"] -f $InstallPath) -ForegroundColor Yellow
      Remove-Item -Path $InstallPath -Recurse -Force
      Write-Host $L["Uninst_DirPurged"] -ForegroundColor Green
    }
    catch {
      Write-Host ($L["Uninst_ErrDirPurge"] -f $_.Exception.Message) -ForegroundColor Red
    }
  }

  if ($connectModuleExists) {
    try {
      Remove-Item -Path $connectModuleDir -Recurse -Force
      Write-Host $L["Uninst_ModConnPurged"] -ForegroundColor Green
    }
    catch {}
  }

  if ($uninstallModuleExists) {
    try {
      Remove-Item -Path $uninstallModuleDir -Recurse -Force
      Write-Host $L["Uninst_ModUninstPurged"] -ForegroundColor Green
    }
    catch {}
  }

  Write-Host $L["Uninst_Success"] -ForegroundColor Green
  Write-Host $L["Uninst_RestartTerm"] -ForegroundColor DarkGray
}