#!/usr/bin/env bash
#
# plan-disk-burns.sh - Split a set of files into per-disc manifests that each
# fit on a Blu-ray (BD-R). Packs files greedily by accumulated size and writes
# one manifest per disc, then prints a summary you can review before burning.
#
# It does NOT burn anything. It only produces discNN_files.txt manifests.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: plan-disk-burns.sh [options]

Options:
  -s DIR       Source directory to scan (default: current directory)
  -p GLOB      Filename pattern, case-insensitive (default: *.raf)
  -o DIR       Output directory for manifests (default: ./br-manifests)
  -l LABEL     Volume label prefix for the burn commands; disc number is
               appended, e.g. -l PHOTOS yields PHOTOS_1 (default: DISK)
  -c LIST      Per-disc capacity in GiB. A single value applies to every disc, or
               a comma-separated list assigns sizes per disc with the last value
               repeating, e.g. -c 23 or -c 20,15 (disc1=20, then 15,15,...).
               Values may be fractional, e.g. 22.5 (default: 23)
  -h           Show this help

Output:
  DIR/disc01_files.txt, disc02_files.txt, ...   absolute file paths (one per line)

Manifests use absolute paths so burning works from any directory. The printed
xorriso command strips the source root and roots everything at the disc root.
EOF
}

src="."
pattern="*.raf"
outdir="./br-manifests"
label="DISK"
cap_gib=23

while getopts ":s:p:o:l:c:h" opt; do
  case "$opt" in
    s) src="$OPTARG" ;;
    p) pattern="$OPTARG" ;;
    o) outdir="$OPTARG" ;;
    l) label="$OPTARG" ;;
    c) cap_gib="$OPTARG" ;;
    h) usage; exit 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 2 ;;
    :)  echo "Option -$OPTARG requires an argument" >&2; exit 2 ;;
  esac
done

[[ -d "$src" ]] || { echo "Source directory not found: $src" >&2; exit 1; }
IFS=',' read -r -a cap_list <<< "$cap_gib"
declare -a cap_bytes
ncaps=0
max_cap_bytes=0
for c in "${cap_list[@]}"; do
  [[ "$c" =~ ^[0-9]+(\.[0-9]+)?$ ]] || { echo "Capacities must be numbers in GiB, e.g. 23 or 20,15: $cap_gib" >&2; exit 1; }
  ncaps=$(( ncaps + 1 ))
  cap_bytes[ncaps]=$(awk -v c="$c" 'BEGIN { printf "%d", c * 1024 * 1024 * 1024 }')
  (( cap_bytes[ncaps] > max_cap_bytes )) && max_cap_bytes=${cap_bytes[ncaps]}
done

# Per-Disc Capacity - Caps apply in order; once the list is exhausted the last
# value repeats, so -c 20,15 yields disc1=20 GiB then 15 GiB for every disc after.
disc_limit() {
  local d=$1
  (( d <= ncaps )) && echo "${cap_bytes[$d]}" || echo "${cap_bytes[$ncaps]}"
}

# Resolve to an absolute path so manifests and the burn command are CWD-independent.
src=$(realpath "$src")

mkdir -p "$outdir"
rm -f "$outdir"/disc*_files.txt

# Collect files sorted by path so discs group naturally by folder/date.
mapfile -d '' entries < <(find "$src" -type f -iname "$pattern" -printf '%s\t%p\0' | sort -z -t$'\t' -k2)

if [[ ${#entries[@]} -eq 0 ]]; then
  echo "No files matching '$pattern' under '$src'." >&2
  exit 1
fi

disc=1
disc_bytes=0
limit=$(disc_limit 1)
total_bytes=0
total_files=0
declare -A disc_bytes_map disc_files_map

manifest() { printf '%s/disc%02d_files.txt' "$outdir" "$1"; }

for entry in "${entries[@]}"; do
  size="${entry%%$'\t'*}"
  path="${entry#*$'\t'}"

  if (( size > max_cap_bytes )); then
    echo "WARNING: '$path' ($((size/1024/1024)) MiB) exceeds the largest disc capacity; skipping." >&2
    continue
  fi

  # Advance to a disc with room. Per-disc caps mean the next disc may be a
  # different size, so re-read the limit each step and bound the search to one
  # full cap cycle to guarantee termination.
  advanced=0
  while (( disc_bytes + size > limit )); do
    disc=$(( disc + 1 ))
    disc_bytes=0
    limit=$(disc_limit "$disc")
    advanced=$(( advanced + 1 ))
    if (( advanced > ncaps )); then
      echo "WARNING: '$path' ($((size/1024/1024)) MiB) does not fit any configured disc size; skipping." >&2
      continue 2
    fi
  done

  printf '%s\n' "$path" >> "$(manifest "$disc")"
  disc_bytes=$(( disc_bytes + size ))
  disc_bytes_map[$disc]=$disc_bytes
  disc_files_map[$disc]=$(( ${disc_files_map[$disc]:-0} + 1 ))
  total_bytes=$(( total_bytes + size ))
  total_files=$(( total_files + 1 ))
done

echo "=== Manifest summary (caps ${cap_gib} GiB) ==="
for ((d=1; d<=disc; d++)); do
  [[ -f "$(manifest "$d")" ]] || continue
  mib=$(( disc_bytes_map[$d] / 1024 / 1024 ))
  cap_mib=$(( $(disc_limit "$d") / 1024 / 1024 ))
  printf '  disc%02d: %5d files, %6d / %6d MiB  ->  %s\n' \
    "$d" "${disc_files_map[$d]}" "$mib" "$cap_mib" "$(manifest "$d")"
done
printf '  TOTAL : %5d files, %6d MiB across %d disc(s)\n' \
  "$total_files" "$(( total_bytes / 1024 / 1024 ))" "$disc"

echo
echo "=== Burn commands (review, then run one per disc) ==="
for ((d=1; d<=disc; d++)); do
  [[ -f "$(manifest "$d")" ]] || continue
  # SC2016 - The $(cat ...) is literal text printed for the user to run later, not meant to expand here.
  # shellcheck disable=SC2016
  printf 'xorriso -outdev /dev/sr0 -volid "%s_%d" \\\n  -map_l %q / $(cat %q) -- -commit -eject\n\n' \
    "$label" "$d" "$src" "$(manifest "$d")"
done
