#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
sops_file="$repo_root/secrets/common/evanreichard.yaml"

# Add another OpenAI-compatible source by adding one entry to each map below.
declare -A provider_urls=(
  [synthetic]="https://api.synthetic.new/openai/v1/models"
)
declare -A provider_outputs=(
  [synthetic]="modules/home/programs/terminal/pi/providers/synthetic.json"
)
declare -A provider_key_envs=(
  [synthetic]="SYNTHETIC_API_KEY"
)
declare -A provider_key_file_envs=(
  [synthetic]="SYNTHETIC_API_KEY_FILE"
)
declare -A provider_sops_keys=(
  [synthetic]='["synthetic_apikey"]'
)

read_provider_key() {
  local provider=$1
  local env_name=${provider_key_envs[$provider]}
  local key_file_env_name=${provider_key_file_envs[$provider]}
  local sops_key=${provider_sops_keys[$provider]}

  if [[ -n "${!env_name:-}" ]]; then
    printf '%s' "${!env_name}"
  elif [[ -n "${!key_file_env_name:-}" && -f "${!key_file_env_name}" ]]; then
    tr -d '\n' < "${!key_file_env_name}"
  elif command -v sops >/dev/null && [[ -f "$sops_file" ]]; then
    sops -d --extract "$sops_key" "$sops_file"
  else
    printf 'API key unavailable for %s; set %s or %s.\n' \
      "$provider" "$env_name" "$key_file_env_name" >&2
    return 1
  fi
}

for provider in "${!provider_urls[@]}"; do
  output="$repo_root/${provider_outputs[$provider]}"
  response=$(mktemp)
  trap 'rm -f "$response"' EXIT

  curl --fail --silent --show-error \
    -H "Authorization: Bearer $(read_provider_key "$provider")" \
    "${provider_urls[$provider]}" > "$response"

  jq -e '(.data | type == "array") and (.data | length > 0)' "$response" >/dev/null
  install -D -m 0644 "$response" "$output"
  printf 'Updated %s from %s (%s models).\n' \
    "$output" "$provider" "$(jq '.data | length' "$response")"
done
