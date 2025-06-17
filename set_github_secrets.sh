#!/bin/bash

# GitHub Repository Secrets設定スクリプト
# 使用方法: ./set_github_secrets.sh <repository> <secret_name> <secret_value>

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ヘルプ表示
show_help() {
    echo -e "${BLUE}GitHub Repository Secrets設定ツール${NC}"
    echo ""
    echo "使用方法:"
    echo "  $0 <repository> <secret_name> <secret_value>"
    echo "  $0 <repository> -f <secrets_file>"
    echo ""
    echo "例:"
    echo "  $0 owner/repo-name AWS_ACCESS_KEY_ID AKIAIOSFODNN7EXAMPLE"
    echo "  $0 owner/repo-name -f secrets.txt"
    echo ""
    echo "オプション:"
    echo "  -h, --help     このヘルプを表示"
    echo "  -f, --file     秘密鍵をファイルから読み込み"
    echo ""
    echo "secrets.txtファイル形式 (key=value):"
    echo "  AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE"
    echo "  AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    echo "  DATABASE_URL=postgresql://user:pass@localhost/db"
    echo ""
    echo "注意: GitHub CLIがインストールされ、認証済みである必要があります"
}

# エラーメッセージ表示
error() {
    echo -e "${RED}エラー: $1${NC}" >&2
}

# 成功メッセージ表示
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# 警告メッセージ表示
warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# GitHub CLIの確認
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI (gh) がインストールされていません"
        echo "インストール方法: https://cli.github.com/"
        exit 1
    fi

    # 認証状態確認
    if ! gh auth status &> /dev/null; then
        error "GitHub CLIが認証されていません"
        echo "認証方法: gh auth login"
        exit 1
    fi
}

# リポジトリの存在確認
check_repository() {
    local repo="$1"
    
    if ! gh repo view "$repo" &> /dev/null; then
        error "リポジトリ '$repo' が見つからないか、アクセス権限がありません"
        exit 1
    fi
}

# シークレット設定（単一）
set_single_secret() {
    local repo="$1"
    local secret_name="$2"
    local secret_value="$3"

    echo "シークレット設定中: $secret_name → $repo"
    
    if echo "$secret_value" | gh secret set "$secret_name" --repo "$repo"; then
        success "シークレット '$secret_name' を設定しました"
    else
        error "シークレット '$secret_name' の設定に失敗しました"
        exit 1
    fi
}

# シークレット設定（ファイルから）
set_secrets_from_file() {
    local repo="$1"
    local secrets_file="$2"

    if [[ ! -f "$secrets_file" ]]; then
        error "ファイル '$secrets_file' が見つかりません"
        exit 1
    fi

    echo "ファイルからシークレットを読み込み中: $secrets_file"
    
    local count=0
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # 空行とコメント行をスキップ
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        
        # 前後の空白を削除
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        if [[ -n "$key" && -n "$value" ]]; then
            echo "  設定中: $key"
            if echo "$value" | gh secret set "$key" --repo "$repo"; then
                success "  ✓ $key"
                ((count++))
            else
                error "  ✗ $key の設定に失敗"
            fi
        fi
    done < "$secrets_file"

    success "$count 個のシークレットを設定しました"
}

# リポジトリのシークレット一覧表示
list_secrets() {
    local repo="$1"
    
    echo -e "${BLUE}リポジトリ '$repo' のシークレット一覧:${NC}"
    gh secret list --repo "$repo"
}

# メイン処理
main() {
    # パラメータ確認
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi

    # ヘルプ表示
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
    esac

    # 最低限のパラメータ確認
    if [[ $# -lt 2 ]]; then
        error "パラメータが不足しています"
        show_help
        exit 1
    fi

    local repo="$1"
    
    # GitHub CLI確認
    check_gh_cli
    
    # リポジトリ確認
    check_repository "$repo"

    # ファイルから読み込み
    if [[ "$2" == "-f" || "$2" == "--file" ]]; then
        if [[ $# -lt 3 ]]; then
            error "ファイル名が指定されていません"
            exit 1
        fi
        set_secrets_from_file "$repo" "$3"
    
    # リスト表示
    elif [[ "$2" == "-l" || "$2" == "--list" ]]; then
        list_secrets "$repo"
    
    # 単一シークレット設定
    else
        if [[ $# -lt 3 ]]; then
            error "シークレット名と値が必要です"
            show_help
            exit 1
        fi
        set_single_secret "$repo" "$2" "$3"
    fi
}

# スクリプト実行
main "$@"