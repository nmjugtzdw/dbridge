#!/usr/bin/env bash
# ============================================================
# 数桥 DBridge · 一键安装脚本（客户侧）
#
# 用法（在客户 Linux 服务器上，一条命令）：
#   bash <(curl -sL https://dbridge.zzzmxxkj.com/install.sh)      # 装最新版
#
# 本脚本默认总是安装【最新版】：版本号由服务端 latest.txt 决定，不带参数即可。
# 仅在需要回滚到某个历史版本时才传版本号（该版本的 tar 必须仍在分发目录）：
#
# 端口说明：
#   客户端对外端口 27301，装好后浏览器访问该端口即可
#
# 脚本会做：
#   1. 解析目标版本（不传参数 = 装最新）
#   2. 检查/安装 Docker
#   3. 下载镜像 tar（断点续传）并校验 sha256
#   4. docker load 导入镜像
#   5. docker run 启动容器（数据持久化 + 授权 URL + 引擎环境变量）
#   6. 等服务真正响应后再报成功
#
# 设计原则：
#   - 全程一条命令，无需 scp、无需手工传文件
#   - 镜像 tar 走 HTTPS 直下（不走 Docker Hub，内网可先下好 tar 再 load）
#   - data 卷持久化，重装/升级不丢数据、不掉授权
#   - 下载中断可断点续传，不用从头再来
#
# 注意：面板框内只放 ASCII（中文字符宽度算法在不同 locale 下不一致，
#       混排会导致右边框错位），中文提示一律放在框外。
# ============================================================
set -euo pipefail

# ---------- 可改参数 ----------
VER="${1:-}"                             # 版本号；留空/写 latest = 自动取最新
BASE_URL="https://dbridge.zzzmxxkj.com"  # 分发源（软件官网，443 静态）
LICENSE_URL="${DBRIDGE_LICENSE_URL:-https://dbridge.zzzmxxkj.com:27302}"  # 授权云端地址
PORT="${DBRIDGE_PORT:-27301}"            # 对外端口
CONTAINER="dbridge"
STEP_TOTAL=6
BOX_W=63                                 # 面板内容区宽度（ASCII 列）
# -----------------------------

# ---------- 终端配色（赛博朋克：霓虹青 / 品红 / 荧光绿） ----------
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] && [ -z "${NO_COLOR:-}" ]; then
  CY=$'\033[38;5;51m'    # 霓虹青
  MG=$'\033[38;5;201m'   # 品红
  GR=$'\033[38;5;46m'    # 荧光绿
  YL=$'\033[38;5;226m'   # 警示黄
  RD=$'\033[38;5;196m'   # 错误红
  DM=$'\033[38;5;242m'   # 暗灰
  BD=$'\033[1m'
  RS=$'\033[0m'
else
  CY=; MG=; GR=; YL=; RD=; DM=; BD=; RS=
fi

# ---------- 面板原语（框内仅 ASCII） ----------
hr()    { printf '═%.0s' $(seq 1 $((BOX_W + 2))); }
frame() { printf '%s╔%s╗%s\n' "$CY" "$(hr)" "$RS"; }
fend()  { printf '%s╚%s╝%s\n' "$CY" "$(hr)" "$RS"; }
fline() { printf '%s╠%s╣%s\n' "$CY" "$(hr)" "$RS"; }
row()   { printf '%s║%s %-63s %s║%s\n' "$CY" "$RS" "$1" "$CY" "$RS"; }
rowc()  { printf '%s║%s %s%-63s%s %s║%s\n' "$CY" "$RS" "$2" "$1" "$RS" "$CY" "$RS"; }

bar() {
  local cur=$1 i out=""
  for ((i=1; i<=STEP_TOTAL; i++)); do
    if [ "$i" -le "$cur" ]; then out+="▰"; else out+="▱"; fi
  done
  printf '%s%s%s' "$MG" "$out" "$RS"
}
step() {
  printf '\n %s[%02d/%02d]%s %s▸%s %s%s%s  %s\n' \
    "$MG" "$1" "$STEP_TOTAL" "$RS" "$CY" "$RS" "$BD" "$2" "$RS" "$(bar "$1")"
}
ok()   { printf '      %s✓%s  %s\n' "$GR" "$RS" "$*"; }
warn() { printf '      %s!%s  %s%s%s\n' "$YL" "$RS" "$YL" "$*" "$RS"; }
info() { printf '      %s·%s  %s%s%s\n' "$DM" "$RS" "$DM" "$*" "$RS"; }
err()  { printf '\n %s✗ FAILED%s  %s%s%s\n\n' "$RD" "$RS" "$RD" "$*" "$RS" >&2; exit 1; }

# ---------- HUD 抬头 ----------
hud() {
  local seal="-----------------------------------------------------------"
  local host
  host="$(uname -s 2>/dev/null || echo linux)/$(uname -m 2>/dev/null || echo x64)"
  host="${host:0:20}"
  frame
  row ""
  rowc "  D B R I D G E   //   C O R E" "$CY"
  rowc "  H E T E R O G E N E O U S   D A T A   S Y N C" "$MG"
  row ""
  rowc "  ${seal}" "$DM"
  row "  CORE ${1}   -   PORT ${PORT}   -   ${host}"
  fend
  printf '  %s▚▚%s 数桥 · 图形化异构数据库同步控制台  %s▞▞%s\n' "$MG" "$DM" "$MG" "$RS"
  printf '  %s作者 木思丁 · 微信 zzzmxxkj · 公众号 桢鸣科技%s\n' "$DM" "$RS"
}
hud "$([ -n "${VER}" ] && echo "v${VER}" || echo latest)"

# ---------- 1. 解析版本号 ----------
step 1 "解析目标版本"
if [ -z "${VER}" ] || [ "${VER}" = "latest" ]; then
  info "查询 ${BASE_URL}/dist/latest.txt"
  VER="$(curl -fsSL --max-time 10 "${BASE_URL}/dist/latest.txt" 2>/dev/null | tr -d '\r\n ')" || true
  [ -n "${VER}" ] || err "无法获取最新版本号，请稍后重试（服务端 /dist/latest.txt 不可达）"
  ok "自动识别最新版本 ${VER}"
else
  ok "使用指定版本 ${VER}"
fi

# ---------- 2. 权限与环境 ----------
step 2 "权限与环境自检"
[ "$(id -u)" -eq 0 ] || err "请用 root 运行：sudo bash <(curl -sL ${BASE_URL}/install.sh)"
ok "当前身份 root"

if ! command -v docker >/dev/null 2>&1; then
  warn "未检测到 Docker，开始安装（阿里云镜像源）"
  curl -fsSL https://get.docker.com | sh -s -- --mirror Aliyun \
    || curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker 2>/dev/null || true
fi
docker --version >/dev/null 2>&1 || err "Docker 不可用，请手动安装后重试"
ok "Docker $(docker --version | awk '{print $3}' | tr -d ',')"

# ---------- 3. 下载镜像 tar（断点续传 + 校验） ----------
TAR="dbridge-docker-${VER}.tar"
URL="${BASE_URL}/dist/${TAR}"
human() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "$1 字节"; }
fsize() { if [ -f "$1" ]; then stat -c%s "$1" 2>/dev/null || echo 0; else echo 0; fi; }

step 3 "拉取镜像包"
SIZE="$(curl -fsSI --max-time 20 "${URL}" 2>/dev/null \
  | awk 'tolower($1)=="content-length:"{print $2}' | tr -d '\r' | tail -n1)"
[ -n "${SIZE}" ] || err "无法获取镜像信息（${URL}），请检查网络或该版本是否已发布"
info "${TAR}  $(human "${SIZE}")"

HAVE="$(fsize "${TAR}")"
if [ "${HAVE}" -gt "${SIZE}" ]; then
  warn "本地同名文件大小异常（$(human "${HAVE}")），删除后重新下载"
  rm -f "${TAR}"
fi

for try in 1 2 3 4 5; do
  HAVE="$(fsize "${TAR}")"
  [ "${HAVE}" -eq "${SIZE}" ] && break
  if [ "${HAVE}" -gt 0 ]; then
    warn "已有 $(human "${HAVE}")，从断点继续（第 ${try}/5 次）"
  fi
  curl -fL --progress-bar -C - \
       --connect-timeout 20 --speed-time 60 --speed-limit 1024 \
       -o "${TAR}" "${URL}" && break
  warn "连接中断，3 秒后重试（已下载部分会保留）"
  sleep 3
done

HAVE="$(fsize "${TAR}")"
[ "${HAVE}" -eq "${SIZE}" ] \
  || err "镜像未下载完整（$(human "${HAVE}") / $(human "${SIZE}")），重跑同一条命令会从断点继续"
ok "镜像包就绪 $(human "${SIZE}")"

WANT="$(curl -fsSL --max-time 15 "${URL}.sha256" 2>/dev/null | awk '{print $1}' | tr -d '\r')" || true
if [ -n "${WANT}" ]; then
  info "sha256 校验中（约十几秒）"
  GOT="$(sha256sum "${TAR}" | awk '{print $1}')"
  [ "${GOT}" = "${WANT}" ] || err "镜像校验失败，请删除 ${TAR} 后重跑本命令"
  ok "sha256 一致 ${GOT:0:16}..."
else
  info "服务端未提供 sha256，跳过校验"
fi

# ---------- 4. 导入镜像 ----------
step 4 "导入镜像到本地 Docker"
docker load -i "${TAR}" >/dev/null 2>&1 || docker load -i "${TAR}" || err "docker load 失败"
docker image inspect "dbridge:${VER}" >/dev/null 2>&1 || err "导入后未找到镜像 dbridge:${VER}"
# 再打一个 latest 标签：文档里的 docker run / compose 用的是 dbridge:latest，
# 客户从 GitHub 复制命令时不该被钉在某个版本号上
docker tag "dbridge:${VER}" dbridge:latest >/dev/null 2>&1 || true
ok "dbridge:${VER} 已就绪（同时标记为 dbridge:latest）"

# ---------- 5. 启动容器 ----------
step 5 "启动服务容器"
if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
  info "清理同名旧容器（data 卷保留，授权与数据不丢）"
  docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
fi
docker run -d --name "${CONTAINER}" \
  -p "${PORT}:27301" \
  -v dbridge-data:/opt/dbridge/data \
  -v /etc/machine-id:/etc/machine-id:ro \
  -e DBRIDGE_LICENSE_URL="${LICENSE_URL}" \
  -e TZ=Asia/Shanghai \
  --restart unless-stopped \
  "dbridge:${VER}" >/dev/null || err "容器启动失败，查看日志：docker logs ${CONTAINER}"
ok "容器 ${CONTAINER} 已创建"

# ---------- 6. 就绪确认 ----------
step 6 "服务就绪确认"
# 公网 IP：优先云厂商元数据（腾讯云/阿里云），再退回公共探测源，全部失败就用内网 IP
pubip() {
  local u ip
  for u in "http://metadata.tencentyun.com/latest/meta-data/public-ipv4" \
           "http://100.100.100.200/latest/meta-data/eipv4" \
           "https://api.ip.sb/ip" \
           "https://ifconfig.me/ip"; do
    ip="$(curl -fsS --max-time 3 "$u" 2>/dev/null | tr -d '\r\n ')" || true
    case "${ip}" in ''|*[!0-9.]*) continue ;; esac
    [ "$(printf '%s' "${ip}" | tr -cd '.' | wc -c)" -eq 3 ] || continue
    printf '%s' "${ip}"
    return 0
  done
  return 1
}
IP_PRIV="$(hostname -I 2>/dev/null | awk '{print $1}')"
IP_PUB="$(pubip || true)"
IP="${IP_PUB:-${IP_PRIV:-<server-ip>}}"
READY=0
for _ in $(seq 1 30); do
  if curl -fsS --max-time 3 "http://127.0.0.1:${PORT}/api/about/version" >/dev/null 2>&1; then
    READY=1; break
  fi
  sleep 2
done
if [ "${READY}" -eq 1 ]; then
  RESP="$(curl -fsS --max-time 3 "http://127.0.0.1:${PORT}/api/about/version" 2>/dev/null)"
  RUN_VER="$(printf '%s' "${RESP}" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')"
  if [ -n "${RUN_VER}" ] && [ "${RUN_VER}" != "${VER}" ]; then
    warn "接口已响应，但运行版本是 ${RUN_VER}（期望 ${VER}）"
  else
    ok "接口已响应 v${RUN_VER:-${VER}}"
  fi
else
  warn "服务尚未响应，可能仍在启动；稍后用 docker logs -f ${CONTAINER} 观察"
fi

# ---------- 收尾 ----------
printf '\n'
frame
row ""
rowc "  SYSTEM ONLINE   //   DBridge v${VER}" "$GR"
row ""
row "  access   http://${IP}:${PORT}"
row "  login    admin / admin123"
row "  license  ${LICENSE_URL}"
row ""
fend
printf '\n %s提示%s  云服务器需在安全组/防火墙放行 %s%s%s 端口\n' "$MG" "$RS" "$YL" "$PORT" "$RS"
if [ -n "${IP_PRIV}" ] && [ "${IP_PRIV}" != "${IP}" ]; then
  printf ' %s内网%s  http://%s:%s\n' "$MG" "$RS" "$IP_PRIV" "$PORT"
fi
printf ' %s常用%s  docker logs -f %s   -   docker ps --filter name=%s\n\n' "$MG" "$RS" "$CONTAINER" "$CONTAINER"

frame
row ""
rowc "  UNINSTALL / REINSTALL" "$CY"
row ""
row "  docker rm -f ${CONTAINER}"
row "  docker rmi dbridge:latest dbridge:${VER}"
row "  docker volume rm dbridge-data     ! clears license and data"
row ""
fend
printf ' 重新安装  %sbash <(curl -sL %s/install.sh)%s\n' "$YL" "$BASE_URL" "$RS"
printf '\n %s数桥 DBridge%s  图形化异构数据库同步控制台\n' "$CY" "$RS"
printf ' %s作者 木思丁 · 微信 zzzmxxkj · 公众号 桢鸣科技%s\n\n' "$DM" "$RS"
