import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { readFileSync } from "fs";
import { join } from "path";
import { z } from "zod";

const API_KEY = process.env.HONCHO_API_KEY || "local";

let config = {};
try {
  const raw = readFileSync(
    join(process.env.HOME, ".honcho", "config.json"),
    "utf8"
  );
  config = JSON.parse(raw);
} catch {}

// Env override > config.json endpoint (updated dynamically by .bashrc) > default
const BASE_URL = process.env.HONCHO_BASE_URL || config?.endpoint?.baseUrl || "http://localhost:8100";

const WORKSPACE = process.env.HONCHO_WORKSPACE || config.hosts?.cursor?.workspace || "cursor";
const AI_PEER = process.env.HONCHO_AI_PEER || config.hosts?.cursor?.aiPeer || "cursor";
const HUMAN_PEER = process.env.HONCHO_HUMAN_PEER || config.peerName || "skyler";

const CONNECT_TIMEOUT_MS = 5_000;
const DEFAULT_TIMEOUT_MS = 30_000;
const INFERENCE_TIMEOUT_MS = 300_000;
const TOOL_RACE_MS = Number(process.env.HONCHO_TOOL_RACE_MS || "30000");
const INFERENCE_RACE_MS = Number(process.env.HONCHO_INFERENCE_RACE_MS || "120000");

// ── Backend connectivity tracking ──
// Probes the backend periodically so tool calls can fail fast when
// the host is down instead of blocking for the full HTTP timeout.
let alive = null; // null = unknown, true = up, false = down
let probeP = null;
let lastProbeAt = 0;

function probe() {
  if (probeP) return probeP;
  lastProbeAt = Date.now();
  probeP = fetch(`${BASE_URL}/`, { signal: AbortSignal.timeout(CONNECT_TIMEOUT_MS) })
    .then(() => { alive = true; return true; })
    .catch(() => { alive = false; return false; })
    .finally(() => { probeP = null; });
  return probeP;
}

setInterval(probe, 60_000);
probe();

function raceNull(promise, ms) {
  return Promise.race([promise, new Promise(r => setTimeout(() => r(null), ms))]);
}

async function api(method, path, body, timeoutMs = DEFAULT_TIMEOUT_MS) {
  if (alive === false) {
    const up = await raceNull(probe(), CONNECT_TIMEOUT_MS);
    if (!up) throw new Error(`Honcho backend unreachable (${BASE_URL}). Is the host machine on?`);
  }
  const opts = {
    method,
    headers: {
      Authorization: `Bearer ${API_KEY}`,
      "Content-Type": "application/json",
    },
    signal: AbortSignal.timeout(timeoutMs),
  };
  if (body !== undefined) opts.body = JSON.stringify(body);
  try {
    const res = await fetch(`${BASE_URL}${path}`, opts);
    alive = true;
    const text = await res.text();
    if (!res.ok) throw new Error(`Honcho ${method} ${path} → ${res.status}: ${text}`);
    return text ? JSON.parse(text) : null;
  } catch (err) {
    if (
      err.name === "TimeoutError" ||
      err.cause?.code === "ECONNREFUSED" ||
      err.cause?.code === "EHOSTUNREACH" ||
      err.cause?.code === "ENETUNREACH"
    ) {
      alive = false;
    }
    throw err;
  }
}

let workspaceReady = false;
async function ensureWorkspaceAndPeers() {
  if (workspaceReady) return;
  await api("POST", "/v3/workspaces", { id: WORKSPACE });
  await api("POST", `/v3/workspaces/${WORKSPACE}/peers`, { id: AI_PEER });
  await api("POST", `/v3/workspaces/${WORKSPACE}/peers`, { id: HUMAN_PEER });
  workspaceReady = true;
}

// Wraps a tool handler so it races against a timeout and never blocks
// the agent indefinitely. If the backend is slow (cold model) or down,
// the agent gets a message back fast and can keep working.
function resilient(fn, raceMs, label) {
  return async (args) => {
    if (alive === false && Date.now() - lastProbeAt < 30_000) {
      probe();
      return {
        content: [{ type: "text", text: `${label}: backend unreachable (${BASE_URL}). Is the host on?` }],
        isError: true,
      };
    }
    try {
      const resultP = fn(args);
      const result = await raceNull(resultP, raceMs);
      if (result === null) {
        resultP.catch(() => {});
        return {
          content: [{
            type: "text",
            text: `${label}: timed out after ${raceMs / 1000}s (backend may be warming up). Retry shortly.`,
          }],
        };
      }
      return result;
    } catch (err) {
      return {
        content: [{ type: "text", text: `${label} error: ${err.message}` }],
        isError: true,
      };
    }
  };
}

const server = new McpServer({
  name: "honcho",
  version: "1.0.0",
});

server.tool(
  "create_conclusion",
  "Save a conclusion/memory about the current conversation. The AI (observer) records what it learned about the human (observed).",
  { content: z.string().describe("The conclusion text to save") },
  resilient(async ({ content }) => {
    await ensureWorkspaceAndPeers();
    const result = await api("POST", `/v3/workspaces/${WORKSPACE}/conclusions`, {
      conclusions: [{ content, observer_id: AI_PEER, observed_id: HUMAN_PEER }],
    });
    return { content: [{ type: "text", text: JSON.stringify(result ?? { saved: true }, null, 2) }] };
  }, TOOL_RACE_MS, "create_conclusion")
);

server.tool(
  "query_conclusions",
  "Semantic search across all saved conclusions/memories.",
  {
    query: z.string().describe("Natural language search query"),
    top_k: z.number().min(1).max(50).default(10).describe("Number of results").optional(),
  },
  resilient(async ({ query, top_k }) => {
    const result = await api("POST", `/v3/workspaces/${WORKSPACE}/conclusions/query`, {
      query,
      top_k: top_k ?? 10,
      filters: { observer_id: AI_PEER, observed_id: HUMAN_PEER },
    });
    return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
  }, TOOL_RACE_MS, "query_conclusions")
);

server.tool(
  "list_conclusions",
  "List recent conclusions/memories with optional filters.",
  {
    page: z.number().min(1).default(1).optional(),
    size: z.number().min(1).max(100).default(20).optional(),
  },
  resilient(async ({ page, size }) => {
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
  }, TOOL_RACE_MS, "list_conclusions")
);

server.tool(
  "delete_conclusion",
  "Delete a specific conclusion by ID.",
  { conclusion_id: z.string().describe("The conclusion ID to delete") },
  resilient(async ({ conclusion_id }) => {
    await api("DELETE", `/v3/workspaces/${WORKSPACE}/conclusions/${conclusion_id}`);
    return { content: [{ type: "text", text: `Deleted conclusion ${conclusion_id}` }] };
  }, TOOL_RACE_MS, "delete_conclusion")
);

server.tool(
  "chat",
  "Have a dialectic chat with Honcho about a peer to get insights.",
  {
    query: z.string().describe("Question or prompt for the dialectic chat"),
    peer_id: z.string().default(HUMAN_PEER).describe("Peer to chat about").optional(),
  },
  resilient(async ({ query, peer_id }) => {
    const pid = peer_id || HUMAN_PEER;
    const result = await api("POST", `/v3/workspaces/${WORKSPACE}/peers/${pid}/chat`, {
      query,
    }, INFERENCE_TIMEOUT_MS);
    return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
  }, INFERENCE_RACE_MS, "chat")
);

server.tool(
  "get_context",
  "Get the current context summary for a peer.",
  {
    peer_id: z.string().default(HUMAN_PEER).describe("Peer ID to get context for").optional(),
  },
  resilient(async ({ peer_id }) => {
    const pid = peer_id || HUMAN_PEER;
    const result = await api("GET", `/v3/workspaces/${WORKSPACE}/peers/${pid}/context`);
    return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
  }, TOOL_RACE_MS, "get_context")
);

server.tool(
  "get_representation",
  "Get the computed representation/profile of a peer.",
  {
    peer_id: z.string().default(HUMAN_PEER).describe("Peer ID").optional(),
  },
  resilient(async ({ peer_id }) => {
    const pid = peer_id || HUMAN_PEER;
    const result = await api("POST", `/v3/workspaces/${WORKSPACE}/peers/${pid}/representation`, {}, INFERENCE_TIMEOUT_MS);
    return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
  }, INFERENCE_RACE_MS, "get_representation")
);

server.tool(
  "search_workspace",
  "Search across all workspace data (conclusions, messages, etc.).",
  { query: z.string().describe("Search query") },
  resilient(async ({ query }) => {
    const result = await api("POST", `/v3/workspaces/${WORKSPACE}/search`, { query });
    return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
  }, TOOL_RACE_MS, "search_workspace")
);

server.tool(
  "inspect_workspace",
  "Get workspace info including peer list and queue status.",
  {},
  resilient(async () => {
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
  }, TOOL_RACE_MS, "inspect_workspace")
);

// Non-blocking warmup — populates the workspace/peers and warms
// the Ollama model. Failures are silent; the resilient() wrapper
// on each tool handles them gracefully at call time.
(async () => {
  try {
    await ensureWorkspaceAndPeers();
    await api(
      "POST",
      `/v3/workspaces/${WORKSPACE}/peers/${HUMAN_PEER}/representation`,
      {},
      INFERENCE_TIMEOUT_MS
    );
  } catch {}
})();

const transport = new StdioServerTransport();
await server.connect(transport);
