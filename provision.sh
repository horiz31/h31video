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
	local result=$($SUDO grep $1 $CONF 2>/dev/null | cut -f2 -d=)
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
		SOURCE=$(value_of SOURCE MIPI)	
		FPS=$(value_of FPS 15)
		HEIGHT=$(value_of HEIGHT 720)
		WIDTH=$(value_of WIDTH 1280)
		BITRATE=$(value_of BITRATE 2000000)
		HOST=$(value_of HOST 192.168.1.29)
		PORT=$(value_of PORT 5600)
		if ! $DEFAULTS ; then
			SOURCE=$(interactive "$SOURCE" "Source, either MIPI or USB endpoint, e.g. /dev/video1")	
			FPS=$(interactive "$FPS" "FPS, frames per second")	
			HEIGHT=$(interactive "$HEIGHT" "HEIGHT, video height in pixels")	
			WIDTH=$(interactive "$WIDTH" "WIDTH, video width in pixels")	
			BITRATE=$(interactive "$BITRATE" "BITRATE, video bitrate in bits per second")	
			HOST=$(interactive "$HOST" "HOST, UDP IPv4 for where to send the video")	
			PORT=$(interactive "$PORT" "PORT, UDP port for where to send the video")	
			
		fi	
		echo "[Service]" > /tmp/$$.env && \
		echo "SOURCE=${SOURCE}" >> /tmp/$$.env && \
		echo "FPS=${FPS}" >> /tmp/$$.env && \
		echo "HEIGHT=${HEIGHT}" >> /tmp/$$.env && \
		echo "WIDTH=${WIDTH}" >> /tmp/$$.env && \
		echo "BITRATE=${BITRATE}" >> /tmp/$$.env && \
		echo "HOST=${HOST}" >> /tmp/$$.env && \
		echo "PORT=${PORT}" >> /tmp/$$.env		
		;;

	
	*)
		# preserve contents or generate a viable empty configuration
		#echo "[Service]" > /tmp/$$.env
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


