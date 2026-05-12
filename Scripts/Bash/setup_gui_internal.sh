# Copyright (c) 2026 Chavatte Security
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# Security Revision: XRDP Hardening (TLS), WSL X11 Fix, VNC Backend Fallback & Bilingual Logs

#!/bin/bash
set -e
set -x

export DEBIAN_FRONTEND=noninteractive

echo "INFO: Starting package update and graphics engine installation... (Iniciando atualização de pacotes e instalação do motor gráfico...)"
apt-get update -y || { echo "ERRO BASH: 'apt-get update' failed (Falha no 'apt-get update')."; exit 1; }
apt-get install -y xrdp parrot-desktop-mate dbus-x11 tigervnc-standalone-server || { echo "ERRO BASH: Failed to install GUI dependencies (Falha ao instalar dependências da GUI)."; exit 1; }

if ! getent group ssl-cert | grep -qw xrdp; then
    adduser xrdp ssl-cert
fi

XF_XRDP_INI="/etc/xrdp/xrdp.ini"
SESMAN_INI="/etc/xrdp/sesman.ini"

if [ -f "$XF_XRDP_INI" ]; then
    echo "INFO: Applying Hardening to xrdp.ini... (Aplicando Hardening no xrdp.ini...)"
    sed -i 's/^security_layer=.*/security_layer=tls/' "$XF_XRDP_INI"
    sed -i 's/^crypt_level=.*/crypt_level=high/' "$XF_XRDP_INI"
    sed -i '/^\[Xorg\]/,/^\[Xvnc\]/ { /^\[Xvnc\]/!d }' "$XF_XRDP_INI"
fi

if [ -f "$SESMAN_INI" ]; then
    echo "INFO: Applying Hardening to sesman.ini (Preventing Root)... (Aplicando Hardening no sesman.ini (Impedindo Root)...)"
    sed -i 's/^AllowRootLogin=.*/AllowRootLogin=false/' "$SESMAN_INI"
fi

echo "allowed_users=anybody" > /etc/X11/Xwrapper.config || true

STARTWM_SH="/etc/xrdp/startwm.sh"
echo "INFO: Rebuilding startwm.sh to force MATE rendering... (Reconstruindo startwm.sh para forçar a renderização do MATE...)"

cat << 'EOF' > "$STARTWM_SH"
#!/bin/sh
if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi

export XDG_SESSION_DESKTOP=mate
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=MATE
exec dbus-run-session -- mate-session
EOF

chmod +x "$STARTWM_SH"

if command -v service &> /dev/null; then
    echo "INFO: Restarting XRDP services... (Reiniciando serviços do XRDP...)"
    sudo service xrdp stop || true
    sleep 2
    sudo service xrdp start || true
    sleep 2
    
    if sudo service xrdp status | grep -Eiq "active \(running|is running\)"; then
        echo "INFO: XRDP service active and successfully hardened. (Serviço XRDP ativo e blindado com sucesso.)"
    else
        echo "AVISO BASH: XRDP service did not confirm status after restart. Check WSL logs. (O serviço XRDP não confirmou o status após o restart. Verifique os logs do WSL.)"
    fi
else
    echo "ERRO BASH: Command 'service' not found (Comando 'service' não encontrado)."
fi