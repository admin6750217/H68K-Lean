#!/bin/sh
# files/etc/uci-defaults/99-enable-wifi
# 首次启动时自动启用无线；如果还没有生成无线配置，先触发一次硬件探测。

logger -t enable-wifi "start"

if ! uci -q show wireless | grep -q "=wifi-device"; then
	logger -t enable-wifi "no wifi-device section, forcing 'wifi config' re-detect"
	wifi config >/dev/null 2>&1 || true
	sleep 2
fi

if ! uci -q show wireless | grep -q "=wifi-device"; then
	logger -t enable-wifi "still no wireless hardware detected after re-detect"
	exit 0
fi

. /lib/functions.sh
COUNTRY="CN"

enable_device() {
	local cfg="$1"
	uci set wireless.${cfg}.disabled='0'
	uci set wireless.${cfg}.country="${COUNTRY}"
}

enable_iface() {
	local cfg="$1"
	if [ -n "$(uci -q get wireless.${cfg}.disabled)" ]; then
		uci set wireless.${cfg}.disabled='0'
	fi
}

config_load wireless
config_foreach enable_device wifi-device
config_foreach enable_iface wifi-iface
uci commit wireless

( sleep 1; wifi reload >/dev/null 2>&1 ) &

logger -t enable-wifi "done, wireless enabled"
exit 0
