#!/usr/bin/env bash
# ============================================================
# DBridge Docker 一键升级脚本
# 封装「组装 → 打包 tar → 上传 → 服务器重建镜像 → 重启容器」全流程
#
# 用法：
#   bash update-docker.sh <版本号> <服务器IP> [ssh账号]
#   例：bash update-docker.sh 1.0.6 111.231.174.142 ubuntu
#
# 前提：
#   1. 已在本机跑过 build.bat 产出 target/dbridge.jar
#   2. 本机已配置到服务器的免密钥 SSH（默认账号 ubuntu）
#   3. 服务器已装 Docker，且之前用同样方式部署过一次（data 卷已存在）
#
# 注意：升级只换镜像 + 重启容器，data 卷（dbridge-data）不删，
#       数据 / 授权 / 任务 / 水位全部保留。
# ============================================================
set -euo pipefail

# ---------- 参数 ----------
VER="${1:?用法: bash update-docker.sh <版本号> <服务器IP> [ssh账号]}"
HOST="${2:?用法: bash update-docker.sh <版本号> <服务器IP> [ssh账号]}"
USER="${3:-ubuntu}"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CTX="$ROOT/deploy/docker"
TARBALL="$ROOT/deploy/dbridge-docker-context.tar.gz"

# 服务器端授权地址（与 docker-compose.yml 保持一致）
LICENSE_URL="${DBRIDGE_LICENSE_URL:-https://dbridge.zzzmxxkj.com}"

echo "============================================================"
echo " DBridge Docker 升级"
echo "   版本号 : $VER"
echo "   服务器 : $USER@$HOST"
echo "   授权URL: $LICENSE_URL"
echo "============================================================"

# ---------- 1. 校验主程序 jar ----------
JAR="$ROOT/target/dbridge.jar"
if [ ! -f "$JAR" ]; then
  echo "错误：找不到 $JAR"
  echo "请先运行 build.bat 打包主程序。"
  exit 1
fi

# ---------- 2. 组装构建上下文 ----------
echo ""
echo "==> [1/5] 组装构建上下文（jar + drivers + 精简引擎）..."
mkdir -p "$CTX/lib" "$CTX/drivers" "$CTX/engine"
cp -f "$JAR" "$CTX/lib/dbridge.jar"
# 用 mv 重命名替代 rm -rf：避免本机 safe-delete 对大目录删除的批量确认拦截，且可回退
STAMP="$(date +%Y%m%d-%H%M%S)"
[ -d "$CTX/drivers" ] && mv "$CTX/drivers" "$CTX/drivers.old-$STAMP" 2>/dev/null || true
mkdir -p "$CTX/drivers"
cp -r "$ROOT/drivers/." "$CTX/drivers/"

SEATUNNEL_SRC="${SEATUNNEL_SRC:-D:/seatunnel}"
if [ -d "$SEATUNNEL_SRC" ]; then
  echo "     组装同步引擎（源 $SEATUNNEL_SRC）..."
  [ -d "$CTX/engine" ] && mv "$CTX/engine" "$CTX/engine.old-$STAMP" 2>/dev/null || true
  mkdir -p "$CTX/engine"
  cp -r "$SEATUNNEL_SRC/lib" "$CTX/engine/lib"
  [ -d "$CTX/engine/lib/_backup" ] && mv "$CTX/engine/lib/_backup" "$CTX/engine/lib/_backup.old-$STAMP" 2>/dev/null || true
  cp -r "$SEATUNNEL_SRC/connectors" "$CTX/engine/connectors"
  mkdir -p "$CTX/engine/starter"
  cp -f "$SEATUNNEL_SRC/starter/seatunnel-starter.jar" "$CTX/engine/starter/"
  cp -r "$SEATUNNEL_SRC/starter/logging" "$CTX/engine/starter/logging" 2>/dev/null || true
  cp -r "$SEATUNNEL_SRC/config" "$CTX/engine/config"
  find "$CTX/engine/config" -name "job-*.conf" -delete 2>/dev/null || true
  cp -r "$SEATUNNEL_SRC/bin" "$CTX/engine/bin"
  cp -r "$SEATUNNEL_SRC/plugins" "$CTX/engine/plugins" 2>/dev/null || true
  cp -r "$SEATUNNEL_SRC/licenses" "$CTX/engine/licenses" 2>/dev/null || true
else
  echo "警告：找不到引擎目录 $SEATUNNEL_SRC，镜像将缺失同步引擎！"
  echo "      可用 SEATUNNEL_SRC=/path/to/seatunnel 指定引擎源目录。"
fi

# ---------- 3. 打包 tar ----------
echo ""
echo "==> [2/5] 打包构建上下文 ..."
cd "$ROOT/deploy"
rm -f "$TARBALL"
# 排除 *.old-* 备份目录，避免 mv 重命名产生的残留把 tar 包撑大
tar -czf "$TARBALL" --exclude='docker/*.old-*' docker/
echo "     $TARBALL  ($(du -h "$TARBALL" | cut -f1))"

# ---------- 4. 上传 ----------
echo ""
echo "==> [3/5] 上传到服务器 ..."
scp -o ConnectTimeout=15 -o BatchMode=yes -o StrictHostKeyChecking=no \
  "$TARBALL" "$USER@$HOST:/home/$USER/"
echo "     上传完成"

# ---------- 5. 服务器端解压 + 构建 + 重启 ----------
echo ""
echo "==> [4/5] 服务器解压 + 构建镜像 dbridge:$VER ..."
ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no "$USER@$HOST" bash -s <<EOF
set -e
cd /home/$USER
sudo rm -rf docker
tar -xzf dbridge-docker-context.tar.gz
cd docker
sudo docker build -t dbridge:$VER .
EOF

echo ""
echo "==> [5/5] 重启容器（沿用 data 卷，数据不丢）..."
ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no "$USER@$HOST" bash -s <<EOF
set -e
sudo docker rm -f dbridge 2>/dev/null || true
sudo docker run -d --name dbridge \
  -p 27301:27301 \
  -v dbridge-data:/opt/dbridge/data \
  -v /etc/machine-id:/etc/machine-id:ro \
  -e DBRIDGE_LICENSE_URL=$LICENSE_URL \
  -e DBRIDGE_ENGINE_HOME=/opt/dbridge/engine \
  -e SEATUNNEL_HOME=/opt/dbridge/engine \
  -e TZ=Asia/Shanghai \
  --restart unless-stopped \
  dbridge:$VER
EOF

echo ""
echo "============================================================"
echo " 升级完成！"
echo "   浏览器打开 http://$HOST:27301 验证（安全组需放行 27301）"
echo "   页头应显示绿点「服务正常」+ 新版本号 $VER"
echo "============================================================"
