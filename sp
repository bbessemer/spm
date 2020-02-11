#!/bin/bash

case $1 in
    build)
        ;;
    *)
        echo "$0: error: unrecognized subcommand $1" >&2
        exit 1
esac

export SP_ROOT=$(dirname $(readlink -f $0))
exec $SP_ROOT/bin/$1.sh "${@:2}"