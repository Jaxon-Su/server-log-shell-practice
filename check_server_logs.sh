#!/usr/bin/env bash

# Beginner-friendly production log checker.
# It scans ICT / FCT1 / FCT2 folders and prints:
#   1. log count
#   2. PASS / FAIL count
#   3. error code ranking
#   4. latest FAIL log for each station
#
# Run from WSL:
#   bash "/mnt/c/Users/su622/Desktop/Server log/check_server_logs.sh"
#
# Optional: pass another log root folder:
#   bash check_server_logs.sh "/mnt/c/Users/su622/Desktop/Server log"

set -e

# ------------------------------------------------------------
# 1. Decide log root folder
# ------------------------------------------------------------

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$SCRIPT_DIR"


STATIONS=("ICT" "FCT1" "FCT2")

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "ERROR: Log root not found: $ROOT_DIR" >&2
  exit 1
fi

# ------------------------------------------------------------
# 2. Small helper functions
# ------------------------------------------------------------

get_value_from_log() {
  # Usage:
  #   get_value_from_log "file.log" "test_result"
  #
  # It reads lines like:
  #   test_result=PASS
  #
  # Then returns:
  #   PASS

  local log_file="$1"
  local key="$2"
  local line
  local value

  while IFS= read -r line; do
    # Remove UTF-8 BOM if the first line was created by Windows tools.
    line="${line#$'\ufeff'}"

    # Remove Windows CR character if the file uses CRLF.
    line="${line%$'\r'}"

    if [[ "$line" == "$key="* ]]; then
      value="${line#*=}"
      echo "$value"
      return
    fi
  done < "$log_file"

  echo ""
}

print_line() {
  printf '%-8s %8s %8s %8s %8s\n' "$1" "$2" "$3" "$4" "$5"
}

# ------------------------------------------------------------
# 3. Print report title
# ------------------------------------------------------------

echo
echo "=== Production Log Quick Check ==="
echo "Root: $ROOT_DIR"
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo

total_logs=0
total_pass=0
total_fail=0

# This temp file stores failed error info in this format:
#   FCT1|FCT1-E120|Boot sequence timeout
ERROR_TEMP_FILE="$(mktemp)"
trap 'rm -f "$ERROR_TEMP_FILE"' EXIT

print_line "Station" "Logs" "PASS" "FAIL" "Fail%"
print_line "-------" "----" "----" "----" "-----"

# ------------------------------------------------------------
# 4. Scan station folders one by one
# ------------------------------------------------------------

for station in "${STATIONS[@]}"; do
  station_dir="$ROOT_DIR/$station"

  if [[ ! -d "$station_dir" ]]; then
    print_line "$station" "MISSING" "-" "-" "-"
    continue
  fi

  logs=0
  pass=0
  fail=0

  # Find every .log file in this station folder.
  while IFS= read -r -d '' log_file; do
    logs=$((logs + 1))

    result="$(get_value_from_log "$log_file" "test_result")"
    error_code="$(get_value_from_log "$log_file" "error_code")"
    error_meaning="$(get_value_from_log "$log_file" "error_meaning")"

    if [[ "$result" == "PASS" ]]; then
      pass=$((pass + 1))
    elif [[ "$result" == "FAIL" ]]; then
      fail=$((fail + 1))

      if [[ -n "$error_code" && "$error_code" != "NONE" ]]; then
        echo "$station|$error_code|$error_meaning" >> "$ERROR_TEMP_FILE"
      fi
    fi
  done < <(find "$station_dir" -type f -name '*.log' -print0)

  if [[ "$logs" -gt 0 ]]; then
    fail_pct="$(awk -v fail="$fail" -v logs="$logs" 'BEGIN { printf "%.1f%%", fail / logs * 100 }')"
  else
    fail_pct="0.0%"
  fi

  total_logs=$((total_logs + logs))
  total_pass=$((total_pass + pass))
  total_fail=$((total_fail + fail))

  print_line "$station" "$logs" "$pass" "$fail" "$fail_pct"
done

print_line "-------" "----" "----" "----" "-----"

if [[ "$total_logs" -gt 0 ]]; then
  total_fail_pct="$(awk -v fail="$total_fail" -v logs="$total_logs" 'BEGIN { printf "%.1f%%", fail / logs * 100 }')"
else
  total_fail_pct="0.0%"
fi

print_line "TOTAL" "$total_logs" "$total_pass" "$total_fail" "$total_fail_pct"
echo

# ------------------------------------------------------------
# 5. Print error code ranking
# ------------------------------------------------------------

echo "=== Error Code Ranking ==="

if [[ ! -s "$ERROR_TEMP_FILE" ]]; then
  echo "No FAIL error codes found."
else
  printf '%-6s %-8s %-14s %s\n' "Count" "Station" "ErrorCode" "Meaning"
  printf '%-6s %-8s %-14s %s\n' "-----" "-------" "---------" "-------"

  # sort: group the same error lines together.
  # uniq -c: count repeated lines.
  # sort -nr: show the largest count first.
  sort "$ERROR_TEMP_FILE" |
    uniq -c |
    sort -nr |
    while read -r count error_line; do
      station="${error_line%%|*}"
      remain="${error_line#*|}"
      error_code="${remain%%|*}"
      error_meaning="${remain#*|}"

      printf '%-6s %-8s %-14s %s\n' "$count" "$station" "$error_code" "$error_meaning"
    done
fi

echo

# ------------------------------------------------------------
# 6. Print latest FAIL log for each station
# ------------------------------------------------------------

echo "=== Latest FAIL Logs ==="

for station in "${STATIONS[@]}"; do
  station_dir="$ROOT_DIR/$station"

  if [[ ! -d "$station_dir" ]]; then
    continue
  fi

  latest_fail_file=""
  latest_fail_time=""

  while IFS= read -r -d '' log_file; do
    result="$(get_value_from_log "$log_file" "test_result")"

    if [[ "$result" != "FAIL" ]]; then
      continue
    fi

    timestamp_start="$(get_value_from_log "$log_file" "timestamp_start")"

    # The timestamp format is yyyy-mm-dd hh:mm:ss.xxx.
    # String compare works here because the date format goes from big to small.
    if [[ -z "$latest_fail_time" || "$timestamp_start" > "$latest_fail_time" ]]; then
      latest_fail_time="$timestamp_start"
      latest_fail_file="$log_file"
    fi
  done < <(find "$station_dir" -type f -name '*.log' -print0)

  if [[ -z "$latest_fail_file" ]]; then
    printf '%-8s %s\n' "$station" "No FAIL logs"
    continue
  fi

  code="$(get_value_from_log "$latest_fail_file" "error_code")"
  meaning="$(get_value_from_log "$latest_fail_file" "error_meaning")"
  file_name="$(basename "$latest_fail_file")"

  printf '%-8s %s | %s | %s | %s\n' "$station" "$latest_fail_time" "$code" "$meaning" "$file_name"
done

echo
echo "Done."
