#!/bin/bash

# GitHub Repository Secrets設定スクリプト
# 使用方法: ./set_github_secrets.sh <repository> <secret_name> <secret_value>

set -euo pipefail

# 色定義
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# グローバル変数
REPOSITORY=""
OPERATION=""
SECRET_NAME=""
SECRET_VALUE=""
SECRETS_FILE=""

# =====================================
# ヘルプ・メッセージ関数群
# =====================================

show_help() {
    cat << EOF
${BLUE}GitHub Repository Secrets設定ツール${NC}

使用方法:
  $0 [repository] <secret_name> <secret_value>
  $0 [repository] -f <secrets_file>
  $0 [repository] -l

例:
  $0 owner/repo-name AWS_ACCESS_KEY_ID AKIAIOSFODNN7EXAMPLE
  $0 AWS_ACCESS_KEY_ID AKIAIOSFODNN7EXAMPLE    # 現在のリポジトリを使用
  $0 owner/repo-name -f secrets.txt
  $0 -f secrets.txt                           # 現在のリポジトリを使用
  $0 owner/repo-name -l
  $0 -l                                       # 現在のリポジトリを使用

オプション:
  -h, --help     このヘルプを表示
  -f, --file     秘密鍵をファイルから読み込み
  -l, --list     リポジトリのシークレット一覧を表示

secrets.txtファイル形式 (key=value):
  AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
  AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
  DATABASE_URL=postgresql://user:pass@localhost/db

注意:
  - GitHub CLIがインストールされ、認証済みである必要があります
  - リポジトリ名省略時は、現在のGitリポジトリから自動取得します
EOF
}

error() {
    echo -e "${RED}エラー: $1${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# =====================================
# 環境チェック関数群
# =====================================

check_gh_cli() {
    command -v gh &> /dev/null || error "GitHub CLI (gh) がインストールされていません
インストール方法: https://cli.github.com/"

    gh auth status &> /dev/null || error "GitHub CLIが認証されていません
認証方法: gh auth login"
}

check_repository() {
    local repo="$1"
    gh repo view "$repo" &> /dev/null || error "リポジトリ '$repo' が見つからないか、アクセス権限がありません"
}

get_current_repository() {
    local repo_url
    repo_url=$(git config --get remote.origin.url 2>/dev/null) || error "現在のディレクトリはGitリポジトリではないか、remote.originが設定されていません"
    
    # HTTPS URLからリポジトリ名を抽出
    if [[ "$repo_url" =~ ^https://github.com/ ]]; then
        echo "$repo_url" | sed -e 's#https://github.com/##' -e 's#\.git$##'
    # SSH URLからリポジトリ名を抽出
    elif [[ "$repo_url" =~ ^git@github.com: ]]; then
        echo "$repo_url" | sed -e 's#git@github.com:##' -e 's#\.git$##'
    else
        error "サポートされていないリポジトリURL形式です: $repo_url"
    fi
}

# =====================================
# 引数解析関数
# =====================================

is_repository_format() {
    [[ "$1" =~ ^[^/]+/[^/]+$ ]]
}

is_option() {
    [[ "$1" =~ ^-[fl]$|^--(file|list)$ ]]
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_help; exit 1; }
    
    case "$1" in
        -h|--help) show_help; exit 0 ;;
    esac

    # 引数パターンの解析
    if is_repository_format "$1"; then
        # パターン1: repository指定あり
        REPOSITORY="$1"
        shift
        parse_operation_with_repo "$@"
    else
        # パターン2: repository省略
        REPOSITORY=$(get_current_repository)
        success "現在のリポジトリを使用: $REPOSITORY"
        parse_operation_without_repo "$@"
    fi
}

parse_operation_with_repo() {
    [[ $# -eq 0 ]] && error "操作が指定されていません"
    
    case "$1" in
        -f|--file)
            [[ $# -lt 2 ]] && error "ファイル名が指定されていません"
            OPERATION="file"
            SECRETS_FILE="$2"
            ;;
        -l|--list)
            OPERATION="list"
            ;;
        *)
            [[ $# -lt 2 ]] && error "シークレット名と値が必要です"
            OPERATION="single"
            SECRET_NAME="$1"
            SECRET_VALUE="$2"
            ;;
    esac
}

parse_operation_without_repo() {
    case "$1" in
        -f|--file)
            [[ $# -lt 2 ]] && error "ファイル名が指定されていません"
            OPERATION="file"
            SECRETS_FILE="$2"
            ;;
        -l|--list)
            OPERATION="list"
            ;;
        *)
            [[ $# -lt 2 ]] && error "シークレット名と値が必要です"
            OPERATION="single"
            SECRET_NAME="$1"
            SECRET_VALUE="$2"
            ;;
    esac
}

# =====================================
# シークレット操作関数群
# =====================================

set_single_secret() {
    local repo="$1" secret_name="$2" secret_value="$3"

    echo "シークレット設定中: $secret_name → $repo"
    
    if echo "$secret_value" | gh secret set "$secret_name" --repo "$repo"; then
        success "シークレット '$secret_name' を設定しました"
    else
        error "シークレット '$secret_name' の設定に失敗しました"
    fi
}

set_secrets_from_file() {
    local repo="$1" secrets_file="$2"

    [[ ! -f "$secrets_file" ]] && error "ファイル '$secrets_file' が見つかりません"

    echo "ファイルからシークレットを読み込み中: $secrets_file"
    
    local count=0
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # 空行とコメント行をスキップ
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        
        # 前後の空白を削除
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        [[ -z "$key" || -z "$value" ]] && continue
        
        echo "  設定中: $key"
        if echo "$value" | gh secret set "$key" --repo "$repo"; then
            success "  ✓ $key"
            ((count++))
        else
            error "  ✗ $key の設定に失敗"
        fi
    done < "$secrets_file"

    success "$count 個のシークレットを設定しました"
}

list_secrets() {
    local repo="$1"
    
    echo -e "${BLUE}リポジトリ '$repo' のシークレット一覧:${NC}"
    gh secret list --repo "$repo"
}

# =====================================
# メイン実行関数
# =====================================

execute_operation() {
    check_repository "$REPOSITORY"
    
    case "$OPERATION" in
        single)
            set_single_secret "$REPOSITORY" "$SECRET_NAME" "$SECRET_VALUE"
            ;;
        file)
            set_secrets_from_file "$REPOSITORY" "$SECRETS_FILE"
            ;;
        list)
            list_secrets "$REPOSITORY"
            ;;
        *)
            error "未知の操作: $OPERATION"
            ;;
    esac
}

main() {
    check_gh_cli
    parse_arguments "$@"
    execute_operation
}

# スクリプト実行
main "$@"
