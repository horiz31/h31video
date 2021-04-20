#!/bin/bash
# usage:
#   ensure-elp-driver.sh
#
# Ensure that the elp camera driver is installed since it will be used by the video service to change bitrates

DRY_RUN=false
LOCAL=/usr/local
ELP_H264_UVC=${LOCAL}/src/ELP_H264_UVC
LINUX_UVC=${ELP_H264_UVC}/Linux_UVC_TestAP
UVDL=https://github.com/uvdl
SUDO=$(test ${EUID} -ne 0 && which sudo)

# If the folder already exists, then just show the last commit

if [ -d "${ELP_H264_UVC}" ] ; then
	( cd ${ELP_H264_UVC} && echo -n "ELP_H264_UVC " && git log | head -1 )
	exit 0
fi

# set -e stops execution of the script if an error is encountered
set -e


if ! [ -d "${ELP_H264_UVC}" ] ; then
	$SUDO mkdir -p $(dirname ${ELP_H264_UVC}) && $SUDO chmod a+w $(dirname ${ELP_H264_UVC})
	( cd $(dirname ${ELP_H264_UVC}) && git clone ${UVDL}/$(basename ${ELP_H264_UVC}).git -b master && $SUDO make -C ${LINUX_UVC} )
else
	( cd ${ELP_H264_UVC} && git pull )
fi
# NB: we have satisfied the dependencies of camera-streamer for functions that we use with the above
#( cd ${CAMERA_STREAMER} && $SUDO make dependencies )
( cd ${ELP_H264_UVC} && echo -n "ELP_H264_UVC " && git log | head -1 )

