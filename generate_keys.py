import nacl.utils
from nacl.public import PrivateKey, PublicKey
import base64

def generate_keypair():
    # 生成 Curve25519 私钥和公钥
    private_key = PrivateKey.generate()
    public_key = private_key.public_key

    # 将公钥和私钥转换为 base64 编码字符串
    private_key_b64 = base64.urlsafe_b64encode(private_key.encode()).decode('utf-8')
    public_key_b64 = base64.urlsafe_b64encode(public_key.encode()).decode('utf-8')

    return private_key_b64, public_key_b64

def save_key_to_file(filename, key_data):
    with open(filename, "w") as f:
        f.write(key_data)
    print(f"Key saved to {filename}")

if __name__ == "__main__":
    # 生成密钥对
    private_key_b64, public_key_b64 = generate_keypair()

    # 保存密钥到文件
    save_key_to_file("private_key.pem", private_key_b64)
    save_key_to_file("public_key.pem", public_key_b64)

    print("[✓] 密钥对已成功生成并保存。")
    print(f"Private Key: {private_key_b64}")
    print(f"Public Key: {public_key_b64}")
