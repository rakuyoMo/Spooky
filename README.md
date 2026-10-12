# Spooky

macOS 原生 Git 客户端：既能打开本机的仓库，也能经 SSH 直接操作另一台机器上的仓库。

## 目录

- `SpookyKit/`：核心库，负责在本机或经 SSH 执行 git，并解析输出

## 构建与测试

```
cd SpookyKit
swift build
swift test
```

## Git 要求

第一版要求本机和服务器上的 Git 均为 `2.41.0` 或更高版本。该版本要求由第一版使用的 `git fetch --porcelain` 确定；版本不足时，Spooky 会显示最低版本和更新方向，由用户负责更新 Git。

本机仓库默认使用 `/usr/bin/git`；服务器仓库使用 SSH 主机别名对应的服务器 Git。

## 协议

[GPL-3.0](LICENSE)
