# AirTAK - Standalone ADS-B to TAK Gateway

AirTAK creates a standalone ADS-B to TAK Gateway using WiFi. Paired with an ATAK, iTAK 
or WinTAK end-user device, AirTAK provides surviellence of airborne craft in the local 
area. When connected to a local or wide area network, AirTAK extends the operational 
coverage area airborne survillence capability.

AirTAK has been used by wildland firefighting agencies and is based on technology used 
by defense, security & response organizations world-wide.

# Building an AirTAK Small Board Computer Image

The build environment for AirTAK is based on [pi-gen](https://github.com/RPi-Distro/pi-gen). 
The build will create a Raspberry Pi OS image, compatible with Raspberry Pi Imager or Balena Etcher.

Any SD card larger than 16 GB should suffice to get started, 32 GB recommended.

When booted on a Small Board Computer, the image will create a local WiFi network.

An EUD running WinTAK, iTAK or ATAK, when connected to this WiFi network, will display 
airborne survillence data within the TAK software.

## Build Steps

To build initially:

1. Checkout this repo.
2. `make init` to download pi-gen.
3. `make build` to create an image.

To Update a build:

1. sync repo
2. `make skip` to skip base-os build steps.
3. `make buld` to create an image.

N.B.: THe `make build` step will attempt to sudo, and may prompt for a password.

# License & Copyright

Copyright 2023 Sensors & Signals LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

# Notes

- pi-gen, Raspberry Pi's official imager: https://github.com/RPi-Distro/pi-gen
- Based on kiosk.pi by deltazero.cz: https://medium.com/@deltazero/making-kioskpi-custom-raspberry-pi-os-image-using-pi-gen-99aac2cd8cb6

Insecure first user:
https://www.raspberrypi.com/news/raspberry-pi-bullseye-update-april-2022/
