#!/bin/bash

set -e

function find_config_files() {
    if [ -z "$CONFFILE_NAME" ]; then
        >&2 echo
        >&2 echo "E: Programmer: Function \`find_config_files\` requires global variable CONFFILE_NAME to be set to the"
        >&2 echo "   basename of the config file being searched for. Usually, this will be either 'peekaygee.json' or"
        >&2 echo "   'peekaygee-archive.json'."
        >&2 echo
        exit 88
    fi

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
        local i=1
        local q=".[0]"
        while [ "$i" -lt "${#CONFIG_FILES[@]}" ]; do
            q="$q * .[$i]"
            !((i++))
        done
        if ! MERGED_CONFIG="$(jq -cs "$q" ${CONFIG_FILES[@]})"; then
            >&2 echo
            >&2 echo "E: Problems merging config! Can't continue."
            >&2 echo
            exit 92
        fi
    fi
    echo "$MERGED_CONFIG"
}

function config_jq() {
    if ! get_merged_config &>/dev/null; then
        exit "${PIPESTATUS[0]}"
    fi
    declare -a args
    while [ "$#" -gt 0 ]; do
        args+=("$1")
        shift
    done
    echo "$MERGED_CONFIG" | jq "${args[@]}"
}

