# LAB — Zabbix Proxy & Agent (com TLS)

> Objetivo: instalar e configurar **Zabbix Proxy** e **Zabbix Agent** para monitoramento distribuído com comunicação segura (TLS).

## Ambiente
- 1x Zabbix Server
- 1x VM para **Proxy** (ex.: Debian/Ubuntu/Kali)
- 1x VM para **Agente** (Linux de teste; Windows opcional)

## Passo a passo

### 1) Proxy
1. Pacotes:
   ```bash
   sudo apt update
   sudo apt install -y zabbix-proxy-mysql zabbix-sql-scripts mariadb-client
   ```
2. Banco do Proxy (no MySQL/MariaDB que será usado pelo Proxy):
   ```sql
   CREATE DATABASE zabbix_proxy CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
   CREATE USER 'zbxproxy'@'localhost' IDENTIFIED BY 'SenhaProxy!';
   GRANT ALL PRIVILEGES ON zabbix_proxy.* TO 'zbxproxy'@'localhost';
   FLUSH PRIVILEGES;
   ```
3. Import do schema:
   ```bash
   zcat /usr/share/zabbix-sql-scripts/mysql/proxy.sql.gz | mysql -uzbxproxy -p zabbix_proxy
   ```
4. `/etc/zabbix/zabbix_proxy.conf` (exemplo):
   ```ini
   Server=<IP_Zabbix_Server>
   Hostname=Proxy-Remoto
   DBName=zabbix_proxy
   DBUser=zbxproxy
   DBPassword=SenhaProxy!
   ```
5. Iniciar:
   ```bash
   sudo systemctl enable zabbix-proxy
   sudo systemctl restart zabbix-proxy
   sudo systemctl status zabbix-proxy --no-pager
   ```

### 2) Agent (Linux)
1. Pacotes:
   ```bash
   sudo apt update
   sudo apt install -y zabbix-agent
   ```
2. `/etc/zabbix/zabbix_agentd.conf` (exemplo):
   ```ini
   Server=<IP_Zabbix_Proxy>
   Hostname=Agente-Linux
   ```
3. Iniciar:
   ```bash
   sudo systemctl enable zabbix-agent
   sudo systemctl restart zabbix-agent
   sudo systemctl status zabbix-agent --no-pager
   ```

### 3) TLS (PSK)
1. Gerar chave PSK (no Server/Proxy/Agent conforme estratégia):
   ```bash
   openssl rand -hex 32 | sudo tee /etc/zabbix/psk.key >/dev/null
   ```
2. Definir um **PSK identity** (ID) e aplicar nos arquivos de conf:
   - Proxy (`zabbix_proxy.conf`):
     ```ini
     TLSConnect=psk
     TLSAccept=psk
     TLSPSKIdentity=proxy-psk-id
     TLSPSKFile=/etc/zabbix/psk.key
     ```
   - Agent (`zabbix_agentd.conf`):
     ```ini
     TLSConnect=psk
     TLSAccept=psk
     TLSPSKIdentity=agent-psk-id
     TLSPSKFile=/etc/zabbix/psk.key
     ```
3. Liberar portas (ex.: 10051/TCP do Server; 10051 Proxy⇄Server; 10050 Agent⇄Proxy).

### 4) Frontend
- **Adicionar Proxy** em *Administration → Proxies*.
- **Cadastrar Hosts** apontando para o Proxy.
- Validar *Latest data* e *Availability*.


## Troubleshooting
- Logs:
  - `journalctl -u zabbix-proxy -e`
  - `journalctl -u zabbix-agent -e`
- Testes:
  - `zabbix_get -s <IP_Agent> -k agent.ping` (via Proxy/Server)
  - Ajuste de DNS/firewall, checar `ServerActive` se usar agente ativo.

> Baseado no roteiro do PDF do lab (complementado com boas práticas e automações).
