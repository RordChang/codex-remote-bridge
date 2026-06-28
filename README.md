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

### Windows 一键部署（推荐）

项目根目录的 `start.ps1` 会按顺序检查 Python、`websocket-client`、Codex CLI、Node.js/npm 和本地配置。缺少组件时，脚本会先询问用户，确认后再自动安装。

首次建议先运行仅检查模式：

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1 -CheckOnly
```

确认配置无误后前台启动：

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

后台启动：

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1 -Background
```

后台模式默认启动隐藏的后台守护进程，不显示 Windows 托盘图标。

如果需要在 Windows 右下角查看运行状态，可以构建并启动轻量托盘 EXE：

```powershell
powershell -ExecutionPolicy Bypass -File .\client\build-tray-exe.ps1
.\CodexRemoteBridgeTray.exe
```

右键托盘图标可以：

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

托盘程序只做低频状态轮询和菜单控制，不包含重型 GUI 框架。它是独立入口，不会改变默认后台启动和 `start.ps1` 的自启动流程。托盘里的“开机自启动”会把 EXE 注册为登录自启动，适合想在右下角直接看到运行状态的场景。

如果只想用 PowerShell 版托盘脚本，也可以运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\client\start-bridge-tray.ps1
```

脚本会提示输入 `QQ_APP_ID` 和 `QQ_APP_SECRET`，申请入口是：

```text
https://q.qq.com/#/
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

### 手动安装

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

如果使用一键脚本，建议直接在项目根目录运行 `start.ps1`。下面是底层手动启动方式。

前台启动：

```powershell
cd client
.\start-bridge.ps1
```

后台 supervisor 启动：

```powershell
cd client
python .\qq_gateway_background.py
```

日志位置：

```text
client/data/qq-gateway-autostart.log
```

`client/data/` 和 `client/.env` 已被 Git 忽略。

### 指令

以 `/` 开头的消息由桥接器本地处理，不会发送给 AI。

```text
/help                         显示所有指令
/status                       显示 Gateway、上下文、模型、思考强度、权限
/whoami                       显示当前 QQ Gateway openid
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
/revise [id] <instruction>    修改待审批请求
/cancel                       取消当前 Codex 任务或待审批请求
/cancel <task_id>             取消指定 Codex 任务
/tasks                        查看运行中和排队中的 Codex 任务
/restart                      重启 QQ Gateway 客户端
/resume                       列出 Codex 原生会话
/resume page 2                列出第 2 页
/resume <id>                  切换到指定 Codex 会话
/new [title]                  新建 Codex 会话
/delete                       列出可删除会话
/delete <id>                  归档/删除指定会话
```

如果 QQ Markdown/Keyboard 权限可用，`/resume` 和 `/model` 可以返回按钮卡片。需要在 `client/.env` 中启用 interaction 事件：

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

### Windows One-Click Setup (Recommended)

The root `start.ps1` script checks Python, `websocket-client`, Codex CLI, Node.js/npm, and local configuration in order. If a component is missing, it asks before installing it automatically.

Run check-only mode first:

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1 -CheckOnly
```

Start in foreground:

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

Start in background:

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1 -Background
```

Background mode starts the hidden background supervisor by default and does not show a Windows tray icon.

If you want to see runtime status in the Windows notification area, build and start the lightweight tray EXE:

```powershell
powershell -ExecutionPolicy Bypass -File .\client\build-tray-exe.ps1
.\CodexRemoteBridgeTray.exe
```

Right-click the tray icon to:

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

The tray helper only performs low-frequency process checks and menu actions. It does not use a heavy GUI framework. It is an independent entry point and does not change the default background or `start.ps1` autostart flow. The startup-at-login menu registers the EXE itself at Windows logon, which is useful when you want the notification-area status indicator after reboot.

The PowerShell tray script is also available as a fallback:

```powershell
powershell -ExecutionPolicy Bypass -File .\client\start-bridge-tray.ps1
```

The script asks for `QQ_APP_ID` and `QQ_APP_SECRET`. Apply for them here:

```text
https://q.qq.com/#/
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

### Manual Setup

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

If you use the one-click script, run `start.ps1` from the project root. The commands below are the lower-level manual startup options.

Foreground:

```powershell
cd client
.\start-bridge.ps1
```

Background supervisor:

```powershell
cd client
python .\qq_gateway_background.py
```

Logs are written to:

```text
client/data/qq-gateway-autostart.log
```

`client/data/` and `client/.env` are ignored by Git.

### Commands

Messages starting with `/` are handled locally by the bridge and are not sent to AI.

```text
/help                         Show available commands
/status                       Show gateway, context, model, reasoning, permission
/whoami                       Show current QQ Gateway openid
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
/revise [id] <instruction>    Revise a pending request
/cancel                       Cancel current Codex task or pending request
/cancel <task_id>             Cancel a specific Codex task
/tasks                        Show running and queued Codex tasks
/restart                      Restart the QQ Gateway client
/resume                       List native Codex sessions
/resume page 2                List page 2
/resume <id>                  Switch to a Codex session
/new [title]                  Start a new Codex session
/delete                       List sessions for deletion
/delete <id>                  Archive/delete a session
```

When QQ Markdown/Keyboard permissions are available, `/resume` and `/model` can return button cards. Enable interaction events in `client/.env`:

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
