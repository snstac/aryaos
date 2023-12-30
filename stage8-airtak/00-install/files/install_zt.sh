#!/bin/bash
<<ENDOFSIGSTART=
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA256

ENDOFSIGSTART=

export PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin

#
# ZeroTier install script
#
# All this script does is determine your OS and/or distribution and then add the correct
# repository or download the correct package and install it. It then starts the service
# and prints your device's ZeroTier address.
#

# Base URL for download.zerotier.com tree; see https://github.com/zerotier/download.zerotier.com if you want to mirror.
# Some things want http, some https, so we must specify both. Must include trailing /
ZT_BASE_URL_HTTPS='https://download.zerotier.com/'
ZT_BASE_URL_HTTP='http://download.zerotier.com/'

echo
echo '*** ZeroTier Service Quick Install for Unix-like Systems'
echo
echo '*** Tested OSes / distributions:'
echo
echo '***   MacOS (10.13+) (just installs ZeroTier One.pkg)'
echo '***   Debian Linux (7+)'
echo '***   RedHat/CentOS Linux (6+)'
echo '***   Fedora Linux (16+)'
echo '***   SuSE Linux (12+)'
echo '***   Mint Linux (18+)'
echo
echo '*** Supported architectures vary by OS / distribution. We try to support'
echo '*** every system architecture supported by the target.'
echo
echo '*** Please report problems to contact@zerotier.com and we will try to fix.'
echo

SUDO=
if [ "$UID" != "0" ]; then
	if [ -e /usr/bin/sudo -o -e /bin/sudo ]; then
		SUDO=sudo
	else
		echo '*** This quick installer script requires root privileges.'
		exit 0
	fi
fi

# Detect MacOS and install .pkg file there
if [ -e /usr/bin/uname ]; then
	if [ "`/usr/bin/uname -s`" = "Darwin" ]; then
		echo '*** Detected MacOS / Darwin, downloading and installing Mac .pkg...'
		$SUDO rm -f "/tmp/ZeroTier One.pkg"
		curl -s ${ZT_BASE_URL_HTTPS}dist/ZeroTier%20One.pkg >"/tmp/ZeroTier One.pkg"
		$SUDO installer -pkg "/tmp/ZeroTier One.pkg" -target /

		echo
		echo '*** Waiting for identity generation...'

		while [ ! -f "/Library/Application Support/ZeroTier/One/identity.secret" ]; do
			sleep 1
		done

		echo
		echo "*** Success! You are connected to port `cat '/Library/Application Support/ZeroTier/One/identity.public' | cut -d : -f 1` of Earth's planetary smart switch."
		echo

		exit 0
	fi
fi

# Detect already-installed on Linux
if [ -f /usr/sbin/zerotier-one ]; then
	echo '*** ZeroTier appears to already be installed.'
	exit 0
fi

rm -f /tmp/zt-gpg-key
echo '-----BEGIN PGP PUBLIC KEY BLOCK-----' >/tmp/zt-gpg-key
cat >>/tmp/zt-gpg-key << END_OF_KEY
Comment: GPGTools - https://gpgtools.org

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
=JgAv
END_OF_KEY
echo '-----END PGP PUBLIC KEY BLOCK-----' >>/tmp/zt-gpg-key

echo '*** Detecting Linux Distribution'
echo

if [ -f /etc/debian_version ]; then
	dvers=`cat /etc/debian_version | cut -d '.' -f 1 | cut -d '/' -f 1`
	$SUDO rm -f /tmp/zt-sources-list

	if [ -f /etc/lsb-release -a -n "`cat /etc/lsb-release 2>/dev/null | grep -F -i LinuxMint`" ]; then
		# Linux Mint -> Ubuntu 'xenial'
		echo '*** Found Linux Mint, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/xenial xenial main" >/tmp/zt-sources-list
	elif [ -f /etc/lsb-release -a -n "`cat /etc/lsb-release 2>/dev/null | grep -F trusty`" ]; then
		# Ubuntu 'trusty'
		echo '*** Found Ubuntu, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/trusty trusty main" >/tmp/zt-sources-list
	elif [ -f /etc/lsb-release -a -n "`cat /etc/lsb-release 2>/dev/null | grep -F wily`" ]; then
		# Ubuntu 'wily'
		echo '*** Found Ubuntu, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/wily wily main" >/tmp/zt-sources-list
	elif [ -f /etc/lsb-release -a -n "`cat /etc/lsb-release 2>/dev/null | grep -F xenial`" ]; then
		# Ubuntu 'xenial'
		echo '*** Found Ubuntu, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/xenial xenial main" >/tmp/zt-sources-list
	elif [ -f /etc/lsb-release -a -n "`cat /etc/lsb-release 2>/dev/null | grep -F zesty`" ]; then
		# Ubuntu 'zesty'
		echo '*** Found Ubuntu, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/zesty zesty main" >/tmp/zt-sources-list
	elif [ -f /etc/lsb-release -a -n "`cat /etc/lsb-release 2>/dev/null | grep -F precise`" ]; then
		# Ubuntu 'precise'
		echo '*** Found Ubuntu, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/precise precise main" >/tmp/zt-sources-list
	elif [ -f /etc/lsb-release -a -n "`cat /etc/lsb-release 2>/dev/null | grep -F artful`" ]; then
		# Ubuntu 'artful'
		echo '*** Found Ubuntu, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/artful artful main" >/tmp/zt-sources-list
	elif [ -f /etc/lsb-release -a -n "`cat /etc/lsb-release 2>/dev/null | grep -F bionic`" ]; then
		# Ubuntu 'bionic'
		echo '*** Found Ubuntu, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/bionic bionic main" >/tmp/zt-sources-list
	elif [ -f /etc/lsb-release -a -n "`cat /etc/lsb-release 2>/dev/null | grep -F yakkety`" ]; then
		# Ubuntu 'yakkety'
		echo '*** Found Ubuntu, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/yakkety yakkety main" >/tmp/zt-sources-list
	elif [ -f /etc/lsb-release -a -n "`cat /etc/lsb-release 2>/dev/null | grep -F disco`" ]; then
		# Ubuntu 'disco'
		echo '*** Found Ubuntu, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/disco disco main" >/tmp/zt-sources-list
	elif [ -f /etc/lsb-release -a -n "`cat /etc/lsb-release 2>/dev/null | grep -F focal`" ]; then
		# Ubuntu 'focal'
		echo '*** Found Ubuntu, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/focal focal main" >/tmp/zt-sources-list
	elif [ -f /etc/lsb-release -a -n "`cat /etc/lsb-release 2>/dev/null | grep -F hirsute`" ]; then
		# Ubuntu 'hirsute'
		echo '*** Found Ubuntu, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/bionic bionic main" >/tmp/zt-sources-list
	elif [ -f /etc/lsb-release -a -n "`cat /etc/lsb-release 2>/dev/null | grep -F impish`" ]; then
		# Ubuntu 'impish'
		echo '*** Found Ubuntu, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/bionic bionic main" >/tmp/zt-sources-list
	elif [ -f /etc/lsb-release -a -n "`cat /etc/lsb-release 2>/dev/null | grep -F mantic`" ]; then
		# Ubuntu 'mantic'
		echo '*** Found Ubuntu, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/mantic mantic main" >/tmp/zt-sources-list
	elif [ -f /etc/lsb-release -a '(' -n "`cat /etc/lsb-release 2>/dev/null | grep -F jammy`" -o -n "`cat /etc/lsb-release 2>/dev/null | grep -F kinetic`" ')' ]; then
		# Ubuntu 'jammy' or 'kinetic'
		echo '*** Found Ubuntu, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/jammy jammy main" >/tmp/zt-sources-list
	elif [ "$dvers" = "6" -o "$dvers" = "squeeze" ]; then
		# Debian 'squeeze'
		echo '*** Found Debian, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/squeeze squeeze main" >/tmp/zt-sources-list
	elif [ "$dvers" = "7" -o "$dvers" = "wheezy" ]; then
		# Debian 'wheezy'
		echo '*** Found Debian, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/wheezy wheezy main" >/tmp/zt-sources-list
	elif [ "$dvers" = "8" -o "$dvers" = "jessie" ]; then
		# Debian 'jessie'
		echo '*** Found Debian, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/jessie jessie main" >/tmp/zt-sources-list
	elif [ "$dvers" = "9" -o "$dvers" = "stretch" ]; then
		# Debian 'stretch'
		echo '*** Found Debian, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/stretch stretch main" >/tmp/zt-sources-list
	elif [ "$dvers" = "10" -o "$dvers" = "buster" -o "$dvers" = "parrot" ]; then
		# Debian 'buster'
		echo '*** Found Debian, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/buster buster main" >/tmp/zt-sources-list
	elif [ "$dvers" = "11" -o "$dvers" = "bullseye" ]; then
		# Debian 'bullseye'
		echo '*** Found Debian, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/bullseye bullseye main" >/tmp/zt-sources-list
	elif [ "$dvers" = "12" -o "$dvers" = "bookworm" ]; then
		# Debian 'bookworm'
		echo '*** Found Debian, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/bookworm bookworm main" >/tmp/zt-sources-list
	elif [ "$dvers" = "testing" -o "$dvers" = "sid" ]; then
		# Debian 'testing', 'sid', and 'bookworm' -> Debian 'bookworm'
		echo '*** Found Debian, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/bookworm bookworm main" >/tmp/zt-sources-list
	else
		# Use Debian "buster" for unrecognized Debians
		echo '*** Found Debian or Debian derivative, creating /etc/apt/sources.list.d/zerotier.list'
		echo "deb ${ZT_BASE_URL_HTTP}debian/buster buster main" >/tmp/zt-sources-list
	fi

	$SUDO apt-get update -y
	$SUDO apt-get install -y gpg
	$SUDO mv -f /tmp/zt-sources-list /etc/apt/sources.list.d/zerotier.list
	$SUDO chown 0 /etc/apt/sources.list.d/zerotier.list
	$SUDO chgrp 0 /etc/apt/sources.list.d/zerotier.list

	$SUDO chmod a+r /tmp/zt-gpg-key
	if [ -d /etc/apt/trusted.gpg.d ]; then
		$SUDO gpg --dearmor < /tmp/zt-gpg-key > /etc/apt/trusted.gpg.d/zerotier-debian-package-key.gpg
	else
		$SUDO apt-key add /tmp/zt-gpg-key
	fi
	$SUDO rm -f /tmp/zt-gpg-key

	echo
	echo '*** Installing zerotier-one package...'

	# Pre-1.1.6 Debian package did not properly enumerate its files, causing
	# problems when we try to replace it. So just delete them to force.
	if [ -d /var/lib/zerotier-one ]; then
		$SUDO rm -f /etc/init.d/zerotier-one /etc/systemd/system/multi-user.target.wants/zerotier-one.service /var/lib/zerotier-one/zerotier-one /usr/local/bin/zerotier-cli /usr/bin/zerotier-cli /usr/local/bin/zero
	fi

	cat /dev/null | $SUDO apt-get update
	cat /dev/null | $SUDO apt-get install -y zerotier-one
elif [ -f /etc/SuSE-release -o -f /etc/suse-release -o -f /etc/SUSE-brand -o -f /etc/SuSE-brand -o -f /etc/suse-brand ]; then
	echo '*** Found SuSE, adding zypper YUM repo...'
	cat /dev/null | $SUDO zypper addrepo -t YUM -g ${ZT_BASE_URL_HTTP}redhat/el/7 zerotier
	cat /dev/null | $SUDO rpm --import /tmp/zt-gpg-key

	echo
	echo '*** Installing zeortier-one package...'

	cat /dev/null | $SUDO zypper install -y zerotier-one
elif [ -d /etc/yum.repos.d ]; then
	baseurl="${ZT_BASE_URL_HTTP}redhat/el/7"
	if [ -n "`cat /etc/redhat-release 2>/dev/null | grep -i fedora`" ]; then
		echo "*** Found Fedora, creating /etc/yum.repos.d/zerotier.repo"
		fedora_release="`cat /etc/os-release | grep -F VERSION_ID= | cut -d = -f 2`"
		if [ -n "$fedora_release" ]; then
			baseurl="${ZT_BASE_URL_HTTP}redhat/fc/$fedora_release"
		else
			baseurl="${ZT_BASE_URL_HTTP}redhat/fc/22"
		fi
	elif [ -n "`cat /etc/redhat-release 2>/dev/null | grep -i centos`" -o -n "`cat /etc/redhat-release 2>/dev/null | grep -i enterprise`" -o -n "`cat /etc/redhat-release 2>/dev/null | grep -i rocky`" -o -n "`cat /etc/redhat-release 2>/dev/null | grep -i alma`" ]; then
		echo "*** Found RHEL/CentOS/Rocky, creating /etc/yum.repos.d/zerotier.repo"
		baseurl="${ZT_BASE_URL_HTTP}redhat/el/\$releasever"
	elif [ -n "`cat /etc/system-release 2>/dev/null | grep -i amazon`" ]; then
		echo "*** Found Amazon (CentOS/RHEL based), creating /etc/yum.repos.d/zerotier.repo"
		if [ -n "`cat /etc/system-release 2>/dev/null | grep -F 'Amazon Linux 2'`" ]; then
			baseurl="${ZT_BASE_URL_HTTP}redhat/el/7"
		else
			baseurl="${ZT_BASE_URL_HTTP}redhat/amzn1/2016.03"
		fi
	else
		echo "*** Found unknown yum-based repo, using el/7, creating /etc/yum.repos.d/zerotier.repo"
	fi

	$SUDO rpm --import /tmp/zt-gpg-key

	$SUDO rm -f /tmp/zerotier.repo
	echo '[zerotier]' >/tmp/zerotier.repo
	echo 'name=ZeroTier, Inc. RPM Release Repository' >>/tmp/zerotier.repo
	echo "baseurl=$baseurl" >>/tmp/zerotier.repo
	echo 'enabled=1' >>/tmp/zerotier.repo
	echo 'gpgcheck=1' >>/tmp/zerotier.repo

	$SUDO mv -f /tmp/zerotier.repo /etc/yum.repos.d/zerotier.repo
	$SUDO chown 0 /etc/yum.repos.d/zerotier.repo
	$SUDO chgrp 0 /etc/yum.repos.d/zerotier.repo

	echo
	echo '*** Installing ZeroTier service package...'

	if [ -e /usr/bin/dnf ]; then
		cat /dev/null | $SUDO dnf install -y zerotier-one
	else
		cat /dev/null | $SUDO yum install -y zerotier-one
	fi
fi

$SUDO rm -f /tmp/zt-gpg-key

if [ ! -e /usr/sbin/zerotier-one ]; then
	echo
	echo '*** Package installation failed! Unfortunately there may not be a package'
	echo '*** for your architecture or distribution. For the source go to:'
	echo '*** https://github.com/zerotier/ZeroTierOne'
	echo
	exit 1
fi

echo
echo '*** Enabling and starting ZeroTier service...'

if [ -e /usr/bin/systemctl -o -e /usr/sbin/systemctl -o -e /sbin/systemctl -o -e /bin/systemctl ]; then
	$SUDO systemctl enable zerotier-one
	# $SUDO systemctl start zerotier-one
	if [ "$?" != "0" ]; then
		echo
		echo '*** Package installed but cannot start service! You may be in a Docker'
		echo '*** container or using a non-standard init service.'
		echo
		exit 1
	fi
else
	if [ -e /sbin/update-rc.d -o -e /usr/sbin/update-rc.d -o -e /bin/update-rc.d -o -e /usr/bin/update-rc.d ]; then
		$SUDO update-rc.d zerotier-one defaults
	else
		$SUDO chkconfig zerotier-one on
	fi
	$SUDO /etc/init.d/zerotier-one start
fi

# echo
# echo '*** Waiting for identity generation...'
# 
# while [ ! -f /var/lib/zerotier-one/identity.secret ]; do
# 	sleep 1
# done
#
# echo
# echo "*** Success! You are ZeroTier address [ `cat /var/lib/zerotier-one/identity.public | cut -d : -f 1` ]."
# echo

echo "*** ZeroTier install complete."
exit 0
-----BEGIN PGP SIGNATURE-----

iQJJBAEBCAAzFiEEdKXpxFjhpDHx2lenFlcZiCPlKmEFAmU//voVHGNvbnRhY3RA
emVyb3RpZXIuY29tAAoJEBZXGYgj5SphbIgP/3tT9ATG9mz9uDzmlJyx/JdzazqM
1lp+mmEUUqrPRKHCcRLtreRm1iNzz6kCwLWsT23R5xdx6Izx0I7zHrGCoB95jBWj
OgS1oTTTQbpD//eVO9FFQega/A4Pnlz3yBoV0MOjB5G3fFv0PQkNiAk0QaJMCBKV
MgNBRLXWkq6VGLCJF4mePYIlhlXl8P9Knq/ehy4efqE9PabVj4yDyo5gb2vUNSxJ
kcAVkcw4N5C+IHOQeucuetkRnXLWPnb+YWavj+4P3KPebghyMho+vtTqxYj8yyvL
Uv+UbRTm06mLtky27EJJdgrSRf542w5GH+JtjWLZ0tNodf6O3yWPQmIfQI4YLzhv
aXkEIfmXEEtFnUGx2+O/1q42bELuB2dYjqFzeehhCsHRtDNbIyYugjWgU6Jyswvm
qpnej2mTeV5aqaG3MEVHc2a3xo6G27UiNZM2ZLPbxv58FpXKjnJRdFWtWJB8PW5/
l4UeZDYlIJarrZrz+J0u9eaBEkP2dLDuG3a6TCVMdGJLR0WHMMypwQEAM6Pjk9+6
vOvgZJX1x9VfcNZvnrsqyyoYe4xKSfgflDLr1TBW0KL5QLFQ2odEh3gJylFQ/LmG
IZ8wFyaFmdmEK08b0gewjmE/sxm0onsIcWg79IpgHvDw/evPlK1wZuHGn6a0SdY+
g66QgLwZXbrAWbk/
=Gl5k
-----END PGP SIGNATURE-----
