# Copyright (c) 2026 Chavatte Security
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.
#
# Security Revision: Enhanced IP extraction, Secure RDP initialization & i18n Root execution

<#
.SYNOPSIS
    [EN] Securely connects to the Parrot OS graphical environment (GUI) via RDP.
    [PT] Conecta-se de forma segura ao ambiente gráfico (GUI) do Parrot OS via RDP.

.DESCRIPTION
    [EN] This script automates the connection process to a GUI in WSL. It verifies if the XRDP service 
    is running, starting it if necessary under Chavatte Security policies. It then dynamically retrieves 
    the IP address of the 'eth0' interface and launches the Remote Desktop client (mstsc.exe).
    
    [PT] Este script automatiza o processo de conexão a uma GUI no WSL. Ele verifica se o serviço XRDP está
    rodando e o inicia se necessário, aplicando políticas de segurança. Em seguida, obtém o endereço IP 
    dinamicamente e inicia o cliente de Conexão de Área de Trabalho Remota (mstsc.exe).

.PARAMETER DistroName
    [EN] The name of your WSL distribution where the GUI is installed. Default is "ParrotOS".
    [PT] O nome da sua distribuição WSL. O valor padrão é "ParrotOS".

.PARAMETER Port
    [EN] The TCP port on which the XRDP service is listening. Default is 3389.
    [PT] A porta TCP na qual o serviço XRDP está escutando. O valor padrão é 3389.

.EXAMPLE
    PS C:\> Connect-ParrotGUI
    [EN] Attempts to connect to the default 'ParrotOS' distribution on port 3389.
    [PT] Tenta se conectar à distribuição padrão 'ParrotOS' na porta padrão 3389.

.LINK
    https://github.com/chavatte/ParrotOS-WSL-Installer
#>
function Connect-ParrotGUI {
    [CmdletBinding()]
    param(
        [string]$DistroName = "ParrotOS",
        [int]$Port = 3389
    )

    $localeScript = Join-Path $PSScriptRoot "Get-Locale.ps1"
    if (Test-Path $localeScript) { . $localeScript; $L = Get-Locale } else { $L = @{} }

    Write-Host $L["ConnGUI_Title"] -ForegroundColor Cyan
    Write-Host ($L["ConnGUI_InitConn"] -f $DistroName, $Port) -ForegroundColor Yellow

    try {
        Write-Host ($L["ConnGUI_AuditXRDP"] -f $DistroName) -ForegroundColor Yellow
        $statusOutput = wsl -d $DistroName -u root -- service xrdp status

        if ($statusOutput -match "is running") {
            Write-Host $L["ConnGUI_XRDPActive"] -ForegroundColor Green
        }
        else {
            Write-Host $L["ConnGUI_XRDPStart"] -ForegroundColor Yellow
            wsl -d $DistroName -u root -- service xrdp start | Out-Null
            Start-Sleep -Seconds 3 
            
            if ((wsl -d $DistroName -u root -- service xrdp status) -match "is running") {
                Write-Host $L["ConnGUI_XRDPSuccess"] -ForegroundColor Green
            }
            else {
                Write-Host $L["ConnGUI_XRDPWarn"] -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host $L["ConnGUI_XRDPErr"] -ForegroundColor Red
        return
    }

    Write-Host $L["ConnGUI_ResolvIP"] -ForegroundColor Yellow
    $ip = $null 
    try {
        $ipOutputLines = wsl -d $DistroName -u root -- ip -4 addr show eth0
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host ($L["ConnGUI_IPShowErr"] -f $DistroName) -ForegroundColor Red
        }
        else {
            foreach ($line in $ipOutputLines) {
                if ($line -match 'inet\s+([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/') {
                    $ip = $matches[1]
                    break 
                }
            }
        }
    }
    catch {
        Write-Host ($L["ConnGUI_RouteErr"] -f $_.Exception.Message) -ForegroundColor Red
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($ip)) {
        Write-Host ($L["ConnGUI_IPFound"] -f $ip) -ForegroundColor Green
        Write-Host ($L["ConnGUI_TunnelWait"] -f $ip, $Port) -ForegroundColor Cyan
        try {
            Start-Process mstsc.exe -ArgumentList "/v:$ip`:$Port /f" -ErrorAction Stop 
            Write-Host $L["ConnGUI_RDPInvoke"] -ForegroundColor Green
        }
        catch {
            Write-Host $L["ConnGUI_RDPFail"] -ForegroundColor Red
        }
    }
    else {
        Write-Host $L["ConnGUI_NetUnreach"] -ForegroundColor Red
    }
}