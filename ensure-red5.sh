#!/bin/bash
# usage:
#   ensure-red5.sh
#
# This script ensures that the red5 linux sdk is installed, which is used to stream video to the server for redistribution

DRY_RUN=false
LOCAL=/usr/local
RED5=${LOCAL}/src/red5pro_linux_streamer
H31=https://github.com/horiz31
SUDO=$(test ${EUID} -ne 0 && which sudo)

# set -e stops execution of the script if an error is encountered
set -e

# if the folder does not exist, create, clone and make. If it does, then just pull and make
if ! [ -d "${RED5}" ] ; then
	$SUDO mkdir -p $(dirname ${RED5}) && $SUDO chmod a+w $(dirname ${RED5})
	( cd $(dirname ${RED5}) && git clone ${H31}/$(basename ${RED5}).git -b master && $SUDO make -C ${RED5} clean && $SUDO make -C ${RED5} )
else
	( cd ${RED5} && git pull && $SUDO make -C ${RED5} clean && $SUDO make -C ${RED5} )
fi

( cd ${RED5} && echo -n "RED5 Streamer " && git log | head -1 )

