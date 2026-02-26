# 更新源并升级包
pkg update && pkg upgrade

# 安装 Python 和 编译工具链
pkg install -y python clang make pkg-config libsodium
# 关键：设置环境变量强制使用系统库，避免它尝试自己下载编译 libsodium
export SODIUM_INSTALL=system

# 执行安装
pip install pynacl
