#!/usr/bin/env bash

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <dir> <malicious_dir> <interval-secs>"
    exit 1
fi

dir_arg=$1
quarantine_arg=$2
interval=$3

if [[ ! -d "$dir_arg" ]]; then
    echo "Error: source directory does not exist: $dir_arg" >&2
    exit 1
fi

if [[ ! "$interval" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: interval must be a positive integer." >&2
    exit 1
fi

mkdir -p -- "$quarantine_arg" || exit 1

dir=$(realpath -- "$dir_arg") || exit 1
malicious_dir=$(realpath -- "$quarantine_arg") || exit 1

if [[ "$dir" == "$malicious_dir" ]]; then
    echo "Error: source and quarantine directories must be different." >&2
    exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
last="$script_dir/directory-info.last"
new="$script_dir/directory-info.new"
whitelist="$script_dir/whitelist.txt"

is_whitelisted() {
    local file=$1
    local checksum

    [[ -f "$whitelist" ]] || return 1

    checksum=$(sha256sum -- "$file" | cut -d ' ' -f 1) || return 1
    grep -Fqx -- "$checksum" "$whitelist"
}

is_malicious() {
    local file=$1
    local filename

    filename=$(basename -- "$file")

    case "$filename" in
        *.exe|*.bat|*.vbs|*.scr|*.ps1)
            return 0
            ;;
    esac

    grep -Eiq -- 'virus|trojan|malware|worm|ransomware' "$file"
}

scan_directory() {
    local file filename

    while IFS= read -r -d '' file; do
        if is_whitelisted "$file"; then
            continue
        fi

        if is_malicious "$file"; then
            filename=$(basename -- "$file")

            if [[ -e "$malicious_dir/$filename" ]]; then
                echo "Error: quarantine already contains $filename; original file was not deleted." >&2
                continue
            fi

            if cp -p -- "$file" "$malicious_dir/$filename"; then
                if rm -- "$file"; then
                    printf '%s is malicious and it is DELETED\n' "$filename"
                else
                    echo "Error: could not delete $file" >&2
                fi
            else
                echo "Error: could not quarantine $file" >&2
            fi
        fi
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type f -print0)
}

take_snapshot() {
    ls -l -- "$dir" > "$1"
}

# Initial scan immediately.
scan_directory
take_snapshot "$last"

echo "Antivirus daemon is running. Press Ctrl+C to stop."

while true; do
    sleep "$interval"
    take_snapshot "$new"

    if ! cmp -s "$last" "$new"; then
        echo "Directory change detected. Scanning..."
        scan_directory
        take_snapshot "$last"
    fi
done
