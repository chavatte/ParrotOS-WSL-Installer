# Copyright (c) 2026 Chavatte Security
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.
#
# Security Revision: Core SecOps Tools Deployment & Bilingual Logs

#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "INFO: Updating Parrot OS package indexes... (Atualizando índices de pacotes do Parrot OS...)"
apt-get update -y || { echo "ERRO BASH: 'apt-get update' failed (Falha no 'apt-get update')."; exit 1; }

echo "INFO: Installing Chavatte Core Tools Pack... (Instalando Chavatte Core Tools Pack...)"
apt-get install -y \
    curl wget git vim nano tmux htop \
    net-tools dnsutils iputils-ping \
    nmap netcat-traditional \
    python3-pip python3-venv unzip jq \
    || { echo "ERRO BASH: Failed to install essential tools (Falha ao instalar as ferramentas essenciais)."; exit 1; }

echo "INFO: Cleaning APT cache to keep the image lightweight... (Limpando cache do APT para manter a imagem leve...)"
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "INFO: Core Tools installation completed successfully. (Instalação do Core Tools concluída com sucesso.)"