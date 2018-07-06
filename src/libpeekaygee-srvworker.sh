#!/bin/bash

set -e

function peekaygee_prep_srvworker_add() {
    if [ -z "$ARCHIVE_TYPE" ]; then
        >&2 echo
        >&2 echo "E: Programmer: You must define the ARCHIVE_TYPE global variable in your worker script before"
        >&2 echo "   using the peekaygee_pre_srvworker_* functions"
        >&2 echo
        exit 20
    fi

    ARCHIVE="$1"
    DEBFILE="$2"
    OPTIONS="$3"

    if [ -z "$ARCHIVE" ] || [ ! -d "$ARCHIVE" ]; then
        >&2 echo
        >&2 echo "E: First argument must be an archive root path (you passed '$ARCHIVE')"
        >&2 echo
        exit 4
    fi
    ARCHIVE="$(readlink -f "$ARCHIVE")"

    if [ -z "$DEBFILE" ] || ! echo "$DEBFILE" | grep -q '\.deb$'; then
        >&2 echo
        >&2 echo "E: Second argument must be a valid debian package file (you passed '$DEBFILE')"
        >&2 echo
        exit 5
    fi
    DEBFILE="$(readlink -f "$DEBFILE")"

    if [ -n "$OPTIONS" ] && ! echo "$OPTIONS" | jq >/dev/null; then
        >&2 echo
        >&2 echo "E: Third argument must be a valid json string, if given. You passed '$OPTIONS'."
        >&2 echo
        exit 6
    fi

    # Get target archive dir based on whether it's public or private
    if [ "$(basename "$(dirname "$DEBFILE")")" == "private" ]; then
        TARG_ARCHIVE="$ARCHIVE/webroot/private/$ARCHIVE_TYPE"
    fi
}

