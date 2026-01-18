import base64
import time
import os
import requests
from nacl.public import PrivateKey, PublicKey, Box
from nacl.encoding import RawEncoder

# =========================
# 配置
# =========================
REQUEST_LOGIN_URL = "https://access.openfrp.net/argoAccess/requestLogin"
POLL_LOGIN_URL = "https://access.openfrp.net/argoAccess/pollLogin"

POLL_INTERVAL = 5          # 每 5 秒轮询一次
MAX_DURATION = 300         # 5 分钟超时
AUTH_FILE = "authorization.txt"  # 保存 Authorization 的文件

# =========================
# 生成 Curve25519 密钥对
# =========================
def generate_keypair():
    private_key = PrivateKey.generate()
    public_key = private_key.public_key

    # ⚠️ 保留 '=' 补齐
    public_key_b64 = base64.urlsafe_b64encode(
        public_key.encode(RawEncoder)
    ).decode()

    return private_key, public_key_b64

# =========================
# 请求登录授权
# =========================
def request_login(public_key_b64):
    body = {"public_key": public_key_b64}
    print("[DEBUG] POST body:", body)

    resp = requests.post(
        REQUEST_LOGIN_URL,
        json=body,
        timeout=10
    )

    if resp.status_code != 200:
        print("[ERROR] Response status:", resp.status_code)
        print("[ERROR] Response body:", resp.text)
        resp.raise_for_status()

    data = resp.json()
    if data["code"] != 200:
        raise RuntimeError(f"Request login failed: {data}")

    return data["data"]["authorization_url"], data["data"]["request_uuid"]

# =========================
# 解密 Authorization
# =========================
def decrypt_authorization(client_private_key, server_public_key_b64, encrypted_b64):
    server_public_key_bytes = base64.urlsafe_b64decode(server_public_key_b64 + "==")
    encrypted_bytes = base64.b64decode(encrypted_b64)

    server_public_key = PublicKey(server_public_key_bytes, RawEncoder)
    box = Box(client_private_key, server_public_key)

    decrypted = box.decrypt(encrypted_bytes)
    return decrypted.decode()

# =========================
# 轮询授权
# =========================
def poll_login(client_private_key, request_uuid):
    start_time = time.time()

    while True:
        if time.time() - start_time > MAX_DURATION:
            raise TimeoutError("Authorization polling timed out")

        resp = requests.get(
            POLL_LOGIN_URL,
            params={"request_uuid": request_uuid},
            timeout=10
        )

        # 429 直接退出
        if resp.status_code == 429:
            raise RuntimeError("Rate limited (429), exit immediately")

        # 400 错误提示
        if resp.status_code == 400:
            print("[ERROR] 400 Bad Request - request_uuid may be expired or wrong format")
            print(resp.text)
            raise RuntimeError("PollLogin failed: 400 Bad Request")

        # 空响应直接继续轮询
        if not resp.text.strip():
            print("[INFO] Empty response, continue polling...")
            time.sleep(POLL_INTERVAL)
            continue

        # 尝试解析 JSON
        try:
            data = resp.json()
        except Exception:
            print("[WARNING] Failed to parse JSON, response:")
            print(resp.text)
            time.sleep(POLL_INTERVAL)
            continue

        # 成功获取 data
        if data.get("code") == 200 and data.get("data"):
            encrypted_auth = data["data"]["authorization_data"]
            server_pubkey_b64 = resp.headers.get("x-request-public-key")

            if not server_pubkey_b64:
                raise RuntimeError("Missing server public key header")

            return decrypt_authorization(
                client_private_key,
                server_pubkey_b64,
                encrypted_auth
            )

        # 无数据时继续轮询
        time.sleep(POLL_INTERVAL)

# =========================
# 保存 Authorization 到文件
# =========================
def save_authorization_to_file(authorization, filename=AUTH_FILE):
    with open(filename, "w") as f:
        f.write(authorization)
    # 设置文件权限，仅当前用户可读写
    try:
        os.chmod(filename, 0o600)
    except Exception:
        pass  # Windows 不支持 chmod，不影响
    print(f"[✓] Authorization saved to {filename}")

# =========================
# 主流程
# =========================
def main():
    print("[*] Generating Curve25519 keypair...")
    client_private_key, client_public_key_b64 = generate_keypair()

    print("[*] Requesting login authorization...")
    auth_url, request_uuid = request_login(client_public_key_b64)

    print("[!] Please open the following URL in browser to authorize:")
    print(auth_url)
    print("[*] Waiting for user authorization...")

    authorization = poll_login(client_private_key, request_uuid)

    print("[✓] Authorization obtained:")
    print(authorization)

    # 保存到文件
    save_authorization_to_file(authorization)

if __name__ == "__main__":
    main()
