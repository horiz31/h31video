#!/bin/bash

SUDO=$(test ${EUID} -ne 0 && which sudo)
LOCAL=/usr/local
ELP_H264_UVC=${LOCAL}/src/ELP_H264_UVC

case ${SOURCE} in
    "MIPI")
        raspivid --nopreview -fps ${FPS} -h ${HEIGHT} -w ${WIDTH} -vf -hf -n -t 0 -b ${BITRATE} -o - | gst-launch-1.0 -v fdsrc ! h264parse ! rtph264pay config-interval=1 pt=96 ! udpsink host=${HOST} port=${PORT}
        ;;
    
    *)
        #we can assume it is a USB camera
        # first set bitrate using         
        if [ -d "${ELP_H264_UVC}" ] ; then
	        ${SUDO} ${ELP_H264_UVC}/Linux_UVC_TestAP/H264_UVC_TestAP ${SOURCE} --xuset-br ${BITRATE}        	    
        fi
        
        gst-launch-1.0 v4l2src device=${SOURCE} ! rtph264pay config-interval=1 pt=96 ! udpsink host=${HOST} port=${PORT}
        ;;
esac
