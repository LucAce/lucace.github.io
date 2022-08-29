#!/bin/bash

VERSION=3.2.1

dnf -y install ncurses ncurses-devel lm_sensors lm_sensors-devel

cat > .build_info << EOI
Hostname:
  `hostname -f`
Build Date:
  `date`
System:
  `uname -a`
  `cat /etc/redhat-release`
EOI

tar --no-same-owner --xz -xf htop-${VERSION}.tar.xz
cd htop-${VERSION}

./configure --prefix=/app/htop/htop-${VERSION}
make
make install || true

cd ../
rm -rf htop-${VERSION}
