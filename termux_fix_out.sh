# 更新源并升级包
pkg update -y && pkg upgrade -y

# 安装 Python 和 编译工具链
pkg install -y python clang make pkg-config libsodium
# 关键：设置环境变量强制使用系统库，避免它尝试自己下载编译 libsodium
export SODIUM_INSTALL=system

# 执行安装
pip install pynacl

# 2. 安装/重装证书包
pkg install ca-certificates

# 3. frpc关闭证书校验(可能吧)
export GODEBUG=x509ignoreCN=0
# 或者针对某些环境
export GIT_SSL_NO_VERIFY=true

#依赖补全
pkg install wget curl jq whiptail -y
