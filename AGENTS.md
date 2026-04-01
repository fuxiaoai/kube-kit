# 给 Coding Agent 的开发指南 (AGENTS.md)

本指南旨在帮助所有的 Coding Agent（如 Trae 等）快速理解本项目的技术栈、修改规范、功能流转机制，从而能在不破坏原有基础体验的前提下高效、安全地扩展功能。

---

## 💻 技术栈

- **语言**: 纯 Bash (`5.0+`)
- **交互引擎**: [fzf](https://github.com/junegunn/fzf) (核心列表搜索与预览驱动)
- **JSON 解析**: [jq](https://stedolan.github.io/jq/) (必须工具，用于格式化 `kubectl get -o json` 的输出并渲染终端 ANSI 颜色)
- **编排平台**: Kubernetes (`kubectl`)
- **环境要求**: Linux / macOS 终端，需支持 TTY，依赖 `pbcopy` / `xclip` 等系统剪贴板工具实现快速复制

---

## 📂 代码结构约定

本项目通过在 `kk` 入口脚本中引入 `lib/` 目录下的多个模块进行分离管理。

| 模块文件 | 核心职责 | Agent 修改场景 |
|---|---|---|
| `kk` | CLI 入口，解析入参 (`-c`, `-n`, `-r`, keyword)，控制三级跳转逻辑 | 增加全局 Flag，调整主流程加载顺序 |
| `lib/core.sh` | 日志输出 (`kn_log_*`)、全局颜色定义 (`$GREEN`, `$RED` 等)、依赖检查与**危险操作二次确认** (`kn_confirm_dangerous`) | 新增全局状态提示、修改依赖检查逻辑 |
| `lib/k8s_api.sh` | 封装了所有 `kubectl` 命令执行 (`kn_kubectl`)。包含针对 `get <resource> -o json` 的**短时文件缓存** (`/tmp/kk_cache`) 机制 | 扩展新的 K8s 资源类型查询（如 StatefulSet、DaemonSet），或修改缓存失效时间 (TTL) |
| `lib/fzf_helpers.sh` | 封装 `fzf` 启动参数 (`kn_fzf_select`) 和按资源类型展示的右侧**预览函数** (`kn_fzf_preview_*`) | 增加新的资源类型预览逻辑、修改顶部教学式 `kubectl` 命令提示、调整预览窗格的快捷键 |
| `lib/navigator.sh` | 控制“选集群”、“选Namespace”、“选资源”的交互式跳转逻辑。通过 `jq` 重度处理 JSON 转换为制表符 (`\t`) 分隔的列表供 `fzf` 使用 | 增加资源列表展示的列信息（如 Age 算法修改、状态标红规则补充） |
| `lib/actions.sh` | 所有选中具体资源后的动作操作（Menu 和真正的命令执行）。| **这是最常被修改的文件**：增加对 Pod 的操作（如 Delete）、扩展对其他资源的新操作入口等 |
| `lib/history.sh` | 通过 `jq` 在 `~/.kk/history.json` 中保存和恢复最后的上下文信息 | 增加新的持久化状态（如用户收藏、最近查询的 N 个记录） |
| `lib/audit.sh` | 记录每一次危险/核心操作的日志（目前尚未全量接入各个 Action） | 在新增高危操作时主动调用该模块 |

---

## 🛠 修改与扩展规范

### 1. 新增一种对已有资源的操作 (例如为 Deployment 新增 Scale 功能)

**步骤一：在 `lib/actions.sh` 添加业务逻辑函数**
```bash
kn_deploy_scale() {
    local deploy="$1"
    echo -ne "Enter new replicas count: "
    read -r replicas
    if [[ -n "$replicas" && "$replicas" =~ ^[0-9]+$ ]]; then
        # 如果是改变状态的操作，建议加上 kn_confirm_dangerous
        if kn_confirm_dangerous "Scale Deployment" "Scale $deploy to $replicas replicas"; then
            kn_kubectl scale deploy "$deploy" --replicas="$replicas"
        fi
    fi
}
```

**步骤二：在 `lib/actions.sh` 的 `kn_action_menu` 中添加菜单入口**
```bash
        elif [[ "$res_type" == "deploy" ]]; then
            # 新增 [S] Scale Deploy 提示
            echo -e "  ${BOLD}[D]${RESET} View Deploy  ${BOLD}[i]${RESET} Change Image    ${BOLD}[E]${RESET} Edit Deploy    ${BOLD}[S]${RESET} Scale Deploy"
```

**步骤三：在 `lib/actions.sh` 的 `case` 判断中加入按键绑定**
```bash
            E) if [[ "$res_type" == "deploy" ]]; then kn_deploy_edit "$res_name"; fi ;;
            S) if [[ "$res_type" == "deploy" ]]; then kn_deploy_scale "$res_name"; fi ;; # 新增
```

### 2. 在导航栏 (Navigator) 改变或增加某列展示数据

由于 `lib/navigator.sh` 中的 `kn_select_resource` 函数使用 `jq` 将 JSON 处理为 `tsv` (制表符分隔) 供列对齐 (`column -t`) 和 `fzf` 解析，所以修改展示数据必须严格遵循 `jq` 语法，并用 `ANSI` 颜色码对数据进行格式化。

> **⚠️ 注意**：如果因为数据为空或类型不匹配导致 `jq` 解析报错，整个过滤后的资源数据都会丢失。因此必须做好**空值或异常值检查**（例如 `(.status.containerStatuses != null)`、`// "Pending"` 等兜底逻辑）。

```jq
# 示例：修改 Age 的生成逻辑，或修改错误状态的颜色标红 (参考现有代码)
(
    if $age_seconds < 60 then "\($age_seconds|floor)s"
    # ...
) as $age |
```

### 3. 修改 fzf 预览窗格

如果在导航中需要给新资源增加预览，或者修改现有资源（如 Pod）右侧的内容：

编辑 `lib/fzf_helpers.sh` 中的 `kn_fzf_preview_xxx` 函数。
*所有 `kn_fzf_preview_*` 函数都被 `export -f` 导出，因为 `fzf` 的 `--preview` 参数是在一个全新的子 `bash` 进程中执行的。*

**要求**：
- 第一行请使用灰色 (`\033[90m`) 打印对应的原生 `kubectl` 命令（便于用户学习和复制）。
- 控制输出长度，由于 `fzf` 预览区大小有限，建议使用 `head -n` 截断过长的输出（如 `get cm -o yaml | head -n 30`）。

### 4. 环境与依赖注意点

- 所有脚本开头需要包含 `#!/usr/bin/env bash`。
- 函数命名使用统一的前缀 `kn_` (代表 KubeNav / kube-kit)。
- 变量引用必须包裹在双引号 `"${var}"` 中以防止单词拆分和路径解析错误。
- 由于是基于 TTY 交互（`read -r -n 1`，`fzf` 等），Agent 无法在自动化沙盒或普通的非交互式 Shell 中直接拉起并运行全套流程，需部署后通过人类用户的 SSH 终端验证。
