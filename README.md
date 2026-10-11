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

## 协议

[GPL-3.0](LICENSE)
