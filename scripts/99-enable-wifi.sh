#!/bin/sh

[ -s /etc/config/wireless ] || wifi config

mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-h68k-conntrack.conf <<'SYSCTL'
net.netfilter.nf_conntrack_max=655200
SYSCTL
sysctl -w net.netfilter.nf_conntrack_max=655200 >/dev/null 2>&1 || true

for device in $(uci -q show wireless | sed -n 's/^\(wireless\.[^.]*\)=wifi-device$/\1/p'); do
	uci -q set "$device.disabled=0"
	uci -q set "$device.country=CN"
done

for iface in $(uci -q show wireless | sed -n 's/^\(wireless\.[^.]*\)=wifi-iface$/\1/p'); do
	uci -q set "$iface.disabled=0"
	uci -q set "$iface.mode=ap"
	uci -q set "$iface.network=lan"
	uci -q set "$iface.encryption=psk2"
	uci -q set "$iface.ssid=${WRT_SSID:-H68K}"
	uci -q set "$iface.key=${WRT_WORD:-12345678}"
done

uci -q commit wireless
wifi reload >/dev/null 2>&1 || wifi up >/dev/null 2>&1 || true
exit 0
