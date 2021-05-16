#!/bin/bash
# usage:
#   ensure-gst.sh [--dry-run]
#
# Ensure that all gstreamer dependencies/modules needed are installed

DRY_RUN=false
SUDO=$(test ${EUID} -ne 0 && which sudo)
if [ "$1" == "--dry-run" ] ; then DRY_RUN=true && SUDO="echo ${SUDO}" ; fi
if ! GST_VERSION=$(gst-launch-1.0 --version | head -1 | cut -f3 -d' ') ; then
	# Core modules needed for gst-inspect-1.0
	if [ -x $(which apt-get) ] && ! $DRY_RUN ; then
		$SUDO apt-get install -y gstreamer1.0-tools gstreamer1.0-doc
	else
		exit 1
	fi
	if ! GST_VERSION=$(gst-launch-1.0 --version | head -1 | cut -f3 -d' ') ; then
		exit 1
	fi
fi
# dry-run is required when no package manager exists
if [ ! -x $(which apt-get) ] ; then DRY_RUN=true ; fi

echo "gstreamer version ${GST_VERSION}"

declare -A pkgdeps
if [ "${PLATFORM}" == "IMX6" ] ; then
	true
elif [ "${PLATFORM}" == "RPIX" ] ; then
	pkgdeps[gstreamer1.0-gl]=true
	pkgdeps[gstreamer1.0-omx-rpi]=true
	pkgdeps[gstreamer1.0-opencv]=true
	pkgdeps[gstreamer1.0-rtsp]=true
	pkgdeps[gstreamer1.0-vaapi]=true
elif [ "${PLATFORM}" == "NVID" ] ; then
	true
else
	pkgdeps[gstreamer1.0-libav]=true
fi

# gstreamer pipeline segments
declare -A gst
gst[aacparse]=gstreamer1.0-plugins-good
gst[alsasrc]=gstreamer1.0-alsa
gst[audioconvert]=gstreamer1.0-plugins-base
gst[autovideoconvert]=gstreamer1.0-plugins-bad
gst[flvmux]=gstreamer1.0-plugins-good
gst[h264parse]=
gst[jpegdec]=gstreamer1.0-plugins-good
gst[progressreport]=gstreamer1.0-plugins-good
gst[rtmpsink]=gstreamer1.0-plugins-bad
gst[rtpmux]=
gst[rtph264pay]=
gst[textoverlay]=gstreamer1.0-plugins-base
gst[timeoverlay]=gstreamer1.0-plugins-base
gst[v4l2src]=gstreamer1.0-plugins-good
gst[videotestsrc]=gstreamer1.0-plugins-base
gst[videoconvert]=gstreamer1.0-plugins-base
gst[videorate]=gstreamer1.0-plugins-base
gst[videoscale]=gstreamer1.0-plugins-base
gst[voaacenc]=gstreamer1.0-plugins-bad
gst[udpsink]=
# platform-specific plugins
if [ "${PLATFORM}" == "IMX6" ] ; then
	gst[imxipuvideotransform]=
	gst[imxvpuenc_h264]=
	gst[h265parse]=
	gst[x265enc]=
	gst[x264enc]=gstreamer1.0-plugins-ugly
	gst[rtph265pay]=
elif [ "${PLATFORM}" == "RPIX" ] ; then
	gst[omxh264enc]=
elif [ "${PLATFORM}" == "NVID" ] ; then
	gst[omxh264enc]=
	gst[h265parse]=
	gst[omxh265enc]=
	gst[rtph265pay]=
else
	#gst[autoaudiosink]=gstreamer1.0-plugins-bad
	#gst[autovideosink]=gstreamer1.0-plugins-bad
	#gst[avenc_aac]=gstreamer1.0-libav
	#gst[avenc_h264_omx]=gstreamer1.0-libav
	gst[fpsdisplaysink]=gstreamer1.0-plugins-bad
	gst[x264enc]=gstreamer1.0-plugins-ugly
fi

for e in ${!gst[@]} ; do
	mod=${gst[$e]}
	if [ -z "$mod" ] ; then continue ; fi
	pkgdeps[$mod]=true
done

#echo "PKGDEPS=${!pkgdeps[@]}"

# go thru packages and return an error if some are missing
declare -A todo
for e in ${!gst[@]} ; do
	echo "Checking ${e}..."
	if ! gst-inspect-1.0 $e > /dev/null ; then
		mod=${gst[${e}]}
		if [ -z $mod ] ; then
			todo[${e}-dev]=true
		else
			todo[$mod]=true
		fi
	fi
done
if $DRY_RUN ; then
	if [ -x $(which apt) ] ; then
		apt list --installed > /tmp/$$.pkgs 2>/dev/null	# NB: warning on stderr about unstable API
	else
		# TODO: figure out how to tell if something is installed in yocto
		touch /tmp/$$.pkgs
	fi
	for m in ${!todo[@]} ; do
		x=$(grep $m /tmp/$$.pkgs)
		if [ -z "$x" ] ; then
			echo "$m: missing"
			todo[$m]=true
		else
			true #&& echo "$x"
		fi
	done
	if [ "${#todo[@]}" -gt 0 ] ; then echo "Please run: apt-get install -y ${!todo[@]}" ; fi
	exit ${#todo[@]}
fi
set -e
if [ "${#todo[@]}" -gt 0 ] ; then
    if [ -x $(which apt-get) ] ; then
	$SUDO apt-get install -y ${!todo[@]}
    else
        echo "Please run: apt-get install -y ${!todo[@]}"
	exit ${#todo[@]}
    fi
fi