import type { Plugin } from "@opencode-ai/plugin";

export const JJOpencode: Plugin = async ({ $ }) => {
    const cache = new Map<string, boolean>();

    return {
        event: async ({ event }) => {
            if (event.type === "message.part.updated") {
                const sessionID = event.properties.part.sessionID;
                const isAssistant = event.properties.part.type === "step-finish";
                cache.set(sessionID, isAssistant);
            }
            if (event.type === "session.idle") {
                const sessionID = event.properties.sessionID;
                if (cache.get(sessionID)) {
                    const { stdout } = await $`jj opencode-jobs | wc -l`.quiet();
                    const jobCount = parseInt(stdout.toString().trim(), 10);
                    await $`notify-send -e -t 5 -a opencode "Session idle" "${jobCount} job${jobCount !== 1 ? 's' : ''} remaining"`;
                    await $`jj opencode-next-job`.quiet();
                }
            }
            if (event.type === "permission.updated") {
                await $`notify-send -e -a opencode "Permission Requested:" "${event.properties.type === "bash" ? "$" : ""
                    } ${event.properties.title}"`;
            }
        },
    };
};
