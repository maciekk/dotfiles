import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

type Phase = "idle" | "planned" | "implemented" | "committed";
type WorkflowMode = "strict" | "flexible";

const STATE_TYPE = "checkpoint-state";
const WORKFLOW_MODE: WorkflowMode = "flexible";

export default function (pi: ExtensionAPI) {
  let phase: Phase = "idle";
  let allowNextCommit = false;
  let allowNextPush = false;

  const setPhase = (next: Phase) => {
    phase = next;
    pi.appendEntry(STATE_TYPE, { phase, ts: Date.now() });
  };

  const phaseLabel = () => `checkpoints: ${phase} (${WORKFLOW_MODE})`;

  const nextCommands = () => {
    if (phase === "idle") return WORKFLOW_MODE === "flexible" ? "/plan, /implement, /commit" : "/plan";
    if (phase === "planned") return WORKFLOW_MODE === "flexible" ? "/implement, /commit" : "/implement";
    if (phase === "implemented") return "/commit";
    return "/push";
  };

  const setStatus = (ctx: { hasUI: boolean; ui: { setStatus: (key: string, value: string) => void } }) => {
    if (ctx.hasUI) ctx.ui.setStatus("checkpoints", phaseLabel());
  };

  const resetGuards = () => {
    allowNextCommit = false;
    allowNextPush = false;
  };

  pi.on("session_start", async (_event, ctx) => {
    phase = "idle";
    resetGuards();
    for (const entry of ctx.sessionManager.getEntries()) {
      if (entry.type === "custom" && entry.customType === STATE_TYPE) {
        const maybe = (entry.data as { phase?: Phase } | undefined)?.phase;
        if (maybe === "idle" || maybe === "planned" || maybe === "implemented" || maybe === "committed") {
          phase = maybe;
        }
      }
    }
    setStatus(ctx);
  });

  pi.registerCommand("plan", {
    description: "Create a plan and stop for confirmation",
    handler: async (args, ctx) => {
      setPhase("planned");
      resetGuards();
      setStatus(ctx);
      pi.sendUserMessage(
        `Create a concise implementation plan${args ? ` for: ${args}` : ""}. Do not implement yet. End by explicitly asking for confirmation to proceed with implementation.`
      );
    },
  });

  pi.registerCommand("implement", {
    description: "Implement after planning (or directly in flexible mode)",
    handler: async (args, ctx) => {
      if (phase !== "planned") {
        if (WORKFLOW_MODE === "strict") {
          ctx.ui.notify("Run /plan first (or re-run it for a new task).", "warning");
          return;
        }
        if (phase === "idle") {
          ctx.ui.notify("Flexible mode: proceeding without /plan.", "info");
        }
      }

      setPhase("implemented");
      resetGuards();
      setStatus(ctx);
      pi.sendUserMessage(
        `Implement the approved plan${args ? ` with this focus: ${args}` : ""}. After implementation, summarize changes and explicitly ask whether to commit. Do not commit yet.`
      );
    },
  });

  pi.registerCommand("commit", {
    description: "Authorize next git commit",
    handler: async (args, ctx) => {
      if (phase !== "implemented") {
        if (WORKFLOW_MODE === "strict") {
          ctx.ui.notify("Run /implement first.", "warning");
          return;
        }

        if (phase === "idle" || phase === "planned") {
          ctx.ui.notify(`Flexible mode: recovering phase from ${phase} to implemented for commit.`, "warning");
          setPhase("implemented");
        }
      }

      allowNextCommit = true;
      allowNextPush = false;
      setStatus(ctx);
      pi.sendUserMessage(
        `Create an appropriate git commit${args ? ` with this guidance: ${args}` : ""}. After commit, show commit hash and short summary, then explicitly ask whether to push. Do not push yet.`
      );
    },
  });

  pi.registerCommand("push", {
    description: "Authorize next git push",
    handler: async (_args, ctx) => {
      if (phase !== "committed") {
        ctx.ui.notify(`Run /commit first. Current phase: ${phase}.`, "warning");
        return;
      }
      allowNextPush = true;
      setStatus(ctx);
      pi.sendUserMessage("Push the current branch to remote now.");
    },
  });

  pi.registerCommand("status", {
    description: "Show checkpoint workflow status",
    handler: async (_args, ctx) => {
      ctx.ui.notify(`Mode: ${WORKFLOW_MODE} | Phase: ${phase} | Next: ${nextCommands()}`, "info");
      setStatus(ctx);
    },
  });

  pi.registerCommand("reset", {
    description: "Reset checkpoint workflow to idle",
    handler: async (_args, ctx) => {
      setPhase("idle");
      resetGuards();
      setStatus(ctx);
      ctx.ui.notify("Checkpoint workflow reset to idle.", "info");
    },
  });

  pi.on("tool_call", async (event, _ctx) => {
    if (!isToolCallEventType("bash", event)) return;

    const cmd = event.input.command ?? "";

    if (/\bgit\s+commit\b/.test(cmd)) {
      if (phase !== "implemented") {
        return {
          block: true,
          reason: `Blocked: git commit not allowed in '${phase}'. Use /commit to recover and authorize (or /status, /reset).`,
        };
      }
      if (!allowNextCommit) {
        return {
          block: true,
          reason: "Blocked: use /commit to authorize the next git commit (or /status).",
        };
      }
      allowNextCommit = false;
      allowNextPush = false;
      setPhase("committed");
    }

    if (/\bgit\s+push\b/.test(cmd)) {
      if (phase !== "committed") {
        return {
          block: true,
          reason: `Blocked: git push not allowed in '${phase}'. Use /commit first (or /status, /reset).`,
        };
      }
      if (!allowNextPush) {
        return {
          block: true,
          reason: "Blocked: use /push to authorize git push.",
        };
      }
      allowNextPush = false;
      setPhase("idle");
    }
  });
}
