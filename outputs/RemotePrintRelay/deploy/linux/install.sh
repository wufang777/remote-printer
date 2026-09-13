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
if [[ -f /etc/debian_version ]]; then
  package_manager="apt-get"
elif [[ -f /etc/redhat-release ]] || grep -q '^ID="alinux"' /etc/os-release; then
  package_manager="dnf"
else
  echo "仅支持 Ubuntu/Debian 或 Alibaba Cloud Linux 3。"
  exit 1
fi

if [[ "$package_manager" == "apt-get" ]]; then
  apt-get update
  apt-get install -y ca-certificates curl git docker.io docker-compose-plugin
else
  dnf install -y ca-certificates curl git
  if rpm -q docker-ce-cli >/dev/null 2>&1; then
    dnf install -y docker-ce containerd.io
  else
    dnf install -y docker
  fi
  if ! docker compose version >/dev/null 2>&1; then
    architecture="$(uname -m)"
    case "$architecture" in
      x86_64) compose_architecture="x86_64" ;;
      aarch64) compose_architecture="aarch64" ;;
      *) echo "不支持的 CPU 架构：$architecture"; exit 1 ;;
    esac
    install -d -m 0755 /usr/local/lib/docker/cli-plugins
    curl -fsSL --http1.1 "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$compose_architecture" -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  fi
fi
systemctl enable --now docker
docker compose version

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
