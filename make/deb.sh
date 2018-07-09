#!/bin/bash

set -e

function place_files() {
    local pkgname="$1"
    local targdir="$2"

    if [ "$pkgname" == "libpeekaygee" ]; then
        mkdir -p "$targdir/usr/lib/peekaygee"
        cp src/libpeekaygee.sh src/libpeekaygee-srvworker.sh "$targdir/usr/lib/peekaygee/"
    elif [ "$pkgname" == "peekaygee" ]; then
        mkdir -p "$targdir/usr/bin"
        cp src/peekaygee src/peekaygee-archive src/peekaygee-push "$targdir/usr/bin/"
    elif [ "$pkgname" == "peekaygee-srvworker-deb" ]; then
        mkdir -p "$targdir/usr/bin"
        cp src/peekaygee-srvworker-deb "$targdir/usr/bin/"
    fi
}

# Include the library and go
if [ -z "$KSUTILS_PATH" ]; then 
    KSUTILS_PATH=/usr/lib/ks-std-libs
fi
if [ ! -e "$KSUTILS_PATH/libdebpkgbuilder.sh" ]; then
    >&2 echo
    >&2 echo "E: Your system doesn't appear to have ks-std-libs installed. (Looking for"
    >&2 echo "   library 'libdebpkgbuilder.sh' in $KSUTILS_PATH. To define a different"
    >&2 echo "   place to look for this file, just export the 'KSUTILS_PATH' environment"
    >&2 echo "   variable.)"
    >&2 echo
    exit 4
else
    . "$KSUTILS_PATH/libdebpkgbuilder.sh"
    build
fi

