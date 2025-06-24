#!/bin/bash
echo "🚀 正在安装 BBR + Xray-core + TLS（VLESS 模式）"

# 权限检查
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请使用 root 用户运行脚本"
  exit 1
fi

# 更新系统和安装依赖
apt update -y && apt install -y curl unzip socat lsb-release cron

# 启用 BBR
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 安装 acme.sh 申请 TLS 证书
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --register-account -m your@email.com
~/.acme.sh/acme.sh --issue -d www.cloudflareop.xyz --standalone
~/.acme.sh/acme.sh --install-cert -d www.cloudflareop.xyz \
  --key-file /etc/xray/key.pem \
  --fullchain-file /etc/xray/cert.pem

# 安装 Xray-core
mkdir -p /usr/local/xray && cd /usr/local/xray
XRAY_VER=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -L -o xray.zip https://github.com/XTLS/Xray-core/releases/download/${XRAY_VER}/Xray-linux-64.zip
unzip xray.zip && rm xray.zip
chmod +x xray

# 写入配置文件
cat > /usr/local/xray/config.json <<EOF
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "d4b40e79-4a52-4f54-8cde-633108e0d1c7",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["http/1.1"],
          "certificates": [
            {
              "certificateFile": "/etc/xray/cert.pem",
              "keyFile": "/etc/xray/key.pem"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

# 配置 systemd 服务
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/usr/local/xray/xray -config /usr/local/xray/config.json
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl enable xray
systemctl start xray

echo ""
echo "✅ 安装完成！"
echo "📌 请在客户端使用以下信息连接："
echo "  地址：www.cloudflareop.xyz"
echo "  端口：443"
echo "  协议：vless"
echo "  UUID：d4b40e79-4a52-4f54-8cde-633108e0d1c7"
echo "  传输：tcp + tls（xtls-rprx-vision）"
