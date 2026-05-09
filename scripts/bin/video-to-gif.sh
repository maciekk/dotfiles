#!/bin/sh

INPUT_FILE=$1
OUTPUT_FILE="output.gif"

ffmpeg\
  -i $INPUT_FILE\
  -vf "fps=10,scale=1280:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse"\
  $OUTPUT_FILE
