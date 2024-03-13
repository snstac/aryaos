#!/bin/sh
CONFIG=""
while read -r line; do CONFIG="\${CONFIG} \$line"; done < ${INSTALL_FOLDER}/aiscatcher.conf
cd ${INSTALL_FOLDER}
/usr/local/bin/AIS-catcher \${CONFIG}
