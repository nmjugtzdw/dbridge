# 数桥 DBridge · Docker 部署

镜像里已经带齐运行所需的一切，一条命令拉起，数据存在独立卷里，升级重装都不丢。

**方式一零前置**（连 Docker 都帮你装）；**方式二、三需要本机已经有 `dbridge:latest` 镜像**，
镜像下载命令见第七节。本项目不发布到 Docker Hub，`docker pull` 拉不到。

| 端口 | 用途 |
|---|---|
| 27301 | 控制台，浏览器访问这个，需要对外开放 |

容器出站还要能访问授权服务，地址和端口已写在 `DBRIDGE_LICENSE_URL` 里，照原样填即可，不用另外开放入站端口。

---

## 一、一键安装（推荐）

在 Linux 服务器上（root）：

```bash
bash <(curl -sL https://dbridge.zzzmxxkj.com/install.sh)
```

脚本会自动完成：检查 Docker → 下载镜像包 → 校验文件完整性 → 导入镜像 → 启动容器 → 等服务真正可用后打印访问地址。

脚本不带参数，**永远装当前最新版**，升级也不用改命令，重跑同一条即可，数据与授权都保留。

下载走 HTTPS 直连，支持断点续传，不依赖 Docker Hub，内网/国内环境也能用。

---

## 二、手动起容器

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

> `-v /etc/machine-id:/etc/machine-id:ro` 这一行建议保留：云服务器上它保证授权在容器重建、升级后仍然有效。

---

## 三、docker compose

```bash
# 前置：本机已有 dbridge:latest（跑过方式一，或导入过镜像包）
git clone https://github.com/nmjugtzdw/dbridge
cd dbridge/deploy/docker
docker compose up -d
```

compose 只负责按文件启动容器，不负责下载镜像。

---

## 四、可配置项

| 配置项 | 默认值 | 说明 |
|---|---|---|
| `DBRIDGE_LICENSE_URL` | `https://dbridge.zzzmxxkj.com:27302` | 授权服务地址，照原样填，不要删掉端口 |
| `TZ` | `Asia/Shanghai` | 时区，影响日志时间与定时任务触发时刻 |
| `DBRIDGE_ADMIN_PASSWORD` | 不设则 `admin123` | 首次登录的出厂密码 |

---

## 五、数据与备份

程序数据、你的数据源、同步任务、授权信息都在 `dbridge-data` 这一个卷里。备份就备份这个卷：

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

升级 = 换镜像 + 重建容器，**卷不删**，所以数据、授权、任务全部保留：

```bash
# 重新跑一次一键安装脚本即可（会装最新版）
bash <(curl -sL https://dbridge.zzzmxxkj.com/install.sh)
```

---

## 七、下载镜像 / 离线部署

```bash
# 直接下载（永远拿到最新版；-C - 支持断点续传）
curl -fL -C - --progress-bar -o dbridge.tar \
  https://dbridge.zzzmxxkj.com/dist/dbridge-docker-latest.tar
docker load -i dbridge.tar

# 内网离线：在能上网的机器上导出镜像，拷到客户侧导入
docker save dbridge:latest -o dbridge.tar
```

## 八、常见问题

**1. 连不上宿主机上的数据库**

DBridge 和 MySQL 装在同一台机器时，容器里填 `localhost` 会连到容器自己。数据源地址请填 `host.docker.internal`，并在启动时加上：

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

**2. 容器重建后变成全新安装**

`data` 卷没挂上。数据源、任务、授权都在卷里，`docker rm` 前请确认卷还在。

**3. 定时任务的时间不对**

设 `TZ=Asia/Shanghai`，否则容器按 UTC 跑，界面上"每 5 分钟"会对不上本地时间。

**4. 显示「未激活」**

容器需要能出站访问 `DBRIDGE_LICENSE_URL`（地址里已带端口）。内网环境请让防火墙放行这个地址，或在授权面板里换用离线激活。

**5. 页头提示组件缺失**

官方镜像已自带全部运行组件。如果出现这个提示，说明镜像包不完整，重新下载导入即可；仍有问题请联系技术支持。
