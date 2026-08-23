#!/usr/bin/env bash

# Subscribe each tool's skills directory to the shared skills pool at ~/.agents/skills.
# Links every pool entry into each tool dir, never overwrites a real (installer-written)
# entry, and prunes dangling pool symlinks left after a skill is removed from the pool.

set -Eeuo pipefail

readonly POOL="${HOME}/.agents/skills"
readonly TOOL_DIRS=(
    "${HOME}/.claude/skills"
)

if [ ! -d "${POOL}" ]; then
    echo "run_after_40-link-shared-skills: ${POOL} is not a directory, skipping" >&2
    exit 0
fi

for tool_dir in "${TOOL_DIRS[@]}"; do
    mkdir -p "${tool_dir}"

    for entry in "${POOL}"/*; do
        [ -e "${entry}" ] || continue

        name="$(basename "${entry}")"
        target="${tool_dir}/${name}"

        if [ -e "${target}" ] && [ ! -L "${target}" ]; then
            echo "run_after_40-link-shared-skills: ${target} is a real entry, keeping it and skipping the pool link for ${name}" >&2
            continue
        fi

        ln -sfn "${entry}" "${target}"
    done

    while IFS= read -r -d '' link; do
        link_target="$(readlink "${link}")"
        case "${link_target}" in
            "${POOL}"/*)
                if [ ! -e "${link_target}" ]; then
                    rm -f "${link}"
                fi
                ;;
        esac
    done < <(find "${tool_dir}" -maxdepth 1 -type l -print0)
done
