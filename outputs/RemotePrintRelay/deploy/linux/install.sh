#!/usr/bin/env bash
set -euo pipefail

domain="${1:-}"
if [[ -z "$domain" ]]; then
  echo "用法：sudo bash install.sh print.example.com"
  exit 1
fi
read -r -p "管理员帐号: " admin_username
read -r -s -p "管理员密码: " admin_password
echo
read -r -s -p "注册码生成密钥 (ADMIN_API_TOKEN): " admin_token
echo
if [[ -z "$admin_username" || -z "$admin_password" || -z "$admin_token" ]]; then
  echo "管理员帐号、密码和注册码生成密钥均不能为空。"
  exit 1
fi
if [[ $EUID -ne 0 ]]; then
  echo "请以 root 或 sudo 运行。"
  exit 1
fi
if [[ ! -f /etc/debian_version ]]; then
  echo "仅支持 Ubuntu 22.04/24.04 或 Debian 12。"
  exit 1
fi

apt-get update
apt-get install -y ca-certificates curl docker.io docker-compose-plugin
systemctl enable --now docker

install_root="/opt/remote-print-relay"
mkdir -p "$install_root"
cp -R "$(cd "$(dirname "$0")/../.." && pwd)" "$install_root/app"
cp "$(dirname "$0")/docker-compose.yml" "$install_root/docker-compose.yml"
cp "$(dirname "$0")/Caddyfile" "$install_root/Caddyfile"
cat > "$install_root/.env" <<EOF
PRINT_DOMAIN=$domain
PUBLIC_BASE_URL=https://$domain
ADMIN_USERNAME=$admin_username
ADMIN_PASSWORD=$admin_password
ADMIN_API_TOKEN=$admin_token
EOF
chmod 600 "$install_root/.env"

cd "$install_root"
docker compose up -d --build
sleep 3
docker compose ps
echo "部署完成：https://$domain"
echo "请确保 DNS 已指向本机公网 IP，并开放 TCP 80、443。"
