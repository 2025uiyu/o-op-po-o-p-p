#!/bin/bash

# 开启 BBR
echo "⚙️ 开启 BBR..."
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 安装依赖
echo "📦 安装必要软件..."
apt update -y && apt install -y curl wget unzip tar socat cron bash

# 安装 acme.sh 获取证书
echo "🔐 安装 acme.sh 并申请 TLS 证书..."
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --register-account -m your@email.com
~/.acme.sh/acme.sh --issue --standalone -d www.cloudflareop.xyz --keylength ec-256
mkdir -p /etc/xray
~/.acme.sh/acme.sh --install-cert -d www.cloudflareop.xyz \
--key-file /etc/xray/key.pem \
--fullchain-file /etc/xray/cert.pem --ecc

# 安装 Xray
echo "⬇️ 下载并安装 Xray..."
mkdir -p /opt/xray
cd /opt/xray
wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip Xray-linux-64.zip
install -m 755 xray /usr/local/bin/xray

# 写入 config.json
echo "⚙️ 写入 Xray 配置..."
cat > /usr/local/etc/xray/config.json <<EOF
{
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [
        {
          "id": "d4b40e79-4a52-4f54-8cde-633108e0d1c7",
          "flow": "xtls-rprx-vision",
          "level": 0,
          "email": "demo@xray.com"
        }
      ],
      "decryption": "none",
      "fallbacks": []
    },
    "streamSettings": {
      "network": "tcp",
      "security": "tls",
      "tlsSettings": {
        "certificates": [
          {
            "certificateFile": "/etc/xray/cert.pem",
            "keyFile": "/etc/xray/key.pem"
          }
        ]
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF

# 写入 Systemd 启动服务
echo "🔧 设置 Xray 开机自启..."
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray -config /usr/local/etc/xray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 启动 Xray 服务
echo "🚀 启动 Xray..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# 输出配置信息
echo ""
echo "✅ 安装完成！请在客户端使用以下信息连接："
echo "地址: www.cloudflareop.xyz"
echo "端口: 443"
echo "UUID: d4b40e79-4a52-4f54-8cde-633108e0d1c7"
echo "协议: vless"
echo "传输: tcp + tls"
echo "flow: xtls-rprx-vision"
