#!/bin/bash
# usage:
#   ensure-gstd.sh [--dry-run]
#
# Ensure that all gstd dependencies/modules needed are installed

DRY_RUN=false
FORCE=false
LOCAL=/usr/local
GSTD=${LOCAL}/bin/gstd
GSTD_SRC=${LOCAL}/src/gstd-1.x
GSTD_TAG=v0.12.0
GST_INTERPIPE_SRC=${LOCAL}/src/gst-interpipe
GST_INTERPIPE_TAG=1.1.4
RIDGERUN=https://github.com/RidgeRun
SUDO=$(test ${EUID} -ne 0 && which sudo)

if [ "$1" == "--dry-run" ] ; then
	DRY_RUN=true && SUDO="echo ${SUDO}"
elif [ "$1" == "--force" ] ; then
	FORCE=true
fi

##PKGDEPS=automake host libtool pkg-config libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libglib2.0-dev libjson-glib-dev gtk-doc-tools libreadline-dev libncursesw5-dev libdaemon-dev 
declare -A pkgdeps
pkgdeps[automake]=true
pkgdeps[gtk-doc-tools]=true
pkgdeps[host]=true
pkgdeps[libdaemon-dev]=true
pkgdeps[libglib2.0-dev]=true
pkgdeps[libgstreamer1.0-dev]=true
pkgdeps[libgstreamer-plugins-base1.0-dev]=true
pkgdeps[libjson-glib-dev]=true
pkgdeps[libncursesw5-dev]=true
pkgdeps[libsoup2.4-dev]=true
pkgdeps[libreadline-dev]=true
pkgdeps[libtool]=true
pkgdeps[pkg-config]=true
pkgdeps[python3-pip]=true

# with dry-run, just go thru packages and return an error if some are missing
if $DRY_RUN ; then
	declare -A todo
	if [ -x $(which apt) ] ; then
		apt list --installed > /tmp/$$.pkgs 2>/dev/null	# NB: warning on stderr about unstable API
	else
		# TODO: figure out how to tell if something is installed in yocto
		touch /tmp/$$.pkgs
	fi
	for m in ${!pkgdeps[@]} ; do
		x=$(grep $m /tmp/$$.pkgs)
		if [ -z "$x" ] ; then
			echo "$m: missing"
			todo[$m]=true
		else
			true #&& echo "$x"
		fi
	done
	if [ -x $(which apt-get) ] ; then
		if [ "${#todo[@]}" -gt 0 ] ; then echo "Please run: apt-get install -y ${!todo[@]}" ; fi
		exit ${#todo[@]}
	else
		exit 0
	fi
fi
if [ "${#pkgdeps[@]}" -gt 0 ] ; then
    if [ -x $(which apt-get) ] ; then
	$SUDO apt-get install -y ${!pkgdeps[@]}
    else
        echo "Please run: apt-get install -y ${!pkgdeps[@]}"
	exit ${#pkgdeps[@]}
    fi
fi
GSTD_VERSION=$(gstd --version)
if ! [ -z "${GSTD_VERSION}" ] ; then
	if gst-inspect-1.0 interpipe ; then
		echo "${GSTD_VERSION}"
		if ! $FORCE ; then exit 0 ; fi
	fi
fi
set -e
if ! [ -d "${GSTD_SRC}" ] ; then
	$SUDO chmod a+w $(dirname ${GSTD_SRC}/)
	( cd $(dirname ${GSTD_SRC}/) && git clone ${RIDGERUN}/$(basename ${GSTD_SRC}).git && cd ${GSTD_SRC} && git checkout ${GSTD_TAG} )
else
	( cd ${GSTD_SRC} && git fetch && git checkout ${GSTD_TAG} && rm -f Makefile configure )
fi
( cd ${GSTD_SRC} && ./autogen.sh && ./configure && make clean && make )
( cd ${GSTD_SRC} && $SUDO make install )

if ! [ -d "${GST_INTERPIPE_SRC}" ] ; then
	$SUDO chmod a+w $(dirname ${GST_INTERPIPE_SRC}/)
	( cd $(dirname ${GST_INTERPIPE_SRC}/) && git clone ${RIDGERUN}/$(basename ${GST_INTERPIPE_SRC}).git && cd ${GST_INTERPIPE_SRC} && git checkout ${GST_INTERPIPE_TAG} )
else
	( cd ${GST_INTERPIPE_SRC} && git fetch && git checkout ${GST_INTERPIPE_TAG} && git submodule update && rm -f Makefile configure )
fi
if [ "${PLATFORM}" == "IMX6" ] ; then
	( cd ${GST_INTERPIPE_SRC} && ./autogen.sh --libdir /usr/lib/arm-linux-gnueabihf && make clean && make )
elif [ "${PLATFORM}" == "RPIX" ] ; then
	# TODO: probably need to distinguish between RPi3/RPi4...
	( cd ${GST_INTERPIPE_SRC} && ./autogen.sh --libdir /usr/lib/arm-linux-gnueabihf && make clean && make )
elif [ "${PLATFORM}" == "NVID" ] ; then
	( cd ${GST_INTERPIPE_SRC} && ./autogen.sh --libdir /usr/lib/aarch64-linux-gnu && make clean && make )
else
	( cd ${GST_INTERPIPE_SRC} && ./autogen.sh && make clean && make )
fi
( cd ${GST_INTERPIPE_SRC} && $SUDO make install )
# https://github.com/RidgeRun/gst-interpipe/issues/49
( cd ${GST_INTERPIPE_SRC} ; set +e ; make check ; set -e )

echo "$(gstd --version)"