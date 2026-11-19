#!/usr/bin/env bash
# Configured by rizky.md@gmail.com - spikecursed
set -u

TIMESTAMP="$(date -u +"%d%m%Y-%H%M")"
HOST="$(hostname -s 2>/dev/null || hostname)"
OUTDIR="/tmp/ir_${HOST}_${TIMESTAMP}"

mkdir -p "${OUTDIR}"/{system,network,users,persistence,logs}

log_step() {
  echo "[$(date -u +"%H:%M:%S")] $1" | tee -a "${OUTDIR}/collection.log"
}

run_cmd() {
  local out_file="$1"
  shift
  {
    echo "# CMD: $*"
    "$@"
  } > "${out_file}" 2>&1 || true
}

log_step "Starting Linux incident data collection into ${OUTDIR}"

# 1. System & volatile state
run_cmd "${OUTDIR}/system/uname_os.txt" uname -a
run_cmd "${OUTDIR}/system/os_release.txt" cat /etc/os-release
run_cmd "${OUTDIR}/system/uptime_date.txt" date -u
run_cmd "${OUTDIR}/system/uptime.txt" uptime
run_cmd "${OUTDIR}/system/ps_auxf.txt" ps auxf
run_cmd "${OUTDIR}/system/ps_elf.txt" ps -ef
run_cmd "${OUTDIR}/system/mounts.txt" mount
run_cmd "${OUTDIR}/system/lsmod.txt" lsmod

# 2. Network state
run_cmd "${OUTDIR}/network/ip_addr.txt" ip addr
run_cmd "${OUTDIR}/network/ip_route.txt" ip route
run_cmd "${OUTDIR}/network/arp.txt" ip neigh
run_cmd "${OUTDIR}/network/sockets_ss.txt" ss -tulnp
run_cmd "${OUTDIR}/network/netstat.txt" netstat -tulnp
run_cmd "${OUTDIR}/network/iptables.txt" iptables -L -n -v
run_cmd "${OUTDIR}/network/nftables.txt" nft list ruleset

# 3. Users & logins
run_cmd "${OUTDIR}/users/passwd.txt" cat /etc/passwd
run_cmd "${OUTDIR}/users/group.txt" cat /etc/group
run_cmd "${OUTDIR}/users/sudoers.txt" cat /etc/sudoers
run_cmd "${OUTDIR}/users/last.txt" last -a -i
run_cmd "${OUTDIR}/users/lastlog.txt" lastlog
run_cmd "${OUTDIR}/users/w.txt" w

# 4. Persistence mechanisms
run_cmd "${OUTDIR}/persistence/crontab_root.txt" crontab -l -u root
run_cmd "${OUTDIR}/persistence/etc_cron.txt" ls -la /etc/cron* /var/spool/cron/crontabs
run_cmd "${OUTDIR}/persistence/systemd_units.txt" systemctl list-unit-files --type=service
run_cmd "${OUTDIR}/persistence/rc_local.txt" ls -la /etc/init.d /etc/rc*.d
run_cmd "${OUTDIR}/persistence/readable.txt" find /etc/ -readable -type f 
run_cmd "${OUTDIR}/persistence/last_14day.txt" find / -mtime -14 -ls

# 5. Logs & shell history (copied safely)
cp -a /var/log/auth.log* /var/log/secure* /var/log/syslog* /var/log/messages* "${OUTDIR}/logs/" 2>/dev/null || true
run_cmd "${OUTDIR}/logs/journal_recent.txt" journalctl -n 500 --no-pager
find /root /home -maxdepth 3 \( -name ".bash_history" -o -name ".zsh_history" -o -name "authorized_keys" \) 2>/dev/null | while read -r f; do
  safe_name="$(echo "$f" | tr '/' '_')"
  cp -a "$f" "${OUTDIR}/logs/${safe_name}" 2>/dev/null || true
done

# 6. Hash collected artifacts
(cd "${OUTDIR}" && find . -type f ! -name "SHA256SUMS" -exec sha256sum {} + > SHA256SUMS)

tar -czf $OUTDIR.tar.gz $OUTDIR 2>/dev/null
log_step "Collection complete file :  ${OUTDIR}.tar.gz"
