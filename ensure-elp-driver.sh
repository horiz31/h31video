#!/bin/bash
# usage:
#   ensure-elp-driver.sh
#
# This script ensures that the elp camera driver is installed since it will be used by the video service to change bitrates

DRY_RUN=false
LOCAL=/usr/local
ELP_H264_UVC=${LOCAL}/src/ELP_H264_UVC
LINUX_UVC=${ELP_H264_UVC}/Linux_UVC_TestAP
UVDL=https://github.com/uvdl
SUDO=$(test ${EUID} -ne 0 && which sudo)

# set -e stops execution of the script if an error is encountered
set -e

# if the folder does not exist, create, clone and make. If it does, then just pull and make
if ! [ -d "${ELP_H264_UVC}" ] ; then
	$SUDO mkdir -p $(dirname ${ELP_H264_UVC}) && $SUDO chmod a+w $(dirname ${ELP_H264_UVC})
	( cd $(dirname ${ELP_H264_UVC}) && git clone ${UVDL}/$(basename ${ELP_H264_UVC}).git -b master && $SUDO make -C ${LINUX_UVC} )
else
	( cd ${ELP_H264_UVC} && git pull && $SUDO make -C ${LINUX_UVC} )
fi

( cd ${ELP_H264_UVC} && echo -n "ELP_H264_UVC " && git log | head -1 )

