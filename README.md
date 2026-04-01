# kube-kit (kk)

kube-kit (`kk`) 是一个专为 Kubernetes 设计的命令行一键导航与操作工具。它旨在解决日常 K8s 运维中频繁切换集群/Namespace、记忆和复制粘贴长资源名称、以及输入冗长 `kubectl` 命令的痛点。

通过极其轻量级的纯 Bash 实现，结合 `fzf` 的强大模糊搜索能力，kube-kit 将绝大多数常见的 K8s 操作压缩到 **3 次按键以内**，同时保持对操作上下文的粘滞记忆。

## 🌟 核心特性

- **Zero Memory (零记忆)**: 无需记忆资源全名，支持模糊搜索直达。
- **Three Keystrokes (极简操作)**: 选集群 -> 选 Namespace -> 选资源，三步定位，随后通过单键快捷菜单执行操作。
- **Sticky Context (上下文粘滞)**: 自动记录最后一次操作的 Cluster/Namespace/Resource，通过 `kk -r` 可快速回到上次上下文。
- **Colorized UI (可视化增强)**: 资源列表高亮显示，异常状态（如 `CrashLoopBackOff`、`ImagePullBackOff` 等）标红警示，附带精确的运行时间 (Age)。
- **Educational (学习友好)**: 实时在预览区顶部展示对应的原生 `kubectl` 命令，方便复制学习。
- **Safety First (安全防范)**: 对于编辑、删除、修改镜像等危险操作，提供统一的二次确认拦截。

## 🚀 快速开始

### 依赖要求

- `bash` (5.0+)
- `kubectl` (与集群版本兼容)
- `fzf` (用于模糊搜索界面)
- `jq` (用于解析 k8s json 格式输出)
- *(可选)* `bat` 或系统剪贴板工具 (`pbcopy`, `xclip`)

### 安装

**一键安装（推荐）**

无需手动下载源码，直接在终端运行以下命令即可安装（前提是有 Git 访问权限）：

```bash
curl -s https://raw.githubusercontent.com/fuxiaoai/kube-kit/main/install.sh | bash
```

> **注意**：如果不方便使用 `curl`，也可以直接复制 [install.sh](https://github.com/fuxiaoai/kube-kit/blob/main/install.sh) 的内容到目标机器执行。

**本地源码安装**

如果你已经克隆了仓库，可以使用仓库内的本地安装脚本：

```bash
cd kube-kit
./local_install.sh
```

脚本会将 `kk` 及其依赖的 `lib` 目录复制到 `~/.local/bin/`。
> **注意**：请确保 `~/.local/bin/` 已经加入到你的环境变量 `$PATH` 中。

### 基本用法

```bash
# 启动完全交互模式（依次选择 Cluster -> Namespace -> 资源）
kk

# 指定关键字搜索当前/默认上下文中的资源
kk <keyword>

# 指定集群或 Namespace 进行快速搜索
kk -n kube-system
kk -c my-cluster -n default <keyword>

# 重复执行上一次的上下文操作
kk -r
kk --repeat

# 查看帮助
kk -h
```

## 🛠 功能模块 (Action Menu)

在导航到具体资源后，会弹出针对该资源的单键快捷操作菜单：

**Pod 操作:**
- `[l]` Logs: 查看日志（支持交互式选择容器、Tail、Follow）。
- `[x]` Exec: 自动检测可用 Shell（bash/sh/ash）并进入容器。
- `[d]` Describe: 查看 Pod 详细事件与状态。
- `[e]` Env: 快速查看运行时的环境变量。
- `[R]` Delete: 危险操作确认后删除该 Pod。

**Deployment 操作:**
- `[D]` View: 查看 Deployment 详情。
- `[i]` Image: 交互式修改镜像版本（修改后自动触发 rollout 监控）。
- `[E]` Edit: 全局编辑 Deployment 资源 YAML。

**ConfigMap 操作:**
- `[c]` View: 浏览 ConfigMap 详细配置。
- `[C]` Edit: 警告确认后进入编辑器修改 ConfigMap。

**Service 操作:**
- `[s]` View: 浏览 Service 详情与映射。

## 🏗 架构设计

kube-kit 采用模块化的纯 Bash 编写方案，无外部运行时（如 Go/Python）依赖，极致轻量，方便分发到任何跳板机/堡垒机上：

```
kube-kit/
├── kk                          # 主入口脚本，处理参数解析与主流程流转
├── lib/
│   ├── core.sh                 # 核心公共函数（日志输出、颜色定义、危险确认等）
│   ├── config_manager.sh       # 配置读写与初始化
│   ├── history.sh              # 历史记录与上下文存储 (依赖 ~/.kk/history.json)
│   ├── k8s_api.sh              # kubectl API 封装，包含针对资源的临时文件缓存机制
│   ├── fzf_helpers.sh          # fzf 渲染组件、快捷键绑定以及预览区内容生成逻辑
│   ├── navigator.sh            # 集群、Namespace、资源列表的获取与数据流 (jq 格式化)
│   └── actions.sh              # 选中资源后的具体操作命令（Menu 及 Exec/Log 动作）
└── install.sh                   # 安装部署脚本
```

## 📝 快捷键 (fzf 界面内)

- **`Ctrl-/`**: 切换右侧预览窗口的显示/隐藏。
- **`Ctrl-y`**: 快速复制当前高亮行内容到系统剪贴板。
- **`Enter`**: 确认选择，进入下一步。
- **`Esc` / `Ctrl-c`**: 退出或返回上一层。
