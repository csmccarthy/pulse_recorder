#!/bin/bash
file_name=$1
./bpm-tag "music/${file_name}.mp3"
bpm=$(id3v2 --list "music/${file_name}.mp3" | grep TBPM | grep -oEi '[0-9]+.[0-9]+')
touch "music/${file_name}.bpm-tag"
echo $bpm > "music/${file_name}.bpm-tag"