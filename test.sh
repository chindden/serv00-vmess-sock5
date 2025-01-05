#!/bin/bash

# 定义颜色
re="\033[0m"
red="\033[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"
red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
reading() { read -p "$(red "$1")" "$2"; }

# 基础变量
USERNAME=$(whoami)
HOSTNAME=$(hostname)
WORKDIR="/home/${USERNAME}/logs"
[ -d "$WORKDIR" ] || mkdir -p "$WORKDIR" && chmod -R 755 "$WORKDIR"

# 生成 UUID
read_uuid() {
    reading "请输入统一的 UUID 密码 (建议回车默认随机): " UUID
    if [[ -z "$UUID" ]]; then
        UUID=$(uuidgen -r)
    fi
    green "你的 UUID 为: $UUID"
}

# 配置 Reality 域名
read_reym() {
    yellow "方式一：回车使用默认 CF 域名 (推荐)"
    yellow "方式二：输入 s 表示使用 Serv00 自带域名"
    yellow "方式三：输入自定义域名 (需符合 Reality 域名规则)"
    reading "请输入 Reality 域名【回车 或 s 或自定义域名】: " reym
    if [[ -z "$reym" ]]; then
        reym="www.speedtest.net"
    elif [[ "$reym" == "s" || "$reym" == "S" ]]; then
        reym="${USERNAME}.serv00.net"
    fi
    green "你的 Reality 域名为: $reym"
}

# Reality Keypair 生成
generate_reality_keypair() {
    output=$(./web generate reality-keypair)
    private_key=$(echo "$output" | awk '/PrivateKey:/ {print $2}')
    public_key=$(echo "$output" | awk '/PublicKey:/ {print $2}')
    echo "$private_key" > private_key.txt
    echo "$public_key" > public_key.txt
    green "Reality 私钥和公钥生成完成"
}

# 读取 Short ID
read_short_id() {
    reading "请输入 Reality 的 Short ID (留空自动生成): " short_id
    if [[ -z "$short_id" ]]; then
        short_id=$(openssl rand -hex 8)
        green "自动生成的 Short ID 为: $short_id"
    fi
}

# 读取端口配置
read_ports() {
    while true; do
        reading "请输入 VLESS Reality 端口 (建议默认 443): " vless_port
        if [[ "$vless_port" =~ ^[0-9]+$ ]] && [ "$vless_port" -ge 1 ] && [ "$vless_port" -le 65535 ]; then
            green "你的 VLESS Reality 端口为: $vless_port"
            break
        else
            yellow "输入错误，请重新输入有效端口"
        fi
    done
    while true; do
        reading "请输入 Vmess WS 端口 (建议默认 80): " vmess_port
        if [[ "$vmess_port" =~ ^[0-9]+$ ]] && [ "$vmess_port" -ge 1 ] && [ "$vmess_port" -le 65535 ]; then
            green "你的 Vmess WS 端口为: $vmess_port"
            break
        else
            yellow "输入错误，请重新输入有效端口"
        fi
    done
    while true; do
        reading "请输入 Hysteria2 端口 (建议默认 443): " hy2_port
        if [[ "$hy2_port" =~ ^[0-9]+$ ]] && [ "$hy2_port" -ge 1 ] && [ "$hy2_port" -le 65535 ]]; then
            green "你的 Hysteria2 端口为: $hy2_port"
            break
        else
            yellow "输入错误，请重新输入有效端口"
        fi
    done
}

# 生成配置文件
generate_config() {
    cat > config.json << EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "tag": "vless-reality",
      "type": "vless",
      "listen": "::",
      "listen_port": $vless_port,
      "users": [
        {
          "uuid": "$UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$reym",
        "reality": {
          "enabled": true,
          "private_key": "$private_key",
          "short_ids": ["$short_id"]
        }
      }
    },
    {
      "tag": "vmess-ws",
      "type": "vmess",
      "listen": "::",
      "listen_port": $vmess_port,
      "users": [
        {
          "uuid": "$UUID"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/$UUID-ws"
      }
    },
    {
      "tag": "hysteria2",
      "type": "hysteria2",
      "listen": "::",
      "listen_port": $hy2_port,
      "users": [
        {
          "password": "$UUID"
        }
      ],
      "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "cert.pem",
        "key_path": "private.key"
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "type": "direct"
    },
    {
      "tag": "block",
      "type": "block"
    }
  ]
}
EOF
    green "配置文件生成完成: config.json"
}

# 节点链接生成
generate_links() {
    vless_link="vless://$UUID@$HOSTNAME:$vless_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$reym&fp=chrome"
    vmess_link="vmess://$(echo "{\"v\": \"2\", \"ps\": \"vmess-ws\", \"add\": \"$HOSTNAME\", \"port\": \"$vmess_port\", \"id\": \"$UUID\", \"net\": \"ws\", \"path\": \"/$UUID-ws\", \"tls\": \"none\"}" | base64 -w0)"
    hysteria_link="hysteria2://$UUID@$HOSTNAME:$hy2_port?sni=$reym&alpn=h3"
    echo -e "$vless_link\n$vmess_link\n$hysteria_link" > list.txt
    green "节点链接生成完成: list.txt"
}

# 主菜单
menu() {
    clear
    echo -e "${green}1. 安装服务${re}"
    echo -e "${yellow}2. 查看节点信息${re}"
    echo -e "${red}3. 卸载服务${re}"
    echo -e "${purple}0. 退出脚本${re}"
    reading "请输入选项: " choice
    case "$choice" in
        1) install_service ;;
        2) cat list.txt ;;
        3) rm -rf $WORKDIR && red "已卸载服务" ;;
        0) exit 0 ;;
        *) red "无效选项，请重新输入！" ;;
    esac
}

# 安装服务
install_service() {
    cd "$WORKDIR"
    read_uuid
    read_reym
    read_short_id
    read_ports
    generate_reality_keypair
    generate_config
    generate_links
    nohup ./web run -c config.json > /dev/null 2>&1 &
    green "服务已启动！"
}

menu
