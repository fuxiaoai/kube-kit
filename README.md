# kube-kit (kk)

kube-kit (`kk`) 是一个专为 Kubernetes 设计的命令行一键导航与操作工具。它旨在解决日常 K8s 运维中频繁切换集群/Namespace、记忆和复制粘贴长资源名称、以及输入冗长 `kubectl` 命令的痛点。

通过**极致轻量和纯bash化实现**，结合 `fzf` 的强大模糊搜索能力，kube-kit 将绝大多数常见的 K8s 操作压缩到 **3 次按键以内**，同时保持对操作上下文的粘滞记忆。特别地，它完美**支持在无网络的全离线私有化环境，手动复制脚本实现到服务器即可执行**。

## 🌟 核心特性

- **Zero Memory (零记忆)**: 无需记忆资源全名，支持模糊搜索直达。
- **Three Keystrokes (极简操作)**: 不用看操作文档，通过符合直觉的选空间 -> 选资源 -> 选操作的这三步流程，即可完成K8S集群运维操作。
- **Visual Preview (可视化预览)**: 选择资源后，右侧实时展示所选资源的配置详情与状态，实现所见即所得。
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

### 安装与分发

kube-kit 提供两种安装模式：**在线一键安装** 和 **纯离线单脚本安装**。

#### 1. 在线一键安装（推荐，需联网）

如果你的机器可以访问 GitHub，可以直接通过以下命令一键安装（自动下载最新代码及 fzf 依赖）：

```bash
curl -fsSL https://raw.githubusercontent.com/fuxiaoai/kube-kit/main/install.sh | bash
```

> **提示**：如果目标机器不方便使用 `curl` 管道，你也可以直接复制本仓库下 [install.sh](install.sh) 的全部内容，粘贴到目标机器的终端中执行，或者保存为脚本后运行。

#### 2. 纯离线单脚本安装（无网络环境）

对于无法连接外网、且无法访问公司内部源的强隔离环境（如专有云、隔离集群），kube-kit 提供了**真正的纯离线单脚本安装**能力。

该模式会将 kube-kit 的源码以及所依赖的 `fzf` 二进制文件（Base64 编码）**全部内嵌到一个单独的 Bash 脚本中**，实现 100% 无网络依赖的闭环安装。

为了方便快速使用，**你完全不需要拉取代码到本地，也不需要手动执行构建**，直接复制我们已经打包好的离线脚本即可：

**最快安装流程（直接复制脚本）：**
1. 在有网的机器上，打开并复制这个地址的全部内容：👉 [**standalone_install.sh (Raw)**](https://raw.githubusercontent.com/fuxiaoai/kube-kit/main/standalone_install.sh)
2. 在隔离环境（无网机器）中新建一个文件，或直接打开终端。
3. 将刚才复制的脚本内容粘贴进去并执行：
   ```bash
   bash standalone_install.sh
   ```
4. 脚本会自动将依赖和工具释放到 `/usr/local/bin`（或覆盖已有路径），即刻完成闭环安装。

---

*(高级用法)* **自行打包流程（适合二次开发）：**
如果你修改了源码并希望自己生成离线脚本，可以在有网/有代码权限的机器执行：
1. 克隆本项目代码并进入目录。
2. 执行 `make st` 命令。
3. 构建系统会自动生成一个自包含的 `standalone_install.sh` 脚本，并自动将其内容复制到你的系统剪贴板。
4. 按照上述安装流程粘贴到目标机器执行即可。

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
- `[L]` Less Logs: 使用 less 分页查看完整日志。
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
├── kk                           # 主入口脚本，处理参数解析与主流程流转
├── lib/
│   ├── core.sh                  # 核心公共函数（日志输出、颜色定义、危险确认、返回码等）
│   ├── config_manager.sh        # 配置读写与初始化
│   ├── history.sh               # 历史记录与上下文存储 (依赖 ~/.kk/history.json)
│   ├── k8s_api.sh               # kubectl API 封装，包含针对资源的临时文件缓存机制
│   ├── fzf_helpers.sh           # fzf 渲染组件、快捷键绑定以及预览区内容生成逻辑
│   ├── navigator.sh             # 集群、Namespace、资源列表的获取与数据流 (jq 格式化)
│   ├── actions.sh               # 选中资源后的具体操作命令（Menu 及 Exec/Log 动作）
│   └── audit.sh                 # 审计日志辅助模块
├── Makefile                     # `make package` / `make st` 构建入口
├── build_standalone_installer.sh # 生成自包含 `standalone_install.sh`
├── install.sh                   # GitHub 在线一键安装脚本
├── kube-kit.tar.gz              # `make package` 生成的打包产物
└── standalone_install.sh        # `make st` 生成的离线安装脚本
```

## 📝 快捷键 (fzf 界面内)

- **`Ctrl-/`**: 切换右侧预览窗口的显示/隐藏。
- **`Ctrl-y`**: 快速复制当前高亮行内容到系统剪贴板。
- **`Enter`**: 确认选择，进入下一步。
- **`Esc`**: 返回上一层。
- **`Ctrl-c`**: 退出工具。
