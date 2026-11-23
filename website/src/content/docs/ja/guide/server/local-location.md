---
title: "この Mac 上の場所"
description: "自動検索、SMB または sshfs のマウント、自分で選んだフォルダのいずれかでサーバリポジトリにこの Mac 上の場所を与え、Finder での表示、ターミナル、外部エディタから開けるようにします。"
---

Finder が表示できるのは、Mac 上のフォルダだけです。サーバリポジトリのファイルはサーバにあります。Finder で表示するには、サーバのファイルが見えるこの Mac 上のフォルダが Spooky に必要です。ふつうは、マウントしたネットワークボリュームです。このフォルダが、リポジトリのこの Mac 上の場所です。

このページでは、Spooky がそのフォルダを見つける方法とマウントする方法、ターミナルやほかのアプリケーションがサーバリポジトリを開く方法を説明します。

## Finder で表示する {#show-in-finder}

:ui[action.revealFinder] は、サーバリポジトリでいつでも使えます。次の場所にあります。

- :ui[menu.file] メニュー
- ツールバーの :ui[toolbar.finder]
- サイドバーの :ui[workspace.title] の行を右クリックしたとき
- [クイックアクション](/guide/repositories/navigation/#quick-actions)
- リポジトリウインドウでサーバリポジトリを右クリックしたとき
- 作業コピーのファイルを右クリックしたとき。Finder でそれらのファイルが選択されます。

場所がわかっていてフォルダがあれば、すぐに Finder が開きます。そうでないときは、Spooky がシートを表示して、次の手順を進めます。

1. リポジトリが接続されていなければ、まず接続します。
2. フォルダを探します。方法が SMB または sshfs のときは、マウントします。
3. それでもフォルダが見つからないと、シートは場所を設定するフォームに変わり、上部に理由が表示されます。[場所を設定する](#set) を参照してください。

:ui[action.cancel] をクリックするとシートが閉じます。設定は変わりません。

## 場所を設定する {#set}

1. サイドバーの :ui[workspace.group] の下にある :ui[repositorySettings.title] をクリックします。
2. :ui[repositorySettings.general] ページで :ui[repositorySettings.localLocation] を探します。方法とフォルダが表示されます。フォルダがないときは、:ui[localLocation.notMounted] などの理由が表示されます。
3. ポインタを行の上に移動し、:ui[localLocation.change] が表示されたらクリックします。リポジトリが接続されている必要があります。
4. :ui[localLocation.title] で、:ui[localLocation.method] の横から方法を選びます。
5. マウントの場合は :ui[localLocation.mount]、ほかの方法の場合は :ui[localLocation.save] をクリックします。

Spooky がフォルダをマウントまたは確認している間、フォームはロックされます。止めるには :ui[action.cancel] をクリックします。以前の設定はそのまま残ります。

場所は、サーバリポジトリごとにこの Mac に保存されます。Spooky がリポジトリやサーバに書き込むことはありません。

SMB または sshfs のマウントが取り出されていると、行に :ui[localLocation.mountAgain] が表示されます。クリックすると、フォルダをもう一度マウントします。

## 方法 {#methods}

:ui[localLocation.method] メニューには、いま使える方法だけが並びます。現在の方法は常に表示されます。

### 自動 {#automatic}

:ui[localLocation.method.automatic] がデフォルトです。Spooky は、この Mac にすでにマウントされているネットワークボリュームを調べます。SMB、NFS、AFP、WebDAV、sshfs などのボリュームです。どのアプリケーションがマウントしたかは問いません。ボリュームのサーバのアドレスがホストエイリアスと同じであれば、対象になります。

次に Spooky は、ボリュームの中でリポジトリのフォルダを探します。同じリポジトリであることを確かめるために、サーバ上のリポジトリの Git フォルダに空のファイルを一時的に置き、ボリュームに現れることを確認してから削除します。

### SMB マウント {#smb}

:ui[localLocation.method.smbMount] は、サーバの共有フォルダを SMB でマウントします。SMB は macOS が使うファイル共有プロトコルです。サーバが SMB のポートで 2 秒以内に応答すると、メニューに表示されます。

1. :ui[localLocation.method.smbMount] を選んで、:ui[localLocation.mount] をクリックします。
2. macOS がサーバの共有フォルダを表示するか、先にログインを求めます。リポジトリを含む共有を選びます。

Spooky は共有を覚えていて、次回は尋ねずにもう一度マウントします。選んだ共有にリポジトリがないと、フォームに :ui[localLocation.notInShare] と表示されます。別の共有を選んで、もう一度試してください。

サーバが Mac の場合は、その Mac の **アップルメニュー › システム設定 › 一般 › 共有** で **ファイル共有** をオンにします。

### sshfs マウント {#sshfs}

:ui[localLocation.method.sshfsMount] は、Spooky が使うのと同じホストエイリアスで、リポジトリのフォルダを SSH 経由でマウントします。この Mac に sshfs と、macFUSE または FUSE-T が必要です。Spooky は `/opt/homebrew/bin`、`/usr/local/bin`、`PATH` の中で `sshfs` を探します。インストールされていないと、この方法は表示されません。

1. :ui[localLocation.method.sshfsMount] を選びます。
2. :ui[localLocation.mountAt] の横の :ui[localLocation.choose] をクリックして、この Mac 上の空のフォルダを選びます。サーバのファイルはそこに現れます。
3. :ui[localLocation.mount] をクリックします。

### 選んだフォルダ {#chosen-folder}

:ui[localLocation.method.chosenFolder] では、フォルダを自分で選べます。たとえば、別の方法でマウントしたフォルダです。

1. :ui[localLocation.method.chosenFolder] を選びます。
2. :ui[localLocation.folder] の横の :ui[localLocation.choose] をクリックして、リポジトリのフォルダを選びます。
3. :ui[localLocation.save] をクリックします。Spooky は保存する前にフォルダを確認します。

Spooky が自分でマウントしたボリュームを取り出すことはありません。あとでリポジトリをもう一度開くと、Spooky は何も尋ねずに、バックグラウンドでもう一度マウントします。

## 追加時にマウントする {#when-adding}

[サーバリポジトリを追加する](/guide/server/add/) とき、:ui[remote.mount] で場所も同時に設定できます。最初は :ui[remote.mount.none] になっています。ホストエイリアスを入力すると、:ui[remote.mount.smb] と :ui[remote.mount.sshfs] のうち使えるものがメニューに並びます。どちらも使えないときは、:ui[remote.mount.unavailable] と表示されます。

- **SMB：** リポジトリが開いたあと、macOS がサーバの共有フォルダまたはログインウインドウを表示します。キャンセルしてもリポジトリは開きます。リポジトリの設定の :ui[repositorySettings.localLocation] に、マウントされていない理由が表示されます。
- **sshfs：** :ui[localLocation.mountAt] の行が追加で表示されます。空のフォルダを選びます。リポジトリが開いたあと、Spooky がそこにマウントします。

ホストエイリアスを変更すると、メニューは :ui[remote.mount.none] に戻ります。

## ターミナルとほかのアプリケーション {#terminal}

次のコマンドは、この Mac 上の場所がなくてもサーバリポジトリで使えます。

- **:ui[action.openTerminal]** は、:ui[app.name > settings.title] › :ui[settings.general] で選んだターミナルアプリケーションを開き、`ssh -t` とホストエイリアスでログインして、リポジトリのフォルダに移動します。サーバが端末を許可しないときは、Spooky が端末なしでもう一度接続します。コマンドは使えますが、行編集とフルスクリーンのプログラムは使えません。:ui[menu.file] メニュー、ツールバーの :ui[toolbar.terminal]、作業コピーやリポジトリウインドウのリポジトリを右クリックしたときのメニューにあります。ターミナルアプリケーションを選ぶには、[ターミナル](/guide/settings/integration/#terminal) を参照してください。
- **:ui[action.copyPath]** は、`driftwood-server:/srv/git/driftwood` のように、先頭にホストエイリアスを付けたパスをコピーします。
- 作業コピーの **:ui[files.open] と :ui[files.openWith]** は、ファイルをほかのアプリケーションで開きます。Visual Studio Code、Visual Studio Code Insiders、Cursor は、Remote SSH 拡張機能がインストールされていれば、サーバ上のファイルを直接開きます。ほかのアプリケーションには、この Mac 上のコピーが渡されます。保存すると、Spooky がコピーをサーバに書き戻します。

その間にサーバ上のファイルが変更されていたときは、Spooky が書き込む前に :ui[externalTool.fileChanged] と確認します。:ui[externalTool.overwrite] をクリックすると、自分のコピーで置き換えます。リポジトリを閉じると、Spooky はコピーを削除します。

クイックルックと、外部の比較ツールとマージツールも、コピーを使います。マージツールが終了すると、Spooky が結果をサーバに書き戻してステージします。

## 関連ページ

- [サーバリポジトリの仕組み](/guide/server/overview/)
- [サーバリポジトリを追加する](/guide/server/add/)
- [連携](/guide/settings/integration/)
