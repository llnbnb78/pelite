#!/bin/sh
# 用法：
#   GITHUB_USER=你的用户名 GITHUB_TOKEN=ghp_xxx sh push.sh
# 该脚本会把当前目录的 PELite 工程推到 GitHub 的 pelite 仓库
set -e

USER="${GITHUB_USER:?需要 GITHUB_USER}"
TOKEN="${GITHUB_TOKEN:?需要 GITHUB_TOKEN}"
REPO="${REPO:-pelite}"
SRC="${SRC:-/var/minis/workspace/PELite}"

cd "$SRC"

if [ ! -d .git ]; then
  git init -q -b main
fi

cat > .gitignore <<'EOF'
build/
*.xcuserstate
xcuserdata/
.DS_Store
EOF

git add -A
git -c user.name="$USER" -c user.email="$USER@users.noreply.github.com" \
    commit -q -m "PELite 2.3.1" || echo "（无改动可提交）"

git remote remove origin 2>/dev/null || true
git remote add origin "https://${USER}:${TOKEN}@github.com/${USER}/${REPO}.git"

# 强制覆盖远端 main，避免网页上传留下残文件
git push -q -f origin HEAD:main

echo "已推送 → https://github.com/${USER}/${REPO}"
echo "文件清单："
git ls-tree -r --name-only HEAD
