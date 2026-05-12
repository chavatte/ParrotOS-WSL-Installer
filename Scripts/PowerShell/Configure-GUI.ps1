# Copyright (c) 2026 Chavatte Security
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.
#
# Security Revision: i18n Dictionary Implementation

function Set-ParrotGUI {
    [CmdletBinding()]
    param(
        [string]$DistroName = "ParrotOS"
    )

    $localeScript = Join-Path $PSScriptRoot "Get-Locale.ps1"
    if (Test-Path $localeScript) { . $localeScript; $L = Get-Locale } else { $L = @{} }

    Write-Host $L["ConfGUI_Title"] -ForegroundColor Cyan

    try {
        Write-Host ($L["ConfGUI_Prep"] -f $DistroName) -ForegroundColor Yellow

        $functionScriptPath = $MyInvocation.MyCommand.ScriptBlock.File
        if ([string]::IsNullOrWhiteSpace($functionScriptPath)) {
            Write-Host $L["ConfGUI_ErrPath"] -ForegroundColor Red
            throw $L["ConfGUI_ThrPath"]
        }

        $ScriptDirectory = Split-Path $functionScriptPath -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($ScriptDirectory)) {
            Write-Host $L["ConfGUI_ErrDir"] -ForegroundColor Red
            throw $L["ConfGUI_ThrDir"]
        }
        
        $bashScriptFileName = "setup_gui_internal.sh"
        $bashScriptPath = Join-Path (Split-Path $ScriptDirectory -Parent) "Bash" $bashScriptFileName
        
        if ([string]::IsNullOrWhiteSpace($bashScriptPath)) {
            Write-Host $L["ConfGUI_ErrBashEmpty"] -ForegroundColor Red
            throw $L["ConfGUI_ThrBashEmpty"]
        }

        if (-not (Test-Path $bashScriptPath -PathType Leaf)) {
            Write-Host ($L["ConfGUI_ErrBashNF"] -f $bashScriptFileName, $bashScriptPath) -ForegroundColor Red
            Write-Host ($L["ConfGUI_CheckBash"] -f $bashScriptFileName, (Split-Path $bashScriptPath -Parent)) -ForegroundColor Yellow
            throw $L["ConfGUI_ThrBashNF"]
        }

        try {
            $guiCommandsTemplate = Get-Content -Path $bashScriptPath -Raw -ErrorAction Stop
        }
        catch {
            Write-Host ($L["ConfGUI_ErrReadBash"] -f $bashScriptPath, $_.Exception.Message) -ForegroundColor Red
            throw 
        }
                                     
        $unixGuiCommands = $guiCommandsTemplate -replace "`r`n", "`n" -replace "`r", "`n"
        
        if ($unixGuiCommands.Length -gt 0 -and $unixGuiCommands[0] -eq [char]0xFEFF) {
            $unixGuiCommands = $unixGuiCommands.Substring(1)
        }

        Write-Host $L["ConfGUI_InstallWait"] -ForegroundColor Yellow
        
        $wslGuiExecutionOutput = ""
        $wslGuiErrorOutput = ""
        $wslGuiExitCode = -1

        $psiGui = New-Object System.Diagnostics.ProcessStartInfo
        $psiGui.FileName = "wsl.exe"
        $psiGui.Arguments = "-d $DistroName --user root -- bash -s" 
        $psiGui.UseShellExecute = $false
        $psiGui.RedirectStandardInput = $true
        $psiGui.RedirectStandardOutput = $true
        $psiGui.RedirectStandardError = $true
        $psiGui.CreateNoWindow = $true 
        $psiGui.StandardInputEncoding = [System.Text.UTF8Encoding]::new($false)
        $psiGui.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
        $psiGui.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)

        $processGui = New-Object System.Diagnostics.Process
        $processGui.StartInfo = $psiGui
        
        try {
            if (-not ($processGui.Start())) {
                Write-Host $L["ConfGUI_ErrWslStart"] -ForegroundColor Red
                throw $L["ConfGUI_ThrWslStart"]
            }
        }
        catch {
            Write-Host ($L["ConfGUI_ErrWslExc"] -f $_.Exception.Message) -ForegroundColor Red
            throw 
        }

        Start-Sleep -Milliseconds 500 
        if ($processGui.HasExited) {
            Write-Host $L["ConfGUI_ErrWslPrem"] -ForegroundColor Red
            $prematureExitCode = $processGui.ExitCode
            $prematureStdOut = $processGui.StandardOutput.ReadToEnd()
            $prematureStdErr = $processGui.StandardError.ReadToEnd()
            
            if (-not [string]::IsNullOrWhiteSpace($prematureStdOut)) {
                Write-Host $L["ConfGUI_PremOut"] -ForegroundColor Yellow
                $prematureStdOut.Split([Environment]::NewLine) | ForEach-Object { Write-Host $_ }
            }
            if (-not [string]::IsNullOrWhiteSpace($prematureStdErr)) {
                Write-Host $L["ConfGUI_PremErr"] -ForegroundColor Red
                $prematureStdErr.Split([Environment]::NewLine) | ForEach-Object { Write-Host $_ -ForegroundColor Red }
            }
            Write-Host ($L["ConfGUI_PremCode"] -f $prematureExitCode) -ForegroundColor Red
            throw ($L["ConfGUI_ThrPrem"] -f $prematureExitCode)
        }

        $inputStreamGui = $processGui.StandardInput
        try {
            $inputStreamGui.Write($unixGuiCommands)
        }
        catch {
            Write-Host ($L["ConfGUI_ErrWrite"] -f $_.Exception.Message) -ForegroundColor Red
            if (!$processGui.HasExited) {
                try { $processGui.Kill() } catch { Write-Host $L["ConfGUI_WarnKill"] }
            }
            $failWriteStdOut = $processGui.StandardOutput.ReadToEnd()
            $failWriteStdErr = $processGui.StandardError.ReadToEnd()
            if (-not [string]::IsNullOrWhiteSpace($failWriteStdOut)) { Write-Host $L["ConfGUI_WriteFailOut"]; $failWriteStdOut.Split([Environment]::NewLine) | ForEach-Object { Write-Host $_ } }
            if (-not [string]::IsNullOrWhiteSpace($failWriteStdErr)) { Write-Host $L["ConfGUI_WriteFailErr"]; $failWriteStdErr.Split([Environment]::NewLine) | ForEach-Object { Write-Host $_ -ForegroundColor Red } }
            throw 
        }
        
        try {
            $inputStreamGui.Close()
        }
        catch {
            Write-Host ($L["ConfGUI_WarnClose"] -f $_.Exception.Message) -ForegroundColor Yellow
        }

        $wslGuiExecutionOutput = $processGui.StandardOutput.ReadToEnd()
        $wslGuiErrorOutput = $processGui.StandardError.ReadToEnd()
        
        $processGui.WaitForExit() 
        $wslGuiExitCode = $processGui.ExitCode 
        $processGui.Close() 

        if (-not [string]::IsNullOrWhiteSpace($wslGuiErrorOutput)) {
            Write-Host $L["ConfGUI_BashOutTitle"] -ForegroundColor DarkCyan
            $wslGuiErrorOutput.Split([Environment]::NewLine) | ForEach-Object {
                $line = $_
                if ($line -match "ERRO BASH:") {
                    Write-Host "🛑 $line" -ForegroundColor Red
                }
                elseif ($line -match "AVISO BASH:") {
                    Write-Host "⚠️ $line" -ForegroundColor Yellow
                }
                elseif ($line -match "INFO:") {
                    Write-Host "ℹ️ $line" -ForegroundColor DarkGray
                }
                else {
                    Write-Host "⚠️ $line" -ForegroundColor Yellow 
                }
            }
        }
        else { Write-Host $L["ConfGUI_NoStdErr"] -ForegroundColor DarkGray }
        
        Write-Host $L["ConfGUI_BashOutEnd"] -ForegroundColor DarkCyan
        Write-Host ($L["ConfGUI_BashExitCode"] -f $wslGuiExitCode) -ForegroundColor Cyan
        
        $strictGuiScriptFailed = $false
        if ($wslGuiExitCode -ne 0) {
            $strictGuiScriptFailed = $true
            Write-Host ($L["ConfGUI_ErrBashExit"] -f $wslGuiExitCode) -ForegroundColor Red
        }
        
        if (($wslGuiExecutionOutput -match "🛑 ERRO BASH:") -or ($wslGuiErrorOutput -match "🛑 ERRO BASH:")) {
            if (-not $strictGuiScriptFailed) { 
                Write-Host ($L["ConfGUI_WarnBashErr"] -f $wslGuiExitCode) -ForegroundColor Yellow
            }
            $strictGuiScriptFailed = $true 
        }
        
        if ($strictGuiScriptFailed) {
            throw $L["ConfGUI_ThrBashFail"]
        }

        if (($wslGuiExecutionOutput -match "⚠️  AVISO BASH:") -or ($wslGuiErrorOutput -match "⚠️  AVISO BASH:")) {
            Write-Host $L["ConfGUI_NoteBashWarn"] -ForegroundColor Cyan
        }

        Write-Host ($L["ConfGUI_SuccessPart1"] -f $DistroName) -ForegroundColor Green
        Write-Host $L["ConfGUI_SuccessPart2"] -ForegroundColor Green
        Write-Host ($L["ConfGUI_ConnectInfo1"] -f $DistroName) -ForegroundColor Cyan
        Write-Host $L["ConfGUI_ConnectInfo2"] -ForegroundColor Cyan
        Write-Host $L["ConfGUI_ConnectInfo3"] -ForegroundColor Cyan
    }
    catch {
        Write-Host ($L["ConfGUI_FatalErr"] -f $DistroName, $_.Exception.Message) -ForegroundColor Red
        if ($_.ScriptStackTrace) {
            Write-Host ($L["ConfGUI_StackTrace"] -f $_.ScriptStackTrace) -ForegroundColor DarkGray
        }
        throw 
    }
}