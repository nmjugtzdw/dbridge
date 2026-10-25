#!/usr/bin/env bash
# ============================================================
# 数桥 DBridge · 一键安装脚本（客户侧）
#
# 用法（在客户 Linux 服务器上，一条命令）：
#   bash <(curl -sL https://dbridge.zzzmxxkj.com/install.sh)
#
# 或指定版本：
#   bash <(curl -sL https://dbridge.zzzmxxkj.com/install.sh) 1.0.6
#
# 脚本会做：
#   1. 检查/安装 Docker
#   2. 从 dbridge.zzzmxxkj.com 下载镜像 tar（docker save 离线包）
#   3. docker load 导入镜像
#   4. docker run 启动容器（数据持久化 + 授权 URL + 同步引擎环境变量）
#   5. 打印访问地址
#
# 设计原则：
#   - 全程一条命令，无需 scp、无需手工传文件
#   - 镜像 tar 走 HTTPS 直下（不走 Docker Hub，内网可先下好 tar 再 load）
#   - data 卷持久化，重装/升级不丢数据、不掉授权
# ============================================================
set -euo pipefail

# ---------- 可改参数 ----------
VER="${1:-1.0.6}"                        # 默认版本号
BASE_URL="https://dbridge.zzzmxxkj.com"  # 分发源（你的授权/分发域名）
LICENSE_URL="${DBRIDGE_LICENSE_URL:-https://dbridge.zzzmxxkj.com}"  # 授权云端地址
PORT="${DBRIDGE_PORT:-27301}"            # 对外端口
CONTAINER="dbridge"
# -----------------------------

say() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
ok()  { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
err() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# ---------- 0. 宣传横幅 ----------
banner() {
  printf '\033[1;36m'
  cat <<'EOF'
═══════════════════════════════════════════════
  数桥 DBridge · 异构数据库同步控制台
═══════════════════════════════════════════════
  作者：木思丁    微信：zzzmxxkj
  公众号：桢鸣科技
  官网：www.zzzmxxkj.com
═══════════════════════════════════════════════
EOF
  printf '\033[0m\n'
}
banner
say "数桥 DBridge 一键安装（版本 ${VER}）"

# ---------- 1. 检查 root ----------
[ "$(id -u)" -eq 0 ] || err "请用 root 运行：sudo bash <(curl -sL ${BASE_URL}/install.sh)"

# ---------- 2. 检查/安装 Docker ----------
say "检查 Docker 环境..."
if ! command -v docker >/dev/null 2>&1; then
  echo "未检测到 Docker，正在安装（用国内源）..."
  curl -fsSL https://get.docker.com | sh -s -- --mirror Aliyun \
    || curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker 2>/dev/null || true
fi
docker --version || err "Docker 安装失败，请手动安装后重试"
ok "Docker 就绪：$(docker --version)"

# ---------- 3. 下载镜像 tar ----------
TAR="dbridge-docker-${VER}.tar"
say "下载镜像（约 300MB，视网速而定）..."
if [ -f "${TAR}" ]; then
  echo "本地已有 ${TAR}，跳过下载（如要重新下载请先删除）"
else
  curl -fSL --progress-bar -o "${TAR}" "${BASE_URL}/dist/${TAR}" \
    || err "下载失败：${BASE_URL}/dist/${TAR}"
fi
ok "镜像 tar 就绪：$(du -h "${TAR}" | cut -f1)"

# ---------- 4. docker load 导入 ----------
say "导入镜像..."
docker load -i "${TAR}" || err "docker load 失败"
ok "镜像已导入"

# ---------- 5. 启动容器 ----------
say "启动容器（端口 ${PORT}）..."
# 先清理同名旧容器（保留 data 卷，数据不丢）
docker rm -f "${CONTAINER}" 2>/dev/null || true

docker run -d --name "${CONTAINER}" \
  -p "${PORT}:27301" \
  -v dbridge-data:/opt/dbridge/data \
  -v /etc/machine-id:/etc/machine-id:ro \
  -e DBRIDGE_LICENSE_URL="${LICENSE_URL}" \
  -e DBRIDGE_ENGINE_HOME=/opt/dbridge/engine \
  -e SEATUNNEL_HOME=/opt/dbridge/engine \
  -e TZ=Asia/Shanghai \
  --restart unless-stopped \
  "dbridge:${VER}" || err "容器启动失败"

ok "容器已启动"

# ---------- 6. 打印结果 ----------
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
say "安装完成！"
echo "  访问地址：http://${IP:-<服务器IP>}:${PORT}"
echo "  首次登录：admin / admin123"
echo "  查看日志：docker logs -f ${CONTAINER}"
echo "  查看状态：docker ps --filter name=${CONTAINER}"
echo ""
echo "  （记得在云安全组/防火墙放行 ${PORT} 端口）"
echo ""
echo "  ---------- 卸载/重装指引 ----------"
echo "  停止并删除容器：docker rm -f ${CONTAINER}"
echo "  删除镜像：       docker rmi dbridge:${VER}"
echo "  删除数据卷：     docker volume rm dbridge-data   （慎用！会清空授权和数据）"
echo "  重新安装：       bash <(curl -sL ${BASE_URL}/install.sh) ${VER}"
echo "  ----------------------------------"
echo ""
printf '\033[1;36m'
echo "  数桥 DBridge —— 图形化异构数据库同步控制台"
echo "  作者：木思丁 · 微信：zzzmxxkj · 公众号：桢鸣科技 · 官网：www.zzzmxxkj.com"
printf '\033[0m'
