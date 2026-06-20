# Installing the ClickUp MCP

The `execute-clickup` skill needs the ClickUp MCP connected so it can read tasks. Walk the user through whichever path fits their setup. After they confirm it's connected, restart the skill from Step 1.

## Path A — Managed connector (Claude Desktop / Claude.ai / Cowork)

If the user is on Claude Desktop, claude.ai, or a managed/Cowork environment, ClickUp is usually added as a **Connector**, not via a config file:

1. Open **Settings → Connectors** (or **Settings → Integrations**).
2. Find **ClickUp** in the directory and click **Connect / Add**.
3. Complete the ClickUp OAuth flow and authorize the workspace that holds the task.
4. Return to the conversation. The `clickup_*` tools should now be available.

This is the most likely path here — managed ClickUp connectors expose tools with an instance-specific server prefix (a UUID), not a name set in a local config file.

## Path B — Claude Code CLI (remote MCP)

If the user runs Claude Code in a terminal and prefers the CLI, ClickUp offers an official remote MCP server (OAuth-authenticated):

```bash
claude mcp add --transport http clickup https://mcp.clickup.com/mcp
```

Then run `/mcp` (or restart the session) and complete the OAuth authentication when prompted.

> The exact endpoint can change. If the command above fails, point the user to ClickUp's official MCP documentation (search "ClickUp MCP server") for the current remote URL, then re-run `claude mcp add` with it.

## Path C — Local/community MCP server (advanced)

Some teams self-host a community ClickUp MCP server that authenticates with a personal API token. Only suggest this if the user explicitly wants it:

1. Generate a ClickUp API token: **ClickUp → Settings → Apps → API Token**.
2. Add the server to their MCP config (the specific package/command depends on which community server they choose), passing the token via env, e.g.:

```bash
claude mcp add clickup --env CLICKUP_API_TOKEN=pk_xxx -- npx -y @<community-clickup-mcp-package>
```

3. Restart the session and verify with `/mcp`.

## Verifying it worked

Ask the user to confirm, or check yourself: the ClickUp tools (names containing `clickup_get_task`) should now be callable. Match on the `clickup_` portion of the tool name — the server prefix varies by install. Once confirmed, resume the skill at Step 1.
