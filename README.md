![AirTAK ADS-B to TAK Gateway](https://images.squarespace-cdn.com/content/v1/6477cab5986c146297acea21/215a9728-55f0-438b-9a82-133012ccdb1b/airtakv1.jpg?format=512w)


# AirTAK - Standalone ADS-B to TAK Gateway

[AirTAK](https://www.snstac.com/blog/introducing-airtak-v1) is a standalone ADS-B to [TAK](https://www.tak.gov) Gateway. AirTAK Open Source is the purpose-built 
operating system used by AirTAK gateways. It is based on Debian, and runs on most ARM64
small-board computers, including the Raspberry Pi.

Don't want to roll your own? You can order an assembled & tested [AirTAK go-kit](https://www.snstac.com/store/p/airtak-v1).

## What does AirTAK Do?

Any smartphone or computer running ATAK, WinTAK or iTAK, when paired to an AirTAK gateway, 
displays aircraft data in native TAK formats.

For example, in this field configuration, a Samsung Galaxy S20 smartphone running ATAK was paired to an AirTAK device carried in a backpack. The AirTAK was powered by a portable USB battery 
also in the backpack. No outside internet connectivity (no LTE, no WiFi) was utilized by the smartphone or AirTAK gateway

![AirTAK attached to a backpack](https://images.squarespace-cdn.com/content/v1/6477cab5986c146297acea21/5156f485-2d40-4609-a226-248f73032c15/backpack.png?format=256w)

On a sunny & warm June day in downtown San Diego, a range of 55 miles was achived using this 
configuration.

![ATAK AirTAK Screenshot](https://images.squarespace-cdn.com/content/v1/6477cab5986c146297acea21/916e24b9-8bc1-491d-b107-39426b0b0572/Screenshot_20230629_113649_ATAK.jpg?format=512w)


## How does AirTAK work?

![AirTAK CONOP](https://images.squarespace-cdn.com/content/v1/6477cab5986c146297acea21/4090f1e7-e65e-45f9-92de-26907b2d46bc/airtak+conop.png?format=512w)

AirTAK creates a standalone ADS-B to TAK Gateway using WiFi. When paired with an ATAK, 
WinTAK or iTAK end-user device, AirTAK displays real-time aircraft data in native TAK 
formats. This allows TAK users to gain airspace situational awareness in an easily 
portable, turn-key device. When connected to a local or wide area network, AirTAK extends the operational coverage area and incrases airspace situational awareness.

## Where is AirTAK used?

AirTAK is in active use by wildland fire, security, safety & response organizations world-wide.

This work is funded by the [Colorado Center of Excellence for Advanced Technology Aerial Firefighting](https://www.cofiretech.org/feature-projects/team-awareness-kit-tak) and the [USDA Forest Service (USFS)](https://www.fs.usda.gov/managing-land/fire).

![Colorado COE](https://images.squarespace-cdn.com/content/v1/6477cab5986c146297acea21/3eaaf2d1-60d4-4883-b944-8a02f1836664/coe+logo.png?format=105)
![USDA](https://images.squarespace-cdn.com/content/v1/6477cab5986c146297acea21/f72561b6-0cf4-4b7f-ac41-75d4bbc076d8/Logo_of_the_United_States_Department_of_Agriculture.svg.png?format=100)
![USFS](https://images.squarespace-cdn.com/content/v1/6477cab5986c146297acea21/61bde71a-14a1-455c-a8ef-90ba685f27c7/Logo_of_the_United_States_Forest_Service.svg+%281%29.png?format=100)

# Building AirTAK

The build environment for AirTAK is based on [pi-gen](https://github.com/RPi-Distro/pi-gen). 
The build will create a Raspberry Pi OS image, compatible with [Raspberry Pi Imager](https://www.raspberrypi.com/software/) or [Balena Etcher](https://etcher.balena.io/).

Any SD card larger than 16 GB should suffice to get started, 32 GB recommended.

The AirTAK build procedure is inspired by @deltazero's [kiosk.pi](https://medium.com/@deltazero/making-kioskpi-custom-raspberry-pi-os-image-using-pi-gen-99aac2cd8cb6).

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

# Configuration

## Change default password

The AirTAK OS image contains a user with a default password. It is recommended that the 
owner of AirTAK gateway change this password.

To change the default password:

1. SSH into AirTAK: ``ssh pi@airtak.local``
2. Change the password: ``passwd``

**Please make note of this password. There is no password recovery feature.**

See also: [Raspberry Pi Insecure first user](https://www.raspberrypi.com/news/raspberry-pi-bullseye-update-april-2022/)


## Change CoT Destination

By default, AirTAK sends Cursor on Target messages to the ATAK Mesh SA multicast group & port: ``udp://239.2.3.1:6969`` (expressed as a read-only port via ``udp+wo://...``). 

To send CoT to a different destination, you'll need to SSH into AirTAK and change the 
configuration for ``adsbcot``.

1. SSH into AirTAK: ``ssh pi@airtak.local``
2. Edit adsbcot's configuration: ``sudo nano /boot/adsbcot-config.txt`` (N.B. This is *not* an INI-style file.)
3. Save & reboot.

## Connect to WiFI

1. Connect to the AirTAK WiFi network and browse to http://airtak.local
2. Click the WiFi configuration option.
3. Enter WiFi credentials and apply

## TODO: Procedure for resetting WiFi connection

