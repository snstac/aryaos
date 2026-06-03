
## **DEVICE_SUFFIX**

**DEVICE_SUFFIX** is four lowercase hexadecimal characters derived on first boot from the last four characters of **`/etc/machine-id`**, or from the primary network interface MAC address if machine-id is unavailable. **`aryaos-firstboot.service`** writes it to **`/etc/aryaos/aryaos-config.txt`** and sets the system hostname to **`aryaos-xxxx`** (same **xxxx**).

Used for:

- System hostname: **`aryaos-xxxx`**
- Comitup WiFi hotspot SSID: **`AryaOS-xxxx`**

Do not edit **DEVICE_SUFFIX** manually after first boot unless you understand the impact on mDNS (`aryaos-xxxx.local`) and the captive WiFi SSID.

Legacy images may still contain an unused **`NODE_ID=`** line in **`aryaos-config.txt`**; it is no longer written or read by AryaOS.
