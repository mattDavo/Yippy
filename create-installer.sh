#!/bin/sh

if test $# -ne 1
then
    echo "$0 usage: $0 [App name]"
    exit 1
fi

dmgName="$1.dmg"
appName="$1.app"

test -f "$dmgName" && rm "$dmgName"
create-dmg \
--volname "Yippy Installer" \
--window-pos 200 120 \
--window-size 800 400 \
--icon-size 100 \
--icon "$appName" 200 190 \
--hide-extension "$appName" \
--app-drop-link 600 185 \
"$dmgName" \
"$appName"
