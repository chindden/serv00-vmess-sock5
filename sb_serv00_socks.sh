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

# 定义路径
USERNAME=$(whoami)
HOSTNAME=$(hostname)
WORKDIR="/home/${USERNAME}/logs"

# 定义变量
export LC_ALL=C
export UUID=${UUID:-'5195c04a-552f-4f9e-8bf9-216d257c0839'}
export NEZHA_SERVER=${NEZHA_SERVER:-'nezha.yutian81.top'} 
export NEZHA_PORT=${NEZHA_PORT:-'5555'}     
export NEZHA_KEY=${NEZHA_KEY:-''} 
export ARGO_DOMAIN=${ARGO_DOMAIN:-''}   
export ARGO_AUTH=${ARGO_AUTH:-''} 
export vmess_port=${vmess_port:-'40000'}
export hy2_port=${hy2_port:-'41000'}
export vless_port=${vless_port:-'42000'}
export reality_domain=${reality_domain:-'www.example.com'}
export reality_public_key=${reality_public_key:-''}
export reality_uuid=${UUID:-'5195c04a-552f-4f9e-8bf9-216d257c0839'}

# 定义文件下载地址
SB_WEB_ARMURL="https://github.com/eooce/test/releases/download/arm64/sb"
SB_WEB_X86URL="https://00.2go.us.kg/web"

[ -d "${WORKDIR}" ] || (mkdir -p "${WORKDIR}" && chmod -R 755 "${WORKDIR}")

# 设置 VLESS + Reality 配置
read_vless_reality_variables() {
    while true; do
        reading "请输入 VLESS + Reality 的端口 (面板开放的 TCP 端口): " vless_port
        if [[ "$vless_port" =~ ^[0-9]+$ ]] && [ "$vless_port" -ge 1 ] && [ "$vless_port" -le 65535 ]; then
            green "你的 VLESS + Reality 端口为: $vless_port"
            break
        else
            yellow "输入错误，请重新输入面板开放的 TCP 端口"
        fi
    done

    while true; do
        reading "请输入 VLESS + Reality 的 UUID: " reality_uuid
        if [[ ! -z "$reality_uuid" ]]; then
            green "你的 VLESS UUID 为: $reality_uuid"
            break
        else
            yellow "UUID 不能为空，请重新输入"
        fi
    done

    while true; do
        reading "请输入 Reality 域名 (例如: www.example.com): " reality_domain
        if [[ ! -z "$reality_domain" ]]; then
            green "你的 Reality 域名为: $reality_domain"
            break
        else
            yellow "域名不能为空，请重新输入"
        fi
    done

    while true; do
        reading "请输入 Reality Public Key (支持自定义): " reality_public_key
        if [[ ! -z "$reality_public_key" ]]; then
            green "你的 Reality Public Key 为: $reality_public_key"
            break
        else
            yellow "Public Key 不能为空，请重新输入"
        fi
    done
}

# 生成配置文件并加入 VLESS + Reality
generate_config() {
    openssl ecparam -genkey -name prime256v1 -out "private.key"
    openssl req -new -x509 -days 3650 -key "private.key" -out "cert.pem" -subj "/CN=${USERNAME}.serv00.net"
    cat > config.json << EOF
{
  "log": {
    "disabled": true,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "tag": "vmess-ws-in",
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
        "path": "/vmess",
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    },
    {
      "tag": "hysteria-in",
      "type": "hysteria2",
      "listen": "::",
      "listen_port": $hy2_port,
      "users": [
        {
          "password": "$UUID"
        }
      ],
      "masquerade": "https://bing.com",
      "tls": {
        "enabled": true,
        "alpn": [
          "h3"
        ],
        "certificate_path": "cert.pem",
        "key_path": "private.key"
      }
    },
    {
      "tag": "vless-reality-in",
      "type": "vless",
      "listen": "::",
      "listen_port": $vless_port,
      "users": [
        {
          "uuid": "$reality_uuid",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$reality_domain",
            "server_port": 443
          },
          "private_key": "$reality_public_key",
          "short_ids": [
            ""
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ]
}
EOF
}

# 获取节点链接
get_links(){
    argodomain=$(get_argodomain)
    echo -e "\e[1;32mArgoDomain:\e[1;35m${argodomain}\e[0m\n"
    sleep 1
    IP=$(curl -s ipv4.ip.sb)
    ISP=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed -e 's/ /_/g') 
    sleep 1
    yellow "注意：客户端需支持 Reality 模式\n"
    cat > list.txt <<EOF
vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$ISP\", \"add\": \"$IP\", \"port\": \"$vmess_port\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\", \"path\": \"/vmess?ed=2048\", \"tls\": \"\", \"sni\": \"\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)

hysteria2://$UUID@$IP:$hy2_port/?sni=www.bing.com&alpn=h3&insecure=1#$ISP

vless://${reality_uuid}@$IP:$vless_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$reality_domain&fp=chrome&pbk=$reality_public_key&sid=&type=tcp#$ISP
EOF
    cat list.txt
    purple "\n$WORKDIR/list.txt 节点文件已保存"
    green "安装完成"
    sleep 2
}

# 主菜单
menu() {
    clear
    echo ""
    purple "--- Sing-box VLESS + Reality 一键脚本 ---"
    echo -e "${green}原作者: 老王${re}\n"
    red "1. 安装所有服务"
    echo  "----------------"
    red "0. 退出脚本"
    echo "----------------"
    reading "请输入选择 (0-1): " choice
    echo ""
    case "${choice}" in
        1) install_singbox ;;
        0) exit 0 ;;
        *) red "无效的选项，请输入 0 或 1" && menu ;;
    esac
}

menu
