#!/bin/bash

USERNAME=$(whoami)
WORKDIR="/home/${USERNAME}/logs"
CRON_NEZHA="nohup ./nezha.sh >/dev/null 2>&1 &"
CRON_SB="nohup ./web run -c config.json >/dev/null 2>&1 &"
CRON_ARGO="nohup ./argo.sh >/dev/null 2>&1 &"
chmod -R 755 "${WORKDIR}"

(crontab -l | grep -v -E "@reboot pkill -kill -u $(whoami)|pgrep -x \"npm\"|pgrep -x \"web\"|pgrep -x \"bot\"") | crontab -
echo "检查已存在的特定任务并清除"
crontab -r
#echo "清除所有已存在的 crontab 任务"

# 初始化一个新的 crontab 文件内容
NEW_CRONTAB=""

echo "正在添加 保活任务 的 crontab 重启任务"
NEW_CRONTAB+="@reboot pkill -kill -u $(whoami) cd ${WORKDIR} && ${CRON_SB}\n"
NEW_CRONTAB+="* * * * * curl -s https://raw.githubusercontent.com/chindden/serv00-vmess-sock5/refs/heads/main/check_sb_cron.sh -o check_sb_cron.sh && bash check_sb_cron.sh\n"
NEW_CRONTAB+="*/2 * * * * if ! pg aux | grep '[n]ezha-agent' > /dev/null; then nohup /home/${USERNAME}/.nezha-agent/start.sh >/dev/null 2>&1 & fi\n"
NEW_CRONTAB+="*/2 * * * * if ! ps aux | grep '[c]onfig' > /dev/null || ! ps aux | grep [l]ocalhost > /dev/null; then /bin/bash domains/${USERNAME}.serv00.net/logs/serv00keep.sh; fi\n"


# 将 crontab 任务更新一次性添加
(crontab -l; echo -e "$NEW_CRONTAB") | crontab -
echo "Crontab 任务已添加完成"
