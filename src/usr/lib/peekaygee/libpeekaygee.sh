#!/bin/bash

set -e

function say() {
    # Make sure we've got verbosity
    if [ -z "$VERBOSITY" ]; then
        >&2 echo "E: Programmer: You must set the VERBOSITY global variable to an integer"
        exit 33
    fi

    # Make sure we've passed a level for this message
    local level="$1"
    shift
    if ! [ "$level" -eq "$level" ] &>/dev/null; then
        >&2 echo "E: Programmer: First argument to 'say' must be an integer representing"
        >&2 echo "   level of verbosity at which to output this message"
        exit 34
    fi

    if [ "$level" -le "$VERBOSITY" ]; then
        if [ "$level" -gt 0 ]; then
            >&2 echo "[verbose$level] $@"
        else
            echo "$@"
        fi
    fi
}

function get_config_file_options() {
    if [ -z "$CONFFILE_OPTIONS" ]; then
        say 2 "get_config_file_options: CONFFILE_OPTIONS not set. Gathering options."

        if [ -z "$CONFFILE_NAME" ]; then
            >&2 echo
            >&2 echo "E: Programmer: Function \`get_config_file_options\` requires global variable CONFFILE_NAME to be set to the"
            >&2 echo "   basename of the config file being searched for. Usually, this will be either 'peekaygee.json' or"
            >&2 echo "   'peekaygee-archive.json'."
            >&2 echo
            exit 88
        fi

        declare -ga CONFFILE_OPTIONS
        for confpath in "/etc/peekaygee" "/etc/peekaygee/$CONFFILE_NAME.d" "$HOME/.config/peekaygee" "$PWD"; do
            if echo "$confpath" | grep -q "\.d$"; then
                say 3 "get_config_file_options: Adding '$confpath' to options"
                CONFFILE_OPTIONS+=("$confpath")
            else
                say 3 "get_config_file_options: Adding '$confpath/$CONFFILE_NAME' to options"
                CONFFILE_OPTIONS+=("$confpath/$CONFFILE_NAME")
            fi
        done
    else
        say 2 "get_config_file_options: CONFFILE_OPTIONS already set. Using cached."
    fi
    say 3 "get_config_file_options: Config file options: ${CONFFILE_OPTIONS[@]}"
    echo "${CONFFILE_OPTIONS[@]}"
}

function find_config_files() {
    if ! declare -p CONFIG_FILES 2> /dev/null | grep -q '^declare \-ga'; then
        say 2 "find_config_files: CONFIG_FILES not set. Finding config files."

        get_config_file_options >/dev/null
        declare -ga CONFIG_FILES
        for f in "${CONFFILE_OPTIONS[@]}"; do
            # Handle .d config directories
            if echo "$f" | grep -q "\.d$"; then
                say 3 "find_config_files: trying conf directory '$f'."
                if [ -d "$f" ]; then
                    say 3 "find_config_files: conf directory '$f' exists. Checking for fragments."
                    for part in "$f"/*; do
                        # May get a null glob, so still have to check to see if the file exists
                        if [ -e "$part" ]; then
                            say 3 "find_config_files: adding '$part' to CONFIG_FILES"
                            CONFIG_FILES+=("$part")
                        fi
                    done
                else
                    say 3 "find_config_files: conf directory '$f' doesn't exist. Skipping."
                fi

            # Handle regular config files
            else
                if [ -e "$f" ]; then
                    say 3 "find_config_files: config file '$f' exists. Adding to CONFIG_FILES"
                    CONFIG_FILES+=("$f")
                else
                    say 3 "find_config_files: config file '$f' doesn't exist. Skipping."
                fi
            fi
        done

    else
        say 2 "find_config_files: CONFIG_FILES already set. Using cached."
    fi
    say 3 "find_config_files: Found config files: ${CONFIG_FILES[@]}"
    echo "${CONFIG_FILES[@]}"
}

function get_merged_config() {
    if [ -z "$MERGED_CONFIG" ]; then
        say 2 "get_merged_config: MERGED_CONFIG not set. Merging configs...."

        find_config_files >/dev/null

        # If there are config files, merge them
        if [ "${#CONFIG_FILES[@]}" -gt 0 ]; then
            say 2 "get_merged_config: Config files found. Attempting to merge."
            local i=1
            local q=".[0]"
            while [ "$i" -lt "${#CONFIG_FILES[@]}" ]; do
                q="$q * .[$i]"
                !((i++))
            done
            say 3 "get_merged_config: running 'jq -cs \"$q\" ${CONFIG_FILES[@]}'"
            if ! MERGED_CONFIG="$(jq -cs "$q" ${CONFIG_FILES[@]})"; then
                >&2 echo
                >&2 echo "E: Problems merging config! Can't continue."
                >&2 echo
                exit 92
            else
                say 2 "get_merged_config: config successfully merged."
            fi

        # Otherwise, use an empty object
        else
            say 2 "get_merged_config: No config files found. Using empty config"
            MERGED_CONFIG="{}"
        fi
    else
        say 2 "get_merged_config: MERGED_CONFIG already set. Using cached."
    fi
    say 3 "get_merged_config: Merged config: $MERGED_CONFIG"
    echo "$MERGED_CONFIG"
}

function require_config() {
    if find_config_files >/dev/null; then
        if [ "${#CONFIG_FILES[@]}" -eq 0 ]; then
            >&2 echo
            >&2 echo "E: No config files found. You need to have at least one of the following config files:"
            >&2 echo
            for f in "${CONFFILE_OPTIONS[@]}"; do
                >&2 echo "   - $f"
            done
            >&2 echo
            exit 90
        fi
    else
        exit "$?"
    fi
}

function check_config() {
    say 2 "Checking config"
    if ! config_jq '.' >/dev/null; then
        exit "${PIPESTATUS[0]}"
    fi
    say 2 "Config valid"
}

function refresh_config() {
    say 2 "refresh_config: Refreshing config...."
    unset CONFFILE_OPTIONS
    unset CONFIG_FILES
    unset MERGED_CONFIG
    get_merged_config >/dev/null
}

function config_jq() {
    say 2 "config_jq: getting config"
    if ! get_merged_config >/dev/null; then
        exit "${PIPESTATUS[0]}"
    fi
    declare -a args
    while [ "$#" -gt 0 ]; do
        args+=("$1")
        shift
    done
    say 2 "config_jq: running jq on config with args '${args[@]}'"
    echo "$MERGED_CONFIG" | jq "${args[@]}"
}





function show_remotes() {
    say 2 "Showing remotes"
    if ! REMOTES=$(config_jq -e '.remotes'); then
        exit "${PIPESTATUS[0]}"
    else
        OUT=
        while read -r -d $'\x1e' remote || [[ $remote ]]; do
            OUT="$OUT$remote"
            if [ "$VERBOSITY" -gt 0 ]; then
                OUT="$OUT    $(echo "$REMOTES" | jq -jc '.["'$remote'"].url')"
            fi
            OUT="$OUT"$'\n'
        done < <(echo "$REMOTES" | jq -jc 'keys | join("\u001e")')
        echo "$OUT" | column -t
    fi
}

