import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

type Phase = "idle" | "planned" | "implemented" | "committed";

const STATE_TYPE = "checkpoint-state";

export default function (pi: ExtensionAPI) {
  let phase: Phase = "idle";

  const setPhase = (next: Phase) => {
    phase = next;
    pi.appendEntry(STATE_TYPE, { phase, ts: Date.now() });
  };

  const phaseLabel = () => `Current workflow phase: ${phase}`;

  pi.on("session_start", async (_event, ctx) => {
    phase = "idle";
    for (const entry of ctx.sessionManager.getEntries()) {
      if (entry.type === "custom" && entry.customType === STATE_TYPE) {
        const maybe = (entry.data as { phase?: Phase } | undefined)?.phase;
        if (maybe === "idle" || maybe === "planned" || maybe === "implemented" || maybe === "committed") {
          phase = maybe;
        }
      }
    }
    if (ctx.hasUI) ctx.ui.setStatus("checkpoints", phaseLabel());
  });

  pi.registerCommand("plan", {
    description: "Create a plan and stop for confirmation",
    handler: async (args, ctx) => {
      setPhase("planned");
      if (ctx.hasUI) ctx.ui.setStatus("checkpoints", phaseLabel());
      pi.sendUserMessage(
        `Create a concise implementation plan${args ? ` for: ${args}` : ""}. Do not implement yet. End by explicitly asking for confirmation to proceed with implementation.`
      );
    },
  });

  pi.registerCommand("implement", {
    description: "Implement only after an approved plan",
    handler: async (args, ctx) => {
      if (phase !== "planned") {
        ctx.ui.notify("Run /plan first (or re-run it for a new task).", "warning");
        return;
      }
      setPhase("implemented");
      if (ctx.hasUI) ctx.ui.setStatus("checkpoints", phaseLabel());
      pi.sendUserMessage(
        `Implement the approved plan${args ? ` with this focus: ${args}` : ""}. After implementation, summarize changes and explicitly ask whether to commit. Do not commit yet.`
      );
    },
  });

  pi.registerCommand("commit", {
    description: "Commit only after implementation",
    handler: async (args, ctx) => {
      if (phase !== "implemented") {
        ctx.ui.notify("Run /implement first.", "warning");
        return;
      }
      setPhase("committed");
      if (ctx.hasUI) ctx.ui.setStatus("checkpoints", phaseLabel());
      pi.sendUserMessage(
        `Create an appropriate git commit${args ? ` with this guidance: ${args}` : ""}. After commit, show commit hash and short summary, then explicitly ask whether to push. Do not push yet.`
      );
    },
  });

  pi.registerCommand("push", {
    description: "Push only after commit and explicit confirmation",
    handler: async (_args, ctx) => {
      if (phase !== "committed") {
        ctx.ui.notify("Run /commit first.", "warning");
        return;
      }
      const ok = await ctx.ui.confirm("Push to remote?", "Run git push now?");
      if (!ok) return;
      setPhase("idle");
      if (ctx.hasUI) ctx.ui.setStatus("checkpoints", phaseLabel());
      pi.sendUserMessage("Push the current branch to remote now.");
    },
  });

  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("bash", event)) return;

    const cmd = event.input.command ?? "";

    if (/\bgit\s+commit\b/.test(cmd)) {
      if (phase !== "implemented" && phase !== "committed") {
        return { block: true, reason: "Blocked: run /implement first" };
      }
      const ok = await ctx.ui.confirm("Allow git commit?", `Command:\n${cmd}`);
      if (!ok) return { block: true, reason: "Commit blocked by user" };
    }

    if (/\bgit\s+push\b/.test(cmd)) {
      if (phase !== "committed") {
        return { block: true, reason: "Blocked: run /commit first" };
      }
      const ok = await ctx.ui.confirm("Allow git push?", `Command:\n${cmd}`);
      if (!ok) return { block: true, reason: "Push blocked by user" };
    }
  });
}
