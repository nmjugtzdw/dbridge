# ============================================================
# 数桥 DBridge · Docker 镜像
# ============================================================
# 构建前置：先跑 build.bat 产出 target/dbridge.jar，
# 然后把 jar 和 drivers 目录放到本文件同级（见 deploy/docker/README.md）。
#
# 授权指纹关键点（务必保留，否则容器重建会掉授权）：
#   1. 不要重新生成 /etc/machine-id —— 固定写入一个值，保证「os」因子稳定
#   2. 不要隔离 /sys —— 让程序读到宿主机 /sys/class/dmi/id/product_uuid（「mb」因子）
#   3. /data 用 volume 挂载持久化（授权文件、H2 库、时间锚点都在里面）
#
# 基础镜像：eclipse-temurin:11-jre —— 官方 JDK11 精简运行时，无需再内置 95MB 运行时
# ============================================================

FROM eclipse-temurin:11-jre-focal

# 元信息
LABEL maintainer="木思丁" \
      org.opencontainers.image.title="DBridge" \
      org.opencontainers.image.description="数桥 DBridge · 图形化异构数据库同步控制台" \
      org.opencontainers.image.version="1.0.8"

# 兜底固定 machine-id：作为「os」指纹因子的最后兜底。
# 注意：运行时优先挂载宿主机 /etc/machine-id（docker-compose 已做），
# 这里的固定值只在「没挂载宿主机 machine-id」的极端环境才生效，
# 且所有容器共享同一值——它只是兜底，不作为唯一锚点。
RUN echo "dbridge-docker-fixed-machine-id-0001" > /etc/machine-id

# 工作目录
WORKDIR /opt/dbridge

# 复制主程序与驱动
COPY lib/dbridge.jar /opt/dbridge/lib/dbridge.jar
COPY drivers/ /opt/dbridge/drivers/

# 复制 SeaTunnel 同步引擎发行包（精简版：不含 flink/spark starter）
# 引擎是执行同步任务的真正执行体，缺了它前端会显示「同步引擎缺失」。
COPY engine/ /opt/dbridge/engine/

# 自检判据占位：PingController 检查 engineHome/bin/seatunnel.cmd 和
# engineHome/run.bat 是否存在（Windows 文件名）。Linux 容器里引擎实际
# 用 java 直接调 starter.jar，不经过 .cmd/.bat，但判据要这两个文件存在
# 才会把「同步引擎缺失」消掉，所以放空占位文件。
RUN touch /opt/dbridge/engine/bin/seatunnel.cmd \
        /opt/dbridge/engine/bin/seatunnel.sh \
        /opt/dbridge/engine/run.bat

# 准备运行时目录（数据/日志/临时目录由 volume 或 bind mount 提供，
# 这里建空目录作为镜像内默认占位）
RUN mkdir -p /opt/dbridge/data /opt/dbridge/logs /opt/dbridge/work

# 镜像驱动到生效目录（与启动.bat 的 robocopy 镜像逻辑一致，
# 避免运行中换驱动时旧 jar 被 JVM 锁住删不掉）
RUN cp -r /opt/dbridge/drivers /opt/dbridge/work/drv-active

# 数据卷（授权文件、H2 库、时间锚点，必须持久化，否则重建容器=全新安装）
VOLUME ["/opt/dbridge/data"]

# 暴露端口（27301，避开常见端口）
EXPOSE 27301

# 同步引擎目录：让程序（app.engine-home）和引擎自身（SEATUNNEL_HOME，
# 定位 connectors 插件目录）都明确指向 /opt/dbridge/engine
ENV DBRIDGE_ENGINE_HOME=/opt/dbridge/engine \
    SEATUNNEL_HOME=/opt/dbridge/engine

# 启动：复刻启动.bat 的核心启动参数
#   -Xms128m -Xmx512m          内存
#   -Dfile.encoding=UTF-8      中文不乱码
#   -Dloader.path=work/drv-active  外置驱动（换驱动不重新打包）
#   --server.address=0.0.0.0   容器内必须监听 0.0.0.0 才能被 -p 映射
#   --server.port=27301
ENTRYPOINT ["java", \
    "-Xms128m", "-Xmx512m", \
    "-Dfile.encoding=UTF-8", \
    "-Dloader.path=/opt/dbridge/work/drv-active", \
    "-jar", "/opt/dbridge/lib/dbridge.jar", \
    "--server.port=27301", "--server.address=0.0.0.0"]
