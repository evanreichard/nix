#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
manifest="$repo_root/modules/nixos/services/llama-swap/providers/providers.json"

read_provider_key() {
  local provider=$1
  local info=$2
  local env_name
  local sops_file
  local sops_secret

  env_name=$(jq -r '.apiKeyEnv // empty' <<< "$info")
  sops_file=$(jq -r '.sopsFile // empty' <<< "$info")
  sops_secret=$(jq -r '.sopsSecret // empty' <<< "$info")

  if [[ -n "$env_name" && -n "${!env_name:-}" ]]; then
    printf '%s' "${!env_name}"
  elif [[ -n "$sops_file" && -n "$sops_secret" ]] \
    && command -v sops >/dev/null \
    && [[ -f "$repo_root/$sops_file" ]]; then
    sops -d --extract "[\"${sops_secret}\"]" "$repo_root/$sops_file"
  else
    printf 'API key unavailable for %s; set %s.\n' "$provider" "$env_name" >&2
    return 1
  fi
}

while IFS= read -r provider; do
  info=$(jq -c --arg provider "$provider" '.[$provider]' "$manifest")
  base_url=$(jq -r '.baseUrl' <<< "$info")
  models_file=$(jq -r '.modelsFile' <<< "$info")
  output="$repo_root/modules/nixos/services/llama-swap/providers/$models_file"
  api_key=$(read_provider_key "$provider" "$info")
  response=$(mktemp)
  trap 'rm -f "$response"' EXIT

  curl --fail --silent --show-error \
    -H "Authorization: Bearer $api_key" \
    "${base_url%/}/models" > "$response"

  jq -e '(.data | type == "array") and (.data | length > 0)' "$response" >/dev/null
  install -D -m 0644 "$response" "$output"
  printf 'Updated %s from %s (%s models).\n' \
    "$output" "$provider" "$(jq '.data | length' "$response")"
done < <(jq -r 'keys[]' "$manifest")
