#!/usr/bin/bash

SRC=~/GoogleDrive
DEST=gdrive:

riff $SRC/$1 <(rclone cat $DEST/$1)
