#!/bin/bash
# This script searches https://packages.debian.org/ for kernels with the PREEMPT_RT patch and allows the user to choose a desired version interactively
# This should be preferred over the re-compilation of the Linux kernel
# Tobit Flatscher - github.com/2b-t (2022)


# Install the kernel from the available pre-compiled packages online
function main {
  sudo apt-get install -y dialog
  sudo apt-get install -y coreutils curl grep dpkg-dev

  # Select Debian version
  POSSIBLE_DEBIAN_VERSIONS=$(cat /etc/debian_version | tr / " ")
  local DIALOG_POSSIBLE_DEBIAN_VERSIONS
  for VER in $POSSIBLE_DEBIAN_VERSIONS
    do
      PREEMPTRT_FILE=$(curl -Ls https://packages.debian.org/$VER/$(dpkg --print-architecture)/linux-image-rt-$(dpkg --print-architecture)/download | grep -o -P '(?<=<h2>Download Page for <kbd>)(linux-image-rt.*)(?=<\/kbd>)')
      DIALOG_POSSIBLE_DEBIAN_VERSIONS="$DIALOG_POSSIBLE_DEBIAN_VERSIONS $VER $PREEMPTRT_FILE"
  done
  DEBIAN_VERSION=$(dialog --stdout --menu "Select the desired PREEMPT_RT kernel version:" 30 70 10 $DIALOG_POSSIBLE_DEBIAN_VERSIONS)

  # Select download server
  DOWNLOAD_SERVERS=$(curl -Ls https://packages.debian.org/$DEBIAN_VERSION/$(dpkg --print-architecture)/linux-image-rt-$(dpkg --print-architecture)/download | grep -o -P '(?<=<li><a href=\")(.*\.deb)(?=\">)')
  local DIALOG_DOWNLOAD_SERVERS
  for VER in $DOWNLOAD_SERVERS
    do
      DIALOG_DOWNLOAD_SERVERS="$DIALOG_DOWNLOAD_SERVERS $VER $VER"
  done
  local DOWNLOAD_FILE_LOCATION=$(dialog --no-tags --stdout --menu "Select a download server:" 30 70 10 $DIALOG_DOWNLOAD_SERVERS)

  # Download the Debian package
  DOWNLOADED_FILE=$(echo "$DOWNLOAD_FILE_LOCATION" | rev | cut -d'/' -f 1 | rev)
  echo "Downloading Debian package $DOWNLOADED_FILE from $DOWNLOAD_FILE_LOCATION..."
  curl -SLO --fail $DOWNLOAD_FILE_LOCATION

  # Install Debian package
  echo "Installing Debian package $DOWNLOADED_FILE..."
  sudo dpkg -i $DOWNLOADED_FILE
  sudo apt-get install -f
  echo "Done: Installation from Debian package completed!"
  exit 0
}

main $@

