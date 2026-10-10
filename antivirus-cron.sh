#!/usr/bin/env bash

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <dir> <malicious_dir>"
    exit 1
fi

dir_arg=$1
quarantine_arg=$2

if [[ ! -d "$dir_arg" ]]; then
    echo "Error: source directory does not exist: $dir_arg" >&2
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
whitelist="$script_dir/whitelist.txt"

is_whitelisted() {
    local checksum

    [[ -f "$whitelist" ]] || return 1
    checksum=$(sha256sum -- "$1" | cut -d ' ' -f 1) || return 1
    grep -Fqx -- "$checksum" "$whitelist"
}

is_malicious() {
    local filename
    filename=$(basename -- "$1")

    case "$filename" in
        *.exe|*.bat|*.vbs|*.scr|*.ps1) return 0 ;;
    esac

    grep -Eiq -- 'virus|trojan|malware|worm|ransomware' "$1"
}

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
