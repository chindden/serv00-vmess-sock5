#!/bin/bash

# =============================
# 颜色与提示函数
# =============================
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

# =============================
# 路径/工作目录等
# =============================
USERNAME=$(whoami)
HOSTNAME=$(hostname)
WORKDIR="/home/${USERNAME}/logs"

[ -d "${WORKDIR}" ] || (mkdir -p "${WORKDIR}" && chmod -R 755 "${WORKDIR}")

# =============================
# 默认变量
# =============================
export LC_ALL=C
# 可在脚本外自行 export 定义这些变量，若无则使用默认
export UUID=${UUID:-'5195c04a-552f-4f9e-8bf9-216d257c0839'}
export NEZHA_SERVER=${NEZHA_SERVER:-'nezha.yutian81.top'}
export NEZHA_PORT=${NEZHA_PORT:-'5555'}
export NEZHA_KEY=${NEZHA_KEY:-''}
export ARGO_DOMAIN=${ARGO_DOMAIN:-''}
export ARGO_AUTH=${ARGO_AUTH:-''}
export vmess_port=${vmess_port:-'40000'}  # TCP
export hy2_port=${hy2_port:-'41000'}     # UDP
export vless_port=${vless_port:-'42000'} # Reality(原socks端口)

export CFIP=${CFIP:-'fan.yutian.us.kg'}
export CFPORT=${CFPORT:-'443'}

# 文件下载地址（ARM / X86）
SB_WEB_ARMURL="https://github.com/eooce/test/releases/download/arm64/sb"
AG_BOT_ARMURL="https://github.com/qmsdh/serv00-vmess-sock5/releases/download/arm64/cloudflared_arm64"
NZ_NPM_ARMURL="https://github.com/eooce/test/releases/download/ARM/swith"
SB_WEB_X86URL="https://00.2go.us.kg/web"
AG_BOT_X86URL="https://00.2go.us.kg/bot"
NZ_NPM_X86URL="https://00.2go.us.kg/npm"

# 其它辅助脚本
CORN_URL="https://raw.githubusercontent.com/qmsdh/serv00-vmess-sock5/main/check_sb_cron.sh"
UPDATA_URL="https://raw.githubusercontent.com/qmsdh/serv00-vmess-sock5/main/sb_serv00_socks.sh"
REBOOT_URL="https://raw.githubusercontent.com/qmsdh/serv00-vmess-sock5/main/reboot.sh"

# =============================
# 1. 安装主流程
# =============================
install_singbox() {
  echo -e "${yellow}本脚本将安装四协议并共存:${purple}\n1) VMess\n2) VMess + Argo (WS-TLS)\n3) Hysteria2\n4) VLESS Reality${re}"
  echo -e "${yellow}开始前，请确保在面板${purple}已开放两条TCP和一条UDP端口${re}"
  green "安装完成后，可在用户根目录输入 \`bash sb00.sh\` 再次进入主菜单"
  
  reading "\n确定继续安装吗？【y/n】: " choice
  case "$choice" in
    [Yy])
        cd "${WORKDIR}"
        input_vmess_port
        input_hy2_port
        input_vless_reality
        argo_configure
        read_nz_variables
        download_singbox
        generate_config
        run_nezha
        run_argo
        run_singbox
        get_links
        creat_cron
        ;;
    [Nn]) menu ;;
    *) red "无效的选择，请输入 y 或 n" && install_singbox ;;
  esac
}

# =============================
# 2. 获取端口/参数
# =============================

# 2.1 设置vmess端口
input_vmess_port() {
  while true; do
    reading "请输入 VMess 端口(面板开放的TCP端口): " vmess_port
    if [[ "$vmess_port" =~ ^[0-9]+$ ]] && [ "$vmess_port" -ge 1 ] && [ "$vmess_port" -le 65535 ]; then
      green "你的 VMess 端口为: $vmess_port"
      break
    else
      yellow "输入错误，请重新输入面板开放的TCP端口"
    fi
  done
}

# 2.2 设置hysteria2端口
input_hy2_port() {
  while true; do
    reading "请输入 Hysteria2 端口(面板开放的UDP端口): " hy2_port
    if [[ "$hy2_port" =~ ^[0-9]+$ ]] && [ "$hy2_port" -ge 1 ] && [ "$hy2_port" -le 65535 ]; then
      green "你的 Hysteria2 端口为: $hy2_port"
      break
    else
      yellow "输入错误，请重新输入面板开放的UDP端口"
    fi
  done
}

# 2.3 VLESS Reality 参数
input_vless_reality() {
  while true; do
    reading "请输入 VLESS Reality 端口(面板开放的TCP端口): " vless_port
    if [[ "$vless_port" =~ ^[0-9]+$ ]] && [ "$vless_port" -ge 1 ] && [ "$vless_port" -le 65535 ]; then
      green "你的 VLESS Reality 端口为: $vless_port"
      break
    else
      yellow "输入错误，请重新输入面板开放的TCP端口"
    fi
  done
}

# =============================
# 3. Argo配置
# =============================
argo_configure() {
  if [[ -z "${ARGO_AUTH}" || -z "${ARGO_DOMAIN}" ]]; then
    reading "是否需要使用固定 Argo 隧道？【y/n】: " argo_choice
    [[ -z $argo_choice ]] && return
    [[ "$argo_choice" != "y" && "$argo_choice" != "Y" && "$argo_choice" != "n" && "$argo_choice" != "N" ]] && {
      red "无效的选择，请输入y或n"
      return
    }
    if [[ "$argo_choice" == "y" || "$argo_choice" == "Y" ]]; then
      reading "请输入 Argo 固定隧道域名: " ARGO_DOMAIN
      green "你的 Argo 固定隧道域名为: $ARGO_DOMAIN"
      reading "请输入 Argo 固定隧道密钥（Json 或 Token）: " ARGO_AUTH
      green "你的 Argo 固定隧道密钥为: $ARGO_AUTH"
      echo -e "${red}注意：${purple}使用token需要在CF后台设置隧道端口和面板TCP端口一致${re}"
    else
      green "将使用临时隧道(ARGO_AUTH未设置)"
      return
    fi
  fi

  # 分别识别 JSON / TOKEN / 未定义 等三种情况
  if [[ "${ARGO_AUTH}" =~ TunnelSecret ]]; then
    echo "${ARGO_AUTH}" > tunnel.json
    cat > tunnel.yml << EOF
tunnel: $(cut -d\" -f12 <<< "$ARGO_AUTH")
credentials-file: ${WORKDIR}/tunnel.json
protocol: http2

ingress:
  - hostname: $ARGO_DOMAIN
    service: http://localhost:$vmess_port
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
    declare -g argo_args="tunnel --edge-ip-version auto --config tunnel.yml run"
    green "ARGO_AUTH 是 Json 格式，将使用 Json 连接 ARGO"
  elif [[ "${ARGO_AUTH}" =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
    declare -g argo_args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token \"${ARGO_AUTH}\""
    green "ARGO_AUTH 是 Token 格式，将使用 Token 连接 ARGO"
  else
    declare -g argo_args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile boot.log --loglevel info --url http://localhost:$vmess_port"
    green "ARGO_AUTH 未定义或不匹配，将使用临时隧道"
  fi

  cat > "${WORKDIR}/argo.sh" << EOF
#!/bin/bash
cd ${WORKDIR} || exit
export TMPDIR=\$(pwd)
chmod +x ./bot
./bot ${argo_args} >/dev/null 2>&1 &
EOF
  chmod +x "${WORKDIR}/argo.sh"
}

# =============================
# 4. 哪吒探针
# =============================
read_nz_variables() {
  if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ]; then
    green "使用自定义哪吒变量：${NEZHA_SERVER}:${NEZHA_PORT}"
    return
  else
    reading "是否需要安装哪吒探针？【y/n】: " nz_choice
    [[ -z $nz_choice ]] && return
    [[ "$nz_choice" != "y" && "$nz_choice" != "Y" ]] && return

    reading "请输入哪吒探针域名或IP: " NEZHA_SERVER
    green "你的哪吒域名为: $NEZHA_SERVER"
    reading "请输入哪吒探针端口(回车默认5555): " NEZHA_PORT
    [ -z "${NEZHA_PORT}" ] && NEZHA_PORT="5555"
    green "你的哪吒端口为: $NEZHA_PORT"
    reading "请输入哪吒探针密钥: " NEZHA_KEY
    green "你的哪吒KEY为: $NEZHA_KEY"
  fi

  # 处理 NEZHA_TLS 参数
  tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
  if [[ "${tlsPorts[*]}" =~ "${NEZHA_PORT}" ]]; then
    NEZHA_TLS="--tls"
  else
    NEZHA_TLS=""
  fi

  # 生成 nezha.sh
  cat > "${WORKDIR}/nezha.sh" << EOF
#!/bin/bash
cd ${WORKDIR} || exit
export TMPDIR=\$(pwd)
chmod +x ./npm
./npm -s "${NEZHA_SERVER}:${NEZHA_PORT}" -p "${NEZHA_KEY}" "${NEZHA_TLS}" >/dev/null 2>&1 &
EOF
  chmod +x "${WORKDIR}/nezha.sh"
}

# =============================
# 5. 下载 singbox / Argo / 哪吒等
# =============================
download_singbox() {
  ARCH=$(uname -m)
  DOWNLOAD_DIR="."
  mkdir -p "${DOWNLOAD_DIR}"
  
  if [[ "$ARCH" == "arm" || "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
    FILE_INFO=("${SB_WEB_ARMURL} web" "${AG_BOT_ARMURL} bot" "${NZ_NPM_ARMURL} npm")
  elif [[ "$ARCH" == "amd64" || "$ARCH" == "x86_64" || "$ARCH" == "x86" ]]; then
    FILE_INFO=("${SB_WEB_X86URL} web" "${AG_BOT_X86URL} bot" "${NZ_NPM_X86URL} npm")
  else
    red "不支持的CPU架构: $ARCH"
    exit 1
  fi

  for entry in "${FILE_INFO[@]}"; do
    url=$(echo "$entry" | cut -d ' ' -f 1)
    name=$(echo "$entry" | cut -d ' ' -f 2)
    if [ -f "${DOWNLOAD_DIR}/${name}" ]; then
      green "${name} 已存在，跳过下载"
    else
      echo "开始下载 ${name}"
      wget -q -O "${DOWNLOAD_DIR}/${name}" "${url}" || {
        red "下载 ${name} 失败！"
        exit 1
      }
      green "下载完成: ${name}"
    fi
    chmod +x "${DOWNLOAD_DIR}/${name}"
  done
}

# =============================
# 6. 生成 config.json (含 VLESS Reality)
# =============================
generate_config() {
  # 生成自签证书(仅给Hysteria2做TLS)
  openssl ecparam -genkey -name prime256v1 -out "private.key"
  openssl req -new -x509 -days 3650 -key "private.key" -out "cert.pem" -subj "/CN=${USERNAME}.serv00.net"

  # 生成 VLESS Reality 私钥/公钥(若需自定义可改)
  rkp_output=$("./web" generate reality-keypair 2>/dev/null)
  if [[ -n "$rkp_output" ]]; then
    reality_privateKey=$(echo "$rkp_output" | grep 'PrivateKey' | awk -F': ' '{print $2}' | xargs)
    reality_publicKey=$(echo "$rkp_output" | grep 'PublicKey' | awk -F': ' '{print $2}' | xargs)
    shortId=$(echo "$rkp_output" | grep 'ShortId' | awk -F': ' '{print $2}' | xargs)
  else
    reality_privateKey="cHSai02ALrhu4KWuVC3pv3dGnSxK60pyaC6Bq4PdM24"
    reality_publicKey="NLygiSTmCl7QE+34nKZgVfpePtwE4WUBNDeEY89gB3c="
    shortId="112233445566"
  fi

  # 写入 config.json
  cat > config.json << EOF
{
  "log": {
    "level": "info",
    "timestamp": true,
    "disabled": true
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "address": "tls://8.8.8.8",
        "strategy": "ipv4_only",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "rule_set": ["geosite-openai"],
        "server": "wireguard"
      },
      {
        "rule_set": ["geosite-netflix"],
        "server": "wireguard"
      },
      {
        "rule_set": ["geosite-category-ads-all"],
        "server": "block"
      }
    ],
    "final": "google"
  },
  "inbounds": [
    {
      "type": "hysteria2",
      "tag": "hysteria-in",
      "listen": "::",
      "listen_port": ${hy2_port},
      "users": [
        {
          "password": "${UUID}"
        }
      ],
      "masquerade": "https://bing.com",
      "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "cert.pem",
        "key_path": "private.key"
      }
    },
    {
      "type": "vmess",
      "tag": "vmess-ws-in",
      "listen": "::",
      "listen_port": ${vmess_port},
      "users": [
        {
          "uuid": "${UUID}"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/vmess",
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    },
    {
      "type": "vless",
      "tag": "reality-in",
      "listen": "::",
      "listen_port": ${vless_port},
      "users": [
        {
          "uuid": "${UUID}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "certificate_path": "cert.pem",
        "key_path": "private.key",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "www.bing.com",
            "server_port": 443
          },
          "private_key": "${reality_privateKey}",
          "short_id": "${shortId}"
        }
      }
    },
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": ${vless_port},
      "users": [
        {
          "uuid": "${UUID}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "certificate_path": "cert.pem",
        "key_path": "private.key"
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
    },
    {
      "type": "dns",
      "tag": "dns-out"
    },
    {
      "type": "wireguard",
      "tag": "wireguard",
      "server": "162.159.195.100",
      "server_port": 4500,
      "local_address": [
        "172.16.0.2/32",
        "2606:4700:110:83c7:b31f:5858:b3a8:c6b1/128"
      ],
      "private_key": "mPZo+V9qlrMGCZ7+E6z2NI6NOV34PD++TpAR09PtCWI=",
      "peer_public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
      "reserved": [26, 21, 228]
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "rule_set": ["geosite-openai"],
        "outbound": "wireguard"
      },
      {
        "rule_set": ["geosite-netflix"],
        "outbound": "wireguard"
      },
      {
        "rule_set": ["geosite-category-ads-all"],
        "outbound": "block"
      }
    ],
    "rule_set": [
      {
        "tag": "geosite-netflix",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-netflix.srs",
        "download_detour": "direct"
      },
      {
        "tag": "geosite-openai",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/openai.srs",
        "download_detour": "direct"
      },
      {
        "tag": "geosite-category-ads-all",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs",
        "download_detour": "direct"
      }
    ],
    "final": "direct"
  },
  "experimental": {
    "cache_file": {
      "path": "cache.db",
      "cache_id": "mycacheid",
      "store_fakeip": true
    }
  }
}
EOF

  green "config.json 生成完毕！"
  # 把 realityPublicKey 写入记录(后面 get_links 用)
  echo "${reality_publicKey}" > reality_pub.key
  echo "${shortId}" > reality_shortid.txt
}

# =============================
# 7. 运行哪吒/Argo/singbox
# =============================

run_nezha() {
  if [[ -f "${WORKDIR}/nezha.sh" && -n "${NEZHA_SERVER}" && -n "${NEZHA_PORT}" && -n "${NEZHA_KEY}" ]]; then
    purple "启动 哪吒探针 ..."
    pkill -9 npm 2>/dev/null
    nohup bash nezha.sh >/dev/null 2>&1 &
    sleep 2
    if pgrep -x npm >/dev/null; then
      green "哪吒探针 已启动"
    else
      red "哪吒探针 启动失败"
    fi
  fi
}

run_argo() {
  if [[ -f "${WORKDIR}/argo.sh" ]]; then
    purple "启动 Argo 隧道 ..."
    pkill -9 bot 2>/dev/null
    nohup bash argo.sh >/dev/null 2>&1 &
    sleep 2
    if pgrep -x bot >/dev/null; then
      green "Argo 隧道 已启动"
    else
      red "Argo 隧道 启动失败"
    fi
  else
    yellow "Argo 未配置或跳过"
  fi
}

run_singbox() {
  if [[ -f "${WORKDIR}/web" && -f "${WORKDIR}/config.json" ]]; then
    purple "启动 SingBox ..."
    pkill -9 web 2>/dev/null
    nohup ./web run -c config.json >/dev/null 2>&1 &
    sleep 2
    if pgrep -x web >/dev/null; then
      green "SingBox 已启动"
    else
      red "SingBox 启动失败"
    fi
  else
    red "SingBox 文件或 config.json 不存在"
  fi
}

# =============================
# 8. 生成链接 & list.txt
# =============================
get_ip() {
  local ip=$(curl -s --max-time 3 ipv4.ip.sb)
  if [ -z "$ip" ]; then
    ip=$( [[ "$HOSTNAME" =~ s[0-9]\.serv00\.com ]] && echo "${HOSTNAME/s/mail}" || echo "$HOSTNAME" )
  fi
  echo "$ip"
}

get_argodomain() {
  if [[ -n "$ARGO_DOMAIN" && -n "$ARGO_AUTH" ]]; then
    echo "$ARGO_DOMAIN"
  else
    grep -oE 'https://[[:alnum:]+\.-]+\.trycloudflare\.com' boot.log | sed 's@https://@@'
  fi
}

get_links() {
  cd "${WORKDIR}"
  local argodomain=$(get_argodomain)
  local ip=$(get_ip)
  [ -z "${ip}" ] && ip="0.0.0.0"
  local realityPublicKey=$(cat reality_pub.key 2>/dev/null || echo "PUBLIC_KEY_NOT_FOUND")
  local shortId=$(cat reality_shortid.txt 2>/dev/null || echo "")

  ISP=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed -e 's/ /_/g')
  [ -z "$ISP" ] && ISP="Serv00"

  # VMess直连
  local vmess_link_1="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$ISP\",\"add\":\"$ip\",\"port\":\"$vmess_port\",\"id\":\"$UUID\",\"aid\":\"0\",\"scy\":\"none\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"\",\"path\":\"/vmess?ed=2048\",\"tls\":\"\",\"sni\":\"\",\"alpn\":\"\",\"fp\":\"\"}" | base64 -w0)"
  # VMess + Argo
  local vmess_link_2="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$ISP\",\"add\":\"$CFIP\",\"port\":\"$CFPORT\",\"id\":\"$UUID\",\"aid\":\"0\",\"scy\":\"none\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$argodomain\",\"path\":\"/vmess?ed=2048\",\"tls\":\"tls\",\"sni\":\"$argodomain\",\"alpn\":\"\",\"fp\":\"\"}" | base64 -w0)"

  # Hysteria2
  local hy2_link="hysteria2://$UUID@$ip:$hy2_port/?sni=www.bing.com&alpn=h3&insecure=1#$ISP"

  # VLESS Reality
  local vless_link="vless://$UUID@$ip:$vless_port?encryption=none&security=reality&sni=www.bing.com&flow=xtls-rprx-vision&pbk=$realityPublicKey&sid=$shortId&spx=%2F#$ISP"

  # VLESS
  local vless_link_2="vless://$UUID@$ip:$vless_port?encryption=none&security=tls&sni=www.bing.com&flow=xtls-rprx-vision&type=tcp&headerType=none#$ISP"

  cat > list.txt << EOF
-------------------------------
           - 节点列表 -
-------------------------------
(1) VMess 直连:
$vmess_link_1

(2) VMess + Argo (CF):
$vmess_link_2

(3) Hysteria2:
$hy2_link

(4) VLESS Reality:
$vless_link

(5) VLESS:
$vless_link_2

-------------------------------
EOF

  cat list.txt
  green "节点信息已保存到 list.txt"
}

# =============================
# 9. Crontab(守护进程)
# =============================
creat_cron() {
  reading "是否添加 crontab 守护进程定时任务？【y/n】: " choice
  case "$choice" in
    [Yy])
      bash <(curl -s ${CORN_URL})
      sleep 2
      menu
      ;;
    [Nn]) menu ;;
    *) red "无效的选择，请输入 y 或 n" && creat_cron ;;
  esac
}

# =============================
# 10. 卸载 / 重置
# =============================
clean_all() {
  echo ""
  green "1. 仅卸载 sing-box"
  echo "----------------"
  green "2. 重置整个服务器(慎)"
  echo "----------------"
  yellow "0. 返回主菜单"
  echo "----------------"
  reading "请输入选择 (0-2): " choice
  case "${choice}" in
    1) uninstall_singbox ;;
    2) clean_all_files ;;
    0) menu ;;
    *) red "无效的选项，请输入 0-2" && clean_all ;;
  esac
}

uninstall_singbox() {
  reading "确定要卸载吗？【y/n】: " choice
  case "${choice}" in
    [Yy])
      pkill -9 web bot npm 2>/dev/null
      rm -rf "${WORKDIR}"
      # 移除 crontab (check_sb_cron.sh)
      crontab -l | sed '/check_sb_cron.sh/d' | crontab -
      green "sing-box 已卸载完成"
      menu
      ;;
    [Nn]) menu ;;
    *) red "无效的选择，请重新输入 y 或 n" && uninstall_singbox ;;
  esac
}

clean_all_files() {
  reading "清理所有文件并重置服务器，确定继续吗？【y/n】: " choice
  case "${choice}" in
    [Yy])
      pkill -9 -u "$(whoami)" 2>/dev/null
      chmod -R 755 ~/*
      chmod -R 755 ~/.* 
      rm -rf ~/.* 
      rm -rf ~/*
      sleep 2
      green "清理完成"
      ;;
    [Nn]) menu ;;
    *) red "无效的选择，请重新输入 y 或 n" && menu ;;
  esac
}

# =============================
# 11. 菜单
# =============================
menu() {
  clear
  echo ""
  purple "--- Serv00/CT8 Sing-Box 一键脚本 (VLESS Reality + VMess + Hysteria2) ---"
  echo -e "${green}原作者：老王, 三改：秋名山, 二改：yutian81, 现改：vless reality\n"
  echo -e "${green}Github项目: https://github.com/qmsdh/serv00-vmess-sock5${re}\n"
  purple "----------------- 主菜单 -----------------\n"
  red   "1. 安装 SingBox(多协议)"
  echo  "-----------------------"
  red   "2. 卸载或清理服务器"
  echo  "-----------------------"
  green "3. 查看节点信息 (list.txt)"
  echo  "-----------------------"
  green "4. 重启所有进程(Argo+SB+哪吒)"
  echo  "-----------------------"
  yellow "5. 写入面板 CRON 计划任务"
  echo  "-----------------------"
  yellow "6. 更新最新脚本"
  echo  "-----------------------"
  red   "0. 退出脚本"
  echo  "-----------------------------------------"

  reading "请输入选择(0-6): " choice
  echo ""
  case "${choice}" in
    1) install_singbox ;;
    2) clean_all ;;
    3) cat "${WORKDIR}/list.txt" 2>/dev/null || red "尚未安装或文件不存在" ;;
    4) bash <(curl -s ${REBOOT_URL}) ;; 
    5) creat_cron ;;
    6)
       curl -s ${UPDATA_URL} -o sb00.sh && chmod +x sb00.sh
       green "脚本已更新，重新执行 ./sb00.sh"
       ;;
    0) exit 0 ;;
    *) red "无效选项，请输入0-6" && menu ;;
  esac
}

# 入口
menu
