# Simple Video Service for H31, PixC4-Pi


## Dependencies

* `gstreamer1.0-tools` 
  
These will be installed automatically by during a `make install` assuming you have an internet connection  


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
 * `start-video.sh` - script ran by the service to start the video


## Supported Platforms
These platforms are supported/tested:


 * Raspberry PI
   - [x] [Raspbian GNU/Linux 10 (buster)](https://www.raspberrypi.org/downloads/raspbian/)


