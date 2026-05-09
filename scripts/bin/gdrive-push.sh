#!/usr/bin/bash

SRC=~/GoogleDrive
DEST=gdrive:

# NOTE: the --color ALWAYS is needed, even if rclone itself does not colorize
# sync, and we use grcat instead. It allows --progress to "print in place".
do_sync() {
    MODE=${1:-"--interactive"}
            
    rclone sync \
        $MODE \
        --progress \
        --color ALWAYS \
        $SRC $DEST \
        | grcat ~/.grc/grc.rclone
}

do_sync --dry-run
read -p "--- Review above dry-run, and press Enter to continue PUSH (real run)"
do_sync
