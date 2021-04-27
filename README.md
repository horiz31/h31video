# Simple Video Service for H31, PixC4-Pi

## TODO: 
I need to setup symbolic links for the cameras selecting during provisioning so they will be guranteed to persist across boots.
## END TODO

This is a simple video streaming service built for the PixC4-Pi with plans to evolve into support for the PixcC4-Jetson. It supports a single MIPI-CSI or usb camera input. No video switching etc. is used.

It also supports starting a red5 streaming service. Note that the red5 service requires an H.264 camera input. As such, if you set up the LOS stream using H.264, you cannot also use that video source for the red5 service. Generally the best option is to use MJPG encoding for the LOS stream with one of the ELP cameras which has MJPG, RAW and H.264 endpoints. MJPG is slightly more latent than H.264 or RAW, but is significantly higher quality than RAW from these cameras because they are limited in frame size. Also note that pulling MJPG and encoding to 264 is somewhat computationally expensive.

## Dependencies

* `gstreamer1.0-tools` 
* `ELP_H264_UVC via https://github.com/uvdl/ELP_H264_UVC` 
* `build-essential`
* `red5pro_linux_streamer via https://github.com/horiz31/red5pro_linux_streamer`
  
These will be installed automatically by during a `make install` assuming you have an internet connection  
ELP_H264_UVC and red5pro_linux_streamer will be compiled  


## Installation

To perform an initial install, establish an internet connection and clone the repository.
You will issue the following commands:
```
cd $HOME
git clone https://github.com/horiz31/video_simple_pi.git
```

provide your credentials, then continue:
```
make -C $HOME/video_simple_pi install
```

This will pull in the necessary dependencies, provision the system and start the video service  

To make future changes in the provisioning:
```
make -C $HOME/video_simple_pi provision
```

This will enter into an interactive session to help you setup your video encoding settings, host endpoint etc.


## Files

 * `Makefile` - installation automation
 * `README.md` - this file
 * `provision.sh` - script to support creating and changing the config file
 * `video.service` - service file
 * `ensure-elp-driver.sh` - script ran during install to clone the ELP driver and compile it
 * `ensure-red5.sh` - script ran during install to clone the red5 streaming sdk and compile it
 * `start-video.sh` - script ran by the service to start the LOS video streaming
 * `start-red5.sh` - script ran by the service to start the red5 streaming


## Supported Platforms
These platforms are supported/tested:

 * Raspberry PI
   - [x] [Raspbian GNU/Linux 10 (buster)](https://www.raspberrypi.org/downloads/raspbian/)


