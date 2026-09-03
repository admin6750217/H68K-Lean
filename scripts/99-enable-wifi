#!/bin/sh
# files/etc/uci-defaults/99-enable-wifi
# 首次启动时自动启用无线 radio（默认编译出的固件 wireless 是 disabled 状态）

COUNTRY="CN"
# 按实际所在地区修改国家码，例如 CN / US / JP / HK 等

# 打开所有 radio 并设置国家码
for radio in $(uci show wireless | grep -o "wireless\.radio[0-9]" | sort -u); do
    uci set ${radio}.disabled='0'
    uci set ${radio}.country="${COUNTRY}"
done

# 打开对应的 wifi-iface（部分模板下 SSID 广播段也带 disabled 标记）
for iface in $(uci show wireless | grep -oE "wireless\.[@a-zA-Z0-9_]+" | grep -v "\.radio" | sort -u); do
    if uci get ${iface}.disabled >/dev/null 2>&1; then
        uci set ${iface}.disabled='0'
    fi
done

uci commit wireless

# 应用配置（放后台执行，避免阻塞首次启动流程）
( wifi reload >/dev/null 2>&1 ) &

exit 0
