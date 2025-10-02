#!/usr/bin/env bash
set -euo pipefail

# install_zabbix_agent.sh
# Instala e configura Zabbix Agent (Linux)
# Uso: sudo bash scripts/install_zabbix_agent.sh <IP_ZABBIX_PROXY> <HOSTNAME_AGENT>

IP_PROXY="${1:-}"
HOSTNAME_AGENT="${2:-Agente-Linux}"

if [[ -z "$IP_PROXY" ]]; then
  echo "Uso: $0 <IP_ZABBIX_PROXY> <HOSTNAME_AGENT>"
  exit 1
fi

echo "[+] Instalando pacotes..."
apt update
DEBIAN_FRONTEND=noninteractive apt install -y zabbix-agent

echo "[+] Configurando /etc/zabbix/zabbix_agentd.conf"
sed -i "s/^#\?Server=.*/Server=${IP_PROXY}/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^#\?Hostname=.*/Hostname=${HOSTNAME_AGENT}/" /etc/zabbix/zabbix_agentd.conf

echo "[+] (Opcional) Habilitando TLS PSK autogerado"
if [[ ! -f /etc/zabbix/psk.key ]]; then
  openssl rand -hex 32 | tee /etc/zabbix/psk.key >/dev/null
fi
chmod 600 /etc/zabbix/psk.key
{
  echo "TLSConnect=psk"
  echo "TLSAccept=psk"
  echo "TLSPSKIdentity=agent-psk-id"
  echo "TLSPSKFile=/etc/zabbix/psk.key"
} >> /etc/zabbix/zabbix_agentd.conf

echo "[+] Habilitando e iniciando serviço"
systemctl enable zabbix-agent
systemctl restart zabbix-agent
systemctl --no-pager status zabbix-agent | head -n 20

echo "[✔] Agent pronto."
