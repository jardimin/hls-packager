#!/bin/bash

# Script created by Daniel Roviriego

: '
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
'

CASA=/media/bambuzal/hls-packager/ # app home folder
WATCH=/media/bambuzal/hls-packager/a-empacotar #folder to watch for
FFMPEG=/home/papoula/bin
AWS_CONFIG_FILE="/home/papoula/.aws/config" #for uploading


# wait for a file to be fully created/written to trigger 

inotifywait  --monitor  -e close_write -e moved_to --format="%w%f" $WATCH | while read file; do

   echo "O arquivo "$file" is in the dir, let's package it!"

# fix file named with spaces and create variable withou basename

newfile=$( echo "$file" | tr -d \\n | sed 's/ /-/g' );
test "$file" != "$newfile" && mv "$file" "$newfile"; 

filebase="`basename "${newfile%.*}"`"

# create folder for storing ts files

MAIN_DIR=$filebase

mkdir  $CASA/$MAIN_DIR
mkdir  $MAIN_DIR/$filebase-3M
mkdir  $MAIN_DIR/$filebase-1M
mkdir  $MAIN_DIR/$filebase-500k

# encode to the video to different qualities

cd $CASA

$FFMPEG/ffmpeg -i $newfile \
   	-acodec copy -map 0  -f segment -vbsf h264_mp4toannexb -flags -global_header  -segment_format mpegts -segment_list_type m3u8 -vcodec libx264 \
	-crf 20 -b:v 2600k -maxrate 2600k -bufsize 2600k -g 30 -segment_list $MAIN_DIR/$filebase-3M/$filebase-3M.m3u8  $MAIN_DIR/$filebase-3M/$filebase-%04d.3M.ts ;

$FFMPEG/ffmpeg -i $newfile \
   	-acodec libfdk_aac -ab 128k  -map 0  -f segment -vbsf h264_mp4toannexb -flags -global_header  -segment_format mpegts -segment_list_type m3u8 -vcodec libx264 \
	-vf "yadif=0, scale=1280:720" \
	-crf 20 -b:v 900k -maxrate 900k -bufsize 900k -g 30 -segment_list $MAIN_DIR/$filebase-1M/$filebase-1M.m3u8  $MAIN_DIR/$filebase-1M/$filebase-%04d.1M.ts ;

$FFMPEG/ffmpeg -i $newfile \
   	-acodec libfdk_aac -ab 64k  -map 0  -f segment -vbsf h264_mp4toannexb -flags -global_header  -segment_format mpegts -segment_list_type m3u8 -vcodec libx264 \
	-vf "yadif=0, scale=640:360" \
	-crf 20 -b:v 450k -maxrate 450k -bufsize 450k -g 30 -segment_list $MAIN_DIR/$filebase-500k/$filebase-500k.m3u8  $MAIN_DIR/$filebase-500k/$filebase-%04d.500k.ts ;


# create variant m3u8 - ugly way

echo "#EXTM3U" > $MAIN_DIR/$filebase.m3u8
echo "#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=500000" >> $MAIN_DIR/$filebase.m3u8
echo "$filebase-500k/$filebase-500k.m3u8" >> $MAIN_DIR/$filebase.m3u8
echo "#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=1000000" >>  $MAIN_DIR/$filebase.m3u8
echo "$filebase-1M/$filebase-1M.m3u8" >> $MAIN_DIR/$filebase.m3u8
echo "#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=3000000" >>  $MAIN_DIR/$filebase.m3u8
echo "$filebase-3M/$filebase-3M.m3u8"  >> $MAIN_DIR/$filebase.m3u8

# upload to s3
aws s3 cp --recursive $filebase/ s3://your_bucket/$filebase --acl public-read


done
