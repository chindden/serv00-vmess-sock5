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
export reality_domain=${reality_domain:-'www.speedtest.net'}
export CFIP=${CFIP:-'fan.yutian.us.kg'} 
export CFPORT=${CFPORT:-'443'} 

# 定义文件下载地址
SB_WEB_ARMURL="https://github.com/eooce/test/releases/download/arm64/sb"
AG_BOT_ARMURL="https://github.com/qmsdh/serv00-vmess-sock5/releases/download/arm64/cloudflared_arm64"
NZ_NPM_ARMURL="https://github.com/eooce/test/releases/download/ARM/swith"
SB_WEB_X86URL="https://00.2go.us.kg/web"
AG_BOT_X86URL="https://00.2go.us.kg/bot"
NZ_NPM_X86URL="https://00.2go.us.kg/npm"
CORN_URL="https://raw.githubusercontent.com/qmsdh/serv00-vmess-sock5/main/check_sb_cron.sh"
UPDATA_URL="https://raw.githubusercontent.com/qmsdh/serv00-vmess-sock5/main/sb_serv00_socks.sh"
REBOOT_URL="https://raw.githubusercontent.com/qmsdh/serv00-vmess-sock5/main/reboot.sh"

[ -d "${WORKDIR}" ] || (mkdir -p "${WORKDIR}" && chmod -R 755 "${WORKDIR}")

# 安装singbox
install_singbox() {
echo -e "${yellow}本脚本同时四协议共存${purple}(vmess,vmess-ws-tls(argo),hysteria2,vless+reality)${re}"
echo -e "${yellow}开始运行前，请确保在面板${purple}已开放3个端口，两个tcp端口和一个udp端口${re}"
echo -e "${yellow}面板${purple}Additional services中的Run your own applications${yellow}已开启为${purple}Enabled${yellow}状态${re}"
green "安装完成后，可在用户根目录输入 \`bash sb00.sh\` 再次进入主菜单"
reading "\n确定继续安装吗？【y/n】: " choice
  case "$choice" in
    [Yy])
        cd "${WORKDIR}"
        read_vmess_port
        read_hy2_port
        read_vless_reality_variables
        argo_configure
        read_nz_variables
        generate_config
        download_singbox
        run_nezha
        run_sb
        run_argo
        get_links
        creat_corn ;;
    [Nn]) menu ;;
    *) red "无效的选择，请输入 y 或 n" && install_singbox ;;
  esac
}

# 设置vmess端口
read_vmess_port() {
    while true; do
        reading "请输入vmess端口 (面板开放的tcp端口): " vmess_port
        if [[ "$vmess_port" =~ ^[0-9]+$ ]] && [ "$vmess_port" -ge 1 ] && [ "$vmess_port" -le 65535 ]; then
            green "你的vmess端口为: $vmess_port"
            break
        else
            yellow "输入错误，请重新输入面板开放的TCP端口"
        fi
    done
}

# 设置hy2端口
read_hy2_port() {
    while true; do
        reading "请输入hysteria2端口 (面板开放的UDP端口): " hy2_port
        if [[ "$hy2_port" =~ ^[0-9]+$ ]] && [ "$hy2_port" -ge 1 ] && [ "$hy2_port" -le 65535 ]; then
            green "你的hysteria2端口为: $hy2_port"
            break
        else
            yellow "输入错误，请重新输入面板开放的UDP端口"
        fi
    done
}

# 设置 VLESS + Reality 端口、UUID 和伪装域名
read_vless_reality_variables() {
    while true; do
        reading "请输入 VLESS + Reality 端口 (面板开放的 TCP 端口): " vless_port
        if [[ "$vless_port" =~ ^[0-9]+$ ]] && [ "$vless_port" -ge 1 ] && [ "$vless_port" -le 65535 ]; then
            green "你的 VLESS + Reality 端口为: $vless_port"
            break
        else
            yellow "输入错误，请重新输入面板开放的 TCP 端口"
        fi
    done

    while true; do
        reading "请输入 VLESS 的 UUID (留空将使用默认 UUID): " vless_uuid
        if [[ -z "$vless_uuid" ]]; then
            vless_uuid="$UUID"  # 使用默认的 UUID
            green "你的 VLESS UUID 为: $vless_uuid"
            break
        elif [[ "$vless_uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
            green "你的 VLESS UUID 为: $vless_uuid"
            break
        else
            yellow "UUID 格式错误，请输入有效的 UUID"
        fi
    done

    # 设置默认域名为 www.speedtest.net
    default_domain="www.speedtest.net"
    reading "请输入 Reality 的伪装域名 (留空将使用默认域名 $default_domain): " reality_domain
    if [[ -z "$reality_domain" ]]; then
        reality_domain="$default_domain"
    fi
    green "你的 Reality 伪装域名为: $reality_domain"
}

# 设置 argo 隧道域名、json 或 token
argo_configure() {
  if [[ -z "${ARGO_AUTH}" || -z "${ARGO_DOMAIN}" ]]; then
    reading "是否需要使用固定 argo 隧道？【y/n】: " argo_choice
    [[ -z $argo_choice ]] && return
    [[ "$argo_choice" != "y" && "$argo_choice" != "Y" && "$argo_choice" != "n" && "$argo_choice" != "N" ]] && { red "无效的选择，请输入y或n"; return; }
    if [[ "$argo_choice" == "y" || "$argo_choice" == "Y" ]]; then
        reading "请输入 argo 固定隧道域名: " ARGO_DOMAIN
        green "你的 argo 固定隧道域名为: $ARGO_DOMAIN"
        reading "请输入 argo 固定隧道密钥（Json 或 Token）: " ARGO_AUTH
        green "你的 argo 固定隧道密钥为: $ARGO_AUTH"
        echo -e "${red}注意：${purple}使用 token，需要在 cloudflare 后台设置隧道端口和面板开放的 tcp 端口一致${re}"
    else
        green "ARGO 变量未设置，将使用临时隧道"
        return
    fi
  fi
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
    # 定义使用 json 时 agro 隧道的启动参数变量
    declare -g args="tunnel --edge-ip-version auto --config tunnel.yml run"
    green "ARGO_AUTH 是 Json 格式，将使用 Json 连接 ARGO；tunnel.yml 配置文件已生成"
  elif [[ "${ARGO_AUTH}" =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
    declare -g args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token \"${ARGO_AUTH}\""
    green "ARGO_AUTH 是 Token 格式，将使用 Token 连接 ARGO"
  else
    declare -g args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile boot.log --loglevel info --url http://localhost:$vmess_port"
    green "ARGO_AUTH 未定义，将使用 ARGO 临时隧道"
  fi
  # 生成 argo.sh 脚本
  cat > "${WORKDIR}/argo.sh" << EOF
#!/bin/bash

cd ${WORKDIR} || exit
export TMPDIR=$(pwd)
chmod +x ./bot
./bot ${args} >/dev/null 2>&1 &
EOF
  chmod +x "${WORKDIR}/argo.sh"
}

# 设置哪吒域名（或ip）、端口、密钥
read_nz_variables() {
  if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ]; then
      green "使用自定义变量运行哪吒探针"
      return
  else
      reading "是否需要安装哪吒探针？【y/n】: " nz_choice
      [[ -z $nz_choice ]] && return
      [[ "$nz_choice" != "y" && "$nz_choice" != "Y" ]] && return
      reading "请输入哪吒探针域名或ip：" NEZHA_SERVER
      green "你的哪吒域名为: $NEZHA_SERVER"
      reading "请输入哪吒探针端口（回车跳过默认使用5555）：" NEZHA_PORT
      [[ -z "${NEZHA_PORT}" ]] && NEZHA_PORT="5555"
      green "你的哪吒端口为: $NEZHA_PORT"
      reading "请输入哪吒探针密钥：" NEZHA_KEY
      green "你的哪吒密钥为: $NEZHA_KEY"
  fi
  # 处理 NEZHA_TLS 参数
  tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
  if [[ "${tlsPorts[*]}" =~ "${NEZHA_PORT}" ]]; then
    NEZHA_TLS="--tls"
  else
    NEZHA_TLS=""
  fi
  # 生成 nezha.sh 脚本
  cat > "${WORKDIR}/nezha.sh" << EOF
#!/bin/bash

cd ${WORKDIR} || exit
export TMPDIR=$(pwd)
chmod +x ./npm
./npm -s "${NEZHA_SERVER}:${NEZHA_PORT}" -p "${NEZHA_KEY}" "${NEZHA_TLS}" >/dev/null 2>&1 &
EOF
  chmod +x "${WORKDIR}/nezha.sh"
}

# 下载singbo文件
download_singbox() {
  ARCH=$(uname -m) && DOWNLOAD_DIR="." && mkdir -p "${DOWNLOAD_DIR}" && FILE_INFO=()
  if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
      FILE_INFO=("${SB_WEB_ARMURL} web" "${AG_BOT_ARMURL} bot" "${NZ_NPM_ARMURL} npm")
  elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
      FILE_INFO=("${SB_WEB_X86URL} web" "${AG_BOT_X86URL} bot" "${NZ_NPM_X86URL} npm")
  else
      echo "不支持的系统架构: $ARCH"
      exit 1
  fi
  for entry in "${FILE_INFO[@]}"; do
      URL=$(echo "$entry" | cut -d ' ' -f 1)
      NEW_FILENAME=$(echo "$entry" | cut -d ' ' -f 2)
      FILENAME="${DOWNLOAD_DIR}/${NEW_FILENAME}"
      if [ -e "${FILENAME}" ]; then
          green "$FILENAME 已经存在，跳过下载"
      else
          echo "正在下载 $FILENAME"
          if wget -q -O "${FILENAME}" "${URL}"; then
              green "$FILENAME 下载完成"
          else
              red "$FILENAME 下载失败"
              exit 1
          fi
      fi
      chmod +x "${FILENAME}"
  done
}

# 获取argo隧道的域名
get_argodomain() {
  if [[ -n "${ARGO_AUTH}" ]]; then
    echo ${ARGO_DOMAIN}
  else
    grep -oE 'https://[[:alnum:]+\.-]+\.trycloudflare\.com' boot.log | sed 's@https://@@'
  fi
}

# 运行 NEZHA 服务
run_nezha() {
  if [ -e "${WORKDIR}/nezha.sh" ] && [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ]; then
    purple "NEZHA 变量均已设置，且脚本文件已生成"
    cd "${WORKDIR}"
    export TMPDIR=$(pwd)
    [ -x "${WORKDIR}/nezha.sh" ] || chmod +x "${WORKDIR}/nezha.sh"
    [ -x "${WORKDIR}/npm" ] || chmod +x "${WORKDIR}/npm"
    nohup ./nezha.sh >/dev/null 2>&1 &
    sleep 2
    if pgrep -x 'npm' > /dev/null; then
       green "NEZHA 正在运行"
    else
       red "NEZHA 未运行，重启中……"
       pkill -x 'npm' 2>/dev/null
       nohup ./nezha.sh >/dev/null 2>&1 &
       sleep 2
          if pgrep -x 'npm' > /dev/null; then
             green "NEZHA 已重启"
          else
             red "NEZHA 重启失败"
          fi
    fi
  else
    purple "NEZHA 变量为空，跳过运行"
  fi
}

# 运行 singbox 服务
run_sb() {
  if [ -e "${WORKDIR}/web" ] && [ -e "${WORKDIR}/config.json" ]; then
    cd "${WORKDIR}"
    export TMPDIR=$(pwd)
    [ -x "${WORKDIR}/web" ] || chmod +x "${WORKDIR}/web"
    [ -e "${WORKDIR}/config.json" ] || chmod 777 "${WORKDIR}/config.json"
    nohup ./web run -c config.json >/dev/null 2>&1 &
    sleep 2
    if pgrep -x 'web' > /dev/null; then
       green "singbox 正在运行"
    else
       red "singbox 未运行，重启中……"
       pkill -x 'web' 2>/dev/null
       nohup ./web run -c config.json >/dev/null 2>&1 &
       sleep 2
          if pgrep -x 'web' > /dev/null; then
             green "singbox 已重启"
          else
             red "singbox 重启失败"
          fi
    fi
  fi
}

# 运行 argo 服务
run_argo() {
  if [ -e "${WORKDIR}/argo.sh" ] && [ -n "$ARGO_DOMAIN" ] && [ -n "$ARGO_AUTH" ]; then
    purple "ARGO 变量均已设置，且脚本文件已生成"
    cd "${WORKDIR}"
    export TMPDIR=$(pwd)
    [ -x "${WORKDIR}/argo.sh" ] || chmod +x "${WORKDIR}/argo.sh"
    [ -x "${WORKDIR}/bot" ] || chmod +x "${WORKDIR}/bot"
    nohup ./argo.sh >/dev/null 2>&1 &
    sleep 2
    if pgrep -x 'bot' > /dev/null; then
       green "ARGO 正在运行"
    else
       red "ARGO 未运行，重启中……"
       pkill -x 'bot' 2>/dev/null
       nohup ./argo.sh >/dev/null 2>&1 &
       sleep 2
          if pgrep -x 'bot' > /dev/null; then
             green "ARGO
