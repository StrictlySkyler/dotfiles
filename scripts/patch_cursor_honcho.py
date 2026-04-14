#!/usr/bin/env python3
"""
Apply local patches to cursor-honcho after git clone/pull.

Patches:
  config.ts        - baseUrl → baseURL typo fix
  cache.ts         - Dialectic result caching helpers
  server.ts        - Timeout from env, progress notifications,
                     45s race/cache chat handler, warmup ping
  before-submit-prompt.ts - baseURL fix, peer.context API
  session-start.ts - baseURL fix, reasoningLevel param
"""
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

    # ── config.ts: baseUrl → baseURL ────────────────────────────────
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

    # ── cache.ts: dialectic result caching ──────────────────────────
    cache_ts = plugin_root / "src/cache.ts"

    if replace_one_of(
        cache_ts,
        [
            "interface ContextCache {\n  userContext?: { data: any; fetchedAt: number };\n  aiContext?: { data: any; fetchedAt: number };\n  summaries?: { data: any; fetchedAt: number };\n  messageCount?: number; // Track messages since last refresh\n  lastRefreshMessageCount?: number; // Message count at last knowledge graph refresh\n}\n",
        ],
        "interface DialecticEntry {\n  query: string;\n  response: string;\n  fetchedAt: number;\n}\n\ninterface ContextCache {\n  userContext?: { data: any; fetchedAt: number };\n  aiContext?: { data: any; fetchedAt: number };\n  summaries?: { data: any; fetchedAt: number };\n  dialectic?: DialecticEntry[];\n  messageCount?: number;\n  lastRefreshMessageCount?: number;\n}\n",
    ):
        changed.append(cache_ts)

    DIALECTIC_BLOCK = (
        "const MAX_DIALECTIC_ENTRIES = 10;\n\n"
        "export function getCachedDialectic(): DialecticEntry[] {\n"
        "  const cache = loadContextCache();\n"
        "  return cache.dialectic ?? [];\n"
        "}\n\n"
        "export function getLatestDialectic(): DialecticEntry | null {\n"
        "  const entries = getCachedDialectic();\n"
        "  if (entries.length === 0) return null;\n"
        "  const ttl = getContextTTL();\n"
        "  const latest = entries[entries.length - 1];\n"
        "  if (Date.now() - latest.fetchedAt < ttl) return latest;\n"
        "  return null;\n"
        "}\n\n"
        "export function getStaleDialectic(): DialecticEntry | null {\n"
        "  const entries = getCachedDialectic();\n"
        "  return entries.length > 0 ? entries[entries.length - 1] : null;\n"
        "}\n\n"
        "export function pushDialecticResult(query: string, response: string): void {\n"
        "  const cache = loadContextCache();\n"
        "  const entries = cache.dialectic ?? [];\n"
        "  entries.push({ query, response, fetchedAt: Date.now() });\n"
        "  if (entries.length > MAX_DIALECTIC_ENTRIES) entries.splice(0, entries.length - MAX_DIALECTIC_ENTRIES);\n"
        "  cache.dialectic = entries;\n"
        "  saveContextCache(cache);\n"
        "}\n\n"
    )
    if replace_one_of(
        cache_ts,
        [
            "  saveContextCache(cache);\n}\n\nexport function isContextCacheStale(): boolean {\n",
        ],
        "  saveContextCache(cache);\n}\n\n" + DIALECTIC_BLOCK + "export function isContextCacheStale(): boolean {\n",
    ):
        changed.append(cache_ts)

    # ── server.ts ───────────────────────────────────────────────────
    mcp_server_ts = plugin_root / "src/mcp/server.ts"

    # Imports: ProgressNotification + RequestHandlerExtra
    if replace_one_of(
        mcp_server_ts,
        [
            """import {\n  CallToolRequestSchema,\n  ListToolsRequestSchema,\n} from "@modelcontextprotocol/sdk/types.js";\n""",
        ],
        """import {\n  CallToolRequestSchema,\n  ListToolsRequestSchema,\n  ProgressNotification,\n} from "@modelcontextprotocol/sdk/types.js";\nimport type { RequestHandlerExtra } from "@modelcontextprotocol/sdk/shared/protocol.js";\n""",
    ):
        changed.append(mcp_server_ts)

    # Imports: cache helpers (getStaleDialectic, pushDialecticResult)
    if replace_one_of(
        mcp_server_ts,
        [
            """  clearAIContextOnly,\n} from "../cache.js";\n""",
        ],
        """  clearAIContextOnly,\n  getStaleDialectic,\n  pushDialecticResult,\n} from "../cache.js";\n""",
    ):
        changed.append(mcp_server_ts)

    # Honcho client: timeout from env var
    if replace_one_of(
        mcp_server_ts,
        [
            """  const honcho = configured ? new Honcho(getHonchoClientOptions(config)) : null;\n""",
            """  const clientOpts = configured ? getHonchoClientOptions(config) : null;\n  const honcho = clientOpts ? new Honcho({ ...clientOpts, timeout: 120_000 }) : null;\n""",
        ],
        """  const clientOpts = configured ? getHonchoClientOptions(config) : null;\n  const timeoutMs = Number(process.env.HONCHO_TIMEOUT_MS || "300000");\n  const honcho = clientOpts ? new Honcho({ ...clientOpts, timeout: timeoutMs }) : null;\n""",
    ):
        changed.append(mcp_server_ts)

    # Handler signature: (request) → (request, extra) + progressToken
    if replace_one_of(
        mcp_server_ts,
        [
            """  server.setRequestHandler(CallToolRequestSchema, async (request) => {\n    const { name, arguments: args } = request.params;\n    const cwd = process.env.CURSOR_PROJECT_DIR || getLastActiveCwd() || process.cwd();\n""",
        ],
        """  server.setRequestHandler(CallToolRequestSchema, async (request, extra) => {\n    const { name, arguments: args } = request.params;\n    const progressToken = request.params._meta?.progressToken;\n    const cwd = process.env.CURSOR_PROJECT_DIR || getLastActiveCwd() || process.cwd();\n""",
    ):
        changed.append(mcp_server_ts)

    # Chat handler: replace simple version with 45s race + cache fallback
    UPSTREAM_CHAT = """        case "chat": {\n          const query = args?.query as string;\n          const userPeer = await honcho.peer(config.peerName);\n          const response = await userPeer.chat(query, {\n            session,\n            reasoningLevel: "medium",\n          });\n          return {\n            content: [{ type: "text", text: response ?? "No response from Honcho" }],\n          };\n        }\n"""

    # Also handle the intermediate patched version (progress only, no race)
    PROGRESS_ONLY_CHAT = """        case "chat": {\n          const query = args?.query as string;\n          const userPeer = await honcho.peer(config.peerName);\n\n          // Send progress notifications every 10s to keep connection alive.\n          // Ollama may need up to 120s on cold start to load the model.\n          let progressCount = 0;\n          const progressInterval = setInterval(async () => {\n            progressCount++;\n            if (progressToken) {\n              await extra.sendNotification({\n                method: "notifications/progress",\n                params: {\n                  progressToken,\n                  progress: progressCount,\n                  message: "Waiting for dialectic response (model may be loading)...",\n                },\n              } as ProgressNotification).catch(() => {});\n            }\n          }, 10_000);\n\n          try {\n            const response = await userPeer.chat(query, {\n              session,\n              reasoningLevel: (args?.reasoningLevel as string) ?? "minimal",\n            });\n            return {\n              content: [{ type: "text", text: response ?? "No response from Honcho" }],\n            };\n          } finally {\n            clearInterval(progressInterval);\n          }\n        }\n"""

    RACE_CACHE_CHAT = (
        '        case "chat": {\n'
        "          const query = args?.query as string;\n"
        "          const userPeer = await honcho.peer(config.peerName);\n"
        "          const RACE_TIMEOUT_MS = 45_000;\n"
        "\n"
        "          let progressCount = 0;\n"
        "          const progressInterval = setInterval(async () => {\n"
        "            progressCount++;\n"
        "            if (progressToken) {\n"
        "              await extra.sendNotification({\n"
        '                method: "notifications/progress",\n'
        "                params: {\n"
        "                  progressToken,\n"
        "                  progress: progressCount,\n"
        '                  message: "Waiting for dialectic response (model may be loading)...",\n'
        "                },\n"
        "              } as ProgressNotification).catch(() => {});\n"
        "            }\n"
        "          }, 10_000);\n"
        "\n"
        "          try {\n"
        "            const liveCall = userPeer.chat(query, {\n"
        "              session,\n"
        '              reasoningLevel: (args?.reasoningLevel as string) ?? "minimal",\n'
        "            });\n"
        "\n"
        "            const timer = new Promise<null>(resolve =>\n"
        "              setTimeout(() => resolve(null), RACE_TIMEOUT_MS)\n"
        "            );\n"
        "\n"
        "            const response = await Promise.race([liveCall, timer]);\n"
        "\n"
        "            if (response !== null) {\n"
        "              pushDialecticResult(query, response);\n"
        "              return {\n"
        "                content: [{ type: \"text\", text: response }],\n"
        "              };\n"
        "            }\n"
        "\n"
        "            // Live call didn't finish in time — return cached result.\n"
        "            // The live call continues in the background and caches when done.\n"
        "            liveCall.then(r => { if (r) pushDialecticResult(query, r); }).catch(() => {});\n"
        "\n"
        "            const cached = getStaleDialectic();\n"
        "            if (cached) {\n"
        "              return {\n"
        "                content: [{\n"
        '                  type: "text",\n'
        "                  text: `${cached.response}\\n\\n---\\n_Cached from ${new Date(cached.fetchedAt).toISOString()} (live query still processing in background). Original query: \"${cached.query}\"_`,\n"
        "                }],\n"
        "              };\n"
        "            }\n"
        "\n"
        "            return {\n"
        "              content: [{\n"
        '                type: "text",\n'
        '                text: "Dialectic response is still loading (Ollama model warming up). The result will be cached for subsequent calls. Please retry in ~30 seconds.",\n'
        "              }],\n"
        "            };\n"
        "          } finally {\n"
        "            clearInterval(progressInterval);\n"
        "          }\n"
        "        }\n"
    )

    if replace_one_of(
        mcp_server_ts,
        [UPSTREAM_CHAT, PROGRESS_ONLY_CHAT],
        RACE_CACHE_CHAT,
    ):
        changed.append(mcp_server_ts)

    # Warmup ping after server.connect()
    WARMUP_BLOCK = (
        "\n"
        "  // Pre-warm Ollama model on startup so the first real chat call is faster.\n"
        "  // Cursor CLI has a ~60s hard MCP timeout; dialectic on the local 4B model\n"
        "  // takes 50-70s. The chat handler races live calls against 45s and falls\n"
        "  // back to cached results, but a warm model helps hit the 45s window.\n"
        "  if (honcho && config) {\n"
        "    (async () => {\n"
        "      try {\n"
        "        const cwd = process.env.CURSOR_PROJECT_DIR || getLastActiveCwd() || process.cwd();\n"
        "        const session = await honcho.session(getSessionName(cwd));\n"
        "        const userPeer = await honcho.peer(config.peerName);\n"
        '        const response = await userPeer.chat("ping", { session, reasoningLevel: "minimal" });\n'
        '        if (response) pushDialecticResult("warmup", response);\n'
        "      } catch {\n"
        "        // Non-critical\n"
        "      }\n"
        "    })();\n"
        "  }\n"
    )

    if patch_after(
        mcp_server_ts,
        "  await server.connect(transport);\n",
        WARMUP_BLOCK,
    ):
        changed.append(mcp_server_ts)

    # ── before-submit-prompt.ts ─────────────────────────────────────
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

    # ── session-start.ts ────────────────────────────────────────────
    session_start_ts = plugin_root / "src/hooks/session-start.ts"
    if replace_one_of(
        session_start_ts,
        [
            """            baseUrl: getHonchoBaseUrl(config),\n""",
        ],
        """            baseURL: getHonchoBaseUrl(config),\n""",
    ):
        changed.append(session_start_ts)

    # Import pushDialecticResult in session-start
    if replace_one_of(
        session_start_ts,
        [
            """  detectGitChanges,\n} from "../cache.js";\n""",
        ],
        """  detectGitChanges,\n  pushDialecticResult,\n} from "../cache.js";\n""",
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

    # Cache dialectic results from session-start context fetches
    if replace_one_of(
        session_start_ts,
        [
            """      contextParts.push(`## AI Summary of ${config.peerName}\\n${userChatContent}`);\n    }\n""",
        ],
        """      contextParts.push(`## AI Summary of ${config.peerName}\\n${userChatContent}`);\n      pushDialecticResult(`Summarize what you know about ${config.peerName}`, userChatContent);\n    }\n""",
    ):
        changed.append(session_start_ts)

    if replace_one_of(
        session_start_ts,
        [
            """      contextParts.push(`## AI Self-Reflection (What ${config.aiPeer} Has Been Doing)\\n${cursorChatContent}`);\n    }\n""",
        ],
        """      contextParts.push(`## AI Self-Reflection (What ${config.aiPeer} Has Been Doing)\\n${cursorChatContent}`);\n      pushDialecticResult(`What has ${config.aiPeer} been working on recently?`, cursorChatContent);\n    }\n""",
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
