import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { readFileSync } from "fs";
import { join } from "path";
import { z } from "zod";

const BASE_URL = process.env.HONCHO_BASE_URL || "http://localhost:8100";
const API_KEY = process.env.HONCHO_API_KEY || "local";

let config = {};
try {
  const raw = readFileSync(
    join(process.env.HOME, ".honcho", "config.json"),
    "utf8"
  );
  config = JSON.parse(raw);
} catch {}

const WORKSPACE = process.env.HONCHO_WORKSPACE || config.hosts?.cursor?.workspace || "cursor";
const AI_PEER = process.env.HONCHO_AI_PEER || config.hosts?.cursor?.aiPeer || "cursor";
const HUMAN_PEER = process.env.HONCHO_HUMAN_PEER || config.peerName || "skyler";

const DEFAULT_TIMEOUT_MS = 30_000;
// Ollama unloads model from VRAM after OLLAMA_KEEP_ALIVE (30m on orphic-lens).
// Any inference-triggering call can hit a cold load (~80s) + generation (~60s).
const INFERENCE_TIMEOUT_MS = 300_000;

async function api(method, path, body, timeoutMs = DEFAULT_TIMEOUT_MS) {
  const opts = {
    method,
    headers: {
      Authorization: `Bearer ${API_KEY}`,
      "Content-Type": "application/json",
    },
    signal: AbortSignal.timeout(timeoutMs),
  };
  if (body !== undefined) opts.body = JSON.stringify(body);
  const res = await fetch(`${BASE_URL}${path}`, opts);
  const text = await res.text();
  if (!res.ok) throw new Error(`Honcho ${method} ${path} → ${res.status}: ${text}`);
  return text ? JSON.parse(text) : null;
}

async function ensureWorkspaceAndPeers() {
  await api("POST", "/v3/workspaces", { id: WORKSPACE });
  await api("POST", `/v3/workspaces/${WORKSPACE}/peers`, { id: AI_PEER });
  await api("POST", `/v3/workspaces/${WORKSPACE}/peers`, { id: HUMAN_PEER });
}

const server = new McpServer({
  name: "honcho",
  version: "1.0.0",
});

server.tool(
  "create_conclusion",
  "Save a conclusion/memory about the current conversation. The AI (observer) records what it learned about the human (observed).",
  { content: z.string().describe("The conclusion text to save") },
  async ({ content }) => {
    await ensureWorkspaceAndPeers();
    const result = await api("POST", `/v3/workspaces/${WORKSPACE}/conclusions`, {
      conclusions: [{ content, observer_id: AI_PEER, observed_id: HUMAN_PEER }],
    });
    return { content: [{ type: "text", text: JSON.stringify(result ?? { saved: true }, null, 2) }] };
  }
);

server.tool(
  "query_conclusions",
  "Semantic search across all saved conclusions/memories.",
  {
    query: z.string().describe("Natural language search query"),
    top_k: z.number().min(1).max(50).default(10).describe("Number of results").optional(),
  },
  async ({ query, top_k }) => {
    const result = await api("POST", `/v3/workspaces/${WORKSPACE}/conclusions/query`, {
      query,
      top_k: top_k ?? 10,
      filters: { observer_id: AI_PEER, observed_id: HUMAN_PEER },
    });
    return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
  }
);

server.tool(
  "list_conclusions",
  "List recent conclusions/memories with optional filters.",
  {
    page: z.number().min(1).default(1).optional(),
    size: z.number().min(1).max(100).default(20).optional(),
  },
  async ({ page, size }) => {
    const params = new URLSearchParams();
    if (page) params.set("page", page);
    if (size) params.set("size", size);
    const qs = params.toString();
    const result = await api(
      "POST",
      `/v3/workspaces/${WORKSPACE}/conclusions/list${qs ? `?${qs}` : ""}`,
      null
    );
    return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
  }
);

server.tool(
  "delete_conclusion",
  "Delete a specific conclusion by ID.",
  { conclusion_id: z.string().describe("The conclusion ID to delete") },
  async ({ conclusion_id }) => {
    await api("DELETE", `/v3/workspaces/${WORKSPACE}/conclusions/${conclusion_id}`);
    return { content: [{ type: "text", text: `Deleted conclusion ${conclusion_id}` }] };
  }
);

server.tool(
  "chat",
  "Have a dialectic chat with Honcho about a peer to get insights.",
  {
    query: z.string().describe("Question or prompt for the dialectic chat"),
    peer_id: z.string().default(HUMAN_PEER).describe("Peer to chat about").optional(),
  },
  async ({ query, peer_id }) => {
    const pid = peer_id || HUMAN_PEER;
    const result = await api("POST", `/v3/workspaces/${WORKSPACE}/peers/${pid}/chat`, {
      query,
    }, INFERENCE_TIMEOUT_MS);
    return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
  }
);

server.tool(
  "get_context",
  "Get the current context summary for a peer.",
  {
    peer_id: z.string().default(HUMAN_PEER).describe("Peer ID to get context for").optional(),
  },
  async ({ peer_id }) => {
    const pid = peer_id || HUMAN_PEER;
    const result = await api("GET", `/v3/workspaces/${WORKSPACE}/peers/${pid}/context`);
    return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
  }
);

server.tool(
  "get_representation",
  "Get the computed representation/profile of a peer.",
  {
    peer_id: z.string().default(HUMAN_PEER).describe("Peer ID").optional(),
  },
  async ({ peer_id }) => {
    const pid = peer_id || HUMAN_PEER;
    const result = await api("POST", `/v3/workspaces/${WORKSPACE}/peers/${pid}/representation`, {}, INFERENCE_TIMEOUT_MS);
    return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
  }
);

server.tool(
  "search_workspace",
  "Search across all workspace data (conclusions, messages, etc.).",
  { query: z.string().describe("Search query") },
  async ({ query }) => {
    const result = await api("POST", `/v3/workspaces/${WORKSPACE}/search`, { query });
    return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
  }
);

server.tool(
  "inspect_workspace",
  "Get workspace info including peer list and queue status.",
  {},
  async () => {
    const [peers, queue] = await Promise.all([
      api("POST", `/v3/workspaces/${WORKSPACE}/peers/list`, null),
      api("GET", `/v3/workspaces/${WORKSPACE}/queue/status`).catch(() => null),
    ]);
    return {
      content: [{
        type: "text",
        text: JSON.stringify({ workspace: WORKSPACE, peers, queue }, null, 2),
      }],
    };
  }
);

async function warmup() {
  try {
    await ensureWorkspaceAndPeers();
    await api(
      "POST",
      `/v3/workspaces/${WORKSPACE}/peers/${HUMAN_PEER}/representation`,
      {},
      INFERENCE_TIMEOUT_MS
    );
  } catch {}
}

warmup();

const transport = new StdioServerTransport();
await server.connect(transport);
