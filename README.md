# H31 Video Service for PixC4-Pi and PixC4-Jetson

This is a simple video streaming service built for the PixC4-Pi and PixC4-Jetson. It supports a single usb camera input that has both xraw and h.264 endpoints (MIPI to be done). Only the h.264 endpoint is used in this example. No video switching etc. is used. For a more complicated scenario, this can be expanded to your needs using the tools present. It may be of value to look at the open source camera-streamer implementation here: https://github.com/uvdl/camera-streamer

This application uses Ridgerun's [Gstd](https://developer.ridgerun.com/wiki/index.php?title=GStreamer_Daemon) and [GstInterpipe](https://developer.ridgerun.com/wiki/index.php?title=GstInterpipe)

The code is tested with the ELP-USBFHD06H webcam, which Horizon31 includes with development kits, or can be purchased directly from various vendors including Amazon. The ELP_H264_UVC API is used to adjust the camera bitrate. 

This app can tee the incoming h.264 stream and create up to four output (4) streams:
* LOS - A high quality stream, sent over the LOS network and derived from the h.264 camera endpoint
* MAVNP - A high quality stream, sent over the MAVPN network and derived from the h.264 endpoint 
* ATAK - A lower quality stream, sent over the LOS network to ATAK device and derived from the h.264 input
* RTMP - A lower quality stream, sent over the internet to the horizon31 video server (video.horizon31.com), derived from the derived from the h.264

When you do a `make install` two symbolic links are set up via udev rules
* `/dev/stream1` This is the endpoing used for the h.264 streaming
* `/dev/camera1` This is the endpoint used for the xraw streaming

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

Then continue:
```
make -C $HOME/h31video install
```

This will pull in the necessary dependencies, and start the provisioning wizard to help you setup your video encoding settings, host endpoint etc.

To make future changes in the provisioning:
```
make -C $HOME/h31video provision
```

To start video streaming, either reboot the system and the service will start, or you can start it manually with
```
sudo systemctl start video
```



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

## Video System Troubleshooting

If you are not getting a video feed on the GCS, follow these steps to help debug:

1. Ensure there are no issues with the USB wiring, cameras, etc.
```
sudo apt-get install v4l-utils
v4l2-ctl --list-devices
```
You should see at least 1 H.264 source. If you do not see the source, check that the camera is showing up using
```
lsusb
```
You should see a device which corresponds to the attached camera. Verify that you are not getting "usb disconnect" errors in the dmesg output
```
dmesg -w
```
any usb disconnect and reconnect is a sign that the wiring is faulty or the camera is fault. Replace and retry.

2. Try to restart the service and see if the stream starts
```
sudo systemctl restart video
```
If a restart causes the stream to start on the GCS, this could indicate that a camera is faulty (normally you would see "usb disconnect" in the dmesg log as well).

3. Check the camera-switcher logs for any clues
Look at the output of
```
sudo journalctl -u video | grep "Warning"
```
and
```
sudo journalctl -u video | grep "Bad"
```
if either of the commands above return results, investigate the source of those errors.

4. Check udev rules. 
```
ls /dev/stream*
```
should return /dev/stream1

5. The video system uses a relatively complicated gstreamer dameon, at this point you can try to run a simple script to verify video works. Stop the camera-switcher service and then run a simple gst-launch pipeline using /dev/stream1.   

Change the ip address 172.20.3.29 in the below command to match the actual ip address of the GCS you are streaming to  
Within QGroundControl, change video settings to Unicast h.264, port 5600  
Now run the commands below  
```
sudo systemctl stop video
gst-launch-1.0 v4l2src device=/dev/stream1 ! "video/x-h264,width=1280,height=720,framerate=15/1" ! rtph264pay config-interval=1 pt=96 ! udpsink host=172.20.3.29 port=5600 multicast-iface=eth0 auto-multicast=true ttl=10
```

6. Network issues - Video is unicast, and on Windows unicast video may be blocked if your network interface is a "Public network". Ensure the network interface on the GCS system is a "Private Network."
![image](https://user-images.githubusercontent.com/13543163/142952215-48a045f5-f8d4-4342-9468-972ab7c4544a.png)



