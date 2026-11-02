// Mirrors the ccstatusline layout configured in ../../../default.nix, so OpenCode's prompt
// footer reads like the Claude Code status line:
//   Model: Opus 5.5 | llm-wiki | ⎇ main | (+0,-0) | Context: [██░░…] 123k/1.0M (12%) | Cost: $0.06 | Session: Fix login bug
// Outside a git repo the root, branch, and changes segments collapse into the directory path,
// where ccstatusline would print "⎇ no git | (no git)".
// It replaces the footer's left-hand status slot, and stands in for the built-in right-hand
// footer (switched off with "-opencode.prompt.footer" in ~/.config/opencode/cli.json) minus
// its token and cost readout, which the left side already covers.
import { execFile } from "node:child_process";
import { basename } from "node:path";
import { Plugin, usePlugin } from "@opencode/plugin/tui";
import { createEffect, createMemo, createSignal, Match, onCleanup, Show, Switch } from "solid-js";

// ccstatusline renders at colorLevel 2 (256 colours); these are the resulting RGB values.
const COLOR = {
  model: "#008787", // cyan
  root: "#87d7ff", // ansi256:117
  branch: "#87ff87", // ansi256:120
  changes: "#ffffd7", // ansi256:230
  context: "#d7af00", // yellow
  cost: "#5faf00", // green
  session: "#008787", // cyan
  separator: "#949494", // gray
};
const GIT_POLL_MS = 5000; // ccstatusline's gitCacheTtlSeconds
const BAR_WIDTH = 16; // ccstatusline's "progress-short" bar
const SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

type Git = { root: string; branch: string; insertions: number; deletions: number } | null;
type Tokens = { input: number; output: number; reasoning: number; cache: { read: number; write: number } };

function git(cwd: string, args: string[]): Promise<string | undefined> {
  return new Promise((resolve) => {
    execFile("git", args, { cwd, timeout: 2000 }, (error, stdout) => resolve(error ? undefined : stdout.trim()));
  });
}

function shortStat(stat: string | undefined) {
  return {
    insertions: Number(/(\d+) insertions?/.exec(stat ?? "")?.[1] ?? 0),
    deletions: Number(/(\d+) deletions?/.exec(stat ?? "")?.[1] ?? 0),
  };
}

async function readGit(cwd: string): Promise<Git> {
  const root = await git(cwd, ["rev-parse", "--show-toplevel"]);
  if (!root) return null;
  const [branch, unstaged, staged] = await Promise.all([
    git(cwd, ["branch", "--show-current"]),
    git(cwd, ["diff", "--shortstat"]),
    git(cwd, ["diff", "--cached", "--shortstat"]),
  ]);
  const a = shortStat(unstaged);
  const b = shortStat(staged);
  return {
    root: basename(root),
    branch: branch || "HEAD",
    insertions: a.insertions + b.insertions,
    deletions: a.deletions + b.deletions,
  };
}

function formatTokens(count: number) {
  if (count >= 1e6 - 500) return `${(count / 1e6).toFixed(1)}M`;
  if (count >= 1000) return `${(count / 1000).toFixed(0)}k`;
  return String(count);
}

function total(tokens: Tokens) {
  return tokens.input + tokens.output + tokens.reasoning + tokens.cache.read + tokens.cache.write;
}

function StatusLine(props: { sessionID?: string }) {
  const context = usePlugin();

  const session = createMemo(() => (props.sessionID ? context.data.session.get(props.sessionID) : undefined));
  const location = createMemo(() => session()?.location ?? context.location ?? context.data.location.default(), undefined, {
    equals: (a, b) => a.directory === b.directory,
  });
  const models = createMemo(() => context.data.location.model.list(location()) ?? []);
  createEffect(() => {
    context.data.location.model.sync(location()).catch(() => {});
  });

  const model = createMemo(() => {
    const current = context.ui.model.current();
    if (!current) return undefined;
    return models().find(
      (m) => m.providerID === current.providerID && (m.id === current.modelID || m.modelID === current.modelID),
    );
  });
  const modelName = createMemo(() => {
    const name = model()?.name ?? context.ui.model.current()?.modelID;
    return name?.replace(/^Claude\s+/i, "").replace(/\s*\(.*\)$/, "");
  });

  // Same measurement as OpenCode's own context readout: the latest assistant step with usage
  // after the last completed compaction and before any revert boundary.
  const usage = createMemo(() => {
    const id = props.sessionID;
    if (!id) return undefined;
    const messages = context.data.session.message.list(id);
    const boundary = session()?.revert?.messageID;
    const boundaryIndex = boundary ? messages.findIndex((m) => m.id === boundary) : -1;
    const end = boundaryIndex === -1 ? messages.length : boundaryIndex;
    const compaction = messages.findLastIndex(
      (m, i) => m.type === "compaction" && (m as { status?: string }).status === "completed" && i < end,
    );
    const last = messages.findLast(
      (m, i) => m.type === "assistant" && m.tokens !== undefined && i > compaction && i < end,
    );
    if (!last || last.type !== "assistant" || !last.tokens) return undefined;
    const used = total(last.tokens);
    if (used <= 0) return undefined;
    const info = models().find(
      (m) => m.providerID === last.model.providerID && (m.id === last.model.id || m.modelID === last.model.id),
    );
    return { used, limit: info?.limit.context };
  });

  const contextText = createMemo(() => {
    const used = usage()?.used ?? 0;
    const limit = usage()?.limit ?? model()?.limit.context;
    if (!limit) return undefined;
    const percent = Math.max(0, Math.min(100, (used / limit) * 100));
    const filled = Math.round((percent / 100) * BAR_WIDTH);
    const bar = `[${"█".repeat(filled)}${"░".repeat(BAR_WIDTH - filled)}]`;
    return `Context: ${bar} ${formatTokens(used)}/${formatTokens(limit)} (${percent.toFixed(0)}%)`;
  });

  const [gitInfo, setGitInfo] = createSignal<Git | undefined>(undefined);
  const refreshGit = () => {
    const dir = location().directory;
    readGit(dir).then((info) => {
      if (location().directory === dir) setGitInfo(info);
    });
  };
  createEffect(refreshGit);
  const gitTimer = setInterval(refreshGit, GIT_POLL_MS);
  onCleanup(() => clearInterval(gitTimer));
  // Pick up the agent's edits as soon as a turn ends instead of waiting for the next poll.
  createEffect((previous?: string) => {
    const status = props.sessionID ? context.data.session.status(props.sessionID) : "idle";
    if (previous === "running" && status === "idle") refreshGit();
    return status;
  });

  const running = createMemo(() => (props.sessionID ? context.data.session.status(props.sessionID) === "running" : false));
  const [frame, setFrame] = createSignal(0);
  createEffect(() => {
    if (!running()) return;
    const timer = setInterval(() => setFrame((f) => (f + 1) % SPINNER.length), 80);
    onCleanup(() => clearInterval(timer));
  });

  const cost = createMemo(() => (props.sessionID ? context.data.session.cost(props.sessionID) : 0));

  const sep = () => <span style={{ fg: COLOR.separator }}> | </span>;

  return (
    <box flexGrow={1} flexShrink={1} minWidth={0} flexDirection="row">
      <text wrapMode="none" truncate={true} flexGrow={1} flexShrink={1} minWidth={0}>
        <Show when={running()}>
          <span style={{ fg: COLOR.separator }}>{`${SPINNER[frame()]} `}</span>
        </Show>
        <Show when={modelName()}>
          <span style={{ fg: COLOR.model }}>{`Model: ${modelName()}`}</span>
          {sep()}
        </Show>
        <Show
          when={gitInfo()}
          fallback={
            <Show when={gitInfo() === null}>
              <span style={{ fg: COLOR.root }}>{context.ui.format.path(location().directory)}</span>
            </Show>
          }
        >
          <span style={{ fg: COLOR.root }}>{gitInfo()!.root}</span>
          {sep()}
          <span style={{ fg: COLOR.branch }}>{`⎇ ${gitInfo()!.branch}`}</span>
          {sep()}
          <span style={{ fg: COLOR.changes }}>{`(+${gitInfo()!.insertions},-${gitInfo()!.deletions})`}</span>
        </Show>
        <Show when={contextText()}>
          {sep()}
          <span style={{ fg: COLOR.context }}>{contextText()}</span>
        </Show>
        <Show when={cost() > 0}>
          {sep()}
          <span style={{ fg: COLOR.cost }}>{`Cost: $${cost().toFixed(2)}`}</span>
        </Show>
        <Show when={session()?.title}>
          {sep()}
          <span style={{ fg: COLOR.session }}>{`Session: ${session()!.title}`}</span>
        </Show>
      </text>
    </box>
  );
}

function plural(count: number, noun: string) {
  return count ? `${count} ${noun}${count === 1 ? "" : "s"}` : undefined;
}

// The built-in right-hand footer without its usage readout: background subagent and shell
// counts (click to browse them), then the agent and command palette shortcut hints.
function FooterRight(props: { sessionID?: string; mode: "normal" | "shell"; showDetails: boolean }) {
  const context = usePlugin();
  const theme = context.theme;
  const shortcut = (id: string) => context.keymap.shortcuts(id)[0];

  const background = createMemo(() => {
    const id = props.sessionID;
    if (!id) return undefined;
    const subagents = context.data.session
      .family(id)
      .filter((child) => child !== id && context.data.session.status(child) === "running").length;
    const shells = context.data.shell.list(context.location).filter((s) => s.metadata.sessionID === id).length;
    const parts = [plural(subagents, "subagent"), plural(shells, "shell")].filter(Boolean);
    return parts.length ? parts.join(" · ") : undefined;
  });
  const [hovered, setHovered] = createSignal(false);

  const hint = (id: string, label: string) => (
    <Show when={shortcut(id)}>
      <text wrapMode="none" flexShrink={0} fg={theme.text.base}>
        {shortcut(id)} <span style={{ fg: theme.text.muted }}>{label}</span>
      </text>
    </Show>
  );

  return (
    <Switch>
      <Match when={props.mode === "shell"}>
        <text wrapMode="none" flexShrink={0} fg={theme.text.base}>
          esc <span style={{ fg: theme.text.muted }}>exit shell mode</span>
        </text>
      </Match>
      <Match when={props.mode === "normal"}>
        <box flexDirection="row" flexShrink={0} gap={2}>
          <Show when={background()} fallback={props.showDetails ? hint("agent.cycle", "agents") : undefined}>
            <box
              flexShrink={0}
              onMouseOver={() => setHovered(true)}
              onMouseOut={() => setHovered(false)}
              onMouseUp={() => context.keymap.dispatch("session.child.first")}
            >
              <text wrapMode="none" fg={hovered() ? theme.text.base : theme.text.muted}>
                <Show when={shortcut("session.child.first")}>
                  <span style={{ fg: theme.text.base }}>{`${shortcut("session.child.first")} `}</span>
                </Show>
                {background()}
              </text>
            </box>
          </Show>
          <Show when={props.showDetails}>{hint("command.palette.show", "commands")}</Show>
        </box>
      </Match>
    </Switch>
  );
}

export default Plugin.define({
  id: "personal.claude-statusline",
  setup(context) {
    const claims = [
      context.ui.slot({
        replace: "prompt.footer.status",
        render: (input) => <StatusLine sessionID={input.sessionID} />,
      }),
      context.ui.slot({
        append: "prompt.footer",
        render: (input) => (
          <FooterRight sessionID={input.sessionID} mode={input.mode} showDetails={input.showDetails} />
        ),
      }),
    ];
    return () => claims.forEach((release) => release());
  },
});
