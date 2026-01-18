echo '                         __            '
echo '  ___  _ __   ___ _ __  / _|_ __ _ __  '
echo " / _ \| '_ \ / _ \ '_ \| |_| '__| '_ \ "
echo '| (_) | |_) |  __/ | | |  _| |  | |_) |'
echo ' \___/| .__/ \___|_| |_|_| |_|  | .__/ '
echo '  |_|                       |_|    '
echo 'openfrp command program'

python oflogin.py
login=$(cat authorization.txt)
#read -s -p 'openfrp Authorization:' login
curl -X POST https://api.openfrp.net/frp/api/getUserInfo \
         -H "Authorization: $login "

echo
while :
do
read -p "of-cmd-0.01$" put
case $put in
add) echo add tunnal
read -p "name" name
read -p "type" type
read -p "localaddr" local
read -p "local port" lport
read -p "remote port" rport
echo
curl -X POST https://api.openfrp.net/frp/api/newProxy \
-H "Authorization: a2d2a2e96dd843129723d1fba208f493YJHKMDLHNTETNJNKYI0ZMWFH" \
-H "Content-Type: application/json" \
-d "{
  \"dataEncrypt\": false,
  \"dataGzip\": false,
  \"domain_bind\": \"\",
  \"local_addr\": \"$local\",
  \"local_port\": $lport,
  \"custom\": \"\",
  \"name\": \"$name\",
  \"node_id\": 26,
  \"remote_port\": $rport,
  \"type\": \"$type\",
  \"autoTls\": false,
  \"forceHttps\": false,
  \"proxyProtocolVersion\": false
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
read -p "id?" id
curl -X POST "https://api.openfrp.net/frp/api/removeProxy" \
  -H "Content-Type: application/json" \
  -H "Authorization: $login" \
  -d "{\"proxy_id\": \"$id\"}"

echo
;;
help) echo "add 添加节点 exit 退出 list 获取所有节点 ulist 获取用户节点 remove 删除节点"
;;
"") continue
;;
exit) exit
;;
*) echo "未知命令"
;;
esac
done
