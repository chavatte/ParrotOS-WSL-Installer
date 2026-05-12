# Copyright (c) 2026 Chavatte Security
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# Security Revision: User and Base System Configuration & Bilingual Logs

#!/bin/bash
set -e
set -x

export DEBIAN_FRONTEND=noninteractive

if locale -a 2>/dev/null | grep -q '^C.UTF-8$'; then
    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8
else
    export LANG=C
    export LC_ALL=C
fi

echo "INFO: Updating base repositories... (Atualizando repositórios base...)"
apt-get update -y || { echo "ERRO BASH: Initial apt-get update failed (Falha no apt-get update inicial)"; exit 1; }

echo "INFO: Installing locales and sudo... (Instalando locales e sudo...)"
apt-get install -y locales sudo || { echo "ERRO BASH: Failed to install locales or sudo (Falha ao instalar locales ou sudo)"; exit 1; }

echo "INFO: Generating Locale en_US.UTF-8... (Gerando Locale en_US.UTF-8...)"
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
dpkg-reconfigure --frontend=noninteractive locales || { echo "ERRO BASH: Failed to execute dpkg-reconfigure locales (Falha ao executar dpkg-reconfigure locales)"; exit 1; }

update-locale LANG=en_US.UTF-8 LANGUAGE="en_US:en" LC_MESSAGES=POSIX LC_ALL=en_US.UTF-8

export LANG=en_US.UTF-8
export LANGUAGE="en_US:en"
export LC_MESSAGES=POSIX
export LC_ALL=en_US.UTF-8

echo "INFO: Configuring securely injected credentials... (Configurando credenciais injetadas de forma segura...)"
if ! id -u "__USERNAME_PLACEHOLDER__" >/dev/null 2>&1; then
    useradd -m -G sudo,adm,cdrom,dip,plugdev -s /bin/bash "__USERNAME_PLACEHOLDER__" || \
        { echo "ERRO BASH: Failed to execute useradd (Falha ao executar useradd)"; exit 1; }

    echo "__USERNAME_PLACEHOLDER__:__PASSWORD_PLACEHOLDER__" | chpasswd || \
        { echo "ERRO BASH: Failed to execute chpasswd (Falha ao executar chpasswd)"; exit 1; }
fi

echo "INFO: Applying default WSL initialization rules... (Aplicando regras padrão de inicialização no WSL...)"
mkdir -p /etc
echo -e "[user]\ndefault = __USERNAME_PLACEHOLDER__" > /etc/wsl.conf || \
    { echo "ERRO BASH: Failed to write to /etc/wsl.conf (Falha ao escrever em /etc/wsl.conf)"; exit 1; }

apt-get upgrade -y || { echo "AVISO BASH: Some dependencies could not be updated. Continuing... (Algumas dependências não puderam ser atualizadas. Continuando...)"; }

echo "INFO: Purging apt cache to save disk space... (Purgando cache do apt para economizar espaço em disco...)"
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "INFO: Configuration script completed successfully. (Script de configuração concluído com sucesso.)"