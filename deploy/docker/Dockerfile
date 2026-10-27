# ============================================================
# 数桥 DBridge · Docker 镜像
# ============================================================
# 运行要求：容器内保留 /sys（读取宿主机硬件标识）并持久化 /opt/dbridge/data 卷，
# 这两点是「容器重建后授权不丢」的前提。
#
# 基础镜像：eclipse-temurin:11-jre —— 官方 JDK 11 精简运行时
# ============================================================

FROM eclipse-temurin:11-jre-focal

# 版本号由构建脚本 --build-arg VERSION=<版本> 注入，发版不用改这个文件
ARG VERSION=dev

# 元信息
LABEL maintainer="木思丁" \
      org.opencontainers.image.title="DBridge" \
      org.opencontainers.image.description="数桥 DBridge · 图形化异构数据库同步控制台" \
      org.opencontainers.image.version="${VERSION}"

# 兜底机器标识：仅在未挂载宿主机 /etc/machine-id 时生效
RUN echo "dbridge-docker-fixed-machine-id-0001" > /etc/machine-id

# 工作目录
WORKDIR /opt/dbridge

# 复制主程序与驱动
COPY lib/dbridge.jar /opt/dbridge/lib/dbridge.jar
COPY drivers/ /opt/dbridge/drivers/

# 复制 SeaTunnel 同步引擎发行包（精简版：不含 flink/spark starter）
# 引擎是执行同步任务的真正执行体，缺了它页面会提示「同步引擎缺失」。
COPY engine/ /opt/dbridge/engine/

# 引擎就绪判据需要的占位文件（Linux 下实际用 java 直接调 starter.jar）
RUN touch /opt/dbridge/engine/bin/seatunnel.cmd \
        /opt/dbridge/engine/bin/seatunnel.sh \
        /opt/dbridge/engine/run.bat

# 运行时目录（数据/日志由 volume 提供）
RUN mkdir -p /opt/dbridge/data /opt/dbridge/logs /opt/dbridge/work

# 驱动镜像到生效目录：运行中换驱动时不会因旧 jar 被占用而失败
RUN cp -r /opt/dbridge/drivers /opt/dbridge/work/drv-active

# 数据卷（授权文件、内置库、时间锚点必须持久化）
VOLUME ["/opt/dbridge/data"]

# 控制台端口
EXPOSE 27301

# 同步引擎目录：主程序与引擎自身都以此定位连接器
ENV DBRIDGE_ENGINE_HOME=/opt/dbridge/engine \
    SEATUNNEL_HOME=/opt/dbridge/engine

# 启动参数
#   -Xms128m -Xmx512m               内存
#   -Dfile.encoding=UTF-8           中文不乱码
#   -Dloader.path=work/drv-active   外置驱动（换驱动不重新打包）
#   --server.address=0.0.0.0        容器内必须监听 0.0.0.0 才能被 -p 映射
ENTRYPOINT ["java", \
    "-Xms128m", "-Xmx512m", \
    "-Dfile.encoding=UTF-8", \
    "-Dloader.path=/opt/dbridge/work/drv-active", \
    "-jar", "/opt/dbridge/lib/dbridge.jar", \
    "--server.port=27301", "--server.address=0.0.0.0"]
