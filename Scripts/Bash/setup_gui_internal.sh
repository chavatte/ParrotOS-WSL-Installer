# Copyright (c) 2025 João Carlos Chavatte (DEV Chavatte)
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.

#!/bin/bash
set -e
set -x

export DEBIAN_FRONTEND=noninteractive

apt-get update -y || { echo "ERRO BASH: Falha no 'apt-get update'."; exit 1; }

apt-get install -y xrdp || { echo "ERRO BASH: Falha ao instalar xrdp."; exit 1; }

if ! getent group ssl-cert | grep -qw xrdp; then
    adduser xrdp ssl-cert
    if getent group ssl-cert | grep -qw xrdp; then
        echo "INFO: Usuário xrdp adicionado ao grupo ssl-cert."
    else
        echo "AVISO BASH: Falha ao confirmar a adição do usuário xrdp ao grupo ssl-cert."
    fi
else
    echo "INFO: Usuário xrdp já é membro do grupo ssl-cert."
fi

apt-get install -y parrot-desktop-mate || { echo "ERRO BASH: Falha ao instalar parrot-desktop-mate."; exit 1; }

XF_XRDP_INI="/etc/xrdp/xrdp.ini"
if [ -f "$XF_XRDP_INI" ]; then
    if grep -Eq "^\s*port\s*=\s*3389" "$XF_XRDP_INI"; then
        echo "INFO: Porta do XRDP está configurada como padrão (3389) em $XF_XRDP_INI."
    elif grep -Eq "^\s*port\s*=" "$XF_XRDP_INI"; then
        PORT_VALUE=$(grep -Eo "^\s*port\s*=\s*[0-9]+" "$XF_XRDP_INI" | grep -Eo "[0-9]+")
        echo "AVISO BASH: A porta do XRDP está definida como '$PORT_VALUE' em $XF_XRDP_INI, não o padrão 3389."
    else
        echo "AVISO BASH: A linha 'port=' não foi encontrada em $XF_XRDP_INI. XRDP usará seu padrão compilado (geralmente 3389)."
    fi
else
    echo "AVISO BASH: Arquivo $XF_XRDP_INI não encontrado. Não foi possível verificar a porta. XRDP usará seu padrão compilado."
fi

if command -v service &> /dev/null; then
    if sudo service xrdp restart; then
        echo "INFO: Comando 'sudo service xrdp restart' executado."
        sleep 2
        if sudo service xrdp status | grep -Eiq "active \(running|is running\)"; then
            echo "INFO: Serviço XRDP está ativo e rodando."
        else
            echo "AVISO BASH: Serviço XRDP pode não estar rodando após tentativa de reinício. Verifique o status manualmente com 'sudo service xrdp status'."
        fi
    else
        echo "ERRO BASH: Falha ao executar 'sudo service xrdp restart'. O serviço pode não ter reiniciado corretamente."
    fi
else
    echo "ERRO BASH: Comando 'service' não encontrado. Não foi possível reiniciar XRDP."
fi