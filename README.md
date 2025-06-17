# GitHub Repository Secrets 設定スクリプト

GitHubリポジトリのActions Secretsを簡単に設定するためのコマンドラインツールです。

## 前提条件

1. **GitHub CLI のインストール**
   ```bash
   # macOS (Homebrew)
   brew install gh
   
   # Ubuntu/Debian
   sudo apt install gh
   
   # その他: https://cli.github.com/
   ```

2. **GitHub CLI の認証**
   ```bash
   gh auth login
   ```

## 使用方法

### 1. 単一のシークレット設定
```bash
./set_github_secrets.sh owner/repository SECRET_NAME "secret_value"
```

例：
```bash
./set_github_secrets.sh myorg/my-repo AWS_ACCESS_KEY_ID "AKIAIOSFODNN7EXAMPLE"
```

### 2. ファイルから複数のシークレットを一括設定
```bash
./set_github_secrets.sh owner/repository -f secrets.txt
```

例：
```bash
./set_github_secrets.sh myorg/my-repo -f secrets_sample.txt
```

### 3. 現在のシークレット一覧表示
```bash
./set_github_secrets.sh owner/repository -l
```

### 4. ヘルプ表示
```bash
./set_github_secrets.sh -h
```

## シークレットファイル形式

`secrets.txt` ファイルは以下の形式で作成してください：

```
# コメント行
SECRET_NAME_1=secret_value_1
SECRET_NAME_2=secret_value_2
DATABASE_URL=postgresql://user:pass@localhost/db
```

- 各行は `KEY=VALUE` 形式
- `#` で始まる行はコメント
- 空行は無視される

## 使用例

1. **AWS認証情報の設定**
   ```bash
   ./set_github_secrets.sh myorg/my-app AWS_ACCESS_KEY_ID "AKIA..."
   ./set_github_secrets.sh myorg/my-app AWS_SECRET_ACCESS_KEY "wJal..."
   ```

2. **複数シークレットの一括設定**
   ```bash
   # secrets.txt を作成
   cat > secrets.txt << EOF
   AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
   AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
   DATABASE_URL=postgresql://user:pass@localhost/db
   EOF
   
   # 一括設定
   ./set_github_secrets.sh myorg/my-app -f secrets.txt
   ```

3. **設定されたシークレットの確認**
   ```bash
   ./set_github_secrets.sh myorg/my-app -l
   ```

## 機能

- ✅ 単一シークレットの設定
- ✅ ファイルからの一括設定
- ✅ 設定済みシークレットの一覧表示
- ✅ エラーハンドリング
- ✅ カラー出力
- ✅ 日本語メッセージ
- ✅ リポジトリ existence チェック
- ✅ GitHub CLI認証チェック

## 注意事項

- シークレット値にスペースや特殊文字が含まれる場合は、クォートで囲んでください
- シークレットファイルには機密情報が含まれるため、適切に管理してください
- 設定されたシークレットは暗号化され、値を後から確認することはできません

## トラブルシューティング

### "GitHub CLI がインストールされていません"
GitHub CLIをインストールしてください：https://cli.github.com/

### "GitHub CLIが認証されていません"
以下のコマンドで認証してください：
```bash
gh auth login
```

### "リポジトリが見つからない"
- リポジトリ名が正しいか確認してください（`owner/repository` 形式）
- リポジトリへのアクセス権限があるか確認してください
