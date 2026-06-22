#!/bin/bash

echo "=========================================="
echo "diy-part1.sh - feeds配置（精简版）"
echo "=========================================="

# 只需要官方 feeds + OpenClash
cat > feeds.conf << 'EOF'
src-git packages https://github.com/openwrt/packages.git;openwrt-24.10
src-git luci https://github.com/openwrt/luci.git;openwrt-24.10
src-git routing https://github.com/openwrt/routing.git;openwrt-24.10
src-git telephony https://github.com/openwrt/telephony.git;openwrt-24.10
EOF

echo "feeds配置完成："
cat feeds.conf
echo ""
echo "=========================================="
