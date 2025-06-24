#!/bin/bash
set -e

# 参数：自定义域名和UUID
DOMAIN="www.cloudflareop.xyz"
UUID="d4b40e79-4a52-4f54-8cde-633108e0d1c7"

echo -e "\n🚀 开始部署：Xray + TLS + BBR..."

# 1. 启用 BBR
echo "✅ 启用 BBR..."
echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
sysctl -p

# 2. 安装依赖
echo "🔧 安装必要依赖..."
apt update && apt install -y curl wget unzip socat cron

# 3. 安装 acme.sh
echo "📜 安装 acme.sh（证书申请工具）..."
curl https://get.acme.sh | sh
source ~/.bashrc
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

# 4. 自动申请证书
echo "📬 正在申请 TLS 证书（域名：$DOMAIN）..."
~/.acme.sh/acme.sh --issue --standalone -d $DOMAIN --keylength ec-256
mkdir -p /etc/xray
~/.acme.sh/acme.sh --install-cert -d $DOMAIN \
--key-file /etc/xray/key.pem \
--fullchain-file /etc/xray/cert.pem \
--ecc

# 5. 下载并安装 Xray-Core
echo "📦 下载并安装 Xray..."
mkdir -p /var/log/xray
curl -Lo xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o xray.zip
chmod +x xray
mv xray /usr/local/bin/xray

# 6. 写入配置文件
echo "🛠️ 写入 Xray 配置..."
cat > /etc/xray/config.json <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "$UUID",
        "flow": "xtls-rprx-vision"
      }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "tls",
      "tlsSettings": {
        "certificates": [{
          "certificateFile": "/etc/xray/cert.pem",
          "keyFile": "/etc/xray/key.pem"
        }]
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF

# 7. 创建 systemd 服务
echo "🔧 配置 Xray systemd 服务..."
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
User=root
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# 8. 启动并设置开机自启
echo "🚀 启动 Xray..."
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# 9. 输出配置信息
echo -e "\n✅ 安装完成！以下是你的连接信息："
echo "————————————————————————"
echo "地址    ：$DOMAIN"
echo "端口    ：443"
echo "协议    ：vless"
echo "UUID    ：$UUID"
echo "加密    ：none"
echo "传输方式：tcp + tls（xtls-rprx-vision）"
echo -e "\n📎 链接（推荐复制导入 v2rayN/v2rayNG）:"
echo "vless://$UUID@$DOMAIN:443?encryption=none&security=tls&type=tcp&flow=xtls-rprx-vision#CloudflareOP"
echo "————————————————————————"
