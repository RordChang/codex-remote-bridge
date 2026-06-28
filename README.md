# Codex Remote Bridge

QQ Gateway 本地桥接器，用于把 QQ 机器人消息转发给本机 Codex CLI。

Local QQ Gateway bridge for Codex CLI.

---

## 中文说明

### 简介

这个项目会在 Windows 本机连接 QQ 官方 Bot WebSocket Gateway，收到 QQ 消息后调用本机 `codex exec`，再通过 QQ 官方 Bot API 把结果回复回去。

它不需要公网回调地址，也不需要远程 relay 服务器。

### 架构

```text
QQ Bot Gateway
-> client/qq_gateway_client.py
-> codex exec / codex exec resume
-> QQ Bot send-message API
```

默认使用 Codex 原生会话续接模式：

```env
CODEX_CONTEXT_MODE=native
```

在 `native` 模式下，普通 QQ 消息会触发一次 `codex exec`。如果已经存在 active Codex session，桥接器会使用 `codex exec resume <session-id>`，让消息接着同一个 Codex 对话继续。

兼容用的本地 prompt-history 模式仍然保留：

```env
CODEX_CONTEXT_MODE=prompt
```

### Windows 快速开始（推荐）

普通用户建议直接下载发布包，不需要先 clone 仓库，也不需要自己编译。

1. 打开本仓库的 [Releases](https://github.com/G-Photon/codex-remote-bridge/releases) 页面。
2. 下载最新的 Windows 发布包，例如 `codex-remote-bridge-*.zip`。
3. 解压到一个固定目录，例如 `D:\Tools\CodexRemoteBridge`。
4. 双击运行解压目录里的 `CodexRemoteBridgeTray.exe`。
5. 按托盘菜单提示完成安装、检查和配置。

首次运行时，托盘程序会自动调用项目里的 `start.ps1` 完成环境检查和配置。缺少 Python、`websocket-client`、Codex CLI、Node.js/npm 等组件时，脚本会先询问用户，确认后再自动安装。

右键 Windows 右下角托盘图标可以：

```text
启动桥接
停止桥接
重启桥接
安装/检查/配置
前台启动窗口
开启开机自启动
关闭开机自启动
打开日志
打开配置
打开项目目录
刷新状态
停止桥接并退出
```

配置时需要填写 QQ Bot 的 `QQ_APP_ID` 和 `QQ_APP_SECRET`，申请入口：

```text
https://q.qq.com/#/
```

如果要限制谁能使用机器人，启动后先给机器人发送：

```text
/whoami
```

然后把返回的 `user_openid` 写入配置里的 `QQ_ALLOWED_USER_OPENIDS`。

### 源码构建（开发者）

如果你想从源码构建托盘 EXE，可以 clone 仓库后运行：

```powershell
git clone https://github.com/G-Photon/codex-remote-bridge.git
cd codex-remote-bridge
powershell -ExecutionPolicy Bypass -File .\client\build-tray-exe.ps1
```

构建完成后会在项目根目录生成：

```text
CodexRemoteBridgeTray.exe
```

然后双击运行这个 EXE 即可。构建脚本使用 Windows 自带的 PowerShell/.NET 编译能力，不需要额外安装 Visual Studio。

开发或排障时，也可以直接运行底层启动脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

仅检查环境和配置：

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1 -CheckOnly
```

后台启动但不显示托盘：

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1 -Background
```

如果不想编译 EXE，也可以使用 PowerShell 版托盘脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\client\start-bridge-tray.ps1
```

自动安装依赖前，脚本会检查环境变量、Windows 代理、git/npm 代理和 WinHTTP 代理。如果检测到代理，会询问是否用于下载安装；如果没有检测到，也可以手动输入代理地址。

安装过程中会显示当前安装阶段和进度提示。`pip` 和 `npm` 会尽量显示自身下载进度，`winget` 安装会显示脚本侧进度，避免用户无法判断是否仍在执行。

脚本输出以中文为主。常见安装路径：

```text
Python 3             -> winget
websocket-client     -> pip install --user
Node.js LTS          -> winget
@openai/codex        -> npm install -g
```

### 手动安装（高级）

安装 Python 依赖：

```powershell
pip install websocket-client
```

创建本地配置：

```powershell
cd client
Copy-Item .env.example .env
```

编辑 `client/.env`：

```env
QQ_APP_ID=replace-with-qq-app-id
QQ_APP_SECRET=replace-with-qq-app-secret
CODEX_COMMAND=codex
CODEX_WORKDIR=C:\path\to\your\workspace
CODEX_CONTEXT_MODE=native
CODEX_MODEL=gpt-5.5
CODEX_REASONING_EFFORT=xhigh
CODEX_PERMISSION=read-only
```

如果要限制谁能使用机器人，先给机器人发送：

```text
/whoami
```

然后把返回的 `user_openid` 写入：

```env
QQ_ALLOWED_USER_OPENIDS=openid1,openid2
```

只有明确希望所有能私聊机器人的用户都可用时，才留空。

### 启动

发布包用户直接运行 `CodexRemoteBridgeTray.exe`。下面是开发和排障时可用的底层启动方式。

托盘 EXE：

```powershell
.\CodexRemoteBridgeTray.exe
```

前台启动：

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

日志位置：

```text
client/data/qq-gateway-autostart.log
```

`client/data/` 和 `client/.env` 已被 Git 忽略。

### 指令

以 `/` 开头的消息由桥接器本地处理，不会发送给 AI。

```text
/start                       显示入口面板、当前模型和快捷按钮
/help                         显示所有指令
/status                       显示 Gateway、上下文、模型、思考强度、权限
/whoami                       显示当前 QQ Gateway openid，用于配置 allowlist
/model                        显示当前模型和思考强度
/model gpt-5.5 high           设置模型和思考强度
/model gpt-5.4 xhigh          设置模型和思考强度
/setup                        显示设置面板
/output                       显示输出设置
/output stage on/off          开关阶段性输出
/output userContext on/off    开关最终输出是否带用户输入
/timeout                      显示 Codex 单次调用超时
/timeout 45                   设置单次调用超时为 45 分钟
/heartbeat                    显示任务提醒频率
/heartbeat 5                  设置任务提醒频率为 5 分钟
/heartbeat off                关闭任务提醒
/truncate on/off              开关长内容截断
/recent-default               显示最近对话默认条数
/recent-default 10            设置 /recent 默认展示 10 条
/permission                   显示当前权限
/permission read only         只读模式
/permission ask               请求批准，普通任务先发待批准请求
/permission auto              替我审批，使用 Codex 自动审批审查
/permission full              完全权限，绕过沙箱和审批
/permission approve           兼容旧命令，等同 /permission auto
/approval-test                生成一条测试审批请求，不执行真实任务
/pending                      显示待审批请求
/allow [id]                   批准待审批请求
/reject [id]                  拒绝待审批请求
/revise <id> <修改意见>       修改要求并重新生成审批计划
/cancel                       取消当前 Codex 任务或待审批请求
/cancel <task_id>             取消指定 Codex 任务
/tasks                        查看运行中和排队中的 Codex 任务
/restart                      重启 QQ Gateway 客户端
/resume                       按目录展示 Codex 原生会话
/resume page 2                展示目录第 2 页
/resume dir <目录>            展示指定目录下的会话
/resume <id>                  切换到指定 Codex 原生会话
/recent                       查看当前会话最近 5 条对话
/recent N S                   从最近第 S 条开始查看 N 条对话（N=1-20，S 可省略）
/recent N S <id>              查看指定会话对应范围的对话
/last user [N S]              查看我发出的最近 N 句，可分页
/last codex [N S]             查看 Codex 的最近 N 句回复，可分页
/new [title]                  新建 Codex 会话
/delete                       列出可删除会话
/delete <id>                  归档/删除指定会话
```

如果 QQ Markdown/Keyboard 权限可用，`/start`、`/setup`、`/resume`、`/model`、`/tasks`、`/permission` 等指令可以返回按钮卡片。需要在 `client/.env` 中启用 interaction 事件：

```env
QQ_GATEWAY_INTENTS=100663296
QQ_ALLOWED_EVENTS=C2C_MESSAGE_CREATE,GROUP_AT_MESSAGE_CREATE,INTERACTION_CREATE
```

按钮点击会作为本地指令处理，不会发送给 AI。

### 图片和附件

QQ 消息里带图片或附件时，桥接器会把可下载的 `http/https` 附件保存到 `client/data/attachments/`，再把本地绝对路径交给 Codex。纯图片消息也会进入队列。

Codex 回复中如果包含单独一行 `SEND_IMAGE: C:\path\to\image.png`，桥接器会把这张本地图片上传并发送回 QQ。Markdown 图片路径 `![alt](C:\path\to\image.png)` 也会被识别。

相关配置：

```env
QQ_ATTACHMENT_DOWNLOAD=1
QQ_ATTACHMENT_MAX_COUNT=4
QQ_ATTACHMENT_MAX_BYTES=26214400
QQ_SEND_LOCAL_IMAGES=1
QQ_SEND_IMAGE_MAX_COUNT=4
QQ_SEND_IMAGE_MAX_BYTES=10485760
```

长任务默认 30 分钟超时，可用 `/timeout 45` 在线调整。常用时长也可以在 `/setup` 的“超时设置”里点击按钮选择。

### 任务队列和半全量输出

普通 Codex 消息会进入本地任务队列并立即返回 `task_id`，并提供“查看任务队列”和“取消当前任务”按钮。同一个 Codex 会话按顺序执行，不同会话最多并发执行 `QQ_CODEX_MAX_PARALLEL` 个任务。运行中任务默认每 5 分钟发送状态心跳，可用 `/heartbeat` 调整。阶段性输出默认关闭，可用 `/output stage on/off` 临时开关；最终输出默认会先显示任务 id 和用户输入，可用 `/output userContext on/off` 控制。长内容默认按分片上限截断，可用 `/truncate off` 改为尽量分段发送完整内容。

```env
QQ_JOB_QUEUE_SIZE=20
QQ_CODEX_MAX_PARALLEL=5
QQ_TASK_STATUS_INTERVAL_SECONDS=300
QQ_TASK_PARTIAL_INTERVAL_SECONDS=60
QQ_TASK_PARTIAL_MAX_CHARS=1200
QQ_SEND_PARTIAL_OUTPUTS=0
QQ_SHOW_TASK_CONTEXT_ON_FINAL=1
QQ_TRUNCATE_LONG_REPLIES=1
```

### 权限映射

```text
read only -> sandbox=read-only, approval=never，不写入文件
ask       -> 请求批准：先生成远程待批准请求；批准后用 workspace-write + on-request 执行
auto      -> 替我审批：workspace-write + on-request + approvals_reviewer=auto_review
full      -> --dangerously-bypass-approvals-and-sandbox，风险最高
approve   -> 兼容旧命令，等同 auto
```

说明：`ask` 目前包含本项目自己的任务级远程审批；`auto` 对齐 Codex UI 的“替我审批”语义，让 Codex 对检测到的风险操作使用自动审批审查。当前 QQ 侧不会完整接管 Codex 原生命令级审批弹窗。

### 安全

不要提交 `client/.env`、QQ AppSecret、openid、日志、本地会话数据、审批状态文件、本地 Codex 状态目录或临时资料目录。

如果 QQ AppSecret 或 token 曾经在截图、日志或聊天中暴露，建议在 QQ Bot 后台重新生成，并更新本地 `client/.env`。

---

## English

### Overview

This project connects to the official QQ Bot WebSocket Gateway from a Windows machine, receives QQ messages, runs local `codex exec`, and sends the result back through the official QQ Bot API.

It does not require a public callback URL or a remote relay server.

### Architecture

```text
QQ Bot Gateway
-> client/qq_gateway_client.py
-> codex exec / codex exec resume
-> QQ Bot send-message API
```

The default context mode is native Codex session resume:

```env
CODEX_CONTEXT_MODE=native
```

In `native` mode, normal QQ messages run `codex exec`. If an active Codex session exists, the bridge uses `codex exec resume <session-id>` so messages continue in the same Codex conversation.

Local prompt-history mode is still available for compatibility:

```env
CODEX_CONTEXT_MODE=prompt
```

### Windows Quick Start (Recommended)

Most users should use the release package instead of cloning and building the repository.

1. Open the repository [Releases](https://github.com/G-Photon/codex-remote-bridge/releases) page.
2. Download the latest Windows package, for example `codex-remote-bridge-*.zip`.
3. Extract it to a stable directory, for example `D:\Tools\CodexRemoteBridge`.
4. Double-click `CodexRemoteBridgeTray.exe` in the extracted directory.
5. Follow the tray menu prompts to install, check, and configure the bridge.

On first run, the tray helper calls the bundled `start.ps1` script for environment checks and configuration. If Python, `websocket-client`, Codex CLI, Node.js/npm, or other required components are missing, the script asks before installing them automatically.

Right-click the Windows tray icon to:

```text
Start bridge
Stop bridge
Restart bridge
Install/check/configure
Foreground startup window
Enable startup at login
Disable startup at login
Open log
Open config
Open project folder
Refresh status
Stop bridge and exit
```

Configuration requires your QQ Bot `QQ_APP_ID` and `QQ_APP_SECRET`. Apply for them here:

```text
https://q.qq.com/#/
```

To restrict who can use the bot, start it and send this message to the bot:

```text
/whoami
```

Then put the returned `user_openid` into `QQ_ALLOWED_USER_OPENIDS`.

### Build From Source (Developers)

If you want to build the tray EXE from source, clone the repository and run:

```powershell
git clone https://github.com/G-Photon/codex-remote-bridge.git
cd codex-remote-bridge
powershell -ExecutionPolicy Bypass -File .\client\build-tray-exe.ps1
```

The output is written to the project root:

```text
CodexRemoteBridgeTray.exe
```

Run that EXE to start the tray helper. The build script uses the PowerShell/.NET compiler available on Windows and does not require Visual Studio.

For development and troubleshooting, you can also run the underlying startup script directly:

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

Check-only mode:

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1 -CheckOnly
```

Background mode without a tray icon:

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1 -Background
```

If you do not want to build the EXE, a PowerShell tray script is available as a fallback:

```powershell
powershell -ExecutionPolicy Bypass -File .\client\start-bridge-tray.ps1
```

Before installing dependencies, the script checks environment variables, Windows proxy settings, git/npm proxy settings, and WinHTTP proxy settings. If a proxy is found, it asks whether to use it for downloads. If no proxy is detected, you can still enter one manually.

During installation, the script displays the current step and progress status. `pip` and `npm` use their own download progress when possible; `winget` uses script-side progress messages so users can see that installation is still running.

Common automatic install paths:

```text
Python 3             -> winget
websocket-client     -> pip install --user
Node.js LTS          -> winget
@openai/codex        -> npm install -g
```

### Manual Setup (Advanced)

Install Python dependencies:

```powershell
pip install websocket-client
```

Create local config:

```powershell
cd client
Copy-Item .env.example .env
```

Edit `client/.env`:

```env
QQ_APP_ID=replace-with-qq-app-id
QQ_APP_SECRET=replace-with-qq-app-secret
CODEX_COMMAND=codex
CODEX_WORKDIR=C:\path\to\your\workspace
CODEX_CONTEXT_MODE=native
CODEX_MODEL=gpt-5.5
CODEX_REASONING_EFFORT=xhigh
CODEX_PERMISSION=read-only
```

To restrict who can use the bot, send this message to the bot first:

```text
/whoami
```

Then put the returned `user_openid` into:

```env
QQ_ALLOWED_USER_OPENIDS=openid1,openid2
```

Leave it empty only if all users who can message the bot are allowed.

### Start

Release users should run `CodexRemoteBridgeTray.exe`. The commands below are lower-level options for development and troubleshooting.

Tray EXE:

```powershell
.\CodexRemoteBridgeTray.exe
```

Foreground:

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

Logs are written to:

```text
client/data/qq-gateway-autostart.log
```

`client/data/` and `client/.env` are ignored by Git.

### Commands

Messages starting with `/` are handled locally by the bridge and are not sent to AI.

```text
/start                       Show the entry panel, current model, and shortcut buttons
/help                         Show available commands
/status                       Show gateway, context, model, reasoning, permission
/whoami                       Show current QQ Gateway openid for allowlist setup
/model                        Show current model/reasoning
/model gpt-5.5 high           Set model and reasoning
/model gpt-5.4 xhigh          Set model and reasoning
/setup                        Show settings panel
/output                       Show output settings
/output stage on/off          Toggle partial output
/output userContext on/off    Toggle user prompt context in final output
/timeout                      Show Codex task timeout
/timeout 45                   Set Codex task timeout to 45 minutes
/heartbeat                    Show task heartbeat frequency
/heartbeat 5                  Set task heartbeat frequency to 5 minutes
/heartbeat off                Disable task heartbeat messages
/truncate on/off              Toggle long-reply truncation
/recent-default               Show default recent-message count
/recent-default 10            Set /recent default count to 10
/permission                   Show current permission mode
/permission read only         Read-only mode
/permission ask               Request approval before normal tasks
/permission auto              Let Codex auto-review risky approval requests
/permission full              Full access; bypass sandbox and approvals
/permission approve           Legacy alias for /permission auto
/approval-test                Create a test pending approval without running a real task
/pending                      Show pending approval requests
/allow [id]                   Approve a pending request
/reject [id]                  Reject a pending request
/revise <id> <instruction>    Revise a pending request and regenerate the approval plan
/cancel                       Cancel current Codex task or pending request
/cancel <task_id>             Cancel a specific Codex task
/tasks                        Show running and queued Codex tasks
/restart                      Restart the QQ Gateway client
/resume                       List native Codex sessions by directory
/resume page 2                Show directory page 2
/resume dir <dir>             Show sessions under a directory
/resume <id>                  Switch to a native Codex session
/recent                       Show the latest 5 messages in the current session
/recent N S                   Show N messages starting at the S-th latest message (N=1-20, S optional)
/recent N S <id>              Show that message window for a specific session
/last user [N S]              Show recent user messages with paging
/last codex [N S]             Show recent Codex replies with paging
/new [title]                  Start a new Codex session
/delete                       List sessions for deletion
/delete <id>                  Archive/delete a session
```

When QQ Markdown/Keyboard permissions are available, commands such as `/start`, `/setup`, `/resume`, `/model`, `/tasks`, and `/permission` can return button cards. Enable interaction events in `client/.env`:

```env
QQ_GATEWAY_INTENTS=100663296
QQ_ALLOWED_EVENTS=C2C_MESSAGE_CREATE,GROUP_AT_MESSAGE_CREATE,INTERACTION_CREATE
```

Button clicks are handled as local commands and are not sent to AI.

### Images and Attachments

When a QQ message contains images or files, the bridge downloads available `http/https` attachments into `client/data/attachments/` and passes the local absolute paths to Codex. Image-only messages are accepted.

If a Codex reply contains a standalone `SEND_IMAGE: C:\path\to\image.png` line, the bridge uploads that local image and sends it back to QQ. Markdown image paths such as `![alt](C:\path\to\image.png)` are recognized too.

Related settings:

```env
QQ_ATTACHMENT_DOWNLOAD=1
QQ_ATTACHMENT_MAX_COUNT=4
QQ_ATTACHMENT_MAX_BYTES=26214400
QQ_SEND_LOCAL_IMAGES=1
QQ_SEND_IMAGE_MAX_COUNT=4
QQ_SEND_IMAGE_MAX_BYTES=10485760
```

Long Codex tasks default to a 30-minute timeout. Use `/timeout 45` to adjust it at runtime. Common values are also available from `/setup` -> timeout settings.

### Task Queue and Semi-Streaming

Normal Codex messages are enqueued and immediately return a `task_id` with task-list and cancel buttons. Tasks for the same Codex session run sequentially, while different sessions may run concurrently up to `QQ_CODEX_MAX_PARALLEL`. Running tasks send heartbeat status messages every 5 minutes by default and can be adjusted with `/heartbeat`. Partial output is off by default and can be toggled with `/output stage on/off`. Final output includes the task id and user prompt by default and can be toggled with `/output userContext on/off`. Long replies are truncated at the reply chunk limit by default; use `/truncate off` to send as many chunks as possible.

```env
QQ_JOB_QUEUE_SIZE=20
QQ_CODEX_MAX_PARALLEL=5
QQ_TASK_STATUS_INTERVAL_SECONDS=300
QQ_TASK_PARTIAL_INTERVAL_SECONDS=60
QQ_TASK_PARTIAL_MAX_CHARS=1200
QQ_SEND_PARTIAL_OUTPUTS=0
QQ_SHOW_TASK_CONTEXT_ON_FINAL=1
QQ_TRUNCATE_LONG_REPLIES=1
```

### Permission Mapping

```text
read only -> sandbox=read-only, approval=never; no file writes
ask       -> request approval: create a remote pending approval first; approved tasks run with workspace-write + on-request
auto      -> auto-review approvals: workspace-write + on-request + approvals_reviewer=auto_review
full      -> --dangerously-bypass-approvals-and-sandbox; highest risk
approve   -> legacy alias for auto
```

Note: `ask` includes this project's task-level remote approval layer. `auto` matches the Codex UI "auto review approvals" intent by enabling Codex automatic approval review for detected risky operations. The QQ side does not currently take over every native Codex command-level approval prompt.

### Security

Do not commit `client/.env`, QQ AppSecret, openids, logs, local session data, approval state files, local Codex state directories, or temporary research/data folders.

If a QQ AppSecret or token was exposed in screenshots, logs, or chat messages, rotate it in the QQ Bot console and update `client/.env`.
