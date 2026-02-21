#!/bin/sh

# sysmon - Magic Scripts command

VERSION="0.1.0"
SCRIPT_NAME="sysmon"

show_help() {
    _ver="${MS_INSTALLED_VERSION:-$VERSION}"
    [ "$_ver" = "dev" ] && _ver_fmt="$_ver" || _ver_fmt="v${_ver}"
    echo "$SCRIPT_NAME ${_ver_fmt}"
    echo "sysmon"
    echo ""
    echo "Usage:"
    echo "  $SCRIPT_NAME              Run the command"
    echo "  $SCRIPT_NAME --help       Show this help message"
    echo "  $SCRIPT_NAME --version    Show version information"
}

show_version() {
    _ver="${MS_INSTALLED_VERSION:-$VERSION}"
    if [ "$_ver" = "dev" ]; then
        echo "$SCRIPT_NAME $_ver"
    else
        echo "$SCRIPT_NAME v$_ver"
    fi
}

case "$1" in
    -h|--help|help)
        show_help
        exit 0
        ;;
    -v|--version|version)
        show_version
        exit 0
        ;;
esac

echo "Hello from sysmon!"
