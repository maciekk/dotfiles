import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

function formatTokens(count: number): string {
	if (count < 1_000) return `${count}`;
	if (count < 10_000) return `${(count / 1_000).toFixed(1)}k`;
	if (count < 1_000_000) return `${Math.round(count / 1_000)}k`;
	return `${(count / 1_000_000).toFixed(1)}M`;
}

function formatCwd(cwd: string): string {
	const home = process.env.HOME;
	return home && (cwd === home || cwd.startsWith(`${home}/`)) ? `~${cwd.slice(home.length)}` : cwd;
}

export default function (pi: ExtensionAPI) {
	let isWorking = false;
	let spinnerIndex = 0;
	let spinnerTimer: ReturnType<typeof setInterval> | undefined;
	let requestRender: (() => void) | undefined;
	let cwd: string | undefined;
	let gitStatus = { staged: 0, unstaged: 0, untracked: 0 };
	const spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

	const stopSpinner = () => {
		if (spinnerTimer) clearInterval(spinnerTimer);
		spinnerTimer = undefined;
	};

	const refreshGitStatus = async () => {
		if (!cwd) return;
		const result = await pi.exec("git", ["status", "--porcelain=v1"], { cwd }).catch(() => undefined);
		const next = { staged: 0, unstaged: 0, untracked: 0 };
		if (result?.code === 0) {
			for (const line of result.stdout.split("\n")) {
				if (!line) continue;
				if (line.startsWith("??")) {
					next.untracked++;
					continue;
				}
				if (line[0] !== " ") next.staged++;
				if (line[1] !== " ") next.unstaged++;
			}
		}
		gitStatus = next;
		requestRender?.();
	};

	pi.on("agent_start", () => {
		isWorking = true;
		stopSpinner();
		spinnerTimer = setInterval(() => {
			spinnerIndex = (spinnerIndex + 1) % spinnerFrames.length;
			requestRender?.();
		}, 80);
		void refreshGitStatus();
		requestRender?.();
	});

	pi.on("agent_settled", () => {
		isWorking = false;
		stopSpinner();
		void refreshGitStatus();
		requestRender?.();
	});

	pi.on("session_shutdown", () => {
		stopSpinner();
		requestRender = undefined;
		cwd = undefined;
	});

	pi.on("session_start", (_event, ctx) => {
		cwd = ctx.cwd;
		ctx.ui.setWorkingVisible(false);
		ctx.ui.setFooter((tui, theme, footerData) => {
			requestRender = () => tui.requestRender();
			const unsubscribe = footerData.onBranchChange(() => tui.requestRender());
			void refreshGitStatus();

			return {
				dispose() {
					unsubscribe();
					requestRender = undefined;
				},
				invalidate() {},
				render(width: number): string[] {
					let input = 0;
					let output = 0;
					let cost = 0;
					let latestCacheHitRate = 0;

					for (const entry of ctx.sessionManager.getBranch()) {
						if (entry.type === "message" && entry.message.role === "assistant") {
							const message = entry.message as AssistantMessage;
							input += message.usage.input;
							output += message.usage.output;
							cost += message.usage.cost.total;
							const promptTokens = message.usage.input + message.usage.cacheRead + message.usage.cacheWrite;
							latestCacheHitRate = promptTokens > 0 ? (message.usage.cacheRead / promptTokens) * 100 : 0;
						}
					}

					const branch = footerData.getGitBranch();
					const gitBits: string[] = [];
					if (gitStatus.staged > 0) gitBits.push(theme.fg("success", `+${gitStatus.staged}`));
					if (gitStatus.unstaged > 0) gitBits.push(theme.fg("warning", `~${gitStatus.unstaged}`));
					if (gitStatus.untracked > 0) gitBits.push(theme.fg("warning", `?${gitStatus.untracked}`));
					const gitBitsStyled = gitBits.join(" ");
					const formattedCwd = formatCwd(ctx.cwd);
					const location = branch
						? `${theme.fg("dim", `${formattedCwd} (${branch}`)}${gitBitsStyled ? ` ${gitBitsStyled}` : ""}${theme.fg("dim", ")")}`
						: `${theme.fg("dim", formattedCwd)}${gitBitsStyled ? ` ${gitBitsStyled}` : ""}`;
					const locationLine = truncateToWidth(location, width, theme.fg("dim", "..."));

					const usage = ctx.getContextUsage();
					const contextPercent = usage?.percent;
					const contextValue = contextPercent ?? 0;
					const contextBarWidth = 8;
					const contextFilled = Math.max(0, Math.min(contextBarWidth, Math.round((contextValue / 100) * contextBarWidth)));
					const contextBar = `${"█".repeat(contextFilled)}${"░".repeat(contextBarWidth - contextFilled)}`;
					const contextText = `ctx ${contextBar}`;
					const styledContext = `${theme.fg("dim", "ctx ")}${theme.bg("customMessageBg", theme.fg("muted", "█".repeat(contextFilled)))}${theme.bg("customMessageBg", theme.fg("dim", "░".repeat(contextBarWidth - contextFilled)))}`;

					const cacheRate = `${latestCacheHitRate.toFixed(1)}%`;
					const usageParts = [`↑${formatTokens(input)}`, `↓${formatTokens(output)}`, `CH${cacheRate}`, `$${cost.toFixed(2)}`];
					const styledUsageParts = [
						`${theme.fg("dim", "↑")}${theme.bold(formatTokens(input))}`,
						`${theme.fg("dim", "↓")}${theme.bold(formatTokens(output))}`,
						`${theme.fg("dim", "CH")}${theme.bold(cacheRate)}`,
						`${theme.fg("dim", "$")}${theme.bold(cost.toFixed(2))}`,
					];
					const usageText = usageParts.join(" ");
					const styledUsage = styledUsageParts.join(" ");

					const statusParts = [...footerData.getExtensionStatuses().entries()]
						.sort(([a], [b]) => a.localeCompare(b))
						.map(([key, text]) => ({
							key,
							text:
								key === "usage"
									? text.replace(/^codex\s+/i, "").replace(/(\d+%)\s+(5h|wk)\b/gi, "$2 $1")
									: text,
						}));
					const statusPlain = statusParts.map(({ text }) => text).join(" ");
					const styledStatus = statusParts
						.map(({ text }) =>
							text
								.split(/(\d+%)/g)
								.map((part) => {
									const percent = /^(\d+)%$/.exec(part);
									if (!percent) return theme.fg("dim", part);
									const value = Number(percent[1]);
									const color = value > 90 ? "error" : value > 70 ? "warning" : "success";
									return theme.bold(theme.fg(color, part));
								})
								.join(""),
						)
						.join(" ");

					const activityPlain = isWorking ? `${spinnerFrames[spinnerIndex]} ` : "";
					const activity = isWorking ? `${theme.fg("accent", spinnerFrames[spinnerIndex])} ` : "";
					const leftPlain = [activityPlain + usageText, contextText, statusPlain].filter(Boolean).join(" ");
					const left = [activity + styledUsage, styledContext, styledStatus].filter(Boolean).join(" ");

					const model = ctx.model?.id ?? "no-model";
					const provider = ctx.model?.provider;
					const thinking = pi.getThinkingLevel();
					const styledThinking =
						thinking === "high"
							? theme.bold(theme.fg("warning", thinking))
							: thinking === "xhigh" || thinking === "max"
								? theme.bold(theme.fg("error", thinking))
								: theme.bold(theme.fg("success", thinking));
					const rightCore = `${theme.bold(theme.fg("text", model))}${theme.fg("dim", " · thinking:")}${styledThinking}`;
					const rightWithProvider = `${provider ? theme.fg("dim", `(${provider}) `) : ""}${rightCore}`;
					const right =
						visibleWidth(left) + 2 + visibleWidth(rightWithProvider) <= width ? rightWithProvider : rightCore;

					const gap = Math.max(2, width - visibleWidth(left) - visibleWidth(right));
					const availableRight = Math.max(0, width - visibleWidth(left) - gap);
					const statsLine = truncateToWidth(
						left + " ".repeat(gap) + truncateToWidth(right, availableRight, ""),
						width,
						"",
					);

					return [locationLine, visibleWidth(leftPlain) <= width ? statsLine : truncateToWidth(left, width, "")];
				},
			};
		});
	});
}
