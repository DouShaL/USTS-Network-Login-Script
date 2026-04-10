#!/bin/bash

BASE_URL="http://10.160.63.9:801"
USERNAME=""  # 账户
PASSWORD=""  # 密码
OPERATOR=""  # 运营商 keda/cmcc/unicom/telecom

echo "==========================="
echo " 🍎苏科大校园网自动认证脚本"
echo "=========================== "
echo

# 检查网络
check_network() {
    echo "[$(date +"%T")] 检查服务器连通性..."
    until ping -c 1 -W 2 10.160.63.9 >/dev/null 2>&1; do
        echo "[$(date +"%T")] 服务器不可达，3秒后重试..."
        sleep 3
    done
    echo "[$(date +"%T")] 网络正常."
}

# 获取本机IP
get_ip() {
    echo "[$(date +"%T")] 正在获取本机校园网 IP..."

    # 尝试通过 ip addr 获取 (OpenWrt/现代Linux标准)
    WLAN_USER_IP=$(ip addr 2>/dev/null | grep -oE 'inet 10\.160\.[0-9]+\.[0-9]+' | awk '{print $2}' | head -n 1)

    # 如果 ip addr 获取失败，尝试 ifconfig
    if [[ -z "$WLAN_USER_IP" ]]; then
        WLAN_USER_IP=$(ifconfig 2>/dev/null | grep "inet " | awk '{print $2}' | sed 's/addr://' | grep "^10\.160\." | head -n 1)
    fi

    # 检查结果
    if [[ -z "$WLAN_USER_IP" ]]; then
        echo "======================================================"
        echo "[$(date +"%T")] 错误：未找到 10.160 网段的有效 IP！"
        echo "[提示] 请确认已连接苏科大校园网 Wi-Fi 或插好网线后重试。"
        echo "======================================================"
        exit 1
    fi

    echo "[$(date +"%T")] 当前识别到有效 IP: $WLAN_USER_IP"
    echo
}

# 登录
login() {
    timestamp=$(($(date +%s) * 1000))
    callback_ts=$((($(date +%s) + 15) * 1000))

    LOGIN_URL="$BASE_URL/eportal/?c=Portal&a=login&callback=dr$callback_ts&login_method=1&user_account=${USERNAME}@${OPERATOR}&user_password=$PASSWORD&wlan_user_ip=$WLAN_USER_IP&wlan_user_mac=000000000000&wlan_ac_ip=221.178.235.146&wlan_ac_name=JSSUZ-MC-CMNET-BRAS-KEDA_ME60X8&jsVersion=3.0&_=${timestamp}"

    echo "[$(date +"%T")] 正在登录..."

    RESPONSE=$(curl -s "$LOGIN_URL")

    if [[ -z "$RESPONSE" ]]; then
        echo "[$(date +"%T")] *** 请求失败（无响应）***"
        echo
        sleep 6
        check_network
        login
    else
        echo "[$(date +"%T")] 服务器响应: $RESPONSE"
        echo
    fi

    if echo "$RESPONSE" | grep -q '"result":"1"'; then
        echo "[$(date +"%T")] *** 登录成功 ***"
        exit 0
    fi

    if echo "$RESPONSE" | grep -q '"ret_code":"2"'; then
        echo "[$(date +"%T")] *** 已经在线 ***"
        exit 0
    fi

    echo "[$(date +"%T")] *** 登录失败，6秒后重试... ***"
    sleep 6
    login
}

# 执行流程
check_network
get_ip
login
