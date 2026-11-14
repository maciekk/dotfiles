import { existsSync } from "node:fs";
import {
  DefaultPackageManager,
  getAgentDir,
  SettingsManager,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";

const HELP = "Updates on Omarchy — Pi: mise upgrade pi; extensions: pi update --extensions. Restart Pi afterwards. Avoid npm/installer self-updates.";

export default function updateHelp(pi: ExtensionAPI) {
  if (!existsSync("/usr/share/omarchy")) return;

  let controller: AbortController | undefined;

  pi.on("session_start", (event, ctx) => {
    if (ctx.mode !== "tui" || (event.reason !== "startup" && event.reason !== "reload")) return;
    if (process.env.PI_OFFLINE) return;

    controller?.abort();
    const check = new AbortController();
    controller = check;

    // Match what `mise upgrade pi` can actually install, including its release-age policy.
    if (!process.env.PI_SKIP_VERSION_CHECK) {
      void pi.exec("mise", ["outdated", "pi", "--json"], {
        cwd: ctx.cwd,
        timeout: 10_000,
        signal: check.signal,
      }).then((result) => {
        if (check.signal.aborted || result.code !== 0 || result.truncated) return;
        const outdated = JSON.parse(result.stdout);
        const update = outdated.pi;
        if (update?.current && update?.latest && update.current !== update.latest) {
          ctx.ui.notify(`Pi update available (${update.current} → ${update.latest}): mise upgrade pi. Restart Pi afterwards.`, "info");
        }
      }).catch(() => {});
    }

    // Reuse Pi's checker so npm/git packages, pins, and project scopes behave like Pi itself.
    void Promise.resolve().then(async () => {
      if (check.signal.aborted) return;
      const agentDir = getAgentDir();
      const settingsManager = SettingsManager.create(ctx.cwd, agentDir, {
        projectTrusted: ctx.isProjectTrusted(),
      });
      const manager = new DefaultPackageManager({ cwd: ctx.cwd, agentDir, settingsManager });
      const updates = await manager.checkForAvailableUpdates();
      if (!check.signal.aborted && updates.length > 0) {
        const names = updates.map((update) => update.displayName).join(", ");
        ctx.ui.notify(`Extension updates available (${names}): pi update --extensions. Restart Pi afterwards.`, "info");
      }
    }).catch(() => {});
  });

  pi.on("session_shutdown", () => {
    controller?.abort();
    controller = undefined;
  });

  pi.registerCommand("update-help", {
    description: "Show the safe Pi and extension update commands on Omarchy",
    handler: async (_args, ctx) => {
      if (ctx.hasUI) ctx.ui.notify(HELP, "info");
    },
  });
}
