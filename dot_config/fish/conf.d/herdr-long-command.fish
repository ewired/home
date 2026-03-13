# Reports a synthetic agent status to Herdr for non-interactive commands that
# run longer than a configurable threshold (default 3s), so long-running shell
# commands surface in herdr's UI like real coding agents.
#
# Lifecycle per command:
#   1. preexec: spawn watcher (external process) with three seq numbers
#   2. watcher sleeps threshold, then reports "working" (if non-interactive)
#   3. postexec: SIGTERM the watcher
#   4. watcher reports "idle" (completion), spawns a detached 5s linger, exits
#   5. linger calls release-agent after 5s
#
# The three seq numbers (working_seq, idle_seq, release_seq) are monotonically
# increasing, which prevents a race condition: if a new command starts during
# the previous command's 5s completion linger, the new command's working report
# has a higher seq than the old linger's release-agent call, so herdr rejects
# the stale release and the new command's status survives.
#
# "Non-interactive" is decided by the watcher via the controlling TTY's termios
# flags: interactive TUIs (vim, hx, less, htop, ssh, ...) clear ICANON/ECHO;
# long-running builders, tests, and daemons do not. No allowlist or blocklist.
#
# Configure via universal variables:
#   set -U __herdr_long_command_threshold_sec 5
#   set -U __herdr_long_command_agent "Fish"
#   set -U __herdr_long_command_source "herdr:fish-longcmd"
#   set -U __herdr_long_command_completion_state idle
#   set -U __herdr_long_command_linger_sec 5

if not set -q __herdr_long_command_threshold_sec
    set -g __herdr_long_command_threshold_sec 3
end
if not set -q __herdr_long_command_source
    set -g __herdr_long_command_source "herdr:fish-longcmd"
end
if not set -q __herdr_long_command_agent
    set -g __herdr_long_command_agent "Fish"
end
if not set -q __herdr_long_command_completion_state
    set -g __herdr_long_command_completion_state idle
end
if not set -q __herdr_long_command_linger_sec
    set -g __herdr_long_command_linger_sec 5
end
# Seq counter: initialized to current epoch so it's higher than any value
# from a previous fish session (whose reports herdr may still remember).
if not set -q __herdr_long_command_seq
    set -g __herdr_long_command_seq (date +%s)
end

function __herdr_long_command_preexec --on-event fish_preexec
    set -g __herdr_long_command_cmd $argv[1]
    # Allocate three seq numbers for this command: working, idle, release.
    # Each must be strictly greater than the previous (herdr rejects seq <= last).
    set -g __herdr_long_command_seq (math $__herdr_long_command_seq + 1)
    set -l working_seq $__herdr_long_command_seq
    set -g __herdr_long_command_seq (math $__herdr_long_command_seq + 1)
    set -l idle_seq $__herdr_long_command_seq
    set -g __herdr_long_command_seq (math $__herdr_long_command_seq + 1)
    set -l release_seq $__herdr_long_command_seq

    env \
        HERDR_PANE_ID=$HERDR_PANE_ID \
        HERDR_LC_THRESHOLD=$__herdr_long_command_threshold_sec \
        HERDR_LC_SOURCE=$__herdr_long_command_source \
        HERDR_LC_AGENT=$__herdr_long_command_agent \
        HERDR_LC_CMD=$argv[1] \
        HERDR_LC_COMPLETION_STATE=$__herdr_long_command_completion_state \
        HERDR_LC_LINGER_SEC=$__herdr_long_command_linger_sec \
        HERDR_LC_WORKING_SEQ=$working_seq \
        HERDR_LC_IDLE_SEQ=$idle_seq \
        HERDR_LC_RELEASE_SEQ=$release_seq \
        herdr-long-command-watch >/dev/null 2>&1 &
    set -g __herdr_long_command_watch_pid $last_pid
end

function __herdr_long_command_postexec --on-event fish_postexec
    if test -n "$__herdr_long_command_watch_pid"
        kill $__herdr_long_command_watch_pid 2>/dev/null
        wait $__herdr_long_command_watch_pid 2>/dev/null
        set -e __herdr_long_command_watch_pid
    end
    set -e __herdr_long_command_cmd
end
