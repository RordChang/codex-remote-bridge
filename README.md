# Codex Remote Bridge

Local QQ Gateway bridge for Codex CLI.

The bridge connects to the official QQ Bot WebSocket Gateway from a Windows
machine, receives QQ messages, runs local `codex exec`, and sends the result
back through the official QQ Bot API.

No public callback URL or relay server is required.

## Architecture

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

In native mode, normal QQ messages run `codex exec`. If an active Codex session
exists, the bridge uses `codex exec resume <session-id>` so messages continue in
the same Codex conversation.

Local prompt-history mode still exists for compatibility:

```env
CODEX_CONTEXT_MODE=prompt
```

## Setup

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

To restrict who can use the bot, send `/whoami` to the bot first and put the
returned `user_openid` into:

```env
QQ_ALLOWED_USER_OPENIDS=openid1,openid2
```

Leave it empty only if all users who can message the bot are allowed.

## Start

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

## Commands

Messages starting with `/` are handled locally by the bridge and are not sent to
AI.

```text
/help                         Show available commands
/status                       Show gateway, context, model, reasoning, permission
/whoami                       Show current QQ Gateway openid
/model                        Show current model/reasoning
/model gpt-5.5 high           Set model and reasoning
/model gpt-5.4 xhigh          Set model and reasoning
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
/resume                       List native Codex sessions
/resume page 2                List page 2
/resume <id>                  Switch to a Codex session
/new [title]                  Start a new Codex session
/delete                       List sessions for deletion
/delete <id>                  Archive/delete a session
```

When QQ Markdown/Keyboard permissions are available, `/resume` and `/model` can
return button cards. Enable interaction events in `client/.env`:

```env
QQ_GATEWAY_INTENTS=100663296
QQ_ALLOWED_EVENTS=C2C_MESSAGE_CREATE,GROUP_AT_MESSAGE_CREATE,INTERACTION_CREATE
```

Button clicks are handled as local commands and are not sent to AI.

## Permission Mapping

```text
read only -> sandbox=read-only, approval=never
ask       -> sandbox=workspace-write, approval=on-request
approve   -> sandbox=workspace-write, approval=never
full      -> --dangerously-bypass-approvals-and-sandbox
```

## Security

Do not commit `client/.env`, QQ AppSecret, openids, logs, local session data, or
approval state files.

If a QQ AppSecret or token was exposed in screenshots, logs, or chat messages,
rotate it in the QQ Bot console and update `client/.env`.
