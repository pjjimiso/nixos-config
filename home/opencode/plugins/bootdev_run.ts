import { spawn } from "node:child_process";
import { Plugin } from "@opencode/plugin";

export default Plugin.define({
  id: "personal.bootdev-run",
  setup: async (ctx) => {
    await ctx.tool.transform((tools) => {
      tools.add({
        name: "bootdev_run",
        description:
          "Run bootdev run <hash> or bootdev run -s <hash> from the project root with a pseudo-terminal. Records to /dev/null instead of a typescript file. Returns JSON with stdout, stderr, and exitcode.",
        input: {
          type: "object",
          properties: {
            command: {
              type: "string",
              description: "A command in the form bootdev run <hash> or bootdev run -s <hash>",
            },
          },
          required: ["command"],
          additionalProperties: false,
        },
        options: { codemode: false },
        execute: async (input, context) => {
          const { command } = input as { command: string };
          const match = /^bootdev[ \t]+run[ \t]+(?:(-s)[ \t]+)?([a-fA-F0-9]+(?:-[a-fA-F0-9]+)*)$/.exec(
            command.trim(),
          );
          if (!match) {
            throw new Error("Expected bootdev run <hash> or bootdev run -s <hash>");
          }

          const result = await new Promise<{
            stdout: string;
            stderr: string;
            exitcode: number | null;
          }>((resolveResult, reject) => {
            const child = spawn(
              "script",
              ["-q", "-e", "-c", `bootdev run ${match[1] ? "-s " : ""}${match[2]}`, "/dev/null"],
              {
                cwd: ctx.location.project.directory,
                signal: context.signal,
                stdio: ["ignore", "pipe", "pipe"],
              },
            );
            let stdout = "";
            let stderr = "";
            child.stdout.setEncoding("utf8");
            child.stderr.setEncoding("utf8");
            child.stdout.on("data", (chunk: string) => {
              stdout += chunk;
            });
            child.stderr.on("data", (chunk: string) => {
              stderr += chunk;
            });
            child.on("error", reject);
            child.on("close", (exitcode) => {
              resolveResult({ stdout, stderr, exitcode });
            });
          });
          return { content: JSON.stringify(result) };
        },
      });
    });
  },
});
