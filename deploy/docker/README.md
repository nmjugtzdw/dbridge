# 数桥 DBridge · Docker 部署说明

## 一、结论：能做，而且授权不会因为容器重建而掉

DBridge 做 Docker 化的门槛很低（Spring Boot 单体 + 单 jar + 数据全在 `data/`），
唯一需要小心的是**设备指纹授权**。结论如下：

| 指纹因子 | 采集源 | 容器里的值 | 稳定性 |
|---|---|---|---|
| **mb（主板 UUID）** | `/sys/class/dmi/id/product_uuid` | 宿主机内核暴露的值 | ✅ 稳定 |
| **os（系统 ID）** | `/etc/machine-id` | 镜像层固定值（Dockerfile 已写死） | ✅ 稳定 |
| **mac（网卡 MAC）** | 容器网络接口 | 默认 bridge 每次随机 | ⚠️ 会变，但无影响 |

**为什么 MAC 变了不影响授权**：授权容错匹配（`LicenseService.matchLevel`）只要
**主板 UUID 对上就是 STRONG 级放行**，MAC 变化不参与判定。

**两个必须保留的前提（Dockerfile 已做）**：
1. 固定 `/etc/machine-id`（不要每次构建重新生成）
2. 不隔离 `/sys`（让程序能读到宿主机主板 UUID）

---

## 二、构建前准备

Docker 镜像里不放源码，只放「主程序 jar + 驱动 + 同步引擎」。构建前先打包并组装目录：

```bat
:: 1. 先打主程序包（产出 target/dbridge.jar）
build.bat

:: 2. 一键组装构建上下文（jar + drivers + 精简引擎）
bash deploy\docker\build-docker.sh 1.0.5
```

> `build-docker.sh` 会自动从 `target/`、`drivers/`、`D:/seatunnel`（引擎源目录）拷贝
> 产物到 `deploy/docker/`。引擎源目录可用 `SEATUNNEL_SRC` 环境变量覆盖。

### 同步引擎（关键，漏了前端会提示「同步引擎缺失」）

DBridge 的同步执行体是 **SeaTunnel 引擎**（独立发行包），不是主程序自己。镜像必须
同时打进引擎，否则 `/api/ping` 返回 `engineFound=false`，前端页头红点提示「同步引擎缺失」。

- 引擎源目录默认 `D:/seatunnel`（501M），`build-docker.sh` 会**精简打包**：去掉
  flink/spark 5 个集群 starter jar（约 200M），只留本地模式需要的 `lib` + `connectors`
  + 核心 `starter/seatunnel-starter.jar` + `config`，最终约 301M。
- 镜像内引擎固定放 `/opt/dbridge/engine`，通过 `DBRIDGE_ENGINE_HOME` 和 `SEATUNNEL_HOME`
  两个环境变量指向它（Dockerfile 已设 ENV）。

> 注意：`deploy/docker/drivers/`、`deploy/docker/lib/`、`deploy/docker/engine/` 已被
> `.gitignore` 忽略（构建产物不进 git），每次构建前重新组装即可。

---

## 三、构建镜像

```bash
cd deploy/docker
docker build -t dbridge:1.0.5 .
```

---

## 四、运行

### 方式 A：docker compose（推荐）

```bash
cd deploy/docker
docker compose up -d
```

浏览器打开 http://localhost:27301 ，首次登录 `admin / admin123`。

### 方式 B：docker run

```bash
docker run -d \
  --name dbridge \
  -p 27301:27301 \
  -v dbridge-data:/opt/dbridge/data \
  -e DBRIDGE_LICENSE_URL=https://dbridge.zzzmxxkj.com \
  -e TZ=Asia/Shanghai \
  --restart unless-stopped \
  dbridge:1.0.5
```

---

## 五、内网离线分发（重点，你们客户主打离线）

客户内网往往上不了 Docker Hub，需要把镜像打成 tar 离线分发，等价于现在的 lite/full zip：

```bash
# 供方侧：导出镜像
docker save dbridge:1.0.5 -o dbridge-1.0.5-docker.tar

# 客户侧：导入镜像
docker load -i dbridge-1.0.5-docker.tar
```

---

## 六、实体机 vs 云服务器：指纹锚定（客户混合场景必读）

你的客户约 60% 实体机 + 40% 云服务器，两种环境指纹来源不同，方案用「三层兜底」：

| 优先级 | 锚点 | 覆盖谁 | 容器里的行为 |
|---|---|---|---|
| 1 | 主板 UUID（`/sys/class/dmi/id/product_uuid`） | 实体机 + 大部分云服务器（KVM 映射的 VM UUID） | 容器**默认穿透**读到宿主/虚拟机值，稳定 |
| 2 | 宿主机 `/etc/machine-id`（挂载进容器） | 读不到主板 UUID 的云实例 | 挂载 `:ro` 后读到宿主机值，稳定 |
| 3 | 固定 machine-id（镜像内兜底） | 极端环境 | 所有容器共享，仅兜底 |

**为什么网卡是虚拟网卡也不影响**：授权容错匹配只要「主板 UUID」对上就是 STRONG 级放行，
容器里 MAC 随机变（虚拟网卡）**不参与判定**。真正的主锚点是主板 UUID + machine-id，
不是网卡。

**关键动作**：compose 里已加 `- /etc/machine-id:/etc/machine-id:ro`，这是 Red Hat 官方
镜像同款做法，保证云服务器读不到主板 UUID 时授权依然不掉。

**验证命令**（真机部署后跑一次，确认三个锚点哪个生效）：

```bash
# 实体机/云服务器上，先看宿主机主板 UUID
cat /sys/class/dmi/id/product_uuid

# 进容器看它读到的值是否一致
docker exec dbridge cat /sys/class/dmi/id/product_uuid
docker exec dbridge cat /etc/machine-id
```

若「容器读到的主板 UUID == 宿主机主板 UUID」，则授权锚定 100% 稳定，可放心交付。

---

## 七、三个容易踩的坑

### 1. 连不上「宿主机上的数据库」

客户把 DBridge 和 MySQL 都装在**同一台服务器**，容器里连 `localhost:3306` 会连到
**容器自己**而不是宿主机。解决：数据源地址填 `host.docker.internal`（compose 里已
预留 `extra_hosts` 配置，取消注释即可）。

### 2. 数据卷没挂 → 重建容器变全新安装

`data/` 里有授权文件、H2 库、时间锚点。**不挂 volume，`docker rm` 再起 = 全新安装，
授权、数据源、任务全没**。compose 已挂 `dbridge-data` 卷，别删。

### 3. 时区不对 → cron 定时错乱

默认 UTC，客户设了「每 5 分钟」却对不上本地时间。compose 已设 `TZ=Asia/Shanghai`。

---

## 八、更新客户端（版本升级流程）

Docker 版升级 = **只换镜像 + 重启容器**，`data` 卷（`dbridge-data`）从不删除，所以
数据、授权、任务、水位全部保留，零丢失。

```bash
# 本机（改完代码、跑完 build.bat 后）
bash deploy/docker/build-docker.sh 1.0.6          # 组装新版本 jar+驱动+引擎
cd deploy && tar -czf dbridge-v1.0.6.tar.gz docker/   # 打 tar
scp dbridge-v1.0.6.tar.gz ubuntu@服务器IP:/home/ubuntu/

# 服务器
cd /home/ubuntu && tar -xzf dbridge-v1.0.6.tar.gz && cd docker
sudo docker build -t dbridge:1.0.6 .
sudo docker rm -f dbridge && sudo docker run -d --name dbridge \
  -p 27301:27301 -v dbridge-data:/opt/dbridge/data \
  -v /etc/machine-id:/etc/machine-id:ro \
  -e DBRIDGE_LICENSE_URL=https://dbridge.zzzmxxkj.com \
  -e DBRIDGE_ENGINE_HOME=/opt/dbridge/engine -e SEATUNNEL_HOME=/opt/dbridge/engine \
  -e TZ=Asia/Shanghai --restart unless-stopped dbridge:1.0.6
```

> 一条命令封装版：见 `update-docker.sh`（参数：版本号 + 服务器 IP），自动完成
> 组装→打包→上传→服务器重建→重启全流程。

---

## 九、交付前检查清单

1. **指纹锚定验证**：在实体机和云服务器各跑一次第六节的验证命令，确认
   `docker exec dbridge cat /sys/class/dmi/id/product_uuid` 与宿主机一致。
2. **同步引擎就绪**：登录后页头应显示绿点「服务正常」，不是红点「同步引擎缺失」；
   或直接查 `curl http://IP:27301/api/ping`（需登录）确认 `engineFound=true`。
3. **授权云端地址**：`DBRIDGE_LICENSE_URL` 指向真实公网授权服务（已上线
   `https://dbridge.zzzmxxkj.com`）。
4. **驱动目录**：目前 Dockerfile 把 `drivers/` 打进镜像。若后续要支持「运行中换驱动」，
   可改为挂载 `drivers` 目录为 volume（和当前 `work/drv-active` 镜像逻辑对齐）。
