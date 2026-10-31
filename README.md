<div align="center">

# 数桥 DBridge · 数据库同步工具

**给不会写配置文件的人用的图形化数据库同步工具。选表 → 点按钮 → 数据同步过去，之后按频率自动跑。**

*DBridge · A visual database sync tool for people who don't write config files.*

免装 JDK · 内网离线可用 · 体检 → 试跑 → 正式同步三层防错护栏

[![GitHub release](https://img.shields.io/github/v/release/nmjugtzdw/dbridge?style=flat-square)](https://github.com/nmjugtzdw/dbridge/releases)
[![License](https://img.shields.io/badge/license-Commercial-red?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-lightgrey?style=flat-square)]()
[![Docker](https://img.shields.io/badge/Docker-支持-blue?style=flat-square&logo=docker)](deploy/docker/README.md)

</div>

---

## 📖 简介 / Introduction

数桥（DBridge）把数据库之间的数据搬运做成了「点点鼠标就能完成」的事：不需要手写 SQL、不需要懂配置文件的语法，填好连接、勾选要同步的表和字段，剩下的交给程序。它会**先体检、再试跑、最后才正式同步**，全程用"人话"告诉你每一步发生了什么。

*DBridge turns cross-database data movement into a point-and-click task. No SQL, no config syntax — just fill in connections, check the tables and fields you want to sync, and let the program handle the rest. It checks first, trial-runs, then syncs for real, explaining every step in plain language.*

> ⚠️ 本仓库只用于**项目介绍与公开信息展示**，不含任何源码。产品为闭源商业软件，这里放的是说明文档、界面截图和部署方式。
> *This repository is for project introduction and public information only. It contains no source code. The product is closed-source; what you find here is documentation, screenshots, and deployment instructions.*

---

## 🖼️ 界面预览 / Screenshots

### 数据源管理 / Data Sources

![数据源管理](docs/images/datasource.png)

添加 MySQL / MariaDB / Oracle / PostgreSQL / SQL Server / TiDB / OceanBase / Greenplum 八种数据源，测试连接显示真实版本与延迟，账号密码加密存储、脱敏显示，并对低于官方支持的库版本自动给出换驱动建议。

### 同步任务 / Sync Jobs

![同步任务](docs/images/jobs.png)

按「任务组」组织同步任务，每组一个源库 → 目标库，勾选要同步的表；每张表实时显示同步进度、耗时、失败原因与体检评级（优 / 良 / 中 / 差）。

### 帮助与数据体检 / Help & Data Health Check

![帮助与体检](docs/images/help.png)

第一次照着看一遍，五分钟上手。每张表上线前可做「体检」（只读），按优/良/中/差分级，发现差异可「一键修复」。

### 驱动管理 / Driver Management

![驱动管理](docs/images/drivers.png)

内置驱动版本兼容档案，按实际数据库版本推荐驱动，一键下载 / 替换 / 回滚，全程不用懂版本号。账号管理、多角色权限也在此页。

---

## ✨ 产品能做什么 / What It Does

- **图形化数据源管理**：MySQL / MariaDB / Oracle / PostgreSQL / SQL Server / TiDB / OceanBase / Greenplum 八种数据库，填主机、端口、账号、密码即可，测试连接一键通过。
- **选表选字段**：不用手写 SQL 或配置文件，勾选要同步的表和字段就行。
- **自动建目标表**：目标库没有对应表时自动建表，字段类型自动对应。
- **字段自动匹配**：源表和目标表的字段按字段名、别名、中文注释自动对应，省去手工一个个对齐。
- **定时调度**：按你设的频率自动跑，支持全量同步和增量同步。
- **只搬变化的数据**：按时间或编号判断哪些是新的、哪些改过，只搬这部分，不重复、不漏数。
- **大表中断能接着搬**：整表搬运中途断了，下次从断的地方继续，已经搬完的部分不会重搬。
- **运行历史与日志**：每次运行都留记录，日志可以只看错误行，也能下载下来发人。
- **试跑校验**：先拿几行数据试一遍，确认无误再正式同步。
- **一键换驱动**：数据库版本和驱动不匹配时，程序自己推荐该用哪个版本，点一下就换好。

---

## 🛡️ 核心特点 / Core Highlights

### 三层递进，保证不会写坏数据 / Three-Layer Guard Against Data Corruption

```
体检（只读）  →  试跑（读几行写临时表）  →  正式同步（写正式表）
   随时点          正式表零改动                前置体检不过直接拒绝
```

1. **体检 / Check**：十几项检查（能不能连上、有没有权限、字段类型对不对得上、主键会不会撞、必填列有没有数据等），结论分成「必须解决」「建议注意」「没问题」三档，用大白话说明该干什么。
2. **试跑 / Trial Run**：只读几行数据写进临时表，回读核对无误后自动删表，**绝不碰正式表**。试跑也不会影响正式同步的进度判断，跑完正式同步照样从该开始的地方开始。
3. **正式同步 / Sync**：体检有「必须解决」的问题就直接拒绝运行。带着已知的毛病去写数据，从一开始就不允许发生。

### 报错说人话 / Human-Readable Errors

连不上、没权限、类型不对、主键冲突等二十多类常见问题，都会翻译成「原因 + 你该怎么办」，而不是甩给你一段英文报错。

### 重复跑不写重，中断了不漏数 / Idempotent, Lossless Incremental Sync

同一批数据重复同步不会变成两倍，中途失败接着跑也不会漏掉中间的记录。时间、日期、自增编号等不同类型的判断依据都做了处理，不会因为认不出类型而多搬或漏搬。

### 断网也能用 / Works Offline

数据同步在你的内网或本机跑，不依赖外网。运行环境和数据库驱动都内置或可离线安装，常见版本驱动已提前备好，完全不出网的客户也能正常使用和授权。

---

## 📊 实测数据 / Measured Performance

固定条件：单表 **10 万行**、局域网、控制台与数据库在同一台机器上（2 核 / 4 GB）。

| 场景 | 耗时 |
|---|---|
| MySQL → MySQL | 16.0 秒 |
| MySQL → PostgreSQL | 15.4 秒 |
| MySQL → Oracle | 17.9 秒 |
| MySQL → SQL Server | 38.7 秒 |
| Oracle → MySQL | 16.8 秒 |
| Oracle → SQL Server（最慢组合） | 48.9 秒 |

- 每一组的读 / 写行数都是 **100,000 / 100,000**，并且**逐行核对过结果**，不只是"跑完了没报错"。
- 上表是目标表已存在时的稳定耗时；第一次由程序自动建表只多约 0.6 秒。
- SQL Server 做目标会慢 3–4 倍，这是它本身的写入特点，不是故障，安排维护窗口时按 40–55 秒估。
- 机器负载会明显影响速度：同一套脚本在更空闲时测得 MySQL / PostgreSQL 约 **7.8 秒**。对外按 **「10 万行 15–20 秒」** 估比较稳妥，不要承诺固定吞吐。
- **适用规模**：中小企业 ERP / 业务库，单表 10–20 万行。百万行级不在目标场景内，不做承诺。

**回归情况**：MySQL、MariaDB、PostgreSQL、Oracle、SQL Server 五套真实数据库全量回归 55 项通过；另有 109 条自动化检查，每次发版前全部跑一遍。

---

## 🆚 与市面工具的对比 / Comparison

| 维度 | 数桥 DBridge | SeaTunnel / DataX | Flink CDC | SyncTool |
|---|---|---|---|---|
| 使用方式 | **图形化点选** | 写配置/代码 | 写配置/代码 | 图形化点选 |
| 免装环境 | ✅ 内置运行环境 | ❌ | ❌ | ⚠️ 需 Java 17+ |
| 内网离线 | ✅ | ⚠️ | ❌ | ✅ |
| 体检/试跑护栏 | ✅ 三层 | ❌ | ❌ | ❌ |
| 数据一致性校验 | ✅ 优/良/中/差 | ❌ | ❌ | ❌ |
| 大表中断续传 | ✅ 从断点继续 | ❌ | ✅ | ⚠️ |
| 增量同步 | ✅ 自动识别时间/编号 | ⚠️ 手动填时间 | ✅ | ✅ |
| CDC 秒级实时 | ❌ | ⚠️ | ✅ | ❌ |
| 国产库（达梦等） | ⚠️ 部分（OceanBase） | ⚠️ 部分 | ⚠️ | ✅ |

**我们最强的三点**：① 免装环境的图形化（目标用户零门槛）；② 三层防错护栏 + 一致性校验（写坏数据前先拦住，独家）；③ 大表续传 + 增量同步（不重不漏）。

**我们暂时弱的三点**：国产库覆盖（已支持 OceanBase，达梦/金仓等在路线图）、存储过程/视图等对象同步、CDC 秒级实时——都在路线图上。

---

## 🚀 部署方法 / Deployment

DBridge 支持三种部署方式，功能完全一致，按你的环境任选其一：

| 方式 | 适用场景 | 入口 |
|---|---|---|
| 🪟 **Windows** | 个人电脑 / Windows 服务器 | 解压 zip 双击 `启动.bat` |
| 🐧 **Linux** | Linux 服务器（裸机部署） | 解压 tar 跑启动脚本 |
| 🐳 **Docker** | 已有 Docker 环境 / 云服务器 | `docker run` 或 `docker compose` |

### 🪟 Windows 部署

分两种包，功能完全一致，只差运行环境：

| 包 | 大小 | 说明 |
|---|---|---|
| **lite 版** | 约 60 MB | 不含 Java。解压后先跑「环境检测.bat」，自动下载 Java 与数据库驱动（需能上外网） |
| **full 版** | 约 117 MB | 内置 Java，解压即用，适合内网、不能上外网的机器 |

#### 三步装起来 / 3-Step Install

1. **解压**：把压缩包整个解压到硬盘（例如 `D:\DBridge`）。不要放 `C:\Program Files`，也不要在压缩包里直接双击运行——那里没有写权限。路径里尽量不要有中文。
2. **检测环境**：双击「环境检测.bat」，逐项检查并给出结论（`OK` / `注意` / `失败`）。缺 Java 自动下载、缺驱动自动补齐，全部通过后生成环境配置。
3. **启动**：双击「启动.bat」，等约 10 秒，浏览器打开 `http://localhost:27301`。那个黑色窗口就是服务本身，关掉即停止服务。

#### 开机自启 / Auto-Start

给「启动.bat」建快捷方式放进启动文件夹（`Win+R` → `shell:startup`），或用「任务计划程序」创建「计算机启动时」运行的任务。

### 🐧 Linux 部署

Linux 服务器裸机部署，解压后运行启动脚本即可（同样内置 Java，无需预装 JDK）：

```bash
# 1. 解压
tar -xzf dbridge-linux.tar.gz
cd dbridge

# 2. 启动（后台运行，日志写入 logs/）
./start.sh

# 3. 浏览器打开 http://服务器IP:27301
```

停止服务：`./stop.sh`（或直接 kill 进程）。

### 🐳 Docker 部署

**方式一：一键安装（推荐，无需任何前置）**

```bash
bash <(curl -sL https://dbridge.zzzmxxkj.com/install.sh)
```

自动装 Docker、下载并导入最新镜像、启动容器。升级重跑同一条，数据与授权都保留。

**方式二：自己起容器（需要先有镜像）**

```bash
# 1) 下载镜像包并导入（latest 永远指向最新版）
curl -fL -C - --progress-bar -o dbridge.tar \
  https://dbridge.zzzmxxkj.com/dist/dbridge-docker-latest.tar
docker load -i dbridge.tar

# 2) 起容器，二选一
#    a. compose（文件在仓库 deploy/docker 下）
git clone https://github.com/nmjugtzdw/dbridge && cd dbridge/deploy/docker && docker compose up -d

#    b. docker run
docker run -d --name dbridge -p 27301:27301 \
  -v dbridge-data:/opt/dbridge/data \
  -v /etc/machine-id:/etc/machine-id:ro \
  -e DBRIDGE_LICENSE_URL=https://dbridge.zzzmxxkj.com:27302 \
  -e TZ=Asia/Shanghai \
  --restart unless-stopped dbridge:latest
```

浏览器打开 `http://localhost:27301`。

> 上面命令里的 `/etc/machine-id` 和 `DBRIDGE_LICENSE_URL` 两项跟授权绑定有关，**保持原样即可**，不要删也不要改。
> 镜像只放在我们自己的服务器上，没发到 Docker Hub，`docker pull` 拉不到。
> 内网离线：`docker save dbridge:latest -o dbridge.tar` 带到客户侧 `docker load -i`。

### 首次登录 / First Login

出厂账号 `admin`，登录后系统会引导修改密码。忘了密码可以用环境变量重置（详见交付说明）。

### 文件结构 / File Layout

| 文件 / 目录 | 用途 |
|---|---|
| `环境检测.bat` | 检查环境、自动下载 Java 与数据库驱动（Windows lite 版） |
| `启动.bat` / `start.sh` | 启动控制台（Windows / Linux） |
| `lib\` | 程序文件，**不用动** |
| `runtime\` | 自带的运行环境（lite 版没有，检测时自动下载） |
| `drivers\` | 数据库驱动（MySQL / MariaDB / Oracle / PostgreSQL / SQL Server / TiDB / OceanBase / Greenplum） |
| `data\` | 你的数据、账号等，**备份就拷这个目录** |
| `logs\` | 运行日志，出问题时打包这个目录发给支持方 |
| `work\` | 临时目录，可整个删除，会自动重建 |

---

## 📜 更新历史 / Changelog

每个版本的完整更新说明都在 [Releases](https://github.com/nmjugtzdw/dbridge/releases) 页面，与下载包一一对应，这里不再重复维护（避免两处不同步）。

---

## 👤 作者 / Author

- **作者 / Author**：木思丁

---

## 📁 目录说明 / Repository Layout

```
dbridge-open/
├── README.md         本文件
├── LICENSE           使用许可
├── docs/
│   └── images/       界面截图
└── deploy/
    └── docker/       Docker 部署文件（自建容器时用得上）
```

---

## ⚠️ 免责声明 / Disclaimer

- 本仓库仅用于**项目介绍与公开信息展示**，不含任何源码。
- 完整产品为闭源商业软件，界面、功能与文档版权归作者所有。
