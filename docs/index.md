AirTAK Documentation.

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

## Change dump1090-fa & dump978-fa SDR serial numbers

AirTAK comes with SDR serial numbers hard-coded for the AirTAK v1 hardware kit. If 
you’re using the AirTAK OS with other SDRs, you’ll need to change these hard-coded values.

### Changing dump1090-fa SDR serial number

1. SSH into the AirTAK: ``ssh pi@airtak.local``
2. List the serial numbers of the installed SDRs by typing the command: ``rtl_test``

![Example rtl_test output with 1 SDR.](https://images.squarespace-cdn.com/content/v1/6477cab5986c146297acea21/8d1ecb30-17f4-4225-a7c6-76eca789b645/Screen+Shot+2023-07-08+at+11.48.45+AM.png)

3. Using the Nano text editor, open the dump1090-fa configuration file: ``sudo nano /etc/default/dump1090-fa``

![dump1090-fa config line](https://images.squarespace-cdn.com/content/v1/6477cab5986c146297acea21/44e90a93-624d-404b-b758-24d55377e626/Screen+Shot+2023-07-08+at+11.49.44+AM.png)

4. Find the line beginning with RECEIVER_SERIAL and change the value to match the SN value from the rtl_test command above.

5. Reload and restart dump1090-fa:
``sudo systemctl daemon-reload``
``sudo systemctl restart dump1090-fa``

### Changing dump978-fa SDR serial number

1. SSH into the AirTAK: ``ssh pi@airtak.local``
2. List the serial numbers of the installed SDRs by typing the command: ``rtl_test``
3. Using the Nano text editor, open the dump978-fa configuration file: 
``sudo nano /etc/default/dump978-fa``
4. Find the line beginning with TK TK
