#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Create a batch of Linear issues via linear-cli.

Usage:
  create-batch-issues.sh [options]

Options:
  --count N           Number of issues to create. Default: 251
  --team KEY          Linear team key. Default: MR
  --prefix TEXT       Title prefix. Default: 251 test task
  --description TEXT  Optional issue description for every created issue
  --start-at N        Starting numeric suffix. Default: 1
  --dry-run           Preview commands without creating issues
  --yes               Skip confirmation prompt
  -h, --help          Show this help

Auth:
  Use configured linear-cli profile, or export LINEAR_API_KEY before running.

Examples:
  export LINEAR_API_KEY='lin_api_xxx'
  ./scripts/create-batch-issues.sh --dry-run
  ./scripts/create-batch-issues.sh --count 10 --prefix 'Load test task' --yes
EOF
}

count=251
team="MR"
prefix="251 test task"
description=""
start_at=1
dry_run=false
assume_yes=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --count)
      count="${2:?missing value for --count}"
      shift 2
      ;;
    --team)
      team="${2:?missing value for --team}"
      shift 2
      ;;
    --prefix)
      prefix="${2:?missing value for --prefix}"
      shift 2
      ;;
    --description)
      description="${2:?missing value for --description}"
      shift 2
      ;;
    --start-at)
      start_at="${2:?missing value for --start-at}"
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    --yes)
      assume_yes=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! [[ "$count" =~ ^[0-9]+$ ]] || (( count < 1 )); then
  echo "--count must be a positive integer" >&2
  exit 1
fi

if ! [[ "$start_at" =~ ^[0-9]+$ ]] || (( start_at < 1 )); then
  echo "--start-at must be a positive integer" >&2
  exit 1
fi

if ! command -v linear-cli >/dev/null 2>&1; then
  echo "linear-cli not found in PATH" >&2
  exit 1
fi

export LINEAR_CLI_NO_PAGER="${LINEAR_CLI_NO_PAGER:-true}"

if [[ "$dry_run" != true && -z "${LINEAR_API_KEY:-}" ]]; then
  if ! linear-cli users me --output json >/dev/null 2>&1; then
    echo "No LINEAR_API_KEY in environment and no working linear-cli auth configuration" >&2
    exit 1
  fi
fi

if [[ "$dry_run" != true && "$assume_yes" != true ]]; then
  echo "About to create $count issue(s) in team '$team' with prefix '$prefix'."
  read -r -p "Continue? [y/N] " reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
  fi
fi

created=0
failed=0

for ((offset = 0; offset < count; offset++)); do
  index=$((start_at + offset))
  title=$(printf "%s %03d" "$prefix" "$index")

  cmd=(linear-cli issues create "$title" --team "$team" --output json)
  if [[ -n "$description" ]]; then
    cmd+=(--description "$description")
  fi
  if [[ "$dry_run" == true ]]; then
    cmd+=(--dry-run)
  fi

  echo "[$((offset + 1))/$count] $title"

  if output=$("${cmd[@]}" 2>&1); then
    printf '%s\n' "$output"
    created=$((created + 1))
  else
    printf '%s\n' "$output" >&2
    failed=$((failed + 1))
  fi
done

echo
echo "Done. successful=$created failed=$failed dry_run=$dry_run"

if (( failed > 0 )); then
  exit 1
fi
