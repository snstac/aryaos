# Download or Build

## Download AirTAK Open Source

* Latest: [R01](https://drive.google.com/file/d/1BT053aHiCUGOuCLW_IXkkuzRCJurwJOw/view?usp=sharing).

## Build AirTAK Open Source

The build environment for AirTAK is based on [pi-gen](https://github.com/RPi-Distro/pi-gen). 
The build will create a Raspberry Pi OS image, compatible with [Raspberry Pi Imager](https://www.raspberrypi.com/software/) or [Balena Etcher](https://etcher.balena.io/).

Any SD card larger than 16 GB should suffice to get started, 32 GB recommended.

The AirTAK build procedure is inspired by @deltazero's [kiosk.pi](https://medium.com/@deltazero/making-kioskpi-custom-raspberry-pi-os-image-using-pi-gen-99aac2cd8cb6).

### Build Steps

To build initially:

1. Checkout this repo.
2. `make init` to download pi-gen.
3. `make build` to create an image.

To Update a build:

1. sync repo
2. `make skip` to skip base-os build steps.
3. `make buld` to create an image.

N.B.: THe `make build` step will attempt to sudo, and may prompt for a password.