#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


def replace_one_of(path: Path, variants: list[str], new: str) -> bool:
    text = path.read_text()
    if new in text:
        return False

    for old in variants:
        if old in text:
            path.write_text(text.replace(old, new))
            return True

    raise RuntimeError(f"expected snippet not found in {path}")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: patch_cursor_honcho.py <plugin-root>", file=sys.stderr)
        return 2

    plugin_root = Path(sys.argv[1]).expanduser().resolve()
    if not plugin_root.exists():
        print(f"plugin root does not exist: {plugin_root}", file=sys.stderr)
        return 1

    changed = []

    config_ts = plugin_root / "src/config.ts"
    if replace_one_of(
        config_ts,
        [
            """export interface HonchoClientOptions {\n  apiKey: string;\n  baseUrl: string;\n  workspaceId: string;\n}\n""",
            """export interface HonchoClientOptions {\n apiKey: string;\n baseURL: string;\n workspaceId: string;\n}\n""",
        ],
        """export interface HonchoClientOptions {\n  apiKey: string;\n  baseURL: string;\n  workspaceId: string;\n}\n""",
    ):
        changed.append(config_ts)

    if replace_one_of(
        config_ts,
        [
            """export function getHonchoClientOptions(config: HonchoConfig): HonchoClientOptions {\n  return {\n    apiKey: config.apiKey,\n    baseUrl: getHonchoBaseUrl(config),\n    workspaceId: config.workspace,\n  };\n}\n""",
            """export function getHonchoClientOptions(config: HonchoConfig): HonchoClientOptions {\n return {\n apiKey: config.apiKey,\n baseURL: getHonchoBaseUrl(config),\n workspaceId: config.workspace,\n };\n}\n""",
        ],
        """export function getHonchoClientOptions(config: HonchoConfig): HonchoClientOptions {\n  return {\n    apiKey: config.apiKey,\n    baseURL: getHonchoBaseUrl(config),\n    workspaceId: config.workspace,\n  };\n}\n""",
    ):
        changed.append(config_ts)

    mcp_server_ts = plugin_root / "src/mcp/server.ts"
    if replace_one_of(
        mcp_server_ts,
        [
            """  const honcho = configured ? new Honcho(getHonchoClientOptions(config)) : null;\n""",
            """  const clientOpts = configured ? getHonchoClientOptions(config) : null;\n  const honcho = clientOpts ? new Honcho({ ...clientOpts, timeout: 120_000 }) : null;\n""",
        ],
        """  const clientOpts = configured ? getHonchoClientOptions(config) : null;\n  const timeoutMs = Number(process.env.HONCHO_TIMEOUT_MS || "300000");\n  const honcho = clientOpts ? new Honcho({ ...clientOpts, timeout: timeoutMs }) : null;\n""",
    ):
        changed.append(mcp_server_ts)

    # Add imports for progress notifications
    if replace_one_of(
        mcp_server_ts,
        [
            """import {\n  CallToolRequestSchema,\n  ListToolsRequestSchema,\n} from "@modelcontextprotocol/sdk/types.js";\n""",
        ],
        """import {\n  CallToolRequestSchema,\n  ListToolsRequestSchema,\n  ProgressNotification,\n} from "@modelcontextprotocol/sdk/types.js";\nimport type { RequestHandlerExtra } from "@modelcontextprotocol/sdk/shared/protocol.js";\n""",
    ):
        changed.append(mcp_server_ts)

    # Add extra param and progressToken extraction to handler
    if replace_one_of(
        mcp_server_ts,
        [
            """  server.setRequestHandler(CallToolRequestSchema, async (request) => {\n    const { name, arguments: args } = request.params;\n    const cwd = process.env.CURSOR_PROJECT_DIR || getLastActiveCwd() || process.cwd();\n""",
        ],
        """  server.setRequestHandler(CallToolRequestSchema, async (request, extra) => {\n    const { name, arguments: args } = request.params;\n    const progressToken = request.params._meta?.progressToken;\n    const cwd = process.env.CURSOR_PROJECT_DIR || getLastActiveCwd() || process.cwd();\n""",
    ):
        changed.append(mcp_server_ts)

    # Replace chat handler with progress notification version
    if replace_one_of(
        mcp_server_ts,
        [
            """        case "chat": {\n          const query = args?.query as string;\n          const userPeer = await honcho.peer(config.peerName);\n          const response = await userPeer.chat(query, {\n            session,\n            reasoningLevel: "medium",\n          });\n          return {\n            content: [{ type: "text", text: response ?? "No response from Honcho" }],\n          };\n        }\n""",
        ],
        """        case "chat": {\n          const query = args?.query as string;\n          const userPeer = await honcho.peer(config.peerName);\n\n          // Send progress notifications every 10s to keep connection alive.\n          // Ollama may need up to 120s on cold start to load the model.\n          let progressCount = 0;\n          const progressInterval = setInterval(async () => {\n            progressCount++;\n            if (progressToken) {\n              await extra.sendNotification({\n                method: "notifications/progress",\n                params: {\n                  progressToken,\n                  progress: progressCount,\n                  message: "Waiting for dialectic response (model may be loading)...",\n                },\n              } as ProgressNotification).catch(() => {});\n            }\n          }, 10_000);\n\n          try {\n            const response = await userPeer.chat(query, {\n              session,\n              reasoningLevel: "medium",\n            });\n            return {\n              content: [{ type: "text", text: response ?? "No response from Honcho" }],\n            };\n          } finally {\n            clearInterval(progressInterval);\n          }\n        }\n""",
    ):
        changed.append(mcp_server_ts)

    if replace_one_of(
        mcp_server_ts,
        [
            """            reasoningLevel: "medium",\n""",
        ],
        """            reasoningLevel: (args?.reasoningLevel as string) ?? "minimal",\n""",
    ):
        changed.append(mcp_server_ts)

    before_submit_ts = plugin_root / "src/hooks/before-submit-prompt.ts"
    if replace_one_of(
        before_submit_ts,
        [
            """          baseUrl: getHonchoBaseUrl(config),\n""",
        ],
        """          baseURL: getHonchoBaseUrl(config),\n""",
    ):
        changed.append(before_submit_ts)

    if replace_one_of(
        before_submit_ts,
        [
            """  const session = await honcho.session(sessionName);\n\n  const contextParts: string[] = [];\n""",
        ],
        """  const session = await honcho.session(sessionName);\n  const userPeer = await honcho.peer(config.peerName);\n\n  const contextParts: string[] = [];\n""",
    ):
        changed.append(before_submit_ts)

    if replace_one_of(
        before_submit_ts,
        [
            """  const contextResult = await session.context({\n    searchQuery,\n    representationOptions: {\n      searchTopK: 5,\n      searchMaxDistance: 0.7,\n      maxConclusions: 10,\n    },\n  });\n""",
        ],
        """  const contextResult = await userPeer.context({\n    searchQuery,\n    searchTopK: 5,\n    searchMaxDistance: 0.7,\n    maxConclusions: 10,\n  });\n""",
    ):
        changed.append(before_submit_ts)

    if replace_one_of(
        before_submit_ts,
        [
            """        const linkedSession = await linkedClient.session(sessionName);\n        return {\n          ws,\n          context: await linkedSession.context({\n            searchQuery,\n            representationOptions: { searchTopK: 3, searchMaxDistance: 0.7, maxConclusions: 5 },\n          }),\n        };\n""",
        ],
        """        const linkedPeer = await linkedClient.peer(config.peerName);\n        return {\n          ws,\n          context: await linkedPeer.context({\n            searchQuery,\n            searchTopK: 3,\n            searchMaxDistance: 0.7,\n            maxConclusions: 5,\n          }),\n        };\n""",
    ):
        changed.append(before_submit_ts)

    session_start_ts = plugin_root / "src/hooks/session-start.ts"
    if replace_one_of(
        session_start_ts,
        [
            """            baseUrl: getHonchoBaseUrl(config),\n""",
        ],
        """            baseURL: getHonchoBaseUrl(config),\n""",
    ):
        changed.append(session_start_ts)

    if replace_one_of(
        session_start_ts,
        [
            """          { session }\n        ),\n""",
        ],
        """          { session, reasoningLevel: "minimal" }\n        ),\n""",
    ):
        changed.append(session_start_ts)

    if replace_one_of(
        session_start_ts,
        [
            """          { session }\n        ),\n""",
        ],
        """          { session, reasoningLevel: "minimal" }\n        ),\n""",
    ):
        changed.append(session_start_ts)

    if changed:
        unique_paths = []
        seen = set()
        for path in changed:
            if path not in seen:
                unique_paths.append(path)
                seen.add(path)
        for path in unique_paths:
            print(f"PATCH {path.relative_to(plugin_root)}")
    else:
        print("OK    cursor-honcho already patched")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
