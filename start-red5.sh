#!/bin/bash
# script to start the red5 streaming service
# note that we assume a udev rule is in place which sets the red5 video source to /dev/red51. This should happen during provision
#
SUDO=$(test ${EUID} -ne 0 && which sudo)
LOCAL=/usr/local
RED5=${LOCAL}/src/red5pro_linux_streamer

echo "Start Red5 Video Script ${SOURCE}"

if [ ! -z "${RED5_HOST}" ] && [ ! "${RED5_HOST}" == "none" ] ; then
   if [ -d "${RED5}" ] ; then
	        ${RED5}/red5_streamer.bin ${RED5_HOST} /dev/red51 ${RED5_HEIGHT} ${RED5_WIDTH} ${RED5_FPS} ${RED5_BITRATE} 
   fi         
fi
        

