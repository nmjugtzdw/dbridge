# 数桥 DBridge · Docker 部署

镜像自带 Java 11、8 种数据库驱动与 SeaTunnel 同步引擎，一条命令拉起，数据用 volume 持久化。

本文三种启动方式的关系，先看这张表再往下看：

| 方式 | 你需要先有什么 | 是否自动下载镜像 |
|---|---|---|
| 一、一键安装脚本 | 一台能上外网的 Linux 服务器 | ✅ 会（连 Docker 都帮你装） |
| 二、docker compose | 本机已有 `dbridge:latest` 镜像 + 本仓库的 compose 文件 | ❌ 不会 |
| 三、docker run | 本机已有 `dbridge:latest` 镜像 | ❌ 不会 |

镜像只有两个来源：**跑过一次方式一**，或**手动 `docker load` 我们提供的 tar**。
本项目不发布到 Docker Hub，`docker pull` 拉不到。

| 端口 | 用途 |
|---|---|
| 27301 | 控制台（Web 界面） |
| 27302 | 授权服务（容器**出站**访问，不需要映射） |

---

## 一、一键安装（推荐）

在 Linux 服务器上（root）：

```bash
bash <(curl -sL https://dbridge.zzzmxxkj.com/install.sh)
```

脚本会自动完成：检查 Docker → 下载镜像包 → sha256 校验 → `docker load` → 启动容器 → 等接口就绪后打印访问地址。

脚本不带参数，**永远装当前最新版**（版本号由服务端 `latest.txt` 决定，镜像导入后自动标记为
`dbridge:latest`）。升级不用改命令，重跑同一条即可，数据卷与授权都保留。

下载走 HTTPS 直连，支持断点续传，不依赖 Docker Hub，内网/国内环境也能用。

---

## 二、手动 docker run

```bash
docker run -d \
  --name dbridge \
  -p 27301:27301 \
  -v dbridge-data:/opt/dbridge/data \
  -v /etc/machine-id:/etc/machine-id:ro \
  -e DBRIDGE_LICENSE_URL=https://dbridge.zzzmxxkj.com:27302 \
  -e TZ=Asia/Shanghai \
  --restart unless-stopped \
  dbridge:latest
```

浏览器打开 `http://localhost:27301`，首次登录 `admin / admin123`，登录后会引导改密码。

> `-v /etc/machine-id:/etc/machine-id:ro` 建议保留：云服务器上它保证授权指纹稳定，
> 容器重建、升级都不会掉授权。

---

## 三、docker compose

```bash
# 前置：本机已有 dbridge:latest（跑过方式一，或 docker load 导入了镜像包）
git clone https://github.com/nmjugtzdw/dbridge
cd dbridge/deploy/docker
docker compose up -d
```

compose 只负责「按 `docker-compose.yml` 里的参数启动容器」，**不会下载镜像**。
`deploy/docker/` 目录只存在于 GitHub 仓库，Windows 客户端 zip 里没有它。

---

## 四、环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `DBRIDGE_LICENSE_URL` | `https://dbridge.zzzmxxkj.com:27302` | 授权服务地址，必须带 `27302` 端口 |
| `TZ` | `Asia/Shanghai` | 时区，影响日志时间戳与定时任务 |
| `DBRIDGE_ADMIN_PASSWORD` | 不设则 `admin123` | 首次登录的出厂密码 |
| `DBRIDGE_ENGINE_HOME` | `/opt/dbridge/engine` | 同步引擎目录，镜像内已固定 |
| `SEATUNNEL_HOME` | `/opt/dbridge/engine` | 同上（引擎自身定位插件用） |

---

## 五、数据与备份

`dbridge-data` 卷里是**授权文件、内置库、时间锚点**，以及你的数据源、同步任务、增量水位。备份就备份这个卷：

```bash
# 备份
docker run --rm -v dbridge-data:/data -v "$PWD":/backup alpine \
  tar czf /backup/dbridge-data.tar.gz -C /data .

# 恢复
docker run --rm -v dbridge-data:/data -v "$PWD":/backup alpine \
  tar xzf /backup/dbridge-data.tar.gz -C /data
```

---

## 六、升级

升级 = 换镜像 + 重建容器，**卷不删**，所以数据、授权、任务、水位全部保留：

```bash
# 重新跑一次一键安装脚本即可（会装最新版）
bash <(curl -sL https://dbridge.zzzmxxkj.com/install.sh)
```

---

## 七、内网 / 离线部署

客户内网上不了外网时，用镜像包离线分发：

```bash
# 有网环境导出（约 418MB）
docker save dbridge:latest -o dbridge.tar

# 客户侧导入
docker load -i dbridge.tar
```

导入后按第二节的 `docker run` 启动即可，全程不需要外网。

---

## 八、常见问题

**1. 连不上宿主机上的数据库**

DBridge 和 MySQL 装在同一台机器时，容器里填 `localhost` 会连到容器自己。数据源地址请填 `host.docker.internal`，并在启动时加上：

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

**2. 容器重建后变成全新安装**

`data` 卷没挂上。授权文件、数据源、任务都在卷里，`docker rm` 前请确认卷还在。

**3. 定时任务的时间不对**

设 `TZ=Asia/Shanghai`，否则容器按 UTC 跑，界面上"每 5 分钟"会对不上本地时间。

**4. 页头提示「同步引擎缺失」**

官方镜像已内置精简版引擎（约 301MB）。自行构建时如果漏掉引擎目录，`/api/ping` 会返回 `engineFound=false`，前端就显示红点。

**5. 显示「未激活」**

容器需要能出站访问 `DBRIDGE_LICENSE_URL` 的 27302 端口。内网环境请让防火墙放行，或在授权面板里换用离线激活。
