import { createHash } from "node:crypto";
import { existsSync, readFileSync, watch, type FSWatcher } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Plugin } from "@opencode/plugin";

// Registers one Elasticsearch MCP server per cluster in ~/Projects/agents/elastic,
// in every project. A cluster gets a server when clusters.json gives it an es_url,
// it isn't marked "mcp": false, and .env holds its key. Edits to either file apply
// live: a new key starts its server, a rotated key restarts it.
const DIR = process.env.ELASTIC_AGENT_DIR ?? join(homedir(), "Projects/agents/elastic");
const REGISTRY = join(DIR, "clusters.json");
const ENV_FILE = join(DIR, ".env");

type Cluster = { es_url?: string; mcp?: boolean };
type Server = { type: "local"; command: string[]; environment: Record<string, string> };

// Same naming as lib.sh: lamas-or-stg -> LAMAS_OR_STG_API_KEY
const keyVar = (name: string) => `${name.toUpperCase().replace(/-/g, "_")}_API_KEY`;

function readEnv(): Record<string, string> {
  if (!existsSync(ENV_FILE)) return {};
  const env: Record<string, string> = {};
  for (const line of readFileSync(ENV_FILE, "utf8").split("\n")) {
    const m = /^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$/.exec(line);
    if (m) env[m[1]] = m[2].trim().replace(/^(['"])(.*)\1$/, "$2");
  }
  return env;
}

function loadServers(): [string, Server][] {
  if (!existsSync(REGISTRY)) return [];
  const clusters: Record<string, Cluster> = JSON.parse(readFileSync(REGISTRY, "utf8")).clusters ?? {};
  const env = readEnv();
  return Object.entries(clusters).flatMap(([name, cluster]): [string, Server][] => {
    const key = env[keyVar(name)];
    if (!cluster.es_url || cluster.mcp === false || !key) return [];
    return [[name, {
      type: "local",
      command: [join(DIR, "mcp-server.sh"), name],
      // mcp-server.sh reads the key itself; this hash only changes the config
      // when the key does, so OpenCode restarts the server after a rotation.
      environment: { ELASTIC_KEY_REV: createHash("sha256").update(key).digest("hex").slice(0, 12) },
    }]];
  });
}

export default Plugin.define({
  id: "personal.elastic-mcp",
  setup: async (ctx) => {
    const load = () => {
      try {
        return loadServers();
      } catch (error) {
        console.error(`elastic-mcp: cannot load ${DIR}:`, error);
        return [];
      }
    };
    let servers = load();
    await ctx.mcp.transform((editor) => {
      for (const [name, server] of servers) editor.set(name, server);
    });

    if (!existsSync(DIR)) return;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const watcher: FSWatcher = watch(DIR, (_event, file) => {
      if (file !== "clusters.json" && file !== ".env") return;
      clearTimeout(timer);
      timer = setTimeout(() => {
        servers = load();
        void ctx.mcp.reload().catch((error) => console.error("elastic-mcp: reload failed:", error));
      }, 500);
    });
    return () => {
      clearTimeout(timer);
      watcher.close();
    };
  },
});
