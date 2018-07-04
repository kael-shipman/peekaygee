#!/bin/bash

function find_config_files() {
    if ! declare -p CONFIG_FILES 2> /dev/null | grep -q '^declare \-ga'; then
        declare -ga CONFIG_FILES
        local HOME_CONF="$HOME/.config/peekaygee"
        if [ -e "$HOME_CONF/peekaygee.json" ]; then
            CONFIG_FILES["${#CONFIG_FILES[@]}"]="$HOME_CONF/peekaygee.json"
        fi

        local REPO_CONF="$PWD"
        if [ -e "$REPO_CONF/peekaygee.json" ]; then
            CONFIG_FILES["${#CONFIG_FILES[@]}"]="$REPO_CONF/peekaygee.json"
        fi

        if [ "${#CONFIG_FILES[@]}" -eq 0 ]; then
            >&2 echo
            >&2 echo "E: No config files found. You should have either a global config file at"
            >&2 echo "   '$HOME_CONF/peekaygee.json', a repo-specific file at"
            >&2 echo "   '$REPO_CONF/peekaygee.json', or both."
            >&2 echo
            exit 90
        fi
    fi
    echo "${CONFIG_FILES[@]}"
}

function get_merged_config() {
    if [ -z "$MERGED_CONFIG" ]; then
        find_config_files >/dev/null
        if [ "${#CONFIG_FILES[@]}" -eq 1 ]; then
            MERGED_CONFIG="$(jq -c "." "${CONFIG_FILES[@]}")"
        else
            if ! MERGED_CONFIG="$(jq -cs ".[0] * .[1]" ${CONFIG_FILES[@]})"; then
                >&2 echo
                >&2 echo "E: Problems merging config! Can't continue."
                >&2 echo
                exit 92
            fi
        fi
    fi
    echo "$MERGED_CONFIG"
}

function config_jq() {
    echo "$(get_merged_config | jq "$@")"
}

