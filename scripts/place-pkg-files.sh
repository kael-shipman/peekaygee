#!/bin/bash

set -e

function place_files() {
    local pkgname="$1"
    local targdir="$2"
    local pkgtype="$3"

    if [ "$pkgname" == "libpeekaygee" ]; then
        mkdir -p "$targdir/usr"
        cp -R src/usr/lib "$targdir/usr/"
    elif [ "$pkgname" == "peekaygee" ]; then
        mkdir -p "$targdir/usr/bin"
        cp src/usr/bin/{peekaygee,peekaygee-archive,peekaygee-push,peekaygee-build} "$targdir/usr/bin/"
    elif [ "$pkgname" == "peekaygee-builder-deb" ]; then
        mkdir -p "$targdir/usr/bin"
        cp src/usr/bin/peekaygee-builder-deb "$targdir/usr/bin/"
    elif [ "$pkgname" == "peekaygee-srvworker-deb-reprepro" ]; then
        mkdir -p "$targdir/usr/bin"
        cp src/usr/bin/peekaygee-srvworker-deb-reprepro "$targdir/usr/bin/"
    else
        >&2 echo
        >&2 echo "E: Don't know how to handle packages of type $pkgtype"
        >&2 echo
        exit 14
    fi
}

place_files "$1" "$2" "$3"

