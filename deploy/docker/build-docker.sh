#!/usr/bin/env bash
# ============================================================
# DBridge Docker 一键构建脚本
# 用法：bash deploy/docker/build-docker.sh [版本号]
#   默认版本号 1.0.8，可传参覆盖，例如 build-docker.sh 1.0.9
# 前提：已先运行 build.bat 产出 target/dbridge.jar
# ============================================================
set -euo pipefail

VER="${1:-1.0.8}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CTX="$ROOT/deploy/docker"

echo "==> 版本号: $VER"
echo "==> 项目根: $ROOT"

# 1. 校验主程序 jar 已存在
JAR="$ROOT/target/dbridge.jar"
if [ ! -f "$JAR" ]; then
  echo "错误：找不到 $JAR"
  echo "请先运行 build.bat 打包主程序。"
  exit 1
fi

# 2. 组装构建上下文（lib + drivers + engine）
echo "==> 组装构建上下文..."
mkdir -p "$CTX/lib" "$CTX/drivers" "$CTX/engine"
cp -f "$JAR" "$CTX/lib/dbridge.jar"
rm -rf "$CTX/drivers"
mkdir -p "$CTX/drivers"
cp -r "$ROOT/drivers/." "$CTX/drivers/"
echo "    lib/dbridge.jar  $(du -h "$CTX/lib/dbridge.jar" | cut -f1)"
echo "    drivers/          $(ls "$CTX/drivers" | wc -l) 个驱动"

# 组装 SeaTunnel 引擎（精简版）：
#   - 引擎源目录默认 D:\seatunnel，可用 SEATUNNEL_SRC 环境变量覆盖
#   - 只保留 Linux 本地模式真正需要的：lib、connectors、starter 核心 jar、
#     config、bin、plugins、licenses
#   - 去掉：flink/spark 5 个集群 starter jar（每个约 40M，共 200M）、
#     lib/_backup 备份、logs 运行日志、config 里的临时 job conf
SEATUNNEL_SRC="${SEATUNNEL_SRC:-D:/seatunnel}"
if [ ! -d "$SEATUNNEL_SRC" ]; then
  echo "警告：找不到引擎目录 $SEATUNNEL_SRC，跳过引擎打包（镜像将缺失同步引擎）。"
  echo "      可用 SEATUNNEL_SRC=/path/to/seatunnel 指定引擎源目录。"
else
  echo "==> 组装同步引擎（源：$SEATUNNEL_SRC）..."
  rm -rf "$CTX/engine"
  mkdir -p "$CTX/engine"
  # lib：引擎核心 jar + JDBC 驱动（去 _backup）
  cp -r "$SEATUNNEL_SRC/lib" "$CTX/engine/lib"
  rm -rf "$CTX/engine/lib/_backup"
  # connectors：连接器插件
  cp -r "$SEATUNNEL_SRC/connectors" "$CTX/engine/connectors"
  # starter：只要 seatunnel-starter.jar（本地模式核心）和 logging 子目录，
  #         不要 flink/spark 那 5 个集群 starter jar
  mkdir -p "$CTX/engine/starter"
  cp -f "$SEATUNNEL_SRC/starter/seatunnel-starter.jar" "$CTX/engine/starter/"
  cp -r "$SEATUNNEL_SRC/starter/logging" "$CTX/engine/starter/logging" 2>/dev/null || true
  # config、bin、plugins、licenses：配置和脚本（bin 里 .cmd 仅占位过判据）
  cp -r "$SEATUNNEL_SRC/config" "$CTX/engine/config"
  # config 里只保留模板和基础配置，去掉运行期生成的 job-*.conf
  find "$CTX/engine/config" -name "job-*.conf" -delete 2>/dev/null || true
  cp -r "$SEATUNNEL_SRC/bin" "$CTX/engine/bin"
  cp -r "$SEATUNNEL_SRC/plugins" "$CTX/engine/plugins" 2>/dev/null || true
  cp -r "$SEATUNNEL_SRC/licenses" "$CTX/engine/licenses" 2>/dev/null || true
  echo "    engine/           $(du -sh "$CTX/engine" | cut -f1)（精简后，源 501M）"
fi

# 3. 构建镜像
echo "==> 构建镜像 dbridge:$VER ..."
docker build -t "dbridge:$VER" "$CTX"

echo ""
echo "==> 完成。运行方式："
echo "    cd deploy/docker && docker compose up -d"
echo "    或：docker run -d -p 27301:27301 -v dbridge-data:/opt/dbridge/data dbridge:$VER"
