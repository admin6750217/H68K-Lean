#!/bin/bash

set -e

# ============================================================
# OpenWrt master 初始化设置
# HomeProxy + Surge Rules + DNS
# ============================================================

echo "========================================"
echo "开始执行 OpenWrt 初始化设置..."
echo "========================================"

# ------------------------------------------------------------
# 默认 LAN 地址修改为 192.168.8.1
# ------------------------------------------------------------

echo "修改默认 LAN 地址为 192.168.8.1..."

if [ -f "package/base-files/files/bin/config_generate" ]; then
    sed -i 's/192\.168\.1\.1/192.168.8.1/g' \
        package/base-files/files/bin/config_generate
fi

if [ -f "package/base-files/luci/bin/config_generate" ]; then
    sed -i 's/192\.168\.1\.1/192.168.8.1/g' \
        package/base-files/luci/bin/config_generate
fi

# ------------------------------------------------------------
# config 文件权限
# ------------------------------------------------------------

if [ -d "files/etc/config" ]; then
    chmod 644 files/etc/config/* 2>/dev/null || true
fi

# ============================================================
# HomeProxy
# ============================================================

echo
echo "========================================"
echo "开始处理 HomeProxy..."
echo "========================================"

# OpenWrt 官方 master 默认 LuCI feed 不包含 HomeProxy
# 因此直接将 ImmortalWrt HomeProxy 源码放入 package/
HOMEPROXY_DIR="./package/luci-app-homeproxy"

HOMEPROXY_REPO="https://github.com/immortalwrt/homeproxy.git"
HOMEPROXY_BRANCH="master"

# ------------------------------------------------------------
# 删除旧 HomeProxy
# ------------------------------------------------------------

if [ -d "${HOMEPROXY_DIR}" ]; then
    echo "发现旧 HomeProxy，删除..."
    rm -rf "${HOMEPROXY_DIR}"
fi

# ------------------------------------------------------------
# 下载 HomeProxy
# ------------------------------------------------------------

echo "正在下载 HomeProxy..."

git clone \
    --depth=1 \
    --single-branch \
    --branch "${HOMEPROXY_BRANCH}" \
    "${HOMEPROXY_REPO}" \
    "${HOMEPROXY_DIR}"

if [ ! -d "${HOMEPROXY_DIR}" ]; then
    echo "错误：HomeProxy 下载失败！"
    exit 1
fi

echo "✅ HomeProxy 源码下载成功"

# ------------------------------------------------------------
# 检查 Makefile
# ------------------------------------------------------------

if [ ! -f "${HOMEPROXY_DIR}/Makefile" ]; then
    echo "错误：HomeProxy Makefile 不存在！"
    exit 1
fi

# ------------------------------------------------------------
# 检查 homeproxy 配置
# ------------------------------------------------------------

DNS_CONFIG_FILE="${HOMEPROXY_DIR}/root/etc/config/homeproxy"

if [ ! -f "${DNS_CONFIG_FILE}" ]; then
    echo "错误：HomeProxy 配置文件不存在："
    echo "${DNS_CONFIG_FILE}"
    exit 1
fi

echo "✅ HomeProxy 配置文件存在"

# ------------------------------------------------------------
# 检查资源目录
# ------------------------------------------------------------

HP_PATH="root/etc/homeproxy"
HP_RESOURCES="${HOMEPROXY_DIR}/${HP_PATH}/resources"

mkdir -p "${HP_RESOURCES}"

echo "HomeProxy resources：${HP_RESOURCES}"

# ============================================================
# HomeProxy DNS 配置
# ============================================================

echo
echo "========================================"
echo "配置 HomeProxy DNS..."
echo "========================================"

# 国外 DNS
# AdGuard DNS IPv4 DoH
sed -i \
    "s#option dns_server '8\.8\.8\.8'#option dns_server 'https://94.140.14.140/dns-query'#g" \
    "${DNS_CONFIG_FILE}"

# 国内 DNS
# 阿里 DNS DoH
sed -i \
    "s#option china_dns_server '223\.5\.5\.5'#option china_dns_server 'https://223.5.5.5/dns-query'#g" \
    "${DNS_CONFIG_FILE}"

echo "当前 HomeProxy DNS："

grep -E \
    "option (dns_server|china_dns_server)" \
    "${DNS_CONFIG_FILE}" || true

echo "✅ HomeProxy DNS 配置完成"

# ============================================================
# Surge Rules
# ============================================================

echo
echo "========================================"
echo "开始更新 HomeProxy 规则..."
echo "========================================"

HP_RULE="surge"
RULE_REPO="https://github.com/Loyalsoldier/surge-rules.git"

rm -rf "./${HP_RULE}"

git clone \
    -q \
    --depth=1 \
    --single-branch \
    --branch "release" \
    "${RULE_REPO}" \
    "./${HP_RULE}"

if [ ! -d "./${HP_RULE}" ]; then
    echo "错误：surge-rules 下载失败！"
    exit 1
fi

cd "./${HP_RULE}"

# ------------------------------------------------------------
# 获取规则版本
# ------------------------------------------------------------

RES_VER="$(git log -1 --pretty=format:'%s' | grep -oE '[0-9]+' | head -1 || true)"

if [ -z "${RES_VER}" ]; then
    RES_VER="$(date +%Y%m%d)"
fi

echo "规则版本：${RES_VER}"

# ------------------------------------------------------------
# 生成版本文件
# ------------------------------------------------------------

printf '%s\n' "${RES_VER}" > china_ip4.ver
printf '%s\n' "${RES_VER}" > china_ip6.ver
printf '%s\n' "${RES_VER}" > china_list.ver
printf '%s\n' "${RES_VER}" > gfw_list.ver

# ------------------------------------------------------------
# IPv4 / IPv6 中国 IP
# ------------------------------------------------------------

if [ -f "cncidr.txt" ]; then

    awk -F, '
    /^IP-CIDR,/ {
        print $2
    }
    ' cncidr.txt > china_ip4.txt

    awk -F, '
    /^IP-CIDR6,/ {
        print $2
    }
    ' cncidr.txt > china_ip6.txt

else
    echo "警告：cncidr.txt 不存在"
    : > china_ip4.txt
    : > china_ip6.txt
fi

# ------------------------------------------------------------
# 国内域名
# ------------------------------------------------------------

if [ -f "direct.txt" ]; then
    sed 's/^\.//g' direct.txt > china_list.txt
else
    echo "警告：direct.txt 不存在"
    : > china_list.txt
fi

# ------------------------------------------------------------
# GFW 域名
# ------------------------------------------------------------

if [ -f "gfw.txt" ]; then
    sed 's/^\.//g' gfw.txt > gfw_list.txt
else
    echo "警告：gfw.txt 不存在"
    : > gfw_list.txt
fi

# ------------------------------------------------------------
# 返回 OpenWrt 根目录
# ------------------------------------------------------------

cd ..

# ------------------------------------------------------------
# 清理旧规则
# ------------------------------------------------------------

rm -f \
    "${HP_RESOURCES}/china_ip4.ver" \
    "${HP_RESOURCES}/china_ip4.txt" \
    "${HP_RESOURCES}/china_ip6.ver" \
    "${HP_RESOURCES}/china_ip6.txt" \
    "${HP_RESOURCES}/china_list.ver" \
    "${HP_RESOURCES}/china_list.txt" \
    "${HP_RESOURCES}/gfw_list.ver" \
    "${HP_RESOURCES}/gfw_list.txt"

# ------------------------------------------------------------
# 安装规则
# ------------------------------------------------------------

cp -f "./${HP_RULE}/china_ip4.ver" \
    "${HP_RESOURCES}/"

cp -f "./${HP_RULE}/china_ip4.txt" \
    "${HP_RESOURCES}/"

cp -f "./${HP_RULE}/china_ip6.ver" \
    "${HP_RESOURCES}/"

cp -f "./${HP_RULE}/china_ip6.txt" \
    "${HP_RESOURCES}/"

cp -f "./${HP_RULE}/china_list.ver" \
    "${HP_RESOURCES}/"

cp -f "./${HP_RULE}/china_list.txt" \
    "${HP_RESOURCES}/"

cp -f "./${HP_RULE}/gfw_list.ver" \
    "${HP_RESOURCES}/"

cp -f "./${HP_RULE}/gfw_list.txt" \
    "${HP_RESOURCES}/"

rm -rf "./${HP_RULE}"

echo "✅ HomeProxy 规则已更新"

# ============================================================
# HomeProxy 检查
# ============================================================

echo
echo "========================================"
echo "检查 HomeProxy..."
echo "========================================"

echo "HomeProxy 路径："
echo "${HOMEPROXY_DIR}"

echo
echo "HomeProxy Makefile："
grep -E \
    'PKG_NAME|LUCI_TITLE|LUCI_DEPENDS' \
    "${HOMEPROXY_DIR}/Makefile" || true

echo
echo "HomeProxy DNS："
grep -E \
    "option (dns_server|china_dns_server)" \
    "${DNS_CONFIG_FILE}" || true

echo
echo "HomeProxy 规则："
ls -lh "${HP_RESOURCES}/" || true

# ============================================================
# 更新 feeds
# ============================================================

echo
echo "========================================"
echo "更新 OpenWrt feeds..."
echo "========================================"

./scripts/feeds update -a

./scripts/feeds install -a

echo "✅ feeds 更新完成"

# ============================================================
# 检查 HomeProxy 是否被识别
# ============================================================

echo
echo "========================================"
echo "检查 luci-app-homeproxy..."
echo "========================================"

if [ -d "package/luci-app-homeproxy" ]; then
    echo "✅ package/luci-app-homeproxy 存在"
else
    echo "错误：package/luci-app-homeproxy 不存在！"
    exit 1
fi

# ============================================================
# 完成
# ============================================================

echo
echo "========================================"
echo "HomeProxy 处理完成！"
echo "初始化设置执行成功!"
echo "========================================"
