#!/usr/bin/env bash
set -euo pipefail

# install_zabbix_proxy.sh
# Instala e configura Zabbix Proxy (MySQL/MariaDB)
# Uso: sudo bash scripts/install_zabbix_proxy.sh <IP_ZABBIX_SERVER> <HOSTNAME_PROXY> [DB_PASS]

IP_SERVER="${1:-}"
HOSTNAME_PROXY="${2:-Proxy-Remoto}"
DB_PASS="${3:-SenhaProxy!}"

if [[ -z "$IP_SERVER" ]]; then
  echo "Uso: $0 <IP_ZABBIX_SERVER> <HOSTNAME_PROXY> [DB_PASS]"
  exit 1
fi

echo "[+] Instalando pacotes..."
apt update
DEBIAN_FRONTEND=noninteractive apt install -y zabbix-proxy-mysql zabbix-sql-scripts mariadb-client

echo "[+] Criando banco (execute no servidor do MySQL se não for local)"
mysql -uroot -p -e "CREATE DATABASE IF NOT EXISTS zabbix_proxy CHARACTER SET utf8mb4 COLLATE utf8mb4_bin; CREATE USER IF NOT EXISTS 'zbxproxy'@'localhost' IDENTIFIED BY '${DB_PASS}'; GRANT ALL PRIVILEGES ON zabbix_proxy.* TO 'zbxproxy'@'localhost'; FLUSH PRIVILEGES;" || true

echo "[+] Importando schema (pode demorar)..."
zcat /usr/share/zabbix-sql-scripts/mysql/proxy.sql.gz | mysql -uzbxproxy -p"${DB_PASS}" zabbix_proxy

echo "[+] Configurando /etc/zabbix/zabbix_proxy.conf"
sed -i "s/^#\?Server=.*/Server=${IP_SERVER}/" /etc/zabbix/zabbix_proxy.conf
sed -i "s/^#\?Hostname=.*/Hostname=${HOSTNAME_PROXY}/" /etc/zabbix/zabbix_proxy.conf
sed -i "s/^#\?DBName=.*/DBName=zabbix_proxy/" /etc/zabbix/zabbix_proxy.conf
sed -i "s/^#\?DBUser=.*/DBUser=zbxproxy/" /etc/zabbix/zabbix_proxy.conf
if grep -q '^#\?DBPassword=' /etc/zabbix/zabbix_proxy.conf; then
  sed -i "s/^#\?DBPassword=.*/DBPassword=${DB_PASS}/" /etc/zabbix/zabbix_proxy.conf
else
  echo "DBPassword=${DB_PASS}" >> /etc/zabbix/zabbix_proxy.conf
fi

echo "[+] (Opcional) Habilitando TLS PSK autogerado"
if [[ ! -f /etc/zabbix/psk.key ]]; then
  openssl rand -hex 32 | tee /etc/zabbix/psk.key >/dev/null
fi
chmod 600 /etc/zabbix/psk.key
{
  echo "TLSConnect=psk"
  echo "TLSAccept=psk"
  echo "TLSPSKIdentity=proxy-psk-id"
  echo "TLSPSKFile=/etc/zabbix/psk.key"
} >> /etc/zabbix/zabbix_proxy.conf

echo "[+] Habilitando e iniciando serviço"
systemctl enable zabbix-proxy
systemctl restart zabbix-proxy
systemctl --no-pager status zabbix-proxy | head -n 20

echo "[✔] Proxy pronto."
