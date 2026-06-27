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

### 安装

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
/timeout                      显示 Codex 单次调用超时
/timeout 45                   设置单次调用超时为 45 分钟
/permission                   显示当前权限
/permission read only         只读模式
/permission ask               Ask for approval
/permission approve           工作区可写，不人工审批
/permission full              完全访问
/pending                      显示待审批请求
/allow [id]                   批准待审批请求
/reject [id]                  拒绝待审批请求
/revise [id] <instruction>    修改待审批请求
/cancel                       取消当前 Codex 任务或待审批请求
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

长任务默认 30 分钟超时，可用 `/timeout 45` 在线调整。

### 权限映射

```text
read only -> sandbox=read-only, approval=never
ask       -> sandbox=workspace-write, approval=on-request
approve   -> sandbox=workspace-write, approval=never
full      -> --dangerously-bypass-approvals-and-sandbox
```

### 安全

不要提交 `client/.env`、QQ AppSecret、openid、日志、本地会话数据或审批状态文件。

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

### Setup

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
/timeout                      Show Codex task timeout
/timeout 45                   Set Codex task timeout to 45 minutes
/permission                   Show current permission mode
/permission read only         Read-only mode
/permission ask               Ask for approval
/permission approve           Workspace write without manual approval
/permission full              Full access
/pending                      Show pending approval requests
/allow [id]                   Approve a pending request
/reject [id]                  Reject a pending request
/revise [id] <instruction>    Revise a pending request
/cancel                       Cancel current Codex task or pending request
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

Long Codex tasks default to a 30-minute timeout. Use `/timeout 45` to adjust it at runtime.

### Permission Mapping

```text
read only -> sandbox=read-only, approval=never
ask       -> sandbox=workspace-write, approval=on-request
approve   -> sandbox=workspace-write, approval=never
full      -> --dangerously-bypass-approvals-and-sandbox
```

### Security

Do not commit `client/.env`, QQ AppSecret, openids, logs, local session data, or approval state files.

If a QQ AppSecret or token was exposed in screenshots, logs, or chat messages, rotate it in the QQ Bot console and update `client/.env`.
