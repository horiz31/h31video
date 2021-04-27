#!/bin/bash
# script to start the red5 streaming service
# note that we assume a udev rule is in place which sets the red5 video source to /dev/red51. This should happen during provision
#
SUDO=$(test ${EUID} -ne 0 && which sudo)
LOCAL=/usr/local
RED5=${LOCAL}/src/red5pro_linux_streamer
# Serial is based on cpuinfo. May be a more standard way to do this, ultimately pull from mavnet provision
SERIAL=$(${SUDO} cat /proc/cpuinfo | grep Serial | head -1 | cut -f2 -d':' | xargs)
ORG="H31"  #ultimately pull from mavnet provision
STREAMNAME=${ORG}/${SERIAL}

echo "Start Red5 Video Script ${SOURCE}"

if [ ! -z "${RED5_HOST}" ] && [ ! "${RED5_HOST}" == "none" ] ; then
   if [ -d "${RED5}" ] ; then
	        ${RED5}/red5_streamer.bin ${RED5_HOST} ${STREAMNAME} /dev/red51 ${RED5_HEIGHT} ${RED5_WIDTH} ${RED5_FPS} ${RED5_BITRATE} 
   fi         
fi
        

