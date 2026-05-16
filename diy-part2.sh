#!/bin/bash
#
# diy-part2.sh - 更新feeds后的自定义配置
# OpenWrt 25.12 版本
# 功能：CUPS汉化(CUPS-zh.zip) + Full Cone NAT + GRUB首次启动修改
# 重要：使用uci-defaults机制，确保编译集成的包也能在首次启动执行
#

echo "=========================================="
echo "OpenWrt 25.12 Build"
echo "diy-part2.sh - 自定义配置"
echo "=========================================="

# 获取工作目录（兼容GitHub Actions和本地环境）
WORKSPACE_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"

# 1. 设置默认主机名
echo "[1/7] 设置默认主机名..."
sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate 2>/dev/null || true
sed -i 's/OpenWrt/OpenWrt-25.12/g' package/base-files/files/bin/config_generate 2>/dev/null || true

# 2. 设置默认时区为上海
echo "[2/7] 设置默认时区..."
sed -i "s/'UTC'/'CST-8'/g" package/base-files/files/bin/config_generate
sed -i "/'CST-8'/a \\\t\tset system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate

# 3. 设置默认主题为Material
echo "[3/7] 设置默认主题为Material..."
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' package/feeds/luci/luci/Makefile 2>/dev/null || true

# 4. 添加自定义banner
echo "[4/7] 添加自定义banner..."
cat > package/base-files/files/etc/banner << 'EOF'
  _______                     ________        __
 |       |.-----.-----.-----.|  |  |  |.----.|  |_
 |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|
 |_______||   __|_____|__|__||________||__|  |____|
          |__| W I R E L E S S   F R E E D O M
 -----------------------------------------------------
 OpenWrt 25.12 "Dave's Guitar"
 -----------------------------------------------------
EOF

# 5. GRUB超时：刷机后首次启动自动修改为2秒
echo "[5/7] 配置GRUB首次启动自动修改..."
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-grub-timeout << 'GRUBEOF'
#!/bin/sh
# 首次启动自动将GRUB等待时间改为2秒
if [ -f /boot/grub/grub.cfg ]; then
    sed -i 's/^set timeout=.*/set timeout=2/' /boot/grub/grub.cfg
    echo "GRUB timeout 已设置为 2 秒"
fi
exit 0
GRUBEOF
chmod +x package/base-files/files/etc/uci-defaults/99-grub-timeout
echo "  - GRUB uci-defaults脚本已创建"

# 6. 创建 cups-zh-cn 汉化包（使用CUPS-zh.zip + uci-defaults）
echo "[6/7] 创建CUPS汉化包..."

# 创建包目录
mkdir -p package/cups-zh-cn/files/usr/share/cups/zh_CN

# 查找CUPS-zh.zip（多路径兼容）
CUPS_ZIP=""
if [ -f "$WORKSPACE_DIR/CUPS-zh.zip" ]; then
    CUPS_ZIP="$WORKSPACE_DIR/CUPS-zh.zip"
elif [ -f "$(dirname $0)/CUPS-zh.zip" ]; then
    CUPS_ZIP="$(dirname $0)/CUPS-zh.zip"
elif [ -f "$GITHUB_WORKSPACE/CUPS-zh.zip" ]; then
    CUPS_ZIP="$GITHUB_WORKSPACE/CUPS-zh.zip"
fi

if [ -n "$CUPS_ZIP" ]; then
    echo "  - 找到CUPS汉化文件: $CUPS_ZIP"
    unzip -o "$CUPS_ZIP" -d /tmp/cups-zh 2>/dev/null
    cp -r /tmp/cups-zh/* package/cups-zh-cn/files/usr/share/cups/zh_CN/ 2>/dev/null
    cp -r /tmp/cups-zh/*.tmpl package/cups-zh-cn/files/usr/share/cups/zh_CN/ 2>/dev/null
    cp -r /tmp/cups-zh/*.html package/cups-zh-cn/files/usr/share/cups/zh_CN/ 2>/dev/null
    cp -r /tmp/cups-zh/*.css package/cups-zh-cn/files/usr/share/cups/zh_CN/ 2>/dev/null
    rm -rf /tmp/cups-zh
    FILE_COUNT=$(find package/cups-zh-cn/files/usr/share/cups/zh_CN/ -type f 2>/dev/null | wc -l)
    echo "  - CUPS汉化文件已复制 ($FILE_COUNT 个文件)"
else
    echo "  - 错误: 未找到CUPS-zh.zip！"
    echo "  - 请确保CUPS-zh.zip与配置文件在同一目录"
fi

# cups-zh-cn Makefile（简化版，只负责安装文件）
cat > package/cups-zh-cn/Makefile << 'MAKEEOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=cups-zh-cn
PKG_VERSION:=2.3.1
PKG_RELEASE:=1

PKG_MAINTAINER:=OpenWrt Builder
PKG_LICENSE:=GPL-2.0-only

include $(INCLUDE_DIR)/package.mk

define Package/cups-zh-cn
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=CUPS Chinese (Simplified) Templates
  DEPENDS:=+cups
  PKGARCH:=all
endef

define Package/cups-zh-cn/description
  Simplified Chinese language templates for CUPS web interface.
  Uses CUPS-zh.zip (user-provided).
endef

define Build/Compile
endef

define Package/cups-zh-cn/install
	$(INSTALL_DIR) $(1)/usr/share/cups/zh_CN
	$(CP) ./files/usr/share/cups/zh_CN/* $(1)/usr/share/cups/zh_CN/
endef

$(eval $(call BuildPackage,cups-zh-cn))
MAKEEOF

echo "  - cups-zh-cn 包已创建"

# 7. CUPS汉化 + 配置：uci-defaults脚本（首次启动执行）
echo "[7/7] 创建CUPS uci-defaults脚本..."
cat > package/base-files/files/etc/uci-defaults/98-cups-zh-cn << 'CUPSEOF'
#!/bin/sh
# 首次启动自动配置CUPS中文汉化和cupsd.conf

# 1. 替换CUPS中文模板
if [ -d /usr/share/cups/zh_CN ]; then
    cp -rf /usr/share/cups/zh_CN/* /usr/share/cups/templates/
    rm -rf /usr/share/cups/zh_CN
    echo "CUPS中文模板已安装"
fi

# 2. 配置cupsd.conf（局域网访问 + Avahi发现）
cat > /etc/cups/cupsd.conf << 'CONF'
Listen *:631
Listen /var/run/cups/cups.sock
LogLevel warn
AccessLog /var/log/cups/access_log
ErrorLog /var/log/cups/error_log
DefaultPolicy default

<Location />
  Order allow,deny
  Allow @LOCAL
</Location>

<Location /admin>
  Order allow,deny
  Allow @LOCAL
</Location>

<Location /admin/conf>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
  Allow @LOCAL
</Location>

<Location /printers>
  Order allow,deny
  Allow @LOCAL
</Location>

Browsing On
BrowseLocalProtocols dnssd
CONF

# 3. 配置Avahi服务（打印机发现）
mkdir -p /etc/avahi/services
cat > /etc/avahi/services/cups.service << 'AVAHI'
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">CUPS 打印服务器 @ %h</name>
  <service>
    <type>_ipp._tcp</type>
    <port>631</port>
    <txt-record>txtvers=1</txt-record>
    <txt-record>qtotal=1</txt-record>
    <txt-record>rp=printers/</txt-record>
  </service>
</service-group>
AVAHI

# 4. 重启服务
[ -x /etc/init.d/avahi-daemon ] && /etc/init.d/avahi-daemon restart 2>/dev/null
[ -x /etc/init.d/cupsd ] && /etc/init.d/cupsd restart 2>/dev/null

echo "CUPS配置完成"
exit 0
CUPSEOF
chmod +x package/base-files/files/etc/uci-defaults/98-cups-zh-cn
echo "  - CUPS uci-defaults脚本已创建"

# 8. 添加 fullconenat 全锥形NAT模块
echo "[8/8] 添加Full Cone NAT模块..."
git clone --depth 1 https://github.com/yujincheng08/openwrt-iptables-mod-fullconenat.git /tmp/fullconenat 2>/dev/null
if [ -d /tmp/fullconenat/iptables-mod-fullconenat ]; then
    cp -r /tmp/fullconenat/iptables-mod-fullconenat package/
    echo "  - fullconenat模块已添加"
else
    echo "  - 警告: fullconenat克隆失败，尝试备用源..."
    git clone --depth 1 https://github.com/LGA1150/openwrt-fullconenat.git /tmp/fullconenat2 2>/dev/null
    if [ -d /tmp/fullconenat2/iptables-mod-fullconenat ]; then
        cp -r /tmp/fullconenat2/iptables-mod-fullconenat package/
        echo "  - fullconenat模块已添加（备用源）"
    else
        echo "  - 错误: fullconenat模块添加失败"
    fi
    rm -rf /tmp/fullconenat2 2>/dev/null
fi
rm -rf /tmp/fullconenat 2>/dev/null

# 配置防火墙规则（刷机后自动启用Full Cone NAT）
mkdir -p package/base-files/files/etc
cat >> package/base-files/files/etc/firewall.user << 'FWEOF'

# Full Cone NAT 规则（刷机后自动生效）
# 改善P2P连接、游戏联机、视频会议等
iptables -t nat -A zone_wan_prerouting -j FULLCONENAT 2>/dev/null
iptables -t nat -A zone_wan_postrouting -j FULLCONENAT 2>/dev/null
FWEOF
echo "  - 防火墙Full Cone NAT规则已配置"

# 调试信息
echo ""
echo "  === 自定义包文件统计 ==="
CUPS_COUNT=$(find package/cups-zh-cn/files/usr/share/cups/zh_CN/ -type f 2>/dev/null | wc -l)
echo "  - CUPS汉化文件: $CUPS_COUNT 个"
echo "  - fullconenat: $(test -d package/iptables-mod-fullconenat && echo '存在' || echo '不存在')"
echo "  - GRUB uci-defaults: $(test -f package/base-files/files/etc/uci-defaults/99-grub-timeout && echo '存在' || echo '不存在')"
echo "  - CUPS uci-defaults: $(test -f package/base-files/files/etc/uci-defaults/98-cups-zh-cn && echo '存在' || echo '不存在')"

echo "=========================================="
echo "构建信息:"
echo "  - OpenWrt版本: 25.12 (Dave's Guitar)"
echo "  - 内核: 6.12"
echo "  - 包管理器: apk (替代opkg)"
echo "  - 目标平台: x86_64"
echo "  - 打印: CUPS + Avahi + 中文(cups-zh-cn)"
echo "  - VPN: WireGuard + pbr"
echo "  - 网络: Tailscale/ACME/frp"
echo "  - 控制: timecontrol"
echo "  - NAT: Full Cone NAT + UPnP"
echo "  - GRUB: 首次启动自动修改为2秒"
echo "  - CUPS: 首次启动自动汉化+配置"
echo "=========================================="
