#!/bin/bash
#
# diy-part2.sh - 自定义配置（精简版）
# OpenWrt 24.10 - 基础 + 中文 + OpenClash
#

echo "=========================================="
echo "diy-part2.sh - 自定义配置（精简版）"
echo "=========================================="

# 设置主机名
echo "[1/6] 设置主机名..."
CONFIG_FILE="package/base-files/files/bin/config_generate"
if [ -f "$CONFIG_FILE" ]; then
    sed -i 's/ImmortalWrt/OpenWrt/g' "$CONFIG_FILE"
    sed -i 's/OpenWrt-24\.10-[0-9.]*/OpenWrt/g' "$CONFIG_FILE"
    sed -i 's/OpenWrt-24\.10/OpenWrt/g' "$CONFIG_FILE"
    sed -i 's/OpenWrt/OpenWrt-24.10/g' "$CONFIG_FILE"
else
    echo " 警告：$CONFIG_FILE 不存在，跳过主机名设置"
fi
echo " 主机名: OpenWrt-24.10"

# 设置时区
echo "[2/6] 设置时区..."
if [ -f "$CONFIG_FILE" ]; then
    sed -i "s/'UTC'/'CST-8'/g" "$CONFIG_FILE"
    sed -i '/set system.@system[-1].zonename/d' "$CONFIG_FILE"
    sed -i "/'CST-8'/a \\\t\\\tset system.@system[-1].zonename='Asia/Shanghai'" "$CONFIG_FILE"
else
    echo " 警告：$CONFIG_FILE 不存在，跳过时区设置"
fi
echo " 时区: Asia/Shanghai (CST-8)"

# 设置默认主题
echo "[3/6] 设置默认主题..."
echo " 主题: Bootstrap（默认）"

# 创建uci-defaults脚本
echo "[4/6] 创建启动脚本..."
mkdir -p package/base-files/files/etc/uci-defaults

# opkg镜像源 + 开启流量卸载
cat > package/base-files/files/etc/uci-defaults/96-opkg-mirror << 'EOF'
#!/bin/sh
if [ -f /etc/opkg/distfeeds.conf ]; then
    sed -i 's|https://mirrors.aliyun.com/openwrt|https://downloads.openwrt.org|g' /etc/opkg/distfeeds.conf
    sed -i 's|https://mirrors.tuna.tsinghua.edu.cn/openwrt|https://downloads.openwrt.org|g' /etc/opkg/distfeeds.conf
fi
uci set firewall.@defaults[0].flow_offloading='1'
uci commit firewall
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/96-opkg-mirror

# 修复 LuCI 权限 + 预热缓存
cat > package/base-files/files/etc/uci-defaults/98-luci-fix << 'EOF'
#!/bin/sh
chmod 755 /www/cgi-bin/luci
if [ -f /etc/config/uhttpd ]; then
    sed -i 's/option rfc1918_filter 1/option rfc1918_filter 0/g' /etc/config/uhttpd
fi
/etc/init.d/uhttpd enable
/etc/init.d/rpcd enable
sleep 2
if [ -f /usr/share/luci/build_index.lua ]; then
    lua /usr/share/luci/build_index.lua 2>/dev/null || true
fi
if [ -x /usr/libexec/luci-index-cache ]; then
    /usr/libexec/luci-index-cache 2>/dev/null || true
fi
curl -s http://127.0.0.1/cgi-bin/luci > /dev/null 2>&1 || true
touch /tmp/.luci-cache-valid 2>/dev/null || true
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/98-luci-fix

# OpenClash 配置（禁用版本更新检查）
cat > package/base-files/files/etc/uci-defaults/99-openclash-settings << 'EOF'
#!/bin/sh
for i in 1 2 3 4 5; do
    if [ -f /etc/config/openclash ]; then
        uci set openclash.config.check_version='0'
        uci set openclash.config.check_dev_version='0'
        uci commit openclash
        break
    fi
    sleep 1
done
# 注释掉 init.d 中的版本检查代码（按内容匹配，不怕版本更新）
if [ -f /etc/init.d/openclash ]; then
    sed -i '/version_rmt_file=/s/^/   # /' /etc/init.d/openclash
    sed -i '/raw.githubusercontent.com/s/^/   # /' /etc/init.d/openclash
    sed -i '/openclash_last_version/s/^/   # /' /etc/init.d/openclash
    sed -i '/clash_last_version/s/^/   # /' /etc/init.d/openclash
    sed -i '/del_clash_log$/s/^/   # /' /etc/init.d/openclash
fi
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-openclash-settings

# 预设root密码
cat > package/base-files/files/etc/uci-defaults/99A-set-password << 'EOF'
#!/bin/sh
echo -e "admin\nadmin" | passwd root
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99A-set-password

# 禁用 OpenClash（用户配置好后手动启用）
cat > package/base-files/files/etc/uci-defaults/100-disable-services << 'EOF'
#!/bin/sh
/etc/init.d/openclash disable 2>/dev/null
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/100-disable-services

echo " uci-defaults已创建"

# 自定义banner
echo "[5/6] 自定义banner..."
cat > package/base-files/files/etc/banner << 'EOF'
  _______                     ________        __
 |       |.-----.-----.-----.|  |  |  |.----.|  |_
 |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|
 |_______||   __|_____|__|__||________||__|  |____|
          |__| W I R E L E S S   F R E E D O M
 -----------------------------------------------------
 OpenWrt 24.10 Lite Build
 -----------------------------------------------------
EOF

# 拉取 OpenClash
echo "[6/6] 拉取 OpenClash..."
if [ ! -d "package/luci-app-openclash" ]; then
    CLONE_SUCCESS=0
    for i in 1 2 3; do
        echo " clone 尝试 $i/3..."
        if git clone --depth 1 --filter=blob:none --sparse https://github.com/kenzok8/small-package.git openclash-tmp; then
            cd openclash-tmp
            git sparse-checkout set luci-app-openclash
            cd ..
            if [ -d "openclash-tmp/luci-app-openclash" ]; then
                mv openclash-tmp/luci-app-openclash package/
                rm -rf openclash-tmp
                CLONE_SUCCESS=1
                echo " OpenClash 已拉取"
                break
            fi
            rm -rf openclash-tmp
        fi
        echo " clone 失败，重试..."
        sleep 5
    done
    if [ "$CLONE_SUCCESS" -eq 0 ]; then
        echo " 警告：OpenClash clone 失败，跳过"
    fi
else
    echo " OpenClash 已存在，跳过"
fi

# 预下载 OpenClash 核心
echo "[6/6] 预下载 OpenClash 核心..."
CORE_FILE="mihomo-linux-amd64-v3-v1.19.27.gz"
CORE_URL="https://github.com/MetaCubeX/mihomo/releases/download/v1.19.27/mihomo-linux-amd64-v3-v1.19.27.gz"
CORE_DEST="package/base-files/files/etc/openclash/core"
if [ -d "package/luci-app-openclash" ]; then
    mkdir -p $CORE_DEST
    if [ -f "dl/$CORE_FILE" ] && [ -s "dl/$CORE_FILE" ]; then
        echo " 从 dl 目录复用核心"
        cp "dl/$CORE_FILE" /tmp/
    else
        echo " 从网络下载核心..."
        curl -sL -o /tmp/$CORE_FILE "$CORE_URL"
        if [ -f "/tmp/$CORE_FILE" ] && [ -s "/tmp/$CORE_FILE" ]; then
            mkdir -p dl
            cp /tmp/$CORE_FILE dl/
            echo " 核心已缓存到 dl 目录"
        fi
    fi
    if [ -f "/tmp/$CORE_FILE" ] && [ -s "/tmp/$CORE_FILE" ]; then
        gunzip -c /tmp/$CORE_FILE > $CORE_DEST/clash_meta
        chmod 755 $CORE_DEST/clash_meta 2>/dev/null || true
        echo " OpenClash 核心已预置到 base-files"
        rm -f /tmp/$CORE_FILE
    else
        echo " 警告：核心下载失败，需手动下载"
    fi
else
    echo " 警告：OpenClash 包不存在，跳过核心下载"
fi

echo "=========================================="
echo "diy-part2.sh 完成"
echo "=========================================="
