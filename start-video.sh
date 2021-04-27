#!/bin/bash
# script to start the LOS video streaming service
# note that we assume a udev rule is in place which sets the video source to /dev/camera1. This should happen during provision
#

SUDO=$(test ${EUID} -ne 0 && which sudo)
LOCAL=/usr/local
ELP_H264_UVC=${LOCAL}/src/ELP_H264_UVC

echo "Start Video Script ${SOURCE}"
# if host is multicast, then append following
if [[ "$HOST" =~ ^224.* ]]; then
    extra="multicast-iface=${MCAST_IFACE} auto-multicast=true ttl=10"
fi

if [ "${SOURCE}" == "MIPI" ] ; then
        BITRATE=$(($BITRATE * 1000))         
        raspivid --nopreview -fps ${FPS} -h ${HEIGHT} -w ${WIDTH} -vf -hf -n -t 0 -b ${BITRATE} -o - | gst-launch-1.0 -v fdsrc ! h264parse ! rtph264pay config-interval=1 pt=96 ! udpsink host=${HOST} port=${PORT} ${extra}        
elif [ "${SOURCE}" == "MJPG" ] ; then            
        gst-launch-1.0 v4l2src device=/dev/camera1 io-mode=mmap ! "image/jpeg,width=(int)${WIDTH},height=(int)${HEIGHT},framerate=(fraction)${FPS}/1" ! jpegdec ! "video/x-raw,format=(string)I420,width=(int)${WIDTH},height=(int)${HEIGHT},framerate=(fraction)${FPS}/1" ! x264enc bitrate=${BITRATE} speed-preset=veryfast key-int-max=30 tune=zerolatency sliced-threads=true ! "video/x-h264,stream-format=(string)byte-stream,width=(int)${WIDTH},height=(int)${HEIGHT},framerate=(fraction)${FPS}/1" ! h264parse ! rtph264pay config-interval=10 pt=96 ! udpsink host=${HOST} port=${PORT} ${extra}      
elif [ "${SOURCE}" == "H.264" ] ; then         
        # first set bitrate, note it is saved in kbps
        BITRATE=$((${BITRATE} * 1000))      
        if [ -d "${ELP_H264_UVC}" ] ; then
	        ${SUDO} ${ELP_H264_UVC}/Linux_UVC_TestAP/H264_UVC_TestAP /dev/camera1 --xuset-br ${BITRATE}        	    
        fi        
        gst-launch-1.0 v4l2src device=/dev/camera1 ! rtph264pay config-interval=1 pt=96 ! udpsink host=${HOST} port=${PORT}
elif [ "${SOURCE}" == "RAW" ] ; then 
       # raw really only works with very specific width/height, e.g. 800x600 and 15fps for the ELP cam
       gst-launch-1.0 v4l2src device=/dev/camera1 io-mode=mmap ! "video/x-raw,format=(string)YUY2,width=(int)800,height=(int)600,framerate=(fraction)15/1" ! videoconvert ! "video/x-raw,format=(string)I420,width=(int)800,height=(int)600,framerate=(fraction)15/1" ! omxh264enc ! rtph264pay config-interval=10 pt=96 ! udpsink host=${HOST} port=${PORT} ${extra}   
fi
        

