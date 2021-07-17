#!/bin/bash
# script to start the LOS video streaming service
# 
#
# This starts four different streams, LOS, MAVPN, ATAK and RTMP to the video server
# Assumption is that two udev rules exist, /dev/camera1 is a xraw source and /dev/stream1 is a h.264 source, should should be done during provisioning, typically make install

SUDO=$(test ${EUID} -ne 0 && which sudo)
LOCAL=/usr/local
ELP_H264_UVC=${LOCAL}/src/ELP_H264_UVC
#PLATFORM=$(python3 serial_number.py | cut -c1-4) #PLATFORM is now stored in the video.conf file

echo "Start Video Script for $PLATFORM"

function ifup {    
    local output=$(ip link show "$1" up 2>/dev/null)
    if [[ -n "$output" ]] ; then return 0        
    else return 1
    fi
}


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
LOS_BITRATE=$(($LOS_BITRATE * 1000)) 
MAVPN_BITRATE=$(($MAVPN_BITRATE * 1000)) 
VIDEOSERVER_BITRATE=$(($VIDEOSERVER_BITRATE * 1000)) 
ATAK_BITRATE=$(($ATAK_BITRATE * 1000)) 

#If the ELP software exists, use it to set the bitrate of stream1 (LOS)
if [ -d "${ELP_H264_UVC}" ] ; then
	        ${SUDO} ${ELP_H264_UVC}/Linux_UVC_TestAP/H264_UVC_TestAP /dev/stream1 --xuset-br ${LOS_BITRATE}        	
            ${SUDO} ${ELP_H264_UVC}/Linux_UVC_TestAP/H264_UVC_TestAP /dev/stream1 --xuset-gop ${LOS_FPS}  
fi   

# ensure previous pipelines are cancelled and cleared
gstd -f /var/run -k
gstd -f /var/run

gst-client pipeline_create h264src v4l2src device=/dev/stream1 ! "video/x-h264,width=1280,height=720,framerate=(fraction)15/1" ! h264parse ! rtph264pay config-interval=1 pt=96 ! udpsink sync=false host=${LOS_HOST} port=${LOS_PORT} ${extra_los}
gst-client pipeline_create xrawsrc v4l2src device=/dev/camera1 io-mode=mmap ! "video/x-raw,format=(string)YUY2,width=(int)640,height=(int)360,framerate=(fraction)15/1" ! videoconvert name=input-format ! "video/x-raw,format=(string)I420,width=(int)640,height=(int)360,framerate=(fraction)15/1" ! videoscale method=bilinear name=input-scale ! "video/x-raw,format=(string)I420,width=(int)1280,height=(int)720,framerate=(fraction)15/1" ! interpipesink name=xrawsrc
gst-client pipeline_create edge interpipesrc listen-to=xrawsrc block=true is-live=true allow-renegotiation=true stream-sync=compensate-ts ! "video/x-raw,format=(string)I420,framerate=(fraction)15/1,width=(int)1280,height=(int)720" ! omxh264enc ${encoder_bitrate}=${MAVPN_BITRATE} iframeinterval=60 ! h264parse ! rtph264pay config-interval=10 pt=96 mtu=1200 ! udpsink sync=false host=${MAVPN_HOST} port=${MAVPN_PORT} ${extra_mavpn}
gst-client pipeline_create server interpipesrc listen-to=xrawsrc block=true is-live=true allow-renegotiation=true stream-sync=compensate-ts ! "video/x-raw,format=(string)I420,framerate=(fraction)15/1,width=(int)1280,height=(int)720" ! omxh264enc ${encoder_bitrate}=${VIDEOSERVER_BITRATE} iframeinterval=60 ! h264parse ! flvmux streamable=true ! rtmpsink location=rtmp://${VIDEOSERVER_HOST}:${VIDEOSERVER_PORT}/live/${VIDEOSERVER_ORG}/${VIDEOSERVER_STREAMNAME}
gst-client pipeline_create atak interpipesrc listen-to=xrawsrc block=true is-live=true allow-renegotiation=true stream-sync=compensate-ts ! "video/x-raw,format=(string)I420,framerate=(fraction)15/1,width=(int)1280,height=(int)720" ! omxh264enc ${encoder_bitrate}=${ATAK_BITRATE} iframeinterval=60 ! h264parse ! mpegtsmux ! rtpmp2tpay ! udpsink host=${ATAK_HOST} port=${ATAK_PORT} ${extra_atak}

# start source pipelines streaming
gst-client pipeline_play h264src
gst-client pipeline_play xrawsrc

#note the edge pipeline will be started by the edge service (if it is run), otherwise it will never play

#check if we can ping the video server at this time, if not don't start that stream yet. h31proxy will evaluate and start this stream later if the connection comes online
if [ -n "${VIDEOSERVER_HOST}" ] ; then   
    if ping -q -c 1 -W 1 ${VIDEOSERVER_HOST} >/dev/null; then    
        echo "Starting server pipeline"  
        gst-client pipeline_play server  
    else
        echo "Not able to ping the video server, not going to try RTMP"
    fi
fi
#start the atak stream if an ATAK host is defined
if [ -n "${ATAK_HOST}" ] ; then
    gst-client pipeline_play atak
fi


