#!/bin/bash

#/bin/bash
echo '                         __            '
echo '  ___  _ __   ___ _ __  / _|_ __ _ __  '
echo " / _ \| '_ \ / _ \ '_ \| |_| '__| '_ \ "
echo '| (_) | |_) |  __/ | | |  _| |  | |_) |'
echo ' \___/| .__/ \___|_| |_|_| |_|  | .__/ '
echo '      |_|                       |_|    '
echo 'openfrp helpful program TUI     version 0.02 for x86_64'

echo "等待启动..."
sleep 0.5

# =========================
# 1. 基础配置与环境修复
# =========================
AUTH_FILE=".authorization"
API_BASE="https://api.openfrp.net/frp/api"
TMP_DATA="/tmp/of_scroll.txt"
CACHE_NODES="/tmp/of_nodes.json"

# 解决 TUI 渲染与颜色
export TERM=xterm
export NEWT_COLORS='root=,blue window=,lightgray border=black,lightgray button=white,red'

check_env() {
    for cmd in jq curl whiptail; do
        command -v $cmd &> /dev/null || { echo "缺失组件: $cmd"; exit 1; }
    done
}

check_auth() {
    [ -f "$AUTH_FILE" ] || { 
        [ -f "oflogin.sh" ] && bash oflogin.sh || { whiptail --msgbox "未登录且缺失 oflogin.sh" 8 45; exit 1; }
    }
    login=$(cat "$AUTH_FILE" | tr -d '\n\r ')
}

show_api_msg() {
    local msg=$(echo "$1" | jq -r '.msg // "未知反馈"')
    whiptail --title "系统反馈" --msgbox "$msg" 8 45
}

# =========================
# 2. 功能核心
# =========================

# [功能] 账号详细
show_full_info() {
    local resp=$(curl -s -X POST "$API_BASE/getUserInfo" -H "Authorization: $login")
    local info=$(echo "$resp" | jq -r '.data | "
[ 账户概览 ]
用户名: \(.username) (ID: \(.id))
用户组: \(.friendlyGroup)
实名认证: \(if .realname then "已认证" else "未认证" end)
注册邮箱: \(.email)
注册时间: \(.regTime)

[ 网络限额 ]
上行带宽: \(.outLimit) Kbps
下行带宽: \(.inLimit) Kbps
用户密钥: \(.token)

[ 资源统计 ]
剩余流量: \(.traffic) MiB
隧道数量: \(.used) / \(.proxies) 条

"')
    whiptail --title "账号一览" --msgbox  "$info" 22 65
}

# [功能] 滚动显示详情 (解决显示不全)
scroll_view() {
    echo -e "$2" > "$TMP_DATA"
    whiptail --title "$1" --scrolltext --textbox "$TMP_DATA" 22 75
    rm -f "$TMP_DATA"
}

# 获取节点菜单数据
get_node_menu() {
    # 1. 检查缓存，若为空则抓取
    if [ ! -s "$CACHE_NODES" ]; then
        curl -s -X POST "$API_BASE/getNodeList" -H "Authorization: $login" > "$CACHE_NODES"
    fi

    # 2. 这里的输出不要重定向到 /dev/null，而是直接打印出来供外部捕获
    # 格式：ID 名称 (ID 是 Tag，名称是 Item)
        jq -r '.data.list[] | [ .id, "[\(.group)] \(.name) [\(.comments)]" ] | @tsv' "$CACHE_NODES"
}

# [功能] 添加隧道 (TUI 交互版)
add_proxy() {
local NODE_LIST=()

    # 读取为数组（核心！！！）
    while IFS=$'\t' read -r id name; do
        NODE_LIST+=("$id" "$name")
    done < <(get_node_menu)

    if [ ${#NODE_LIST[@]} -eq 0 ]; then
        whiptail --msgbox "节点列表为空" 8 45
        return
    fi

    nid=$(whiptail \
        --title "选择节点" \
        --menu "请选择一个节点" \
        25 115 17 \
        "${NODE_LIST[@]}" \
        3>&1 1>&2 2>&3)

    [ -z "$nid" ] && return
    local name=$(whiptail --inputbox "隧道名称:" 8 45 "work" 3>&1 1>&2 2>&3)
    local type=$(whiptail --menu "协议类型" 15 45 6 "tcp" "TCP" "udp" "UDP" "http" "HTTP" "https" "HTTPS" 3>&1 1>&2 2>&3)
    local l_addr=$(whiptail --inputbox "本地地址:" 8 45 "127.0.0.1" 3>&1 1>&2 2>&3)
    local l_port=$(whiptail --inputbox "本地端口:" 8 45 "80" 3>&1 1>&2 2>&3)
    local r_port=$(whiptail --inputbox "远程端口 (0随机):" 8 45 "0" 3>&1 1>&2 2>&3)
    if [ $r_port = 0 ] ; then
    rand=$(( (RANDOM << 15 | RANDOM) % 65535 + 1 ))
r_port=$rand
fi
    local bind=""
    [[ "$type" == "http" || "$type" == "https" ]] && bind=$(whiptail --inputbox "绑定域名:" 8 45 "" 3>&1 1>&2 2>&3)
    
    # 初始默认值
fhttps="false"; datae="false"; datag="false"; atls="false"; proxypro="false"

if whiptail --title "高级功能" --yesno "是否需要修改高级功能设置？" 8 45; then
    # 强制 HTTPS
    whiptail --title "高级设置" --yesno "是否开启 强制HTTPS (forceHttps)?" 8 45 \
        && fhttps="true" || fhttps="false"
        
    # 数据加密
    whiptail --title "高级设置" --yesno "是否开启 数据加密 (dataEncrypt)?" 8 45 \
        && datae="true" || datae="false"
        
    # 数据压缩
    whiptail --title "高级设置" --yesno "是否开启 数据压缩 (dataGzip)?" 8 45 \
        && datag="true" || datag="false"
        
    # 自动 TLS
    whiptail --title "高级设置" --yesno "是否开启 自动TLS (autoTls)?" 8 45 \
        && atls="true" || atls="false"
        
    # Proxy Protocol
    whiptail --title "高级设置" --yesno "是否开启 Proxy Protocol V2?" 8 45 \
        && proxypro="true" || proxypro="false"
fi

    local domain_json=$(jq -n --arg b "$bind" '[$b] | @json')
    local resp=$(curl -s -X POST "$API_BASE/newProxy" -H "Authorization: $login" -H "Content-Type: application/json" \
        -d "{\"dataEncrypt\": $datae,\"dataGzip\": $datag,\"autoTls\": \"$atls\",\"forceHttps\": $fhttps,\"proxyProtocolVersion\": $proxypro,\"domain_bind\":$domain_json, \"local_addr\":\"$l_addr\", \"local_port\":$l_port, \"name\":\"$name\", \"node_id\":$nid, \"remote_port\":$r_port, \"type\":\"$type\"}")
    show_api_msg "$resp"
}

# [功能] 获取隧道列表菜单 (用于删除/编辑)
get_proxy_list() {
    # 修正点：将 proxy_type 改为 proxyType，将 proxy_name 改为 proxyName
    curl -s -X POST "$API_BASE/getUserProxies" -H "Authorization: $login" | \
    jq -r '.data.list[] | "\(.id) [\(.proxyType)] \(.proxyName) \(.friendlyNode)"' 
}

# =========================
# 3. 主界面逻辑
# =========================
check_env
check_auth

while :
do
    CHOICE=$(whiptail --title "OpenFRP TUI" --menu "请使用方向键选择操作" 22 70 12 \
        "1.INFO"  "【账户】全字段信息与流量统计" \
        "2.NODE"  "【节点】查看所有可用节点 (可滚动)" \
        "3.MY"    "【详情】查看所有隧道详细配置 (可滚动)" \
        "4.ADD"   "【新建】创建穿透隧道" \
        "5.EDIT"  "【编辑】修改现有隧道本地端口/名称" \
        "6.DEL"   "【删除】永久移除隧道" \
        "7.RUN"   "【启动】运行 frpc 客户端" \
        "8.RELOG" "【登录】重新获取授权/切换账号" \
        "9.ABOUT" "【关于】关于这个程序"\
        "0.EXIT"  "【退出】安全关闭" 3>&1 1>&2 2>&3)

    case $CHOICE in
        "1.INFO") show_full_info ;;
        "2.NODE") 
            resp=$(curl -s -X POST "$API_BASE/getNodeList" -H "Authorization: $login")
            content=$(echo "$resp" | jq -r '.data.list[] | "[\(.id)] \(.name)\n地址: \(.hostname)\n描述: \(.comments)\n----------------------------------------"')
            scroll_view "节点列表 (使用方向键翻页)" "$content" ;;
        "3.MY")
    resp=$(curl -s -X POST "$API_BASE/getUserProxies" -H "Authorization: $login")
    # 修正字段名：proxyName, proxyType, nid, remotePort, localIp, localPort
    content=$(echo "$resp" | jq -r '
        if (.data.list | length) == 0 then 
            "暂无隧道数据" 
        else 
            .data.list[] | "ID: \(.id)\n名称: \(.proxyName) [\(.proxyType)]\n节点: \(.nid) (\(.friendlyNode // "未知"))\n远程地址: \(.connectAddress // "无")\n本地配置: \(.localIp):\(.localPort)\n扩展地址:\(.extAddress//"无")\n----------------------------------------" 
        end')
    scroll_view "我的隧道详情" "$content"
    ;;
        "4.ADD") add_proxy ;;
        "5.EDIT")
            list=$(get_proxy_list)
            if [ -z "$list" ]; then
        whiptail --title "提示" --msgbox "当前账户下没有隧道" 10 50
        continue
    fi
            nid=$()
# 改进版：使用数组处理菜单项
menu_options=()
while read -r line; do
    id=$(echo "$line" | awk '{print $1}')
    label=$(echo "$line" | cut -d' ' -f2-)
    menu_options+=("$id" "$label")
done <<< "$list"

# 调用时使用 "${menu_options[@]}"
pid=$(whiptail --title "选择编辑隧道" --menu "请选择要编辑的隧道" 20 60 10 "${menu_options[@]}" 3>&1 1>&2 2>&3)
            [ -n "$pid" ] && {
                nid=$(curl -s -X POST "https://api.openfrp.net/frp/api/getUserProxies" -H "Authorization: $login " | sed -n 's/.*"nid":[[:space:]]*\([0-9]\+\).*/\1/p')
                type=$(curl -s -X POST "https://api.openfrp.net/frp/api/getUserProxies" -H "Authorization: $login " | sed -n 's/.*"proxyType":[[:space:]]*"\([^"]*\)".*/\1/p')
                n_name=$(whiptail --inputbox "新名称:" 8 45 3>&1 1>&2 2>&3)
                n_addr=$(whiptail --inputbox "新本地地址:" 8 45 "127.0.0.1" 3>&1 1>&2 2>&3)
                n_port=$(whiptail --inputbox "新本地端口:" 8 45 3>&1 1>&2 2>&3)
    bind=""
        [[ "$type" == "http" || "$type" == "https" ]] && bind=$( whiptail --inputbox "绑定域名:" 8 45 "" 3>&1 1>&2 2>&3 )
    # 初始默认值
fhttps="false"; datae="false"; datag="false"; atls="false"; proxypro="false"
if whiptail --title "高级功能" --yesno "是否需要启用高级功能设置？" 8 45; then
    # 强制 HTTPS
    whiptail --title "高级设置" --yesno "是否开启 强制HTTPS (forceHttps)?" 8 45 \
        && fhttps="true" || fhttps="false"
    # 数据加密
    whiptail --title "高级设置" --yesno "是否开启 数据加密 (dataEncrypt)?" 8 45 \
        && datae="true" || datae="false"
    # 数据压缩
    whiptail --title "高级设置" --yesno "是否开启 数据压缩 (dataGzip)?" 8 45 \
        && datag="true" || datag="false"
    # 自动 TLS
    whiptail --title "高级设置" --yesno "是否开启 自动TLS (autoTls)?" 8 45 \
        && atls="true" || atls="false"
    # Proxy Protocol
    whiptail --title "高级设置" --yesno "是否开启 Proxy Protocol V2?" 8 45 \
        && proxypro="true" || proxypro="false"
fi
 domain_json=$(jq -n --arg b "$bind" '[$b] | @json')
                resp=$(curl -s -X POST "$API_BASE/editProxy" -H "Authorization: $login" -H "Content-Type: application/json" -d "{\"domain_bind\":$domain_json,\"dataEncrypt\": $datae,\"dataGzip\": $datag,\"autoTls\": \"$atls\",\"forceHttps\": $fhttps,\"proxyProtocolVersion\": $proxypro,\"proxy_id\":$pid, \"name\":\"$n_name\", \"local_addr\":\"$n_addr\", \"local_port\":$n_port,\"node_id\":$nid}")
                show_api_msg "$resp"
            } ;;
        "6.DEL")
            list=$(get_proxy_list)

    # 检查是否有隧道
    if [ -z "$list" ]; then
        whiptail --title "提示" --msgbox "当前账户下没有隧道" 10 50 10
        continue
    fi

# 改进版：使用数组处理菜单项
menu_options=()
while read -r line; do
    id=$(echo "$line" | awk '{print $1}')
    label=$(echo "$line" | cut -d' ' -f2-)
    menu_options+=("$id" "$label")
done <<< "$list"

# 调用时使用 "${menu_options[@]}"
pid=$(whiptail --title "选择删除隧道" --menu "请选择要删除的隧道" 20 60 10 "${menu_options[@]}" 3>&1 1>&2 2>&3)

    # 如果用户选择了项
    if [ -n "$pid" ]; then
        # 弹出确认框
        if whiptail --title "确认删除" --yesno "确定要删除 ID $pid 吗?" 8 45 10; then
            # 调用 API 删除隧道
            del_resp=$(curl -s -X POST "$API_BASE/removeProxy" \
                -H "Authorization: $login" \
                -H "Content-Type: application/json" \
                -d "{\"proxy_id\":$pid}")
            
            # 显示 API 响应
            show_api_msg "$del_resp"
        fi
    fi;;
        "7.RUN")
            list=$(get_proxy_list)
if [ -z "$list" ]; then
        whiptail --title "提示" --msgbox "当前账户下没有隧道" 10 50 10
        continue
    fi
    latest=$(curl -s -X GET 'https://api.openfrp.net/commonQuery/get?key=software' | jq -r .data.latest_full)
if [ -e frpc_linux_amd64 ]; then
    echo 进行检查更新
    frpc_ver=$(./frpc_linux_amd64 -v)
   if [ $frpc_ver == $latest ]
then
echo 版本是最新的
else
echo 版本不是最新的 更新中...
   wget -O frpc.tar.gz -q https://staticassets.naids.com/client/$latest/frpc_linux_amd64.tar.gz
    tar -xvf frpc.tar.gz
fi
else
    echo "你必须下载openfrp的frpc客户端才可以启动"
    echo "现在下载...."
    wget -O frpc.tar.gz -q https://staticassets.naids.com/client/$latest/frpc_linux_amd64.tar.gz
    tar -xvf frpc.tar.gz
fi
            [ -n "$list" ] && {
# 改进版：使用数组处理菜单项
menu_options=()
while read -r line; do
    id=$(echo "$line" | awk '{print $1}')
    label=$(echo "$line" | cut -d' ' -f2-)
    menu_options+=("$id" "$label")
done <<< "$list"

# 调用时使用 "${menu_options[@]}"
pid=$(whiptail --title "选择启动隧道" --menu "请选择要启动的隧道" 20 60 10 "${menu_options[@]}" 3>&1 1>&2 2>&3)
                [ -n "$pid" ] && {
                    token=$(curl -s -X POST "$API_BASE/getUserInfo" -H "Authorization: $login" | jq -r '.data.token')
                    clear && ./frpc_linux_amd64 -u "$token" -p "$pid" -n && read -p "已断开，回车返回菜单..." temp
                }
            } ;;
        "8.RELOG") rm -f "$AUTH_FILE" && check_auth ;;
        "9.ABOUT") whiptail --title "关于" --msgbox "Openfrp4Bash\nVer0.02\n此项目由社区开发，"OpenFrp"官方不负责除节点问题以外的技术支持\n此项目没有支持\n修BUG自己修" 12 65 15 ;;
        "0.EXIT" | "") rm -f $CACHE_NODES && exit 0 ;;
    esac
done
