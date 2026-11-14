import { existsSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const HELP = "Updates on Omarchy — Pi: mise upgrade pi; extensions: pi update --extensions. Restart Pi afterwards. Avoid npm/installer self-updates.";

export default function updateHelp(pi: ExtensionAPI) {
  if (!existsSync("/usr/share/omarchy")) return;

  pi.on("session_start", (event, ctx) => {
    if (ctx.mode === "tui" && (event.reason === "startup" || event.reason === "reload")) {
      ctx.ui.notify(HELP, "info");
    }
  });

  pi.registerCommand("update-help", {
    description: "Show the safe Pi and extension update commands on Omarchy",
    handler: async (_args, ctx) => {
      if (ctx.hasUI) ctx.ui.notify(HELP, "info");
    },
  });
}
