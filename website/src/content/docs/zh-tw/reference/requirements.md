---
title: "系統需求"
description: "檢視 Spooky 對 macOS、Git 與伺服器的需求。"
---

這一頁列出 Spooky 對你的 Mac 與要連線的伺服器有哪些需求。

## Mac {#mac}

| 項目 | 需求 |
|---|---|
| macOS | macOS 26 或以上版本 |
| Git | Git 2.41.0 或以上版本。Spooky 預設用 `/usr/bin/git`，想換的話，在 :ui[app.name > settings.title] › :ui[settings.gitConfig] 的 :ui[settings.gitProgram] 裡選，見 [Git 程式](/guide/settings/identity/#git-program)。 |
| SSH | macOS 內建的 SSH。伺服器儲存庫用它來連線。 |

Spooky 用到了 Git 2.41.0 才有的功能，更舊的版本用不了。

## 伺服器 {#servers}

伺服器可以是一台 Linux 機器，也可以是一台 Mac。Spooky 在那裡不需要管理者權限，也不安裝常駐服務。

| 項目 | 需求 |
|---|---|
| 登入 | 經 Mac 上 `~/.ssh/config` 裡的主機別名，用金鑰登入 SSH。只能用密碼登入的帳號連不上，見 [準備 SSH](/guide/server/prepare-ssh/)。 |
| Git | Git 2.41.0 或以上版本，在非互動式 SSH 登入用的 `PATH` 裡能找到 |
| SSH 服務 | OpenSSH，開啟 SFTP，允許 Unix socket 轉送，這兩項預設都是開啟的。`MaxSessions` 不能少於 10，預設就是 10。 |
| 私鑰密語詢問 | 伺服器上的 Git 要詢問 SSH 私鑰密語時，需要 OpenSSH 8.4 或以上版本 |
| Perl | `/usr/bin/perl`，帶有標準模組 `IO::Socket::UNIX`、`JSON::PP`、`POSIX` 與 `Fcntl` |
| 檔案 | 能寫入伺服器上個人資料夾裡的 `~/.spooky/bin`，以及 `/tmp` |
| 垃圾桶 | 可以沒有。伺服器是 Mac 時，Spooky 用 `/usr/bin/trash`，macOS 15 起內建。Linux 上用 `gio` 或 `trash-put`。都沒有的話，Spooky 先確認，再永久刪除檔案。 |

加入儲存庫之前，想知道伺服器符不符合，可以跑一遍 [準備 SSH](/guide/server/prepare-ssh/#test) 裡的測試，也可以在 :ui[app.name > settings.title] › :ui[settings.environment] 裡檢查一台伺服器，見 [檢查伺服器](/guide/settings/general/#server-check)。

## 選用 {#optional}

| 想用 | 需要 |
|---|---|
| Git LFS | 儲存庫所在的機器上裝有 Git LFS 2.9.0 或以上版本，在那裡 Git 用的 `PATH` 裡能找到 |
| sshfs 掛載 | Mac 上裝有 sshfs，以及 macFUSE 或 FUSE-T |
| SMB 掛載 | 伺服器開啟了 SMB 檔案共享 |
| Pull Request 與 Merge Request | github.com、GitLab.com 的帳號，或 9.0 及以上版本的自行架設 GitLab 的帳號 |

## 相關頁面

- [安裝 Spooky](/guide/start/install/)
- [伺服器儲存庫如何運作](/guide/server/overview/)
- [資料與隱私權](/reference/data-privacy/)
