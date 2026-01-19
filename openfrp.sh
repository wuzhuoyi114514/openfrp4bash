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
echo automantic logind
curl -X POST https://api.openfrp.net/frp/api/getUserInfo \
         -H "Authorization: $login "
else
python oflogin.py
login=$(cat .authorization)
#read -s -p 'openfrp Authorization:' login
curl -X POST https://api.openfrp.net/frp/api/getUserInfo \
         -H "Authorization: $login "
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
read -p "远程端口:" rport
read -p "高级功能(yes / No)?:" adv
if [[ "$adv" == "yes" || "$adv" == "y" ]]
then
read -p "数据加密(true or false):" datae
read -p "数据压缩(true or false):" datag
read -p "自动TLS?(true or false):" atls
read -p "Proxy Protocol V2(true or false):" proxypro
else
datae=false
datag=false
atls=false
proxypro=false
fi
echo
curl -X POST https://api.openfrp.net/frp/api/newProxy \
-H "Authorization: a2d2a2e96dd843129723d1fba208f493YJHKMDLHNTETNJNKYI0ZMWFH" \
-H "Content-Type: application/json" \
-d "{
  \"dataEncrypt\": \"$datae\",
  \"dataGzip\": \"$datag\",
  \"domain_bind\": \"\",
  \"local_addr\": \"$local\",
  \"local_port\": $lport,
  \"custom\": \"\",
  \"name\": \"$name\",
  \"node_id\": \"$id\",
  \"remote_port\": $rport,
  \"type\": \"$type\",
  \"autoTls\": \"$atls\",
  \"forceHttps\": false,
  \"proxyProtocolVersion\": \"$proxypro\"
}"
echo
;;
list)
curl -X POST "https://api.openfrp.net/frp/api/getNodeList" \
  -H "Authorization: $login "
echo
;;
ulist)
curl -X POST "https://api.openfrp.net/frp/api/getUserProxies" \
  -H "Authorization: $login "
echo
;;
remove)
read -p "节点ID?:" id
curl -X POST "https://api.openfrp.net/frp/api/removeProxy" \
  -H "Content-Type: application/json" \
  -H "Authorization: $login" \
  -d "{\"proxy_id\": \"$id\"}"

echo
;;
login)
python oflogin.py
login=$(cat authorization.txt)
curl -X POST https://api.openfrp.net/frp/api/getUserInfo \
         -H "Authorization: $login "
echo
;;
help) echo "add 添加节点 exit 退出 list 获取所有节点 ulist 获取用户节点 remove 删除节点 login 重新登录 start 启动节点"
;;
"") continue
;;
start)
if [ -e frpc_linux_amd64 ]; then
    continue
else
    echo "你必须下载openfrp的frpc客户端才可以启动"
    echo "现在下载...."
    wget https://staticassets.naids.com/client/OF_0.65.0_a4a4b99f_251013/frpc_linux_amd64.tar.gz
    tar -xvf frpc_linux_amd64.tar.gz
fi
 token=$(resp=$(curl -s -X POST https://api.openfrp.net/frp/api/getUserInfo \
  -H "Authorization: $(tr -d '\n\r ' < .authorization)")&&echo "$resp" | jq -r '.data.token')
read -p "需要启动的节点ID?" startid
./frpc_linux_amd64 -u $token -p $startid

;;
exit) exit
;;
*) echo "未知命令"
;;
esac
done
