#!/bin/bash

# =========================
# 配置
# =========================
REQUEST_LOGIN_URL="https://access.openfrp.net/argoAccess/requestLogin"
POLL_LOGIN_URL="https://access.openfrp.net/argoAccess/pollLogin"
AUTH_FILE=".authorization"
POLL_INTERVAL=5
MAX_DURATION=300

# 从生成的 Pem 文件中提取密钥字符串 (假设文件里只有 Base64 字符串)
# 如果你的 pem 文件包含 -----BEGIN...----- 标签，请手动提取中间的字符串
CLIENT_PRIVATE_KEY=$(cat private_key.pem)
CLIENT_PUBLIC_KEY=$(cat public_key.pem)

# =========================
# 1. 请求登录
# =========================
echo "[*] 正在发送登录请求..."
# 使用 curl 发送 JSON 负载
RESPONSE=$(curl -s -X POST "$REQUEST_LOGIN_URL" \
    -H "Content-Type: application/json" \
    -d "{\"public_key\": \"$CLIENT_PUBLIC_KEY\"}")

# 简单的 JSON 字段提取
CODE=$(echo "$RESPONSE" | grep -oP '"code":\s*\K\d+')
if [ "$CODE" != "200" ]; then
    echo "[ERROR] 请求失败: $RESPONSE"
    exit 1
fi

AUTH_URL=$(echo "$RESPONSE" | grep -oP '"authorization_url":\s*"\K[^"]+')
REQUEST_UUID=$(echo "$RESPONSE" | grep -oP '"request_uuid":\s*"\K[^"]+')

echo "------------------------------------------------------------"
echo "请在浏览器中打开以下链接进行授权："
echo "$AUTH_URL"
echo "------------------------------------------------------------"

# =========================
# 2. 轮询授权结果
# =========================
echo "[*] 正在等待用户授权..."
START_TIME=$(date +%s)

while true; do
    if [ $(($(date +%s) - START_TIME)) -gt $MAX_DURATION ]; then
        echo -e "\n[!] 授权超时，请重新运行脚本。"
        exit 1
    fi

    # 获取响应和 Header
    TMP_HEADER=$(mktemp)
    POLL_RESP=$(curl -s -i -G "$POLL_LOGIN_URL" --data-urlencode "request_uuid=$REQUEST_UUID" -D "$TMP_HEADER")
    HTTP_STATUS=$(grep "HTTP/" "$TMP_HEADER" | tail -n1 | awk '{print $2}')
    
    # 提取服务器公钥 (用于解密)
    SERVER_PUBKEY=$(grep -i "x-request-public-key:" "$TMP_HEADER" | awk '{print $2}' | tr -d '\r')
    rm "$TMP_HEADER"

    if [ "$HTTP_STATUS" == "429" ]; then
        echo -e "\n[!] 请求太频繁 (429)，请稍后再试。"
        exit 1
    fi

    # 检查是否有加密的 authorization 数据
    ENCRYPTED_DATA=$(echo "$POLL_RESP" | grep -oP '"authorization_data":\s*"\K[^"]+')

    if [ -z "$ENCRYPTED_DATA" ]; then
        printf "." # 打印进度点
        sleep $POLL_INTERVAL
        continue
    fi

    # =========================
    # 3. 解密 Authorization
    # =========================
    echo -e "\n[✓] 授权成功，正在解密..."

    # 调用一行 Python 处理 Curve25519 解密
    AUTHORIZATION=$(python3 -c "
import base64
from nacl.public import PrivateKey, PublicKey, Box
from nacl.encoding import RawEncoder

# 准备密钥和数据
sk_bytes = base64.urlsafe_b64decode('$CLIENT_PRIVATE_KEY' + '==')
pk_bytes = base64.urlsafe_b64decode('$SERVER_PUBKEY' + '==')
encrypted_bytes = base64.b64decode('$ENCRYPTED_DATA')

# 执行解密
box = Box(PrivateKey(sk_bytes), PublicKey(pk_bytes))
print(box.decrypt(encrypted_bytes).decode())
")

    echo "------------------------------------------------------------"
    echo "认证完成！您的 Authorization 令牌为："
    echo "$AUTHORIZATION"
    
    # 保存结果
    echo "$AUTHORIZATION" > "$AUTH_FILE"
    chmod 600 "$AUTH_FILE"
    echo "[*] 已加密保存至 $AUTH_FILE"
    echo "------------------------------------------------------------"
    break
done
