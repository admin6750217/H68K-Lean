# ==== 以下内容追加到 init-settings.sh 末尾 ====
# 在编译主机上直接生成 uci-defaults 脚本并赋权，
# 不依赖仓库里 files/ 目录携带的文件权限位（避免因 git/编辑器丢失可执行位导致脚本被跳过）


# 修复 unetd 在新版 GCC 下 host.c strcpy array-bounds 误报导致 -Werror 编译失败
UNETD_MK="package/network/services/unetd/Makefile"
if [ -f "$UNETD_MK" ] && ! grep -q "Wno-error=array-bounds" "$UNETD_MK"; then
  sed -i '/include \$(INCLUDE_DIR)\/package.mk/a TARGET_CFLAGS += -Wno-error=array-bounds' "$UNETD_MK"
  echo "unetd array-bounds 警告已降级"
fi





echo "开始生成 wifi 自动启用脚本..."
mkdir -p files/etc/uci-defaults

cat > files/etc/uci-defaults/99-enable-wifi << 'WIFIEOF'
#!/bin/sh
# 首次开机自动启用无线；若未检测到任何 wifi-device 段，先强制重新探测硬件

logger -t enable-wifi "start"

if ! uci -q show wireless | grep -q "=wifi-device"; then
	logger -t enable-wifi "no wifi-device section, forcing 'wifi config' re-detect"
	wifi config
	sleep 2
fi

if ! uci -q show wireless | grep -q "=wifi-device"; then
	logger -t enable-wifi "still no wireless hardware detected after re-detect - check lspci/dmesg on this device"
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
	[ -n "$(uci -q get wireless.${cfg}.disabled)" ] && \
		uci set wireless.${cfg}.disabled='0'
}

config_load wireless
config_foreach enable_device wifi-device
config_foreach enable_iface wifi-iface
uci commit wireless

( sleep 1; wifi reload >/dev/null 2>&1 ) &

logger -t enable-wifi "done, wireless enabled"
exit 0
WIFIEOF

chmod +x files/etc/uci-defaults/99-enable-wifi
ls -la files/etc/uci-defaults/99-enable-wifi
echo "wifi 自动启用脚本已生成并赋权"
# ==== 追加内容结束 ====





# 删除feeds中的插件
rm -rf ./feeds/packages/net/{geoview,chinadns-ng,hysteria,mosdns,v2ray-geodata,lucky}
rm -rf ./feeds/packages/net/{shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev}
rm -rf ./feeds/packages/net/{sing-box,v2ray-geodata,v2ray-plugin,xray-core,smartdns}

rm -rf ./feeds/luci/applications/{luci-app-passwall,luci-app-passwall2,luci-app-openclash,luci-app-homeproxy}
rm -rf ./feeds/luci/applications/{luci-app-lucky,luci-app-smartdns,luci-app-timecontrol,luci-app-mosdns}
rm -rf ./feeds/luci/applications/{luci-app-nikki,luci-app-momo,luci-app-daed}

# 克隆依赖插件
git clone --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git package/pwpage
# git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang


# 克隆的源码放在small文件夹
mkdir package/small
pushd package/small

# luci-theme-aurora
git clone -b master --depth 1 https://github.com/eamonxg/luci-theme-aurora.git

# luci-app-nft-timecontrol
git clone -b main --depth 1 https://github.com/sirpdboy/luci-app-timecontrol.git

# adguardhome
# git clone -b 2024.09.05 --depth 1 https://github.com/XiaoBinin/luci-app-adguardhome.git

# homeproxy
git clone -b master --depth 1 https://github.com/immortalwrt/homeproxy.git

# lucky
git clone -b main --depth 1 https://github.com/gdy666/luci-app-lucky.git

# smartdns
git clone -b master --depth 1 https://github.com/pymumu/luci-app-smartdns.git
git clone -b master --depth 1 https://github.com/pymumu/smartdns.git
sed -i 's@include ../../lang/rust/rust-package.mk@include $(TOPDIR)/feeds/packages/lang/rust/rust-package.mk@g' smartdns/package/openwrt/Makefile
sed -n '33p' smartdns/package/openwrt/Makefile

# ssrp
# git clone -b master --depth 1 https://github.com/fw876/helloworld.git

# VIKINGYFY/packages
git clone -b main --depth 1 https://github.com/VIKINGYFY/packages.git

# passwall
git clone -b main --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall.git

# passwall2
git clone -b main --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall2.git

# mosdns
git clone -b v5 --depth 1 https://github.com/sbwml/luci-app-mosdns.git

# luci-app-netspeedtest
git clone -b master --depth 1 https://github.com/sirpdboy/luci-app-netspeedtest.git

# openclash
git clone -b master --depth 1 https://github.com/vernesong/OpenClash.git

# OpenWrt-nikki
git clone -b main --depth 1 https://github.com/nikkinikki-org/OpenWrt-nikki.git

# OpenWrt-momo
git clone -b main --depth 1 https://github.com/nikkinikki-org/OpenWrt-momo.git

# daed
git clone -b master --depth 1 https://github.com/QiuSimons/luci-app-daed.git

#modem
# git clone -b main --depth 1 https://github.com/FUjr/modem_feeds.git

popd

echo "packages executed successfully!"
