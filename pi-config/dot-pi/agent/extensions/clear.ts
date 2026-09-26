import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function clearCompatibilityExtension(pi: ExtensionAPI) {
	pi.registerCommand("clear", {
		description: "Explain that /clear is not a context-reset command; use /new",
		handler: async (_args, ctx) => {
		ctx.ui.notify(
			"/clear is a Claude compatibility alias, not a Pi context reset. Use /new for a fresh session; /compact summarizes existing context.",
			"warning",
		);
	},
	});
}
