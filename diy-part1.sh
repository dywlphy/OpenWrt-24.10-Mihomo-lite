#!/bin/bash
# ==========================================
# feeds 配置：官方默认源 + kenzok8 全家桶 + helloworld
# ==========================================

echo "src-git kenzo https://github.com/kenzok8/openwrt-packages.git" >> feeds.conf.default
echo "src-git small https://github.com/kenzok8/small.git" >> feeds.conf.default
echo "src-git smpackage https://github.com/kenzok8/small-package" >> feeds.conf.default
echo "src-git helloworld https://github.com/fw876/helloworld" >> feeds.conf.default

echo "✅ 已添加 kenzo、small、smpackage、helloworld 源"
