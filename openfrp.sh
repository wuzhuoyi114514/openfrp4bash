#/bin/bash
echo '                         __            '
echo '  ___  _ __   ___ _ __  / _|_ __ _ __  '
echo " / _ \| '_ \ / _ \ '_ \| |_| '__| '_ \ "
echo '| (_) | |_) |  __/ | | |  _| |  | |_) |'
echo ' \___/| .__/ \___|_| |_|_| |_|  | .__/ '
echo '      |_|                       |_|    '
echo 'openfrp command program     version 0.02 for x86_64'

if [ -e .authorization ]
then
login=$(cat .authorization)
echo automantic logged in
curl -s -X POST https://api.openfrp.net/frp/api/getUserInfo \
         -H "Authorization: $login " | jq
else
python oflogin.py
login=$(cat .authorization)
#read -s -p 'openfrp Authorization:' login
curl -s -X POST https://api.openfrp.net/frp/api/getUserInfo \
         -H "Authorization: $login " | jq
fi

echo
while :
do
read -p "of-cmd-0.02$ " put
case $put in
add) echo add tunnal
read -p "节点ID?:" id
read -p "名字:" name
read -p "类型:" type
read -p "本地地址:" local
read -p "本地端口:" lport
if [[ "$type" == "http" || "$type" = "https" ]]
then
read -p "绑定域名? " bind
fi
read -p "远程端口:" rport
read -p "高级功能(yes / No)?:" adv
if [[ "$adv" == "yes" || "$adv" == "y" ]]
then
read -p "强制https?(true or false):" fhttps
read -p "数据加密(true or false):" datae
read -p "数据压缩(true or false):" datag
read -p "自动TLS?(true or false):" atls
read -p "Proxy Protocol V2(true or false):" proxypro
else
datae=false
datag=false
atls=false
proxypro=false
fhttps=false
fi
echo


# 1. 先转成数组 
# 2. 再通过 @json 将数组序列化为带转义的字符串
final_format=$(jq -n --arg b "$bind" '[$b] | @json')

curl -s -X POST https://api.openfrp.net/frp/api/newProxy \
-H "Authorization: $login " \
-H "Content-Type: application/json" \
-d "{
  \"dataEncrypt\": \"$datae\",
  \"dataGzip\": \"$datag\",
  \"domain_bind\":"$final_format",
  \"local_addr\": \"$local\",
  \"local_port\": $lport,
  \"custom\": \"\",
  \"name\": \"$name\",
  \"node_id\": \"$id\",
  \"remote_port\": $rport,
  \"type\": \"$type\",
  \"autoTls\": \"$atls\",
  \"forceHttps\": $fhttps,
  \"proxyProtocolVersion\": \"$proxypro\"
}" |  jq -r .msg
echo
;;
list)
curl -s -X POST "https://api.openfrp.net/frp/api/getNodeList" \
  -H "Authorization: $login " | jq -r .data.list
echo
;;
ulist)
curl -s -X POST "https://api.openfrp.net/frp/api/getUserProxies" \
  -H "Authorization: $login " | jq -r '.data | { total, list }'
echo
;;
remove)
read -p "节点ID?:" id
curl -s -X POST "https://api.openfrp.net/frp/api/removeProxy" \
  -H "Content-Type: application/json" \
  -H "Authorization: $login" \
  -d "{\"proxy_id\": \"$id\"}" | jq .msg

echo
;;
login)
python oflogin.py
login=$(cat authorization.txt)
curl -s -X POST https://api.openfrp.net/frp/api/getUserInfo \
         -H "Authorization: $login " | 
echo
;;
help) echo "add 添加节点 exit 退出 list 获取所有节点 ulist 获取用户节点 remove 删除节点 login 重新登录 start 启动节点 edit 编辑隧道"
;;
"") continue
;;
start)
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
 token=$(resp=$(curl -s -X POST https://api.openfrp.net/frp/api/getUserInfo \
  -H "Authorization: $(tr -d '\n\r ' < .authorization)")&&echo "$resp" | jq -r '.data.token')
read -p "需要启动的节点ID?" startid
./frpc_linux_amd64 -u $token -p $startid -n
;;
edit)
echo 还没做
;;
exit) exit
;;
*) echo "未知命令"
;;
esac
done
