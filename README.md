# りどみ
⚠️ This project is a personal tool for learning and sharing among friends.  
⚠️ No guarantee, no support. Use at your own risk.

Google Cloud Platform（GCP）の Compute Engine を利用して、Minecraft 1.10.2 サーバーを自動構築するためのツール。
1コマンド実行するだけで、数分以内にサーバーが起動し、すぐにプレイ可能。

## 機能
  
- VPCファイアウォール ルールを作成
  - 名前: `minecraft-server-firewall`
  - 種類: 内向き
  - プロトコル/ポート: `tcp:25565`
  - IP範囲: `0.0.0.0/0`
    
- 静的IPアドレスを新規取得
  - 名前: `minecraft-server-ip`
  - リージョン: `asia-northeast1`
  - バージョン: IPv4
 
- Compute Engine による VM 自動作成
 
- Docker + docker-compose による軽量なサーバー運用

- `The Unusual SkyBlock v12.0.9` を公式サイトから自動取得し、`world` ディレクトリに配置

## 構成ファイル

| ファイル名          | 説明                              |
|--------------------|-----------------------------------|
| `deploy.sh`        | GCP 上での VM 作成および初期設定スクリプト     |
| `server_setup.sh`  | 	VM 内部での Docker 構築・起動処理  |
| `server.properties`| Minecraft サーバーの設定ファイル              |
| `Dockerfile`       |	`deploy.sh` を実行する軽量コンテナ定義 |

## 事前準備
### 1. GCPアカウントと請求アカウントを作成
[無料トライアル登録](https://cloud.google.com/free/)

### 2. gcloud CLIのインストール
[公式ガイド](https://cloud.google.com/sdk/docs/install)

### 3. 認証と初期化
```
gcloud auth login
```

### 4. Docker Desktopのダウンロード
[Docker Desktop ダウンロード](https://www.docker.com/products/docker-desktop/)

## 使用方法（Windows）
### 1. リポジトリのダウンロード
`git clone` または ZIP ファイルをダウンロード・展開する。

### 2. Dockerイメージのビルド
PowerShellを開き、リポジトリのディレクトリに移動：
```powershell
docker build -t mc-deploy .
```
### 3. サーバーをデプロイ
```powershell
docker run --rm `
  -v "$env:APPDATA\gcloud:/root/.config/gcloud" `
  -v "${PWD}:/app" `
  -w /app `
  mc-deploy
```
#### 補足
- `%USERPROFILE%\.config\gcloud` は Linux/macOS の `$HOME/.config/gcloud` に対応。
- `gcloud auth login` は必ずホスト OS 側で一度実行しておくこと。
- `mc-deploy` は実行中に `server_setup.sh` をリモート実行し、Docker 上で Minecraft サーバーを起動する。

#### 外部ps1の実行許可コマンド
以下のコマンドをpowershell（管理者特権不要）で実行してください。
```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
## 今後追加したい機能（予定）

- ワールドの**自動バックアップ**
- **コンソールから直接コマンド入力**（rcon対応）
- スクリプトの**設定簡略化**や**汎用性の向上**
