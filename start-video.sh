#!/bin/bash

case ${SOURCE} in
    "MIPI")
        raspivid --nopreview -fps ${FPS} -h ${HEIGHT} -w ${WIDTH} -vf -hf -n -t 0 -b ${BITRATE} -o - | gst-launch-1.0 -v fdsrc ! h264parse ! rtph264pay config-interval=1 pt=96 ! udpsink host=${HOST} port=${PORT}
        ;;
    
    *)
        #we can assume it is a USB camera
        gst-launch-1.0 v4l2src device=${SOURCE} ! rtph264pay config-interval=1 pt=96 ! udpsink host=${HOST} port=${PORT}
        ;;
esac
