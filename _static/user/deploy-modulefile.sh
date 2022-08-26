#!/bin/bash
###############################################################################
#
#   Filename: deploy-modulefile.sh
#
#   Functional Description:
#
#       Bash script which deploys an Environment Modules modulefile with
#       an example application.
#
#   Requires:
#
#       Requires the system to already have deploy-env-modules.sh deployed
#
#   Usage:
#
#       ./deploy-modulefile.sh
#
###############################################################################


# Ensure running as root or sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "ERROR: Please run as root or use sudo\n"
  exit
fi

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying modulefile...\n"


###############################################################################
# Script Configuration Options
###############################################################################

# htop Versino
HTOP_VERSION="3.2.1"


###############################################################################
# Installation Commands
###############################################################################

# Update System
dnf -y upgrade

# Create application directory:
mkdir -p /app/htop/htop-${HTOP_VERSION}/build/

# Create modulefiles directory:
mkdir -p /app/modulefiles/htop/

# Download the htop source files if not already present
if [ ! -f "/app/htop/htop-${HTOP_VERSION}/build/htop-${HTOP_VERSION}.tar.xz" ]; then
  wget -nv \
    https://github.com/htop-dev/htop/releases/download/${HTOP_VERSION}/htop-${HTOP_VERSION}.tar.xz \
    -P /app/htop/htop-${HTOP_VERSION}/build/
fi

# Ensure source files are present
if [ ! -f "/app/htop/htop-${HTOP_VERSION}/build/htop-${HTOP_VERSION}.tar.xz" ]; then
  echo "ERROR: htop-${HTOP_VERSION}.tar.xz Not Found"
  exit 1
fi

# Create htop build script:
cat > /app/htop/htop-${HTOP_VERSION}/build/build.sh <<EOF
#!/bin/bash

VERSION=3.2.1

dnf -y install ncurses ncurses-devel lm_sensors lm_sensors-devel

cat > .build_info << EOI
Hostname:
  \`hostname -f\`
Build Date:
  \`date\`
System:
  \`uname -a\`
  \`cat /etc/redhat-release\`
EOI

tar --no-same-owner --xz -xf htop-\${VERSION}.tar.xz
cd htop-\${VERSION}

./configure --prefix=/app/htop/htop-\${VERSION}
make
make install || true

cd ../
rm -rf htop-\${VERSION}
EOF

chmod 755 /app/htop/htop-${HTOP_VERSION}/build/build.sh

# Build htop:
cd /app/htop/htop-${HTOP_VERSION}/build/
./build.sh

# Create modulefile:
cat > /app/modulefiles/htop/${HTOP_VERSION} <<EOF
#%Module1.0####################################################################
##
## htop ${HTOP_VERSION} modulefile
##
###############################################################################


# --- Application Specific Information ----------------------------------------

# Application information
set             app_name        "htop"
set             app_version     ${HTOP_VERSION}
set             app_root        /app/htop/htop-\${app_version}
set             mod_name        htop
set             mod_conflicts   "htop"
conflict        htop


# --- Module Configuration ----------------------------------------------------

# Environment module messages
module-whatis   "Loads \${app_name} \${app_version} module into your environment"
module-version  \$mod_name/\${app_version}

# Set environment variables
prepend-path    PATH            \${app_root}/bin

# Module configuration
set             module_info     [module-info name]
if { [ module-info mode load ] } {
    puts stderr "Module for \${app_name} '\${module_info}' loaded."
} elseif { [ module-info mode remove ] } {
    puts stderr "Module for \${app_name} '\${module_info}' unloaded."
}


# --- Module Help Information -------------------------------------------------

proc ModulesHelp { } {
    global app_name
    global app_version
    global app_root
    global mod_name
    global mod_conflicts

    puts stderr "\${app_name} \${app_version}"

    puts stderr "\nPath:      \${app_root}"
    puts stderr "Website:   https://htop.dev/"
    puts stderr "Conflicts: \${mod_conflicts}"
}
EOF

# Test modulefile:
echo -e "\nExecuting: \"module help htop/${HTOP_VERSION}\""
module help htop/${HTOP_VERSION}

echo -e "\nExecuting: \"module unload htop\""
module unload htop

echo -e "\nExecuting: \"module load htop/${HTOP_VERSION}\""
module load htop/${HTOP_VERSION}

echo -e "\nWhich htop: `which htop`"
echo -e "Launch Command: \"htop\""

echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] Deploying modulefile Complete\n"
exit 0
