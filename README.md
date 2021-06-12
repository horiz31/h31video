# H31 Video Service for PixC4-Pi and PixC4-Jetson

This is a simple video streaming service built for the PixC4-Pi and PixcC4-Jetson. It supports a single usb camera input that has both xraw and h.264 endpoints (MIPI to be done). No video switching etc. is used. For a more complicated scenario, this can be expanded to your needs using the tools present. It may be of value to look at the open source camera-streamer implementation here: https://github.com/uvdl/camera-streamer

This application uses Ridgerun's [Gstd](https://developer.ridgerun.com/wiki/index.php?title=GStreamer_Daemon) and [GstInterpipe](https://developer.ridgerun.com/wiki/index.php?title=GstInterpipe)

It is meant to be used with the ELP-USBFHD06H webcam, which Horizon31 includes with development kits, or can be purchased directly from various vendors including Amazon.

It tries to create 4 different streams
* LOS - A high quality stream, sent over the LOS network and derived from the h.264 camera endpoint
* MAVNP - A high quality stream, sent over the MAVPN network and derived from the xraw endpoint 
* ATAK - A lower quality stream, sent over the LOS network to ATAK device and derived from the xraw input
* RTMP - A lower quality stream, sent over the internet to the horizon31 video server (video.horizon31.com), derived from the xraw input

When you do a `make install` two symbolic links are set up via udev rules
* `/dev/camera1` This is the endpoint used for the xraw streaming
* `/dev/stream1` This is the endpoing used for the h.264 streaming

To set the bitrate of the ELP camera, the ELP_H264_UVC application is used (https://github.com/uvdl/ELP_H264_UVC)

## Dependencies

* `Gstreamer, set up via ensure-gst.sh for specific platforms` 
* `v4l-utils`
* `ELP_H264_UVC via https://github.com/uvdl/ELP_H264_UVC` 
* `build-essential`
  
These will be installed automatically by during a `make install` assuming you have an internet connection  
ELP_H264_UVC will be compiled  


## Installation

To perform an initial install, establish an internet connection and clone the repository.
You will issue the following commands:
```
cd $HOME
git clone https://github.com/horiz31/h31video.git
```

provide your credentials, then continue:
```
make -C $HOME/h31video install
```

This will pull in the necessary dependencies, provision the system and start the video service  

To make future changes in the provisioning:
```
make -C $HOME/h31video provision
```

This will enter into an interactive session to help you setup your video encoding settings, host endpoint etc.

## Running

The install above will create a service and enable it (/usr/systemd/system/video.service). It will start automatically after a reboot.  

To stop it manually
```
sudo systemctl stop video
```
To start it manually
```
sudo systemctl start video
```
To view output logs while it is running  
```
sudo journalctl -fu video
```


## Files

 * `Makefile` - installation automation
 * `README.md` - this file
 * `provision.sh` - script to support creating and changing the config file
 * `video.service` - service file
 * `ensure-elp-driver.sh` - script ran during install to clone the ELP driver and compile it
 * `ensure-gstd.sh` - script ran during install to clone and install GSTD
 * `ensure-gst.sh` - script ran during install to clone and install Gstreamer
 * `start-video.sh` - script ran by the service to start the LOS video streaming
 * `serial_number.py` - python app to get serial number across various platforms
 

## Supported Platforms
These platforms are supported/tested:

 * Raspberry PI
   - [x] [Raspbian GNU/Linux 10 (buster)](https://www.raspberrypi.org/downloads/raspbian/)
 * NVIDIA Jetson Nano
   - [x] [NVIDIA L4T 32.5.1 (Jetpack 4.5.1)](https://developer.nvidia.com/embedded/jetpack)


