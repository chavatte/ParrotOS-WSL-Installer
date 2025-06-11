# Copyright (c) 2025 João Carlos Chavatte (DEV Chavatte)
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.

<#
.SYNOPSIS
    Conecta-se ao ambiente gráfico (GUI) de uma distribuição WSL via RDP.

.DESCRIPTION
    Este script automatiza o processo de conexão a uma GUI no WSL. Ele primeiro verifica se o serviço XRDP está
    rodando na distribuição especificada e o inicia se necessário. Em seguida, obtém o endereço IP da
    interface 'eth0' da distribuição e inicia o cliente de Conexão de Área de Trabalho Remota (mstsc.exe).

.PARAMETER DistroName
    O nome da sua distribuição WSL na qual o ambiente gráfico está instalado.
    O valor padrão é "ParrotOS".

.PARAMETER Port
    A porta TCP na qual o serviço XRDP está escutando dentro da distribuição.
    O valor padrão é 3389.

.EXAMPLE
    PS C:\> Connect-ParrotGUI

    Tenta se conectar à distribuição padrão 'ParrotOS' na porta padrão 3389.

.EXAMPLE
    PS C:\> Connect-ParrotGUI -DistroName "Ubuntu-GUI" -Port 3390

    Tenta se conectar a uma distribuição chamada "Ubuntu-GUI" em uma instância do XRDP rodando na porta 3390.

.LINK
    https://github.com/chavatte/ParrotOS-WSL-Installer
#>
function Connect-ParrotGUI {
    [CmdletBinding()]
    param(
        [string]$DistroName = "ParrotOS",
        [int]$Port = 3389
    )

    Write-Host "`n=== 🖥️  CONECTANDO AO PARROT OS GUI VÍA RDP === " -ForegroundColor Cyan
    Write-Host "ℹ️ Iniciando conexão à GUI do '$DistroName' na porta $Port..." -ForegroundColor Yellow

    try {
        Write-Host "🛠️  Verificando o status do serviço XRDP em '$DistroName'..." -ForegroundColor Yellow
        $statusOutput = wsl -d $DistroName -- sudo service xrdp status

        if ($statusOutput -match "is running") {
            Write-Host "✅ Serviço XRDP já está ativo." -ForegroundColor Green
        }
        else {
            Write-Host "ℹ️ Serviço XRDP não está ativo. Tentando iniciar (pode ser necessário inserir a senha no terminal WSL)..." -ForegroundColor Yellow
            wsl -d $DistroName -- sudo service xrdp start
            Start-Sleep -Seconds 3 
            
            $statusOutputAfterStart = wsl -d $DistroName -- sudo service xrdp status
            if ($statusOutputAfterStart -match "is running") {
                Write-Host "✅ Serviço XRDP iniciado com sucesso." -ForegroundColor Green
            }
            else {
                Write-Host "⚠️  AVISO: Falha ao confirmar o status do XRDP após a inicialização. A conexão pode falhar." -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "🛑 ERRO: Falha ao tentar verificar/iniciar o serviço XRDP." -ForegroundColor Red
        Write-Host "   Certifique-se de que o XRDP está instalado na distribuição '$DistroName'." -ForegroundColor Yellow
    }

    Write-Host "🛠️  Obtendo endereço IP para '$DistroName' (via interface eth0)..." -ForegroundColor Yellow
    $ip = $null 
    try {
        $ipOutputLines = wsl -d $DistroName -- ip -4 addr show eth0
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "🛑 ERRO PS: Falha ao executar 'ip addr show eth0' em '$DistroName'." -ForegroundColor Red
        }
        else {
            foreach ($line in $ipOutputLines) {
                if ($line -match 'inet\s+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/') {
                    $ip = $matches[1]
                    break 
                }
            }
        }
    }
    catch {
        Write-Host "🛑 ERRO PS: Falha crítica ao executar o comando para obter o IP. $($_.Exception.Message)" -ForegroundColor Red
    }

    if (-not [string]::IsNullOrWhiteSpace($ip)) {
        Write-Host "✅ Endereço IP encontrado para '$DistroName': $ip" -ForegroundColor Green
        Write-Host "⏳ Iniciando Conexão de Área de Trabalho Remota para $ip`:$Port (tela cheia)..." -ForegroundColor Cyan
        try {
            Start-Process mstsc.exe -ArgumentList "/v:$ip`:$Port /f" -ErrorAction Stop 
            Write-Host "✅ Comando para iniciar RDP enviado." -ForegroundColor Green
        }
        catch {
            Write-Host "🛑 ERRO PS: Falha ao iniciar 'mstsc.exe' (Conexão de Área de Trabalho Remota)." -ForegroundColor Red
        }
    }
    else {
        Write-Host "🛑 ERRO: Não foi possível obter o endereço IP para '$DistroName' via interface 'eth0'." -ForegroundColor Red
        Write-Host "   Verifique se a distribuição WSL está em execução e se a rede está funcionando." -ForegroundColor Yellow
    }
}