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
  -c GiB       Per-disc capacity in GiB, may be fractional e.g. 22.5 (default: 23)
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
[[ "$cap_gib" =~ ^[0-9]+(\.[0-9]+)?$ ]] || { echo "Capacity must be a number (GiB), e.g. 23 or 22.5: $cap_gib" >&2; exit 1; }

# Resolve to an absolute path so manifests and the burn command are CWD-independent.
src=$(realpath "$src")

limit=$(awk -v c="$cap_gib" 'BEGIN { printf "%d", c * 1024 * 1024 * 1024 }')
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
total_bytes=0
total_files=0
declare -A disc_bytes_map disc_files_map

manifest() { printf '%s/disc%02d_files.txt' "$outdir" "$1"; }

for entry in "${entries[@]}"; do
  size="${entry%%$'\t'*}"
  path="${entry#*$'\t'}"

  if (( size > limit )); then
    echo "WARNING: '$path' ($((size/1024/1024)) MiB) exceeds disc capacity (${cap_gib} GiB); skipping." >&2
    continue
  fi

  if (( disc_bytes + size > limit )); then
    disc=$(( disc + 1 ))
    disc_bytes=0
  fi

  printf '%s\n' "$path" >> "$(manifest "$disc")"
  disc_bytes=$(( disc_bytes + size ))
  disc_bytes_map[$disc]=$disc_bytes
  disc_files_map[$disc]=$(( ${disc_files_map[$disc]:-0} + 1 ))
  total_bytes=$(( total_bytes + size ))
  total_files=$(( total_files + 1 ))
done

echo "=== Manifest summary (cap ${cap_gib} GiB/disc) ==="
for ((d=1; d<=disc; d++)); do
  [[ -f "$(manifest "$d")" ]] || continue
  mib=$(( disc_bytes_map[$d] / 1024 / 1024 ))
  printf '  disc%02d: %5d files, %6d MiB  ->  %s\n' \
    "$d" "${disc_files_map[$d]}" "$mib" "$(manifest "$d")"
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
