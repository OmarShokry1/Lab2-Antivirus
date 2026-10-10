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

if [[ ! -d "$quarantine_arg" ]]; then
    echo "Error: quarantine directory does not exist: $quarantine_arg" >&2
    exit 1
fi

dir=$(realpath -- "$dir_arg") || exit 1
malicious_dir=$(realpath -- "$quarantine_arg") || exit 1

if [[ "$dir" == "$malicious_dir" ]]; then
    echo "Error: source and quarantine directories must be different." >&2
    exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
whitelist="$script_dir/whitelist.txt"

if ! find "$malicious_dir" -maxdepth 1 -type f -print -quit | grep -q .; then
    echo "No malicious files to review."
    exit 0
fi

while true; do
    mapfile -d '' -t files < <(
        find "$malicious_dir" -maxdepth 1 -type f -print0 | sort -z
    )

    if [[ ${#files[@]} -eq 0 ]]; then
        echo "No files remain in quarantine."
        break
    fi

    echo
    echo "Files in quarantine:"

    for i in "${!files[@]}"; do
        printf '%d) %s\n' "$((i + 1))" "$(basename -- "${files[$i]}")"
    done

    echo "Enter 0 to exit."
    read -r -p "Choose a file by number: " choice

    if [[ "$choice" == "0" ]]; then
        break
    fi

    if [[ ! "$choice" =~ ^[0-9]+$ ]] ||
       (( choice < 1 || choice > ${#files[@]} )); then
        echo "Invalid selection. Try again."
        continue
    fi

    selected=${files[$((choice - 1))]}
    filename=$(basename -- "$selected")

    echo
    echo "Selected: $filename"
    echo "1) Restore this file"
    echo "2) Permanently delete this file"
    echo "3) Leave this file as-is and return to the list"

    read -r -p "Choose an action (1-3): " action

    case "$action" in
        1)
            if [[ -e "$dir/$filename" ]]; then
                echo "Error: a file with that name already exists in $dir_arg." >&2
                continue
            fi

            checksum=$(sha256sum -- "$selected" | cut -d ' ' -f 1) || {
                echo "Error: could not calculate file checksum." >&2
                continue
            }

            if mv -- "$selected" "$dir/"; then
                if touch "$whitelist" &&
                   { grep -Fqx -- "$checksum" "$whitelist" ||
                     printf '%s\n' "$checksum" >> "$whitelist"; }; then
                    printf 'Restored %s to %s.\n' "$filename" "$dir_arg"
                else
                    echo "Warning: file restored, but whitelist update failed." >&2
                    printf 'Restored %s to %s.\n' "$filename" "$dir_arg"
                fi
            else
                echo "Error: could not restore $filename." >&2
            fi
            ;;
        2)
            if rm -- "$selected"; then
                printf '%s permanently deleted.\n' "$filename"
            else
                echo "Error: could not delete $filename." >&2
            fi
            ;;
        3)
            echo "Leaving $filename unchanged."
            ;;
        *)
            echo "Invalid action. Returning to the list."
            ;;
    esac
done
