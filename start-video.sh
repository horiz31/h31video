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
AUDIO_BITRATE=$(($AUDIO_BITRATE * 1000)) 

#If the ELP software exists, use it to set the bitrate of stream1 (LOS)
if [ -d "${ELP_H264_UVC}" ] ; then
	        ${SUDO} ${ELP_H264_UVC}/Linux_UVC_TestAP/H264_UVC_TestAP /dev/stream1 --xuset-br ${LOS_BITRATE}        	
            ${SUDO} ${ELP_H264_UVC}/Linux_UVC_TestAP/H264_UVC_TestAP /dev/stream1 --xuset-gop ${LOS_FPS}  
fi   

# ensure previous pipelines are cancelled and cleared
gstd -f /var/run -k
gstd -f /var/run

# video pipelines
gst-client pipeline_create h264src v4l2src device=/dev/stream1 ! "video/x-h264,width=1280,height=720,framerate=(fraction)15/1" ! interpipesink name=h264src
gst-client pipeline_create los interpipesrc listen-to=h264src block=true is-live=true allow-renegotiation=true stream-sync=compensate-ts ! h264parse ! rtph264pay config-interval=1 pt=96 ! udpsink sync=false host=${LOS_HOST} port=${LOS_PORT} ${extra_los}
gst-client pipeline_create edge interpipesrc listen-to=h264src block=true is-live=true allow-renegotiation=true stream-sync=compensate-ts ! nvv4l2decoder disable-dpb=true ! queue ! nvv4l2h264enc control-rate=1 ${encoder_bitrate}=${MAVPN_BITRATE} preset-level=1 ! 'video/x-h264,width=1280,height=720,framerate=15/1' ! h264parse ! rtph264pay config-interval=1 pt=96 ! udpsink host=${MAVPN_HOST} port=${MAVPN_PORT} ${extra_mavpn}
gst-client pipeline_create server interpipesrc listen-to=h264src block=true is-live=true allow-renegotiation=true stream-sync=compensate-ts ! nvv4l2decoder enable-max-performance=true disable-dpb=true ! queue ! nvv4l2h264enc control-rate=1 ${encoder_bitrate}=${VIDEOSERVER_BITRATE} preset-level=1 ! 'video/x-h264,width=1280,height=720,framerate=15/1' ! h264parse ! flvmux streamable=true ! rtmpsink location=rtmp://${VIDEOSERVER_HOST}:${VIDEOSERVER_PORT}/live/${VIDEOSERVER_ORG}/${VIDEOSERVER_STREAMNAME}
gst-client pipeline_create atak interpipesrc listen-to=h264src ! nvv4l2decoder disable-dpb=true ! queue ! omxh264enc ${encoder_bitrate}=${ATAK_BITRATE} ! h264parse ! mpegtsmux ! rtpmp2tpay ! udpsink sync=false host=${ATAK_HOST} port=${ATAK_PORT} ${extra_atak}

# audio pipelines
gst-client pipeline_create mic alsasrc device="hw:2,0" ! "audio/x-raw,format=(string)S16LE,rate=(int)44100,channels=(int)1" ! interpipesink name=mic
gst-client pipeline_create audio_los interpipesrc listen-to=mic is-live=true block=true ! voaacenc bitrate=${AUDIO_BITRATE} ! aacparse ! rtpmp4apay pt=96 ! udpsink sync=false host=${LOS_HOST} port=${AUDIO_PORT} ${extra_los}
gst-client pipeline_create audio_edge interpipesrc listen-to=mic is-live=true block=true ! voaacenc bitrate=${AUDIO_BITRATE} ! aacparse ! rtpmp4apay pt=96 ! udpsink sync=false host=${MAVPN_HOST} port=${AUDIO_PORT} ${extra_mavpn}

# start source pipelines streaming
gst-client pipeline_play h264src
gst-client pipeline_play los
gst-client pipeline_play mic


#edge pipelines (edge and audio_edge) will play when/if n2n is started and may be control by h31proxy to conserve bandwidth

# server pipeline will be started if we can ping the video server, but ultimately this is unreliable. The connection will by monitored and managed by h31proxy 
 
if [ -n "${VIDEOSERVER_HOST}" ] ; then   
   if ping -q -c 1 -W 1 ${VIDEOSERVER_HOST} >/dev/null; then    
       echo "Starting server pipeline"  
       gst-client pipeline_play server  
   else
       echo "Not able to ping the video server, not going to try RTMP"
   fi
fi

# start atak stream if host provided
if [ -n "${ATAK_HOST}" ] ; then
    gst-client pipeline_play atak
fi

gst-client pipeline_play audio_los




