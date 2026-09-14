# Linux 一键部署

支持 Ubuntu 22.04/24.04、Debian 12 与 Alibaba Cloud Linux 3。服务器需要公网 IP、一个已解析到该 IP 的域名，以及开放的 TCP 80/443 端口。

## 安装

将整个 `RemotePrintRelay` 目录上传到服务器，然后运行：

```bash
cd RemotePrintRelay/deploy/linux
sudo bash install.sh print.example.com
```

安装脚本会提示设置管理员帐号、管理员密码和 `ADMIN_API_TOKEN`，安装 Docker 与 Docker Compose，将服务部署到 `/opt/remote-print-relay`，并由 Caddy 自动申请和续期 HTTPS 证书。

如果服务器的 80 端口已被宝塔 Nginx 占用，脚本会自动切换为宝塔反向代理模式。安装后，在宝塔中为域名添加反向代理，目标 URL 为 `http://127.0.0.1:17880`，并在宝塔中申请 HTTPS 证书。

客户端 API 地址填写：

```text
https://print.example.com/v1
```

## 常用运维命令

```bash
cd /opt/remote-print-relay
sudo docker compose ps
sudo docker compose logs -f relay
sudo docker compose restart
sudo docker compose down
```

## 备份

中转任务和设备信息存储在 Docker 卷 `remote-print-relay_relay-data`。升级或迁移前执行：

```bash
sudo docker run --rm -v remote-print-relay_relay-data:/data -v "$PWD":/backup alpine tar czf /backup/relay-data-backup.tgz -C /data .
```

不要把开发环境的 `RP-LOCAL-TEST` 用作生产注册码；生产环境应为每台设备分发独立注册码。
