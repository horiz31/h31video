#!/bin/bash
# SERIAL is passed in as an env variable
SUDO=$(test ${EUID} -ne 0 && which sudo)
UDEV_RULESD=/etc/udev/rules.d
PLATFORM=$(python3 serial_number.py | cut -c1-4)
CONF=$1
shift
DEFAULTS=false
DRY_RUN=false
while (($#)) ; do
	if [ "$1" == "--dry-run" ] && ! $DRY_RUN ; then DRY_RUN=true ; set -x ;
	elif [ "$1" == "--defaults" ] ; then DEFAULTS=true ;
	fi
	shift
done

function address_of {
	local result=$(ip addr show $1 | grep inet | grep -v inet6 | head -1 | sed -e 's/^[[:space:]]*//' | cut -f2 -d' ' | cut -f1 -d/)
	echo $result
}

function value_of {
	local result=$($SUDO grep ^$1 $CONF 2>/dev/null | cut -f2 -d=)
	if [ -z "$result" ] ; then result=$2 ; fi
	echo $result
}

# pull default provisioning items from the network.conf (generate it first)
function value_from_network {
	local result=$($SUDO grep $1 $(dirname $CONF)/network.conf 2>/dev/null | cut -f2 -d=)
	if [ -z "$result" ] ; then result=$2 ; fi
	echo $result
}

function interactive {
	local result
	read -p "${2}? ($1) " result
	if [ -z "$result" ] ; then result=$1 ; elif [ "$result" == "*" ] ; then result="" ; fi
	echo $result
}

function contains {
	local result=no
	#if [[ " $2 " =~ " $1 " ]] ; then result=yes ; fi
	if [[ $2 == *"$1"* ]] ; then result=yes ; fi
	echo $result
}

case "$(basename $CONF)" in
	video.conf)				
		DEVICE_H264=$(value_of DEVICE_H264 /dev/video1)	
		DEVICE_XRAW=$(value_of DEVICE_XRAW /dev/video0)	
		LOS_HOST=$(value_of LOS_HOST 224.10.10.10)
		LOS_PORT=$(value_of LOS_PORT 5600)
		LOS_IFACE=$(value_of LOS_IFACE eth0)
		LOS_WIDTH=$(value_of LOS_WIDTH 1280)
        	LOS_HEIGHT=$(value_of LOS_HEIGHT 720)
        	LOS_FPS=$(value_of LOS_FPS 30)
        	LOS_BITRATE=$(value_of LOS_BITRATE 3000)				
		MAVPN_HOST=$(value_of MAVPN_HOST 225.11.10.10)
		MAVPN_PORT=$(value_of MAVPN_PORT 5600)
		MAVPN_IFACE=$(value_of MAVPN_IFACE edge0)
		MAVPN_BITRATE=$(value_of MAVPN_BITRATE 1300)
		ATAK_HOST=$(value_of ATAK_HOST 239.10.10.10)
		ATAK_PORT=$(value_of ATAK_PORT 5600)
		ATAK_IFACE=$(value_of ATAK_IFACE eth0)
		ATAK_BITRATE=$(value_of ATAK_BITRATE 500)
		VIDEOSERVER_HOST=$(value_of VIDEOSERVER_HOST video.horizon31.com)
		VIDEOSERVER_PORT=$(value_of VIDEOSERVER_PORT 1935)
		VIDEOSERVER_BITRATE=$(value_of VIDEOSERVER_BITRATE 500)
		VIDEOSERVER_ORG=$(value_of VIDEOSERVER_ORG H31)
		VIDEOSERVER_STREAMNAME=$(value_of VIDEOSERVER_STREAMNAME ${SERIAL})
		AUDIO_PORT=$(value_of AUDIO_PORT 5601)				
		AUDIO_BITRATE=$(value_of AUDIO_BITRATE 128)
		
		if ! $DEFAULTS ; then		    			
			echo "Video Provision for Serial Number ${SERIAL}"
			echo -e "Please answer the questions below to provision this device...\nThe video service will generate 4 streams and requires a camera with an H.264 endpoint and a XRAW endpoint.\n\n"
			# show the user the devices which support the RAW format				
			
			echo -e "Scanning /dev/video* for RAW sources...\n"
			for dev in /dev/video* ; do
				if v4l2-ctl -d $dev --list-formats > /tmp/video.$$ ; then					
					if grep YUYV /tmp/video.$$ &> /dev/null ; then
						echo "*** $dev supports RAW (YUYV)"
					fi	
				fi				
			done	
	
			DEVICE_XRAW=$(interactive "$DEVICE_XRAW" "Please select the desired RAW endpoint, e.g. /dev/video0")		
			echo -e "\nScanning /dev/video* for H.264 sources...\n"
			for dev in /dev/video* ; do
			    if  [ $dev != ${DEVICE_XRAW} ] ; then									
					if v4l2-ctl -d $dev --list-formats > /tmp/video.$$ ; then					
						if grep H.264 /tmp/video.$$ &> /dev/null; then						
							echo "*** $dev supports H.264"						
						fi	
					fi	
				fi			
			done	
			DEVICE_H264=$(interactive "$DEVICE_H264" "Please select the desired H.264 endpoint, e.g. /dev/video1")			
			echo -e "\n--- Line of Sight Video Configuration ---"		
			LOS_WIDTH=$(interactive "$LOS_WIDTH" "LOS_WIDTH LOS video width in pixels")	
			LOS_HEIGHT=$(interactive "$LOS_HEIGHT" "LOS_HEIGHT, LOS video height in pixels")	
			LOS_FPS=$(interactive "$LOS_FPS" "LOS_FPS, LOS video frames per second")	
			LOS_BITRATE=$(interactive "$LOS_BITRATE" "LOS_BITRATE, LOS video bitrate in kbps")	
			los_current_ip=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1 2>/dev/null)
			echo "INFO: The LOS (eth0) interface IP address is currently $los_current_ip"								
			LOS_HOST=$(interactive "$LOS_HOST" "LOS_HOST, UDP IPv4 for where to send the LOS video")	
			LOS_PORT=$(interactive "$LOS_PORT" "LOS_PORT, Port for the LOS video")	
			LOS_IFACE=$(interactive "$LOS_IFACE" "LOS_IFACE, Multicast interface for the LOS video, if applicable")	
			echo -e "\n--- MAVPN Video Config ---"
			mavpn_current_ip=$(/sbin/ip -o -4 addr list edge0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
			if [[ -z $mavpn_current_ip ]] ; then echo "Warning, no MAVPN interface detected!!!"
			else echo "INFO: The MAVPN (edge0 ) interface IP address is currently $mavpn_current_ip"	
			fi
			MAVPN_HOST=$(interactive "$MAVPN_HOST" "MAVPN_HOST, UDP IPv4 for where to send the MAVPN video")	
			MAVPN_PORT=$(interactive "$MAVPN_PORT" "MAVPN_PORT, Port for the MAVPN video")	
			MAVPN_IFACE=$(interactive "$MAVPN_IFACE" "MAVPN_IFACE, Multicast interface for the MAVPN video, if applicable")	
			MAVPN_BITRATE=$(interactive "$MAVPN_BITRATE" "MAVPN_BITRATE, MAVPN video bitrate in kbps")		
			echo -e "\n--- ATAK Video Config ---"
			ATAK_HOST=$(interactive "$ATAK_HOST" "ATAK_HOST, UDP IPv4 for where to send the ATAK video, type "none" if not using")	
			ATAK_PORT=$(interactive "$ATAK_PORT" "ATAK_PORT, Port for the ATAK video")	
			ATAK_IFACE=$(interactive "$ATAK_IFACE" "ATAK_IFACE, Multicast interface for the ATAK video, if applicable")	
			ATAK_BITRATE=$(interactive "$ATAK_BITRATE" "ATAK_BITRATE, ATAK video bitrate in kbps")
			echo -e "\n--- Video Distribution Server Config ---"
			VIDEOSERVER_HOST=$(interactive "$VIDEOSERVER_HOST" "VIDEOSERVER_HOST, IPv4 for the Horizon31 video server, type "none" if not using")
			VIDEOSERVER_PORT=$(interactive "$VIDEOSERVER_PORT" "VIDEOSERVER_PORT, Port for the Horizon31 video server")
			VIDEOSERVER_BITRATE=$(interactive "$VIDEOSERVER_BITRATE" "VIDEOSERVER_BITRATE, Video server bitrate in kbps")
			VIDEOSERVER_ORG=$(interactive "$VIDEOSERVER_ORG" "VIDEOSERVER_ORG, Organizational id for this device (used for organizing video on the server)")
			VIDEOSERVER_STREAMNAME=$(interactive "$VIDEOSERVER_STREAMNAME" "VIDEOSERVER_STREAMNAME, Stream name for this device, typically the device serial number")
  			AUDIO_PORT=$(interactive "$AUDIO_PORT" "AUDIO_PORT, Port for the audio")
			AUDIO_BITRATE=$(interactive "$AUDIO_BITRATE" "AUDIO_BITRATE, Audio bitrate in kbps")
			if [[ "$VIDEOSERVER_HOST" == "none" ]] ; then VIDEOSERVER_HOST="" ; fi
			if [[ "$ATAK_HOST" == "none" ]] ; then ATAK_HOST="" ; fi

									
		fi	

		#make udev rules
		touch /tmp/$$.rule	

		ok=true
		declare -A config
		udevadm info -a -n ${DEVICE_XRAW} | grep ATTR > /tmp/camera1.$$
	    for kw in devpath idProduct idVendor index ; do
			config[$kw]=$(grep $kw /tmp/camera1.$$ | head -1 | cut -f2 -d\")
			if [ -z "${config[$kw]}" ] ; then ok=false ; fi
	    done
		if $ok ; then
			echo "SUBSYSTEM==\"video4linux\", ATTRS{idVendor}==\"${config[idVendor]}\", ATTRS{idProduct}==\"${config[idProduct]}\", ATTRS{devpath}==\"${config[devpath]}\", ATTR{index}==\"${config[index]}\", SYMLINK+=\"camera1\"" >> /tmp/$$.rule	
			echo -e "\nMade UDEV Rule for /dev/camera1..."		
		else
			echo "*** ${DEVICE_XRAW}  not configured for camera1 ***"
		fi

		udevadm info -a -n ${DEVICE_H264} | grep ATTR > /tmp/stream1.$$
	    for kw in devpath idProduct idVendor index ; do
			config[$kw]=$(grep $kw /tmp/stream1.$$ | head -1 | cut -f2 -d\")
			if [ -z "${config[$kw]}" ] ; then ok=false ; fi
	    done
		if $ok ; then
			echo "SUBSYSTEM==\"video4linux\", ATTRS{idVendor}==\"${config[idVendor]}\", ATTRS{idProduct}==\"${config[idProduct]}\", ATTRS{devpath}==\"${config[devpath]}\", ATTR{index}==\"${config[index]}\", SYMLINK+=\"stream1\"" >> /tmp/$$.rule			
			echo "Made UDEV Rule for /dev/stream1..."		
		else
			echo "*** ${DEVICE_H264}  not configured for stream1 ***"
		fi	

		#write config file
		echo "[Service]" > /tmp/$$.env && \
		echo "DEVICE_H264=${DEVICE_H264}" >> /tmp/$$.env && \
		echo "DEVICE_XRAW=${DEVICE_XRAW}" >> /tmp/$$.env && \
		echo "LOS_WIDTH=${LOS_WIDTH}" >> /tmp/$$.env && \
		echo "LOS_HEIGHT=${LOS_HEIGHT}" >> /tmp/$$.env && \
		echo "LOS_FPS=${LOS_FPS}" >> /tmp/$$.env && \
		echo "LOS_BITRATE=${LOS_BITRATE}" >> /tmp/$$.env && \
		echo "LOS_HOST=${LOS_HOST}" >> /tmp/$$.env && \
		echo "LOS_PORT=${LOS_PORT}" >> /tmp/$$.env && \
		echo "LOS_IFACE=${LOS_IFACE}" >> /tmp/$$.env && \
		echo "MAVPN_HOST=${MAVPN_HOST}" >> /tmp/$$.env && \
		echo "MAVPN_PORT=${MAVPN_PORT}" >> /tmp/$$.env && \
		echo "MAVPN_IFACE=${MAVPN_IFACE}" >> /tmp/$$.env && \
		echo "MAVPN_BITRATE=${MAVPN_BITRATE}" >> /tmp/$$.env && \
		echo "ATAK_HOST=${ATAK_HOST}" >> /tmp/$$.env && \
		echo "ATAK_PORT=${ATAK_PORT}" >> /tmp/$$.env && \
		echo "ATAK_IFACE=${ATAK_IFACE}" >> /tmp/$$.env && \
		echo "ATAK_BITRATE=${ATAK_BITRATE}" >> /tmp/$$.env && \
		echo "VIDEOSERVER_HOST=${VIDEOSERVER_HOST}" >> /tmp/$$.env && \
		echo "VIDEOSERVER_PORT=${VIDEOSERVER_PORT}" >> /tmp/$$.env && \
		echo "VIDEOSERVER_BITRATE=${VIDEOSERVER_BITRATE}" >> /tmp/$$.env && \
		echo "VIDEOSERVER_ORG=${VIDEOSERVER_ORG}" >> /tmp/$$.env && \
		echo "VIDEOSERVER_STREAMNAME=${VIDEOSERVER_STREAMNAME}" >> /tmp/$$.env && \
		echo "AUDIO_PORT=${AUDIO_PORT}" >> /tmp/$$.env && \
		echo "AUDIO_BITRATE=${AUDIO_BITRATE}" >> /tmp/$$.env && \
		echo "PLATFORM=${PLATFORM}" >> /tmp/$$.env 	 	
		;;	
	*)		
		;;
esac


if $DRY_RUN ; then
	set +x
	echo $CONF && cat /tmp/$$.env && echo ""
else
	mkdir -p $CONF
	$SUDO install -Dm644 /tmp/$$.env $CONF	
	echo -e "Installing udev rules..."	
	$SUDO install -Dm644 /tmp/$$.rule ${UDEV_RULESD}/83-webcam.rules
	$SUDO udevadm control --reload-rules && $SUDO udevadm trigger	
fi
rm /tmp/$$.env
rm /tmp/$$.rule
echo -e "\nHere are the contents of ${CONF}"
$SUDO cat $CONF
echo -e "\nTo start the video streams now by 'sudo systemctl start video', otherwise they will start on the next reboot."
echo -e "\nYou can view the live video stream at https://gcs.horizon31.com/getvideo/?org=${VIDEOSERVER_ORG}&streamName=${VIDEOSERVER_STREAMNAME}\n"



