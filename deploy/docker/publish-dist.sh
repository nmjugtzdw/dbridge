#!/usr/bin/env bash
# ============================================================
# DBridge 一键分发脚本（发布新版到客户可拉取的地址）
#
# 用法（本机 Git Bash，项目根目录）：
#   bash deploy/docker/publish-dist.sh 1.0.8
#
# 前置：镜像 dbridge:<版本> 已通过 update-docker.sh 构建在服务器上。
#
# 会做：
#   1. 确保免密登录
#   2. 服务器上检查镜像存在 + docker save 导出 tar
#   3. 上传 install.sh 到服务器分发目录
#   4. 服务器上配置 nginx 分发路由（install.sh + /dist/*.tar 直出）
#   5. reload nginx
#
# 客户侧随后即可一条命令安装（自动装最新）：
#   bash <(curl -sL https://dbridge.zzzmxxkj.com/install.sh)
#
# 每个版本都会额外写一个 latest.txt（内容就是版本号），install.sh 不带参数时
# 读它来决定装哪个版本；同时维护 dbridge-docker-latest.tar 软链给老命令兜底。
#
# 免密登录：首次运行自动推公钥，之后全程免密。
# ============================================================
set -euo pipefail

# ---------- 按需修改 ----------
SERVER="111.231.174.142"
USER="ubuntu"
SSH_PORT="22"
REMOTE_DIST="/var/www/dbridge-dist"                 # 服务器分发目录（tar + install.sh）
NGINX_EXT="/www/server/panel/vhost/nginx/extension/dbridge.zzzmxxkj.com"  # 宝塔 nginx 扩展目录
# -----------------------------

VER="${1:?用法: bash deploy/docker/publish-dist.sh <版本号>}"
IMAGE="dbridge:${VER}"
TAR="dbridge-docker-${VER}.tar"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SH="${SCRIPT_DIR}/install.sh"

say() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mxx %s\033[0m\n' "$*" >&2; exit 1; }

SSH_OPTS=(-p "${SSH_PORT}")
SCP_OPTS=(-P "${SSH_PORT}")

# ---------- 1. 确保免密登录 ----------
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "${SSH_OPTS[@]}" "${USER}@${SERVER}" "true" 2>/dev/null; then
  say "1/5 首次配置免密登录（输一次密码）..."
  if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    ssh-copy-id -i "$HOME/.ssh/id_rsa.pub" "${SSH_OPTS[@]}" "${USER}@${SERVER}"
  elif [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    ssh-copy-id -i "$HOME/.ssh/id_ed25519.pub" "${SSH_OPTS[@]}" "${USER}@${SERVER}"
  else
    ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519"
    ssh-copy-id -i "$HOME/.ssh/id_ed25519.pub" "${SSH_OPTS[@]}" "${USER}@${SERVER}"
  fi
fi

# ---------- 2. 服务器上检查镜像 + docker save ----------
say "2/5 检查服务器上镜像 ${IMAGE} ..."
ssh "${SSH_OPTS[@]}" "${USER}@${SERVER}" "sudo docker image inspect ${IMAGE} >/dev/null 2>&1" \
  || die "服务器上没有镜像 ${IMAGE}。请先：bash deploy/docker/update-docker.sh ${VER} ${SERVER} ${USER}"

say "3/5 服务器上 docker save 导出 tar ..."
ssh "${SSH_OPTS[@]}" "${USER}@${SERVER}" "sudo docker save ${IMAGE} -o /tmp/${TAR} && sudo chown ${USER} /tmp/${TAR}"
echo "   服务器 /tmp/${TAR} 已导出"

# ---------- 3. 上传 install.sh + 移动 tar 到分发目录 ----------
say "4/5 上传 install.sh 并归位 tar ..."
ssh "${SSH_OPTS[@]}" "${USER}@${SERVER}" "sudo mkdir -p ${REMOTE_DIST}"
scp "${SCP_OPTS[@]}" "${INSTALL_SH}" "${USER}@${SERVER}:/tmp/install.sh"
ssh "${SSH_OPTS[@]}" "${USER}@${SERVER}" \
  "sudo mv /tmp/install.sh ${REMOTE_DIST}/install.sh && sudo mv /tmp/${TAR} ${REMOTE_DIST}/${TAR} \
   && echo '${VER}' | sudo tee ${REMOTE_DIST}/latest.txt >/dev/null \
   && sudo ln -sfn ${REMOTE_DIST}/${TAR} ${REMOTE_DIST}/dbridge-docker-latest.tar \
   && cd ${REMOTE_DIST} && sha256sum ${TAR} | sudo tee ${TAR}.sha256 >/dev/null \
   && sudo chmod 755 ${REMOTE_DIST}/install.sh \
   && sudo chmod 644 ${REMOTE_DIST}/${TAR} ${REMOTE_DIST}/${TAR}.sha256 ${REMOTE_DIST}/latest.txt \
   && sudo chown www:www ${REMOTE_DIST}/install.sh ${REMOTE_DIST}/${TAR} ${REMOTE_DIST}/${TAR}.sha256 ${REMOTE_DIST}/latest.txt"
echo "   已归位到 ${REMOTE_DIST}/（含 latest.txt = ${VER}、sha256 校验文件）"

# ---------- 4. 配置 nginx 分发路由 ----------
say "5/5 配置 nginx 分发路由 ..."
ssh "${SSH_OPTS[@]}" "${USER}@${SERVER}" bash -s <<EOF
set -e
CONF="${NGINX_EXT}/dbridge-dist.conf"
sudo tee "\${CONF}" > /dev/null <<'CONFEOF'
# DBridge 一键安装分发（自动生成，请勿手改）
# install.sh 和镜像 tar 走本地文件直出，不经过 27302 反代
location = /install.sh {
    root /var/www/dbridge-dist;
    add_header Cache-Control "no-store";
    default_type text/plain;
}
# 版本号文件绝对不能缓存，否则客户装到上一个版本
location = /dist/latest.txt {
    alias /var/www/dbridge-dist/latest.txt;
    add_header Cache-Control "no-store";
    default_type text/plain;
}
location ^~ /dist/ {
    alias /var/www/dbridge-dist/;
    add_header Cache-Control "public, max-age=3600";
    autoindex off;
}
CONFEOF
# 宝塔机器上 systemd 里没有 nginx 服务，必须用宝塔自带的二进制
NGX=/www/server/nginx/sbin/nginx
[ -x "\$NGX" ] || NGX=\$(command -v nginx)
sudo "\$NGX" -t && sudo "\$NGX" -s reload
echo "   nginx 路由已生效（\$NGX）"
EOF

say "发布完成！客户现在可一条命令安装最新版："
echo "   bash <(curl -sL https://dbridge.zzzmxxkj.com/install.sh)"
echo "   指定版本（回滚）：bash <(curl -sL https://dbridge.zzzmxxkj.com/install.sh) ${VER}"
