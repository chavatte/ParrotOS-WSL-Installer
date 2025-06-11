# Copyright (c) 2025 João Carlos Chavatte (DEV Chavatte)
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.

function Set-ParrotGUI {
    [CmdletBinding()]
    param(
        [string]$DistroName = "ParrotOS"
    )

    Write-Host "`n=== 🖼️ CONFIGURANDO AMBIENTE GRÁFICO (XRDP + MATE) === " -ForegroundColor Cyan

    try {
        Write-Host "ℹ️ Preparando para configurar o ambiente gráfico no '$DistroName'..." -ForegroundColor Yellow

        $functionScriptPath = $MyInvocation.MyCommand.ScriptBlock.File
        if ([string]::IsNullOrWhiteSpace($functionScriptPath)) {
            Write-Host "🛑 ERRO PS: Não foi possível determinar o caminho do script da função via \$MyInvocation.MyCommand.ScriptBlock.File." -ForegroundColor Red
            throw "Falha ao determinar o caminho do script da função."
        }

        $ScriptDirectory = Split-Path $functionScriptPath -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($ScriptDirectory)) {
            Write-Host "🛑 ERRO PS: Não foi possível determinar o diretório do script da função (ScriptDirectory está vazio ou nulo)." -ForegroundColor Red
            throw "Falha ao determinar o diretório do script da função."
        }
        
        $bashScriptFileName = "setup_gui_internal.sh"
        $bashScriptPath = Join-Path (Split-Path $ScriptDirectory -Parent) "Bash" $bashScriptFileName
        
        if ([string]::IsNullOrWhiteSpace($bashScriptPath)) {
            Write-Host "🛑 ERRO PS: Caminho para o script Bash da GUI (\$bashScriptPath) está vazio ou nulo APÓS Join-Path." -ForegroundColor Red
            throw "Caminho para o script Bash da GUI é inválido."
        }

        if (-not (Test-Path $bashScriptPath -PathType Leaf)) {
            Write-Host "🛑 ERRO PS: Script de configuração da GUI ('$bashScriptFileName') NÃO ENCONTRADO ou não é um arquivo em: '$bashScriptPath'" -ForegroundColor Red
            Write-Host "   Verifique se o arquivo '$bashScriptFileName' existe em '$(Split-Path $bashScriptPath -Parent)'." -ForegroundColor Yellow
            throw "Script de configuração da GUI não encontrado."
        }

        try {
            $guiCommandsTemplate = Get-Content -Path $bashScriptPath -Raw -ErrorAction Stop
        }
        catch {
            Write-Host "🛑 ERRO PS: Falha ao ler o arquivo de script Bash da GUI '$bashScriptPath'. Exceção: $($_.Exception.Message)" -ForegroundColor Red
            throw 
        }
                                     
        $unixGuiCommands = $guiCommandsTemplate -replace "`r`n", "`n" -replace "`r", "`n"
        
        if ($unixGuiCommands.Length -gt 0 -and $unixGuiCommands[0] -eq [char]0xFEFF) {
            $unixGuiCommands = $unixGuiCommands.Substring(1)
        }

        Write-Host "⏳ Instalando e configurando XRDP e MATE desktop (isso pode levar vários minutos)..." -ForegroundColor Yellow
        
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
                Write-Host "🛑 ERRO PS: Falha ao iniciar o processo wsl.exe para configuração da GUI (Start() retornou false)." -ForegroundColor Red
                throw "Falha ao iniciar wsl.exe para GUI (Start() retornou false)."
            }
        }
        catch {
            Write-Host "🛑 ERRO PS: Exceção ao tentar iniciar o processo wsl.exe para configuração da GUI. $($_.Exception.Message)" -ForegroundColor Red
            throw 
        }

        Start-Sleep -Milliseconds 500 
        if ($processGui.HasExited) {
            Write-Host "🛑 ERRO PS: Processo wsl.exe para GUI terminou inesperadamente logo após o início." -ForegroundColor Red
            $prematureExitCode = $processGui.ExitCode
            $prematureStdOut = $processGui.StandardOutput.ReadToEnd()
            $prematureStdErr = $processGui.StandardError.ReadToEnd()
            
            if (-not [string]::IsNullOrWhiteSpace($prematureStdOut)) {
                Write-Host "--- Saída Prematura STDOUT (GUI Process) ---" -ForegroundColor Yellow
                $prematureStdOut.Split([Environment]::NewLine) | ForEach-Object { Write-Host $_ }
            }
            if (-not [string]::IsNullOrWhiteSpace($prematureStdErr)) {
                Write-Host "--- Saída Prematura STDERR (GUI Process) ---" -ForegroundColor Red
                $prematureStdErr.Split([Environment]::NewLine) | ForEach-Object { Write-Host $_ -ForegroundColor Red }
            }
            Write-Host "Código de Saída Prematuro (GUI Process): $prematureExitCode" -ForegroundColor Red
            throw "Processo wsl.exe para GUI terminou prematuramente com código $prematureExitCode."
        }

        $inputStreamGui = $processGui.StandardInput
        try {
            $inputStreamGui.Write($unixGuiCommands)
        }
        catch {
            Write-Host "🛑 ERRO PS: Exceção durante inputStreamGui.Write() para configuração da GUI. Mensagem: $($_.Exception.Message)" -ForegroundColor Red
            if (!$processGui.HasExited) {
                try { $processGui.Kill() } catch { Write-Host "⚠️ AVISO: Falha ao tentar finalizar o processo GUI após erro de escrita." }
            }
            $failWriteStdOut = $processGui.StandardOutput.ReadToEnd()
            $failWriteStdErr = $processGui.StandardError.ReadToEnd()
            if (-not [string]::IsNullOrWhiteSpace($failWriteStdOut)) { Write-Host "--- STDOUT (GUI) após falha no Write ---"; $failWriteStdOut.Split([Environment]::NewLine) | ForEach-Object { Write-Host $_ } }
            if (-not [string]::IsNullOrWhiteSpace($failWriteStdErr)) { Write-Host "--- STDERR (GUI) após falha no Write ---"; $failWriteStdErr.Split([Environment]::NewLine) | ForEach-Object { Write-Host $_ -ForegroundColor Red } }
            throw 
        }
        
        try {
            $inputStreamGui.Close()
        }
        catch {
            Write-Host "⚠️  AVISO PS: Exceção durante inputStreamGui.Close() para configuração da GUI. Mensagem: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        $wslGuiExecutionOutput = $processGui.StandardOutput.ReadToEnd()
        $wslGuiErrorOutput = $processGui.StandardError.ReadToEnd()
        
        $processGui.WaitForExit() 
        $wslGuiExitCode = $processGui.ExitCode 
        $processGui.Close() 

        if (-not [string]::IsNullOrWhiteSpace($wslGuiErrorOutput)) {
            Write-Host "--- 📜 Saída de Erros/Avisos/Infos da Configuração da GUI no WSL ---" -ForegroundColor DarkCyan
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
        else { Write-Host "(Nenhuma saída de erro padrão)" -ForegroundColor DarkGray }
        Write-Host "--- Fim da Saída Erros/Avisos/Infos ---" -ForegroundColor DarkCyan
        Write-Host "ℹ️ Código de saída do script Bash da GUI: $wslGuiExitCode" -ForegroundColor Cyan
        
        $strictGuiScriptFailed = $false
        if ($wslGuiExitCode -ne 0) {
            $strictGuiScriptFailed = $true
            Write-Host "🛑 ERRO PS: O script de configuração da GUI dentro do WSL terminou com o código de saída: $wslGuiExitCode." -ForegroundColor Red
        }
        
        if (($wslGuiExecutionOutput -match "🛑 ERRO BASH:") -or ($wslGuiErrorOutput -match "🛑 ERRO BASH:")) {
            if (-not $strictGuiScriptFailed) { 
                Write-Host "⚠️  AVISO PS: Foram detectados '🛑 ERRO BASH:' na saída do script de configuração da GUI, embora o código de saída tenha sido $wslGuiExitCode. Tratando como falha." -ForegroundColor Yellow
            }
            $strictGuiScriptFailed = $true 
        }
        
        if ($strictGuiScriptFailed) {
            throw "O script de configuração da GUI dentro do WSL falhou ou relatou erros. Verifique a saída detalhada acima." 
        }

        if (($wslGuiExecutionOutput -match "⚠️  AVISO BASH:") -or ($wslGuiErrorOutput -match "⚠️  AVISO BASH:")) {
            Write-Host "ℹ️ NOTA PS: Foram detectados '⚠️  AVISO BASH:' na saída do script de configuração da GUI (visível acima). A configuração principal pode estar OK." -ForegroundColor Cyan
        }

        Write-Host "✅ Ambiente gráfico (XRDP + MATE) parece ter sido configurado pela distribuição '$DistroName' (script PowerShell concluiu)." -ForegroundColor Green
        Write-Host "   A funcionalidade real dependerá da execução interna do script Bash (verifique a saída completa acima)." -ForegroundColor Green
        Write-Host "ℹ️  Para conectar, use a opção no menu principal, execute 'Connect-ParrotGUI -DistroName $DistroName' ou conecte-se manualmente via RDP:" -ForegroundColor Cyan
        Write-Host "    Endereço: (O IP da VM WSL será detectado por Connect-ParrotGUI)" -ForegroundColor Cyan
        Write-Host "    Porta: 3389 (porta padrão XRDP)" -ForegroundColor Cyan
    }
    catch {
        Write-Host "🛑 ERRO FATAL PS: Falha crítica ao configurar o ambiente gráfico para '$DistroName'. Mensagem: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ScriptStackTrace) {
            Write-Host "   Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
        }
        throw 
    }
}