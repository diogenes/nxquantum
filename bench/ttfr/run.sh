#!/bin/sh
# NxQuantum time-to-first-result (TTFR) harness.
#
# Runs the getting-started consumer flow from an empty Mix/Hex home and times
# each step:
#   1. mix local.hex --force, mix local.rebar --force
#   2. mix new demo
#   3. write the nx_quantum dependency line into mix.exs
#   4. mix deps.get
#   5. mix compile
#   6. mix run -e <evaluate the snippet and inspect its return value>
# Success = every step exits 0 AND the last non-empty stdout line of step 6
# equals --expect. Elixir/OTP must already be on PATH (toolchain install time
# is not measured). Human reading time is not measured.
#
# Usage:
#   bench/ttfr/run.sh --out DIR [--label NAME] [--package-dir DIR | --dep LINE]
#                     [--snippet FILE] --expect TEXT [--work DIR]
#
#   --dep LINE         deps tuple, e.g. '{:nx_quantum, "~> 0.12.0"}'
#   --package-dir DIR  use '{:nx_quantum, path: DIR}' (an unpacked
#                      `mix hex.build --unpack` directory)
#   --snippet FILE     plain Elixir that RETURNS the value (not prints it);
#                      default: test/fixtures/docs/getting_started_first_result.elixir
#   --expect TEXT      expected inspected return value
#                      (default: [0.3623577356338501])
#   --out DIR          output dir for <label>.log and environment.txt
#   --label NAME       default: run
#   --work DIR         parent for the fresh home (default: mktemp -d)
# Exit code: 0 success, 1 flow failed, 2 usage error, 3 output mismatch.
set -u

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
dep=""; pkg=""; snippet="$repo_root/test/fixtures/docs/getting_started_first_result.elixir"
expect="[0.3623577356338501]"; out=""; label="run"; work=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dep) dep=$2; shift 2 ;;
    --package-dir) pkg=$2; shift 2 ;;
    --snippet) snippet=$2; shift 2 ;;
    --expect) expect=$2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    --label) label=$2; shift 2 ;;
    --work) work=$2; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$out" ] || { echo "--out is required" >&2; exit 2; }
[ -f "$snippet" ] || { echo "snippet not found: $snippet" >&2; exit 2; }
if [ -z "$dep" ]; then
  [ -n "$pkg" ] || { echo "pass --dep or --package-dir" >&2; exit 2; }
  dep="{:nx_quantum, path: \"$pkg\"}"
fi
mkdir -p "$out"
out=$(cd "$out" && pwd)
snippet=$(cd "$(dirname "$snippet")" && pwd)/$(basename "$snippet")

if [ -n "$work" ]; then mkdir -p "$work"; root=$(mktemp -d "$work/ttfr.XXXXXX")
else root=$(mktemp -d); fi

# Fresh, empty homes. Nothing from the invoking user's home is reused.
export HOME="$root/home" MIX_HOME="$root/mix" HEX_HOME="$root/hex"
export HEX_CACHE_DIR="$root/hexcache" XDG_CACHE_HOME="$root/xdg-cache"
export XDG_DATA_HOME="$root/xdg-data" XDG_CONFIG_HOME="$root/xdg-config"
unset MIX_ARCHIVES MIX_DEPS_PATH MIX_BUILD_PATH MIX_TARGET MIX_ENV
mkdir -p "$HOME" "$MIX_HOME" "$HEX_HOME" "$HEX_CACHE_DIR" "$XDG_CACHE_HOME" \
  "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
# Default path: no EXLA/Torchx env flags.
unset NXQ_ENABLE_EXLA NXQ_ENABLE_TORCHX

log="$out/$label.log"
raw="$root/raw.log"
: > "$raw"

now() {
  perl -MTime::HiRes=time -e 'printf "%.3f\n", time' 2>/dev/null || date +%s
}
cache_state() {
  n=$(find "$1" -type f 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" = 0 ] && echo empty || echo "non-empty ($n files)"
}

{
  echo "label: $label"
  echo "date_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "dep: $dep"
  echo "expect: $expect"
  echo "cache_state_at_start: MIX_HOME=$(cache_state "$MIX_HOME") HEX_HOME=$(cache_state "$HEX_HOME") HEX_CACHE_DIR=$(cache_state "$HEX_CACHE_DIR") XDG_CACHE_HOME=$(cache_state "$XDG_CACHE_HOME")"
} >> "$raw"

times=""
total=0
failed=""
step() { # name, command...
  name=$1; shift
  echo "--- step: $name" >> "$raw"
  t0=$(now)
  "$@" >> "$raw" 2>&1
  rc=$?
  t1=$(now)
  dt=$(echo "$t0 $t1" | awk '{printf "%.1f", $2-$1}')
  echo "--- step: $name exit=$rc seconds=$dt" >> "$raw"
  times="$times$name=$dt "
  total=$(echo "$total $dt" | awk '{printf "%.1f", $1+$2}')
  [ $rc -eq 0 ] || failed="$name"
  return $rc
}

write_deps() {
  # Insert the dependency line into the generated deps/0 function.
  awk -v dep="$dep" '
    /^ *defp deps do/ { indesp=1 }
    indesp && /^ *\[/ && !done { print "      [" dep; done=1; next }
    { print }' mix.exs > mix.exs.new && mv mix.exs.new mix.exs
  grep -q "nx_quantum" mix.exs
}

run_snippet() {
  TTFR_SNIPPET="$snippet" mix run -e 'IO.inspect(elem(Code.eval_file(System.fetch_env!("TTFR_SNIPPET")), 0), limit: :infinity, printable_limit: :infinity)' > "$root/snippet.out" 2>> "$raw"
  rc=$?
  cat "$root/snippet.out" >> "$raw"
  return $rc
}

cd "$root" || exit 1
step local.hex mix local.hex --force &&
step local.rebar mix local.rebar --force &&
step new mix new demo &&
{ cd demo && step write_deps write_deps; } &&
step deps.get mix deps.get &&
step compile mix compile &&
step run run_snippet

got=""
[ -f "$root/snippet.out" ] && got=$(grep -v '^[[:space:]]*$' "$root/snippet.out" | tail -n 1 | tr -d '\r')
status=ok; code=0
if [ -n "$failed" ]; then status="FAIL (step $failed)"; code=1
elif [ "$got" != "$expect" ]; then status="FAIL (output mismatch)"; code=3; fi

{
  echo "=== result ==="
  echo "printed: $got"
  echo "step_seconds: $times"
  echo "total_seconds: $total"
  echo "status: $status"
} >> "$raw"

# Environment record (no usernames, hostnames, or absolute paths).
{
  echo "date_utc: $(date -u +%Y-%m-%d)"
  echo "os: $(sw_vers 2>/dev/null | tr '\n' ' ' || uname -sr)"
  echo "arch: $(uname -m)"
  echo "cpu: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || grep -m1 'model name' /proc/cpuinfo)"
  echo "cores: $(sysctl -n hw.ncpu 2>/dev/null || nproc)"
  echo "elixir: $(elixir --version 2>&1 | tail -n 1)"
  echo "otp_release: $(erl -noshell -eval 'io:format("~s~n",[erlang:system_info(otp_release)]), halt().')"
  echo "network: live network to hex.pm and builds.hex.pm (not throttled or mirrored)"
  echo "caches: fresh empty MIX_HOME, HEX_HOME, HEX_CACHE_DIR, XDG_* dirs per run"
  echo "script_ref: $(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null)"
} > "$out/environment.txt"

# Scrub absolute paths before anything is committed.
sed -e "s|$root|<fresh-home>|g" -e "s|${pkg:-@@none@@}|<unpacked-package>|g" \
    -e "s|$repo_root|<repo>|g" -e "s|$snippet|<snippet>|g" "$raw" > "$log"
echo "$label: $status printed=$got total=${total}s steps: $times"
rm -rf "$root"
exit $code
