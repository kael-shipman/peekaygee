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
            >&2 echo "[verbose$1] $@"
        else
            echo "$@"
        fi
    fi
}

function peekaygee_prep_srvworker_add() {
    if [ -z "$ARCHIVE_TYPE" ]; then
        >&2 echo
        >&2 echo "E: Programmer: You must define the ARCHIVE_TYPE global variable in your worker script before"
        >&2 echo "   using the peekaygee_pre_srvworker_* functions"
        >&2 echo
        exit 20
    fi

    ARCHIVE="$1"
    PKGFILE="$2"
    OPTIONS="$3"
    FILESPEC="$4"

    if [ -z "$ARCHIVE" ] || [ ! -d "$ARCHIVE" ]; then
        >&2 echo
        >&2 echo "E: First argument must be a(n) $ARCHIVE_TYPE archive root path (you passed '$ARCHIVE')"
        >&2 echo
        exit 4
    fi
    ARCHIVE="$(readlink -f "$ARCHIVE")"

    if [ -z "$PKGFILE" ] || ! echo "$PKGFILE" | grep -q "$FILESPEC" || [ ! -e "$ARCHIVE/$PKGFILE" ]; then
        >&2 echo
        >&2 echo "E: Second argument must be a valid package file relative to '$ARCHIVE'."
        >&2 echo "   (You passed '$PKGFILE')"
        >&2 echo
        exit 5
    fi
    PKGFILE="$(readlink -f "$ARCHIVE/$PKGFILE")"

    if [ -n "$OPTIONS" ] && ! echo "$OPTIONS" | jq '.' >/dev/null; then
        >&2 echo
        >&2 echo "E: Third argument must be a valid json string, if given. You passed '$OPTIONS'."
        >&2 echo
        exit 6
    fi

    # Get target archive dir based on whether it's public or private
    local VISIBILITY="$(basename "$(dirname "$PKGFILE")")"
    if [ "$VISIBILITY" == "private" ]; then
        TARG_ARCHIVE="$ARCHIVE/webroot/private/$ARCHIVE_TYPE"
    elif [ "$VISIBILITY" == "public" ]; then
        TARG_ARCHIVE="$ARCHIVE/webroot/public/$ARCHIVE_TYPE"
    fi
}

