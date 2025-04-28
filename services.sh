#!/bin/bash
set -euo pipefail

# Set base directory for plist files and metadata
PLIST_DIR="$HOME/Library/LaunchAgents"
META_FILE="$HOME/.local/services/meta.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/plist-template.xml"

# Ensure base folders exist
mkdir -p "$PLIST_DIR"
mkdir -p "$(dirname "$META_FILE")"

# Helper: Generate plist file name based on the script path
generate_plist_name() {
    local script_path="$1"
    local absolute_path
    local plist_name

    # Get the absolute path of the script
    absolute_path=$(realpath "$script_path")
    absolute_path="${absolute_path/#$HOME\//}"

    # Remove the .sh extension and replace slashes with dots
    plist_name=$(echo "$absolute_path" | sed 's|\.sh$||' | sed 's|/|.|g' | tr '[:upper:]' '[:lower:]')

    # Normalize by removing any characters that are not [a-z0-9._-]
    plist_name=$(echo "$plist_name" | tr -cd 'a-z0-9._-')

    # Return the final plist filename
    echo "local.services.$plist_name"
}

# Command: start
start_service() {
    local script_path="$1"
    if [[ ! -x "$script_path" ]]; then
        echo "Error: Script is not executable: $script_path"
        return 1
    fi

    # Generate plist name
    local plist_name
    plist_name=$(generate_plist_name "$script_path")

    # Prepare log paths
    local absolute_path=$(realpath "$script_path")
    mkdir -p ".logs"
    local stdout_path="$absolute_path/.logs/$(basename "$script_path").stdout.log"
    local stderr_path="$absolute_path/.logs/$(basename "$script_path").stderr.log"

    # Read and replace placeholders in template
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        echo "Error: Missing plist template at $TEMPLATE_FILE"
        exit 1
    fi
    local template_file="$TEMPLATE_FILE"
    local plist_content
    plist_content=$(< "$template_file")
    plist_content=${plist_content//\{\{PLIST_NAME\}\}/$plist_name}
    plist_content=${plist_content//\{\{ABSOLUTE_PATH\}\}/$absolute_path}
    plist_content=${plist_content//\{\{STDOUT_PATH\}\}/$stdout_path}
    plist_content=${plist_content//\{\{STDERR_PATH\}\}/$stderr_path}

    # Write the generated plist
    echo "$plist_content" > "$PLIST_DIR/$plist_name.plist"

    # Load the service
    launchctl load "$PLIST_DIR/$plist_name.plist"

    # Save mapping to meta file
    echo "$plist_name|$absolute_path" >> "$META_FILE"

    echo "Started service: $plist_name"
}


# Command: stop
stop_service() {
  local script_path="$1"

  # Generate plist name
  local plist_name
  plist_name=$(generate_plist_name "$script_path")

  local plist_file="$PLIST_DIR/$plist_name.plist"

  if [ ! -f "$plist_file" ]; then
    echo "Service not found for script '$script_path'"
    exit 1
  fi

  launchctl unload "$plist_file"
  rm "$plist_file"

  # Clean from metadata
  grep -v "^$plist_name|" "$META_FILE" > "${META_FILE}.tmp" || true
  mv "${META_FILE}.tmp" "$META_FILE"

  echo "Stopped service: $plist_name"
}

# Command: list
list_services() {
  echo "Running Services:"
  echo "-----------------"
  if [ -f "$META_FILE" ]; then
    while IFS='|' read -r plist_name absolute_path; do
      local status=$(launchctl list | grep "$plist_name")
      local status_code=$(echo "$status" | awk '{print $2}')
      if [ "$status_code" -eq 0 ]; then
        echo "[RUNNING] $absolute_path"
      else
        echo "[STOPPED ($status_code)] $absolute_path"
      fi
    done < "$META_FILE"
  else
    echo "(no services found)"
  fi
}

# Main entry
case "$1" in
  start)
    start_service "$2"
    ;;
  stop)
    stop_service "$2"
    ;;
  list)
    list_services
    ;;
  *)
    echo "Usage: $0 {start|stop|list} [script_path]"
    exit 1
    ;;
esac
