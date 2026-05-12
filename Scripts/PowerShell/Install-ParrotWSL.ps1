# Copyright (c) 2026 Chavatte Security
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.
#
# Security Revision: Memory Sanitization, Credential Hardening, Diagnostic Logging & i18n

function Install-ParrotWSL {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RootFSPath,

    [string]$DistroName = "ParrotOS",

    [string]$InstallPath = "$env:SystemDrive\WSL_Distros\ParrotOS"
  )

  $localeScript = Join-Path $PSScriptRoot "Get-Locale.ps1"
  if (Test-Path $localeScript) { . $localeScript; $L = Get-Locale } else { $L = @{} }

  Write-Host $L["InstWSL_Title"] -ForegroundColor Cyan

  Write-Host $L["InstWSL_ChkRoot"] -ForegroundColor Yellow
  if (-not (Test-Path $RootFSPath)) {
    Write-Host ($L["InstWSL_ErrRoot"] -f $RootFSPath) -ForegroundColor Red
    exit 1
  }
  Write-Host $L["InstWSL_SuccRoot"] -ForegroundColor Green

  Write-Host $L["InstWSL_ChkDir"] -ForegroundColor Yellow
  if (-not (Test-Path $InstallPath)) {
    try {
      Write-Host ($L["InstWSL_MkDir"] -f $InstallPath) -ForegroundColor Yellow
      New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }
    catch {
      Write-Host ($L["InstWSL_ErrDir"] -f $_.Exception.Message) -ForegroundColor Red
      exit 1
    }
  }

  $existingDistros = wsl --list --quiet
  if ($existingDistros -contains $DistroName) {
    Write-Host ($L["InstWSL_WarnExists"] -f $DistroName) -ForegroundColor Yellow
    
    $choiceUser = $null
    while ($choiceUser -notmatch '^[sSyYnN]$') {
      $choiceUser = Read-Host $L["InstWSL_PromptReinst"]
    }

    if ($choiceUser -notmatch '^[sSyY]') {
      Write-Host $L["InstWSL_Cancel"] -ForegroundColor Yellow
      exit 0
    }
    
    try {
      Write-Host ($L["InstWSL_RemExist"] -f $DistroName) -ForegroundColor Yellow
      wsl --unregister $DistroName | Out-Null
      Start-Sleep -Seconds 3 
    }
    catch {
      Write-Host ($L["InstWSL_ErrRem"] -f $_.Exception.Message) -ForegroundColor Red
      exit 1
    }
  }

  try {
    Write-Host $L["InstWSL_ImportWait"] -ForegroundColor Yellow
    wsl --import $DistroName $InstallPath $RootFSPath --version 2
    if ($LASTEXITCODE -ne 0) {
      Write-Host ($L["InstWSL_ErrImport"] -f $LASTEXITCODE) -ForegroundColor Red
      exit 1
    }
    Write-Host $L["InstWSL_SuccImport"] -ForegroundColor Green
  }
  catch {
    Write-Host $L["InstWSL_ErrImpExc"] -ForegroundColor Red
    exit 1
  }

  try {
    Write-Host $L["InstWSL_TitleUser"] -ForegroundColor Cyan
    
    $defaultUserSuggestion = ($env:USERNAME -replace '[^a-zA-Z0-9]', '').ToLower()
    if ([string]::IsNullOrWhiteSpace($defaultUserSuggestion)) { $defaultUserSuggestion = "parrotuser" }
    
    $userName = ""
    while ([string]::IsNullOrWhiteSpace($userName) -or $userName -match '[^a-zA-Z0-9_]') {
      $userName = Read-Host ($L["InstWSL_PromptUser"] -f $defaultUserSuggestion)
      if ([string]::IsNullOrWhiteSpace($userName)) { $userName = $defaultUserSuggestion }
    }
    
    while ($true) {
      $passwordInput = Read-Host ($L["InstWSL_PromptPass"] -f $userName) -AsSecureString
      if ($passwordInput.Length -eq 0) {
        Write-Host $L["InstWSL_WarnPass"] -ForegroundColor Yellow
        continue
      }
      break 
    }
    
    Write-Host $L["InstWSL_ConfEnv"] -ForegroundColor Yellow
    
    $functionScriptPath = $MyInvocation.MyCommand.ScriptBlock.File
    $ScriptDirectory = Split-Path $functionScriptPath -ErrorAction Stop
    $bashScriptPath = Join-Path (Split-Path $ScriptDirectory -Parent) "Bash" "configure_parrot_internal.sh"

    if (-not (Test-Path $bashScriptPath -PathType Leaf)) {
      Write-Host ($L["InstWSL_ErrBashNF"] -f $bashScriptPath) -ForegroundColor Red
      exit 1
    }

    $wslCommandsTemplate = Get-Content -Path $bashScriptPath -Raw -ErrorAction Stop
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "wsl.exe"
    $psi.Arguments = "-d $DistroName -- bash -s" 
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true 

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $process.Start() | Out-Null
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($passwordInput)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    $wslCommands = $wslCommandsTemplate.Replace('__USERNAME_PLACEHOLDER__', $userName).Replace('__PASSWORD_PLACEHOLDER__', $plainPassword)
    $unixWslCommands = $wslCommands -replace "`r`n", "`n" -replace "`r", "`n"
    $inputStream = $process.StandardInput
    $inputStream.Write($unixWslCommands)
    $inputStream.Close() 

    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    $passwordInput.Dispose()
    $plainPassword = [string]::Empty
    $wslCommands = [string]::Empty
    $unixWslCommands = [string]::Empty
    Remove-Variable plainPassword, wslCommands, unixWslCommands -ErrorAction SilentlyContinue
    [System.GC]::Collect()
    Write-Host $L["InstWSL_Sanitized"] -ForegroundColor DarkGray

    $wslExecutionOutput = $process.StandardOutput.ReadToEnd()
    $wslErrorOutput = $process.StandardError.ReadToEnd()
    $process.WaitForExit() 
    $wslExitCode = $process.ExitCode 
    $process.Close() 

    if ($wslExitCode -ne 0) {
      Write-Host ($L["InstWSL_ErrConf"] -f $wslExitCode) -ForegroundColor Red
      if (-not [string]::IsNullOrWhiteSpace($wslExecutionOutput)) {
        Write-Host $L["InstWSL_StdOut"] -ForegroundColor DarkGray
        Write-Host $wslExecutionOutput -ForegroundColor Gray
      }
      if (-not [string]::IsNullOrWhiteSpace($wslErrorOutput)) {
        Write-Host $L["InstWSL_StdErr"] -ForegroundColor Red
        Write-Host $wslErrorOutput -ForegroundColor Red
      }
      exit 1
    }
    
    Write-Host $L["InstWSL_SuccConf"] -ForegroundColor Green
  }
  catch {
    Write-Host $L["InstWSL_FatalConf"] -ForegroundColor Red
    exit 1
  }

  try {
    Write-Host $L["InstWSL_RestartWSL"] -ForegroundColor Yellow
    wsl --terminate $DistroName
    Start-Sleep -Seconds 3 
  }
  catch { }

  Write-Host $L["InstWSL_SuccFinal"] -ForegroundColor Green
}