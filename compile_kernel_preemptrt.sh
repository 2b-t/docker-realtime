#!/bin/bash
# Script for compiling a kernel with the PREEMPT_RT real-time patch with a simple graphical interface
# Tobit Flatscher - github.com/2b-t (2022)
#
# Usage:
# - '$ ./patch_kernel_preemprt.sh' and go through with a graphical user interface
# - Select a PREEMPT_RT version at https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/"
#   and compile with '$ sudo ./patch_kernel_preemprt.sh 5.10.78-rt55'


# Install required dependencies
function install_dependencies {
  echo "Installing dependencies..."
  sudo apt-get install -y grep curl sed
  sudo apt-get install -y build-essential bc ca-certificates gnupg2 libssl-dev lsb-release libelf-dev bison flex dwarves zstd libncurses-dev dpkg-dev
  echo "Dependencies installed successfully!"
}

# Get major versions by crawling website
function get_preemptrt_major_versions {
  echo $(curl -Ls https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt | grep -o -P '(?<=href\=\")(\d\.\d*)+(?=/\">)')
}

# Select the desired major version with a user dialog
function select_preemptrt_major_version {
  local PREEMPTRT_MAJOR_VERSIONS=$(get_preemptrt_major_versions)
  local DIALOG_PREEMPTRT_MAJOR_VERSIONS=""
  for VER in ${PREEMPTRT_MAJOR_VERSIONS}
    do
      DIALOG_PREEMPTRT_MAJOR_VERSIONS="${DIALOG_PREEMPTRT_MAJOR_VERSIONS} ${VER} ${VER}"
  done
  CURRENT_KERNEL_VERSION=$(uname -r | sed 's/\.[^\.]*//2g')
  echo $(dialog --no-tags --stdout --default-item ${CURRENT_KERNEL_VERSION} --menu "Select a major kernel version:" 30 40 10 ${DIALOG_PREEMPTRT_MAJOR_VERSIONS})
}

# Get the full versions by crawling website
function get_preemptrt_full_versions {
  echo $(curl -Ls https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${PREEMPT_RT_VER} | grep -o -P '(?<=href\=\"patch-).*(?=.patch.gz\">)')
}

# Select the desired major version with a user dialog
function select_preemptrt_full_version {
  local PREEMPTRT_FULL_VERSIONS=$(get_preemptrt_full_versions)
  local DIALOG_PREEMPTRT_FULL_VERSIONS=""
  for VER in ${PREEMPTRT_FULL_VERSIONS}
    do
      DIALOG_PREEMPTRT_FULL_VERSIONS="${DIALOG_PREEMPTRT_FULL_VERSIONS} ${VER} ${VER}"
  done
  echo $(dialog --no-tags --stdout --menu "Select the desired version of PREEMPT_RT:" 30 40 10 ${DIALOG_PREEMPTRT_FULL_VERSIONS})
}

# Reconstruct the corresponding kernel major version
function reconstruct_kernel_major_version {
  local KERNEL_MAJOR_VERSION=$(echo "${PREEMPT_RT_VER}" | grep -o -P '^\s*(\d)+')
  echo "$(curl -Ls https://www.kernel.org/pub/linux/kernel | grep -o -P "(?<=href\=\")(v${KERNEL_MAJOR_VERSION}.*)(?=/\">)")"
}

# Download and extract the vanilla kernel
function download_and_extract_kernel {
  echo "Downloading kernel '${KERNEL_VER_FULL}'..."
  curl -SLO --fail https://www.kernel.org/pub/linux/kernel/${KERNEL_VER}/linux-${KERNEL_VER_FULL}.tar.xz
  curl -SLO --fail https://www.kernel.org/pub/linux/kernel/${KERNEL_VER}/linux-${KERNEL_VER_FULL}.tar.sign
  xz -d linux-${KERNEL_VER_FULL}.tar.xz
}

# Download and extract the PREEMPT_RT patch
function download_and_extract_preemptrt {
  echo "Downloading PREEMPT_RT patch '${PREEMPT_RT_VER_FULL}'..."
  curl -SLO --fail https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${PREEMPT_RT_VER}/patch-${PREEMPT_RT_VER_FULL}.patch.xz
  curl -SLO --fail https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${PREEMPT_RT_VER}/patch-${PREEMPT_RT_VER_FULL}.patch.sign 
  xz -d patch-${PREEMPT_RT_VER_FULL}.patch.xz
}

# Sign the kernel and the patch
function sign_kernel_and_preemptrt {
  echo "Signing keys..."
  # Catch non-zero exit code despite "set -e", see https://stackoverflow.com/a/57189853
  if gpg2 --verify linux-${KERNEL_VER_FULL}.tar.sign; then 
    :
  else
    local KERNEL_KEY=$(gpg2 --verify linux-${KERNEL_VER_FULL}.tar.sign 2>&1 | grep -o -P '(?<=RSA key )(.*)')
    gpg2 --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys ${KERNEL_KEY}
    gpg2 --verify linux-${KERNEL_VER_FULL}.tar.sign
  fi

  if gpg2 --verify patch-${PREEMPT_RT_VER_FULL}.patch.sign; then 
    :
  else
    local PREEMPT_KEY=$(gpg2 --verify patch-${PREEMPT_RT_VER_FULL}.patch.sign 2>&1 | grep -o -P '(?<=RSA key )(.*)')
    gpg2 --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys ${PREEMPT_KEY}
    gpg2 --verify patch-${PREEMPT_RT_VER_FULL}.patch.sign
  fi
}

# Apply the patch to the kernel
function apply_patch_to_kernel {
  echo "Applying PREEMPT_RT patch '${PREEMPT_RT_VER_FULL}' to kernel '${KERNEL_VER_FULL}'..."
  tar xf linux-${KERNEL_VER_FULL}.tar
  cd linux-${KERNEL_VER_FULL}
  patch -p1 < ../patch-${PREEMPT_RT_VER_FULL}.patch
}

# Generate a new kernel configuration
function generate_new_kernel_configuration {
  # Only option set in the configuration is full PREEMPT_RT, rest is left on default
  echo "Generating kernel configuration"
  echo "4" | make oldconfig
}

# Function for finding a certain setting, replacing it or adding it if not existing
# @param $1 The name of the setting
# @param $2 its desired value
function find_and_replace_in_config {
  local CONFIG_FILE=".config"
  grep -E "$1=" $CONFIG_FILE && sed -i "s/$1=.*/$1=$2/" $CONFIG_FILE || echo $1"="$2 >> ${CONFIG_FILE}
}

# Function for commenting out certain settings in the configuration files
# @param $1 The name of the setting to be commented out
function comment_out_in_config {
  local CONFIG_FILE=".config"
  sed -E "/$1/ s/^#*/#/" -i ${CONFIG_FILE}
}

# Unsign the kernel configuration
function unsign_kernel_configuration {
  echo "Forcing unsigned kernel..."
  find_and_replace_in_config "CONFIG_SYSTEM_TRUSTED_KEYS" '""'
  find_and_replace_in_config "CONFIG_SYSTEM_REVOCATION_KEYS" '""'
}

# Select the installation modality
function select_installation_mode {
  echo $(dialog --stdout --default-item "Debian package" --menu "Select the desired installation mode:" 30 40 10 "Debian" "Debian package" "Classic" "Install directly")
}

# Generate a debian package for easier installation
function generate_preemptrt_kernel_debian_package {
  echo "Generating Debian package..."
  sudo make -j$(nproc) deb-pkg
}

# Function for deciding whether to install the kernel now or install it later
function select_install_now {
  dialog --stdout --title "Install Debian package" --yesno "Want to install the Debian package now" 7 60
  echo $?
}

# Install PREEMPT_RT from the Debian package
function install_preemptrt_kernel_debian_package {
  echo "Installing Debian package..."
  sudo dpkg -i ../linux-image-${PREEMPT_RT_VER_FULL}_${PREEMPT_RT_VER_FULL}-1_$(dpkg --print-architecture).deb
}

# Install the kernel directly without creating a Debian package first
function install_preemptrt_kernel_directly {
  echo "Installing in the classic way..."
  sudo make -j$(nproc)
  sudo make modules_install -j$(nproc)
  sudo make install -j$(nproc)
}

# Install and let the user decide the kernel etc.
function install_kernel_interactive {
  {
    sudo apt-get install -y dialog
    install_dependencies
  } || {
    echo "Warning: Could not install dependencies. Installation might fail!"
  }

  # Get patch version via dialog
  local PREEMPT_RT_VER=$(select_preemptrt_major_version) # e.g. 5.10
  local PREEMPT_RT_VER_FULL=$(select_preemptrt_full_version) # e.g. 5.10.78-rt55
  local KERNEL_VER=$(reconstruct_kernel_major_version) # e.g. v5.x
  local KERNEL_VER_FULL=$(echo "${PREEMPT_RT_VER_FULL}" | sed 's/-rt.*//g') # e.g. 5.10.78

  # Download and extract the files for kernel and patch
  download_and_extract_kernel
  download_and_extract_preemptrt
  sign_kernel_and_preemptrt

  # Apply patch to kernel
  apply_patch_to_kernel
  generate_new_kernel_configuration
  unsign_kernel_configuration

  # Choose between Debian package and installing directly
  local INSTALLATION_MODE=$(select_installation_mode)
  if [ "${INSTALLATION_MODE}" == "Debian" ]
    then
      generate_preemptrt_kernel_debian_package
      INSTALL_NOW=$(select_install_now)
      if [ "${INSTALL_NOW}" -eq 0 ]
        then
          install_preemptrt_kernel_debian_package
          echo "Done: Installation with Debian package completed!"
      else 
        echo "Done: Debian package generated!"
      fi
  else
    install_preemptrt_kernel_directly
    echo "Done: Classic installation complete!"
  fi
}

# Installs the kernel as Debian package from a given command-line argument without interactive choices
function install_kernel_noninteractive {
  {
    install_dependencies
  } || {
    echo "Warning: Could not install dependencies. Installation might fail!"
  }

  local PREEMPT_RT_VER_FULL=$1 # e.g. 5.10.78-rt55
  local KERNEL_VER_FULL=$(echo "${PREEMPT_RT_VER_FULL}" | sed 's/-rt.*//g') # e.g. 5.10.78
  local PREEMPT_RT_VER=$(echo "${KERNEL_VER_FULL}" | sed 's/\.[^\.]*//2g') # e.g. 5.10
  local KERNEL_VER="v"$(echo "${PREEMPT_RT_VER}" | sed -n 's/\(.*\)[.]\(.*\)/\1.x/p') # e.g. v5.x

  download_and_extract_kernel
  download_and_extract_preemptrt
  sign_kernel_and_preemptrt
  apply_patch_to_kernel
  generate_new_kernel_configuration
  unsign_kernel_configuration
  generate_preemptrt_kernel_debian_package
  install_preemptrt_kernel_debian_package
  echo "Done: Installation with Debian package completed!"
}


# Install the kernel either in an interactive or non-interactive way depending if an input argument is given
function main {
  set -e # Exit immediately in case of failure
  if [ "$#" -eq 0 ]
    then
      install_kernel_interactive
  elif [ "$#" -eq 1 ] && [ "${EUID}" -eq 0 ]
    then
      install_kernel_noninteractive $@
  else
    echo "Error: Could not run installation script!"
    echo "Either launch it as: "
    echo " - '$ ./patch_kernel_preemprt.sh'"
    echo " - '$ sudo ./patch_kernel_preemprt.sh 5.10.78-rt55'"
    echo "For the available PREEMPT_RT versions see: "
    echo "see https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/"
    exit 1
  fi
  exit 0
}

main $@

