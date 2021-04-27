#!/bin/bash

SUDO=$(test ${EUID} -ne 0 && which sudo)
SYSCFG=/etc/systemd
UDEV_RULESD=/etc/udev/rules.d

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

#changes needed
#add MCAST_IFACE
#make SOURCE MIPI, MJPG or RAW
#for red5 need  [HOST] [DEVICE] [HEIGHT] [WIDTH] [FPS] [BITRATE]

case "$(basename $CONF)" in
	video.conf)	
		SOURCE=$(value_of DEVICE MJPG)	
		DEVICE=$(value_of DEVICE /dev/video0)	
		FPS=$(value_of FPS 15)
		HEIGHT=$(value_of HEIGHT 720)
		WIDTH=$(value_of WIDTH 1280)
		BITRATE=$(value_of BITRATE 2000)
		HOST=$(value_of HOST 192.168.1.29)
		MCAST_IFACE=$(value_of MCAST_IFACE eth0)
		PORT=$(value_of PORT 5600)
		RED5_HOST=$(value_of RED5_HOST 67.227.213.59)
		RED5_DEVICE=$(value_of RED5_DEVICE /dev/video2)
		RED5_WIDTH=$(value_of RED5_WIDTH 1280)
		RED5_HEIGHT=$(value_of RED5_HEIGHT 720)
		RED5_FPS=$(value_of RED5_FPS 30)
		RED5_BITRATE=$(value_of RED5_BITRATE 750)
		if ! $DEFAULTS ; then
		    PS3="Please enter camera stream type for LOS/N2N streaming: "
			options=("MJPG" "RAW" "H.264" "MIPI")
			select opt in "${options[@]}"
			do
				case $opt in
					"MJPG")
						echo "Camera type set to MJPG" && SOURCE="MJPG"
						break
						;;
					"RAW")
						echo "Camera type set to RAW" && SOURCE="RAW"
						break
						;;
					"H.264")
						echo "Camera type set to H.264" && SOURCE="H.264"
						break
						;;
					"MIPI")
						echo "Camera type set to MIPI" && SOURCE="MIPI"
						break
						;;													
					*) 
						echo "invalid option $REPLY"
						break
					;;
				esac
			done
			
			# show the user the devices which support the desired format				
			if [ "${SOURCE}" == "MJPG" ] ; then
				echo -e "Scanning /dev/video* for MJPG sources...\n"
				for dev in /dev/video* ; do
					if v4l2-ctl -d $dev --list-formats > /tmp/video.$$ ; then					
						if grep MJPG /tmp/video.$$ &> /dev/null ; then
							echo "*** $dev supports MJPG"
						fi	
					fi				
				done	
				echo -e "\n"		
			elif [ "${SOURCE}" == "RAW" ] ; then	    
				echo -e "Scanning /dev/video* for RAW sources...\n"
				for dev in /dev/video* ; do
					if v4l2-ctl -d $dev --list-formats > /tmp/video.$$ ; then					
						if grep YUYV /tmp/video.$$ &> /dev/null ; then
							echo "*** $dev supports RAW (YUYV)"
						fi	
					fi				
				done	
				echo -e "\n"		
			elif [ "${SOURCE}" == "H.264" ]	; then    
				echo -e "Scanning /dev/video* for H.264 sources...\n"
				for dev in /dev/video* ; do
					if v4l2-ctl -d $dev --list-formats > /tmp/video.$$ ; then					
						if grep H.264 /tmp/video.$$ &> /dev/null ; then
							echo "*** $dev supports H.264"
						fi	
					fi				
				done
				echo -e "\n"
			fi
			DEVICE=$(interactive "$DEVICE" "Video endpoint, e.g. /dev/video0")	
			FPS=$(interactive "$FPS" "FPS, frames per second")				
			WIDTH=$(interactive "$WIDTH" "WIDTH, video width in pixels")	
			HEIGHT=$(interactive "$HEIGHT" "HEIGHT, video height in pixels")	
			BITRATE=$(interactive "$BITRATE" "BITRATE, video bitrate in kbps")				
			HOST=$(interactive "$HOST" "HOST, UDP IPv4 for where to send the video")	
			MCAST_IFACE=$(interactive "$MCAST_IFACE" "Multicast interface to use, if applicable")	
			PORT=$(interactive "$PORT" "PORT, UDP port for where to send the video")
			# if H.264 was selected above, make sure we don't use the same h.264 source for red5 as we can't open two interfaces at one
			RED5_HOST=$(interactive "$RED5_HOST" "RED5 HOST, IPv4 for where to send the video. 'none' to disable RED5")
			echo -e "\nScanning /dev/video* for H.264 sources...\n"
			for dev in /dev/video* ; do
			    if [ "${SOURCE}" == "H.264" ] && [ $dev == ${DEVICE} ] ; then
					echo "Notice: $dev supports H.264 but is already used"
					break
				fi
				if v4l2-ctl -d $dev --list-formats > /tmp/video.$$ ; then					
					if grep H.264 /tmp/video.$$ &> /dev/null; then						
						echo "*** $dev supports H.264"						
					fi	
				fi				
			done
			echo -e "\n"
			RED5_DEVICE=$(interactive "$RED5_DEVICE" "H.264 video endpoint for the red5 pro service")
			RED5_WIDTH=$(interactive "$RED5_WIDTH" "RED5 WIDTH, video width in pixels")
			RED5_HEIGHT=$(interactive "$RED5_HEIGHT" "RED5 HEIGHT, video height in pixels")
			RED5_FPS=$(interactive "$RED5_FPS" "RED5 FPS, frames per second")
			RED5_BITRATE=$(interactive "$RED5_BITRATE" "RED5 BITRATE, video bitrate in kbps")	
			
		fi	
		echo "[Service]" > /tmp/$$.env && \
		echo "SOURCE=${SOURCE}" >> /tmp/$$.env && \
		echo "DEVICE=${DEVICE}" >> /tmp/$$.env && \
		echo "FPS=${FPS}" >> /tmp/$$.env && \
		echo "HEIGHT=${HEIGHT}" >> /tmp/$$.env && \
		echo "WIDTH=${WIDTH}" >> /tmp/$$.env && \
		echo "BITRATE=${BITRATE}" >> /tmp/$$.env && \
		echo "HOST=${HOST}" >> /tmp/$$.env && \
		echo "PORT=${PORT}" >> /tmp/$$.env && \
		echo "RED5_HOST=${RED5_HOST}" >> /tmp/$$.env && \
		echo "RED5_DEVICE=${RED5_DEVICE}" >> /tmp/$$.env && \
		echo "RED5_WIDTH=${RED5_WIDTH}" >> /tmp/$$.env && \
		echo "RED5_HEIGHT=${RED5_HEIGHT}" >> /tmp/$$.env && \
		echo "RED5_FPS=${RED5_FPS}" >> /tmp/$$.env && \
		echo "RED5_BITRATE=${RED5_BITRATE}" >> /tmp/$$.env 	
		;;	
	*)		
		;;
esac

if $DRY_RUN ; then
	set +x
	echo $CONF && cat /tmp/$$.env && echo ""
elif [[ $(basename $CONF) == *.sh ]] ; then
	$SUDO install -Dm755 /tmp/$$.env $CONF
else
	$SUDO install -Dm644 /tmp/$$.env $CONF
fi
rm /tmp/$$.env


