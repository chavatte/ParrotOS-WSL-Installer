# Copyright (c) 2026 Chavatte Security
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.
#
# Security Revision: Secure Script Injection for Core Tools & i18n

function Install-ParrotTools {
  [CmdletBinding()]
  param(
    [string]$DistroName = "ParrotOS"
  )

  $localeScript = Join-Path $PSScriptRoot "Get-Locale.ps1"
  if (Test-Path $localeScript) { . $localeScript; $L = Get-Locale } else { $L = @{} }

  Write-Host $L["InstTools_Title"] -ForegroundColor Cyan

  try {
    $functionScriptPath = $MyInvocation.MyCommand.ScriptBlock.File
    $ScriptDirectory = Split-Path $functionScriptPath -ErrorAction Stop
    $bashScriptPath = Join-Path (Split-Path $ScriptDirectory -Parent) "Bash" "install_tools_internal.sh"

    if (-not (Test-Path $bashScriptPath -PathType Leaf)) {
      Write-Host ($L["InstTools_ErrBashNF"] -f $bashScriptPath) -ForegroundColor Red
      return
    }

    $toolsCommandsTemplate = Get-Content -Path $bashScriptPath -Raw -ErrorAction Stop
    $unixToolsCommands = $toolsCommandsTemplate -replace "`r`n", "`n" -replace "`r", "`n"

    Write-Host $L["InstTools_Wait"] -ForegroundColor Yellow
    Write-Host $L["InstTools_WaitTime"] -ForegroundColor DarkGray
        
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "wsl.exe"
    $psi.Arguments = "-d $DistroName --user root -- bash -s" 
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true 

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $process.Start() | Out-Null

    $inputStream = $process.StandardInput
    $inputStream.Write($unixToolsCommands)
    $inputStream.Close() 

    $toolsOutput = $process.StandardOutput.ReadToEnd()
    $toolsError = $process.StandardError.ReadToEnd()
    $process.WaitForExit() 
    $exitCode = $process.ExitCode 
    $process.Close() 

    if ($exitCode -ne 0) {
      Write-Host ($L["InstTools_ErrInst"] -f $exitCode) -ForegroundColor Red
            
      if (-not [string]::IsNullOrWhiteSpace($toolsOutput)) {
        Write-Host $L["InstTools_StdOut"] -ForegroundColor DarkGray
        Write-Host $toolsOutput -ForegroundColor Gray
      }
      if (-not [string]::IsNullOrWhiteSpace($toolsError)) {
        Write-Host $L["InstTools_StdErr"] -ForegroundColor Red
        Write-Host $toolsError -ForegroundColor Red
      }
    }
    else {
      Write-Host $L["InstTools_Succ"] -ForegroundColor Green
    }
  }
  catch {
    Write-Host $L["InstTools_Fatal"] -ForegroundColor Red
  }
}