#!/bin/bash
# script to start the LOS video streaming service
# 
#
# This starts four different streams, LOS, MAVPN, ATAK and RTMP to the video server
# Assumption is that two udev rules exist, /dev/camera1 is a xraw source and /dev/stream1 is a h.264 source, should should be done during provisioning, typically make install
# The LOS and MAVPN streams use the HIGHQUALTIY params and the H.264 source
# The RTMP and ATAK streams use the LOWQUALTIY params and the xraw source. Note that for the xraw, the scaling very picky, so it is fixed to 1280x720 but you can adjust the birtate, that is why only bitrate is exposed for LOWQUALTIY

SUDO=$(test ${EUID} -ne 0 && which sudo)
LOCAL=/usr/local
ELP_H264_UVC=${LOCAL}/src/ELP_H264_UVC
PLATFORM=$(python3 serial_number.py | cut -c1-4)

echo "Start Video Script for ${PLATFORM}"

# if host is multicast, then append extra
if [[ "$LOS_HOST" =~ ^224.* ]]; then
    extra_los="multicast-iface=${LOS_IFACE} auto-multicast=true ttl=10"
fi
if [[ "$MAVPN_HOST" =~ ^224.* ]]; then
    extra_mavpn="multicast-iface=${MAVPN_IFACE} auto-multicast=true ttl=10"
fi
if [[ "$ATAK_HOST" =~ ^224.* ]]; then
    extra_atak="multicast-iface=${ATAK_IFACE} auto-multicast=true ttl=10"
fi

if [[ "$PLATFORM" == "RPIX" ]]; then
    encoder_bitrate="target-bitrate"
else
    encoder_bitrate="bitrate"
fi

#Scale the bitrate from kbps to bps
HIGHQUALITY_BITRATE=$(($HIGHQUALITY_BITRATE * 1000)) 
LOWQUALITY_BITRATE=$(($LOWQUALITY_BITRATE * 1000)) 

#If the ELP software exists, use it to set the bitrate of stream1
if [ -d "${ELP_H264_UVC}" ] ; then
	        ${SUDO} ${ELP_H264_UVC}/Linux_UVC_TestAP/H264_UVC_TestAP /dev/stream1 --xuset-br ${HIGHQUALITY_BITRATE}        	    
fi   
gst-launch-1.0 v4l2src device=/dev/camera1 io-mode=0 ! "video/x-raw,format=(string)YUY2,width=(int)640,height=(int)360,framerate=(fraction)15/1" ! \
videorate max-rate=15 skip-to-first=true ! videoconvert ! videoscale method=bilinear name=scale ! "video/x-raw,format=(string)I420,width=(int)1280,height=(int)720,framerate=(fraction)15/1" ! \
omxh264enc control-rate=1 ${encoder_bitrate}=${LOWQUALITY_BITRATE} ! tee name=t t. ! queue max-size-buffers=0 max-size-bytes=0 max-size-time=134000000 min-threshold-buffers=1 leaky=upstream ! \
h264parse ! flvmux streamable=true ! rtmpsink location=rtmp://${VIDEOSERVER_HOST}:${VIDEOSERVER_PORT}/live/${VIDEOSERVER_ORG}/${VIDEOSERVER_STREAMNAME} t. ! \
queue max-size-buffers=0 max-size-bytes=0 max-size-time=134000000 min-threshold-buffers=1 leaky=upstream ! mpegtsmux ! rtpmp2tpay ! udpsink sync=false host=${ATAK_HOST} port=${ATAK_PORT} ${extra_atak} \
v4l2src device=/dev/stream1 io-mode=mmap ! "video/x-h264,width=${HIGHQUALITY_WIDTH},height=${HIGHQUALITY_HEIGHT},framerate=(fraction)${HIGHQUALITY_FPS}/1" ! h264parse ! tee name=t1 t1. ! \
queue max-size-buffers=0 max-size-bytes=0 max-size-time=134000000 min-threshold-buffers=1 leaky=upstream ! queue max-size-buffers=0 max-size-bytes=0 max-size-time=134000000 min-threshold-buffers=1 leaky=upstream ! \
rtph264pay config-interval=1 pt=96 ! udpsink sync=false host=${LOS_HOST} port=${LOS_PORT} ${extra_los} t1. ! queue max-size-buffers=0 max-size-bytes=0 max-size-time=134000000 min-threshold-buffers=1 leaky=upstream ! \
rtph264pay config-interval=1 pt=96 ! udpsink sync=false host=${MAVPN_HOST} port=${MAVPN_PORT} ${extra_mavpn}

# Todo later, handle MIPI  raspivid --nopreview -fps ${FPS} -h ${HEIGHT} -w ${WIDTH} -vf -hf -n -t 0 -b ${BITRATE} -o - | gst-launch-1.0 -v fdsrc ! h264parse ! rtph264pay config-interval=1 pt=96 ! udpsink host=${HOST} port=${PORT} ${extra}        
        

