#!/usr/bin/env bash
# One-time, per-machine setup so run_perf_stats.sh can use `perf stat`
# without being root. Lowers perf_event_paranoid so an unprivileged user
# can open hardware performance counters; the benchmarks themselves still
# run as the invoking user (this does not use sudo on perf itself).
#
# This is a system-wide, persistent-until-reboot sysctl change -- run it
# deliberately, once per machine, not automatically from run_perf_stats.sh.
set -euo pipefail

CURRENT=$(cat /proc/sys/kernel/perf_event_paranoid)
echo "Current kernel.perf_event_paranoid: $CURRENT"

if [[ "$CURRENT" -le -1 ]]; then
	echo "Already permissive enough; nothing to do."
	exit 0
fi

echo "Setting kernel.perf_event_paranoid=-1 (allow all perf_event_open access)..."
sudo sysctl -w kernel.perf_event_paranoid=-1

echo
echo "Done for this boot. To make it permanent across reboots, add to"
echo "/etc/sysctl.d/local.conf (or similar):"
echo "  kernel.perf_event_paranoid = -1"
