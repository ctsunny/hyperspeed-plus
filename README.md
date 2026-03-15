# HyperSpeed Plus

<div align="center">

![Version](https://img.shields.io/badge/version-6.3.0-blue?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![Shell](https://img.shields.io/badge/shell-bash-orange?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey?style=flat-square)

**长时压力测速 · 后台守护 · 三网/国际节点 · 曲线分析 · 报告上传**

</div>

---

## 功能特性

- 🔁 **长时压力测速** — 支持自定义时长（小时级），随机间隔多轮连续测速
- 🌙 **后台守护模式** — `nohup` 守护进程，断开 SSH 不中断
- 🌐 **双引擎节点** — bimc 高精度节点 + ookla/speedtest.net 三网/国际节点
- 📡 **智能节点探测** — 对所有 ookla 节点自动 ping 延迟排序，取最优1个
- 📈 **曲线分析** — 自动生成速度/延迟 SVG 曲线图 + HTML 报告
- ☁️ **报告上传** — 支持 Catbox / transfer.sh / tmpfiles.org 一键生成分享链接
- 🧵 **八线程测速** — 可选开启多线程模式
- 📋 **CSV 日志** — 每轮每节点结果记入 CSV，方便二次分析

---

## 快速开始

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ctsunny/hyperspeed-plus/main/hyperspeed-plus.sh)
```

> 需要 root 权限（speedtest 工具安装至 `/root/speedtest-cli`）

---

## 节点选择说明

进入测速前会显示节点选择菜单，支持混合输入：

```
可选测试地区/节点 (bimc 高精度节点):
  01. [bimc ] 电信       上海
  02. [bimc ] 电信       江苏镇江5G
  03. [bimc ] 电信       江苏南京5G
  04. [bimc ] 港澳台日韩 环电宽频 (香港)
  05. [bimc ] 港澳台日韩 中华电信 (台北)

  --- 动态加载最优单节点 (ookla, 延迟最低1个) ---
  a.联通  b.电信  c.移动  d.香港  e.台湾  f.日本  g.新加坡
  n.三网就近(联通+电信+移动 各1个)
```

| 输入示例 | 效果 |
|---|---|
| `1,2` | 仅选 bimc 上海 + 镇江 |
| `1,2,a,d` | bimc 上海+镇江 + 联通最优1个 + 香港最优1个 |
| `n` | 联通/电信/移动 三网就近各1个 |
| `ecs` | 同 `n`，三网就近各1个 |
| `all` | bimc全部5个 + ookla七大区各1个 = 最多12个节点 |

> ookla 节点会自动 ping 探测取延迟最低的1个；若 ping 不可达则取列表第一个节点作为 fallback。

---

## 主菜单

```
1.  前台开始测速
2.  后台守护开始测速
3.  查看后台任务状态
4.  停止后台任务
5.  日志列表
6.  查看最新日志
7.  查看指定日志
8.  分析最新CSV并生成曲线
9.  选择CSV做分析并生成曲线
10. 报告文件列表
11. 上传最新报告并生成下载链接
12. 三网/国际 speedtest.net 测速（单次）
0.  退出
```

---

## 文件目录

```
~/.hyperspeed-plus/
├── logs/          # 测速日志 (.log) 和原始数据 (.csv)
├── reports/       # 分析报告 (SVG 曲线图 / HTML / 摘要)
├── tmp/           # bimc 二进制组件
└── run/           # 后台进程文件 (PID / task.env / worker.sh)
```

---

## 依赖

| 依赖 | 说明 |
|---|---|
| `bash` ≥ 4.0 | 脚本运行环境 |
| `curl` 或 `wget` | 下载组件和节点列表 |
| `base64` `awk` `sed` | 数据处理 |
| `ping` | ookla 节点延迟探测（可选，失败自动 fallback） |
| `tar` | 打包报告 |

speedtest 工具（ookla 官方 CLI 或 speedtest-go）由脚本自动下载安装，无需手动准备。

---

## CSV 字段说明

| 字段 | 说明 |
|---|---|
| `time` | 测试时间 |
| `round` | 轮次编号 |
| `group` | 节点分组 |
| `location` | 节点位置 |
| `isp` | 运营商 |
| `upload_mbps` | 上传速度 (Mbps) |
| `upload_status` | 上传状态（正常/失败） |
| `download_mbps` | 下载速度 (Mbps) |
| `download_status` | 下载状态（正常/失败） |
| `latency_ms` | 延迟 (ms) |
| `jitter_ms` | 抖动 (ms) |
| `packet_loss` | 丢包率（ookla节点有效，bimc为NULL） |

---

## 鸣谢

- [bimc](https://bench.im) — 高精度测速核心
- [spiritLHLS/ecsspeed](https://github.com/spiritLHLS/ecsspeed) — 三网/国际 speedtest.net 节点数据源
- [ookla speedtest CLI](https://www.speedtest.net/apps/cli) — 官方测速工具
- [showwin/speedtest-go](https://github.com/showwin/speedtest-go) — 备用测速工具

---

## License

[MIT](./LICENSE) © 2024 ctsunny
