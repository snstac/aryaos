# Configuration

## Web Configuration

Many functions of the AryaOS can be controlled, configured and monitored via the AryaOS Web page. When connecting directly to the AryaOS in Hotspot mode (via AryaOS-XXXX WiFi Network) you can access the AryaOS Web page by visiting [http://AryaOS.local](http://AryaOS.local) from your Chrome or Safari web browser (Android & iOS) or in Edge, Chrome or Safari on you computer.

### Connect to WiFI

**N.B.**: If you are connected to AryaOS via the WiFi Hospot (AryaOS-XXXX), reconfiguring the WiFi to connect to another network will terminate your Hospot connection. To reach the AryaOS Web page after this point, you'll need to connect to the same network as AryaOS.

1. Connect to the AryaOS WiFi network and browse to http://AryaOS.local
2. Click the WiFi configuration option.
3. Enter WiFi credentials and apply.

## Reset WiFi

Use the AryaOS web portal (when connected to the device) or re-flash / follow network recovery steps in [Troubleshooting](troubleshooting.md). Advanced deployments may use Cockpit or SSH with tools shipped on the image.

## Disable WiFi

Disable or reconfigure wireless interfaces from **Cockpit** (Networking), **NetworkManager**, or SSH using the same tooling as upstream Raspberry Pi OS. Exact steps depend on whether you use hotspot mode or client WiFi.

## Change TAK / CoT destination (summary)

System-wide PyTAK clients typically read **`COT_URL`** from **`/etc/aryaos/aryaos-config.txt`**. For command-line edits and service restarts, see **Command-line Configuration → Change TAK / CoT Destination** below.

## Command-line Configuration

For advanced users. These steps require familiarity with command-line terminals using SSH. 

### Change default password

The AryaOS image contains a user with a default password. It is recommended that the 
owner of AryaOS gateway change this password.

To change the default password:

1. SSH into AryaOS: ``ssh pi@AryaOS.local``
2. Change the password: ``passwd``

**Please make note of this password. There is no password recovery feature.**

See also: [Raspberry Pi Insecure first user](https://www.raspberrypi.com/news/raspberry-pi-bullseye-update-april-2022/)

### Change TAK / CoT Destination

By default, AryaOS routes Cursor on Target traffic based on **`COT_URL`** in **`/etc/aryaos/aryaos-config.txt`** (see that file on a running system for the active scheme — multicast, TLS, TCP, etc.). 

To send CoT to a different destination, SSH into AryaOS and edit the global environment file, then restart affected gateways:

1. SSH into AryaOS: ``ssh pi@AryaOS.local``
2. Edit ``sudo nano /etc/aryaos/aryaos-config.txt`` and adjust ``COT_URL`` (and related PyTAK TLS variables if you use TLS).
3. Restart dependent services (for example ``sudo systemctl restart adsbcot``) or reboot.

### Change dump1090-fa & dump978-fa SDR serial numbers

Pre-assembled AryaOS devices come with SDR serial numbers pre-configured in dump1090-fa and dump978-fa. 

You'll need to change the value of the SDR serial numbers configured in dump1090-fa and dump978-fa if:

1. Using a self-assmbled AryaOS device.
2. There is need to change these values (for example, replacing an SDR).

An AryaOS Web Dashboard method of doing this is under development. See Issue [#21](https://github.com/snstac/AryaOS/issues/21).

#### Changing dump1090-fa SDR serial number

1. SSH into the AryaOS: ``ssh pi@AryaOS.local``
2. List the serial numbers of the installed SDRs by typing the command: ``rtl_test``

![Example rtl_test output with 1 SDR.](https://images.squarespace-cdn.com/content/v1/6477cab5986c146297acea21/8d1ecb30-17f4-4225-a7c6-76eca789b645/Screen+Shot+2023-07-08+at+11.48.45+AM.png)

3. Using the Nano text editor, open the dump1090-fa configuration file: ``sudo nano /etc/default/dump1090-fa``

![dump1090-fa config line](https://images.squarespace-cdn.com/content/v1/6477cab5986c146297acea21/44e90a93-624d-404b-b758-24d55377e626/Screen+Shot+2023-07-08+at+11.49.44+AM.png)

4. Find the line beginning with RECEIVER_SERIAL and change the value to match the SN value from the rtl_test command above.

5. Reload and restart dump1090-fa:
``sudo systemctl daemon-reload``
``sudo systemctl restart dump1090-fa``

### Changing dump978-fa SDR serial number

1. SSH into the AryaOS: ``ssh pi@AryaOS.local``
2. List the serial numbers of the installed SDRs by typing the command: ``rtl_test``
3. Using the Nano text editor, open the dump978-fa configuration file: 
``sudo nano /etc/default/dump978-fa``
4. Find the line containing ``driver=rtlsdr`` and set the ``serial=`` field to match your 978 SDR’s serial from ``rtl_test`` (see comments in the file for examples).
5. Reload and restart dump978-fa:

``sudo systemctl daemon-reload``

``sudo systemctl restart dump978-fa``
