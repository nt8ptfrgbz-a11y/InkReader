#!/bin/zsh
set -euo pipefail
"${0:A:h}/scripts/install_iphone.sh" "$@"
echo "按回车关闭窗口。"
read -r
