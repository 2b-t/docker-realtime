#!/bin/bash
# Installation script for PREEMPT_RT real-time patch with simple graphical interface
# Tobit Flatscher - github.com/2b-t (2022)


# Install required dependencies
function install_dependencies {
  echo "Installing dependencies..."
  sudo apt-get install -y dialog
  sudo apt-get install -y grep curl
  sudo apt-get install -y fakeroot kernel-package linux-source libncurses-dev libssl-dev equivs gcc flex bison dpkg-dev
  echo "Dependencies installed successfully"
}

# Get major versions by crawling website
function get_preemptrt_major_versions {
  echo $(curl -Ls https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt | grep -o -P '(?<=href\=\")(\d\.\d*)+(?=/\">)')
}

# Select the desired major version with a user dialog
function select_preemptrt_major_version {
  local PREEMPTRT_MAJOR_VERSIONS=$(get_preemptrt_major_versions)
  local DIALOG_PREEMPTRT_MAJOR_VERSIONS
  for VER in $PREEMPTRT_MAJOR_VERSIONS
  do
    DIALOG_PREEMPTRT_MAJOR_VERSIONS="$DIALOG_PREEMPTRT_MAJOR_VERSIONS $VER $VER"
  done
  CURRENT_KERNEL_VERSION=$(uname -r | sed 's/\.[^\.]*//2g')
  echo $(dialog --no-tags --stdout --default-item $CURRENT_KERNEL_VERSION --menu "Select a major kernel version:" 30 40 10 $DIALOG_PREEMPTRT_MAJOR_VERSIONS)
}

# Get the full versions by crawling website
function get_preemptrt_full_versions {
  echo $(curl -Ls https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/$PREEMPT_RT_VER | grep -o -P '(?<=href\=\"patch-).*(?=.patch.gz\">)')
}

# Select the desired major version with a user dialog
function select_preemptrt_full_version {
  local PREEMPTRT_FULL_VERSIONS=$(get_preemptrt_full_versions)
  local DIALOG_PREEMPTRT_FULL_VERSIONS
  for VER in $PREEMPTRT_FULL_VERSIONS
  do
    DIALOG_PREEMPTRT_FULL_VERSIONS="$DIALOG_PREEMPTRT_FULL_VERSIONS $VER $VER"
  done
  echo $(dialog --no-tags --stdout --menu "Select the desired version of PREEMPT_RT:" 30 40 10 $DIALOG_PREEMPTRT_FULL_VERSIONS)
}

# Reconstruct the corresponding kernel major version
function reconstruct_kernel_major_version {
  local KERNEL_MAJOR_VERSION=$(echo "${PREEMPT_RT_VER}" | grep -o -P '^\s*(\d)+')
  echo "$(curl -Ls https://www.kernel.org/pub/linux/kernel | grep -o -P "(?<=href\=\")(v$KERNEL_MAJOR_VERSION.*)(?=/\">)")"
}

# Download and extract the vanilla kernel
function download_and_extract_kernel {
  echo "Downloading kernel '${KERNEL_VER_FULL}'..."
  echo "https://www.kernel.org/pub/linux/kernel/${KERNEL_VER}/linux-${KERNEL_VER_FULL}.tar.xz"
  echo "https://www.kernel.org/pub/linux/kernel/${KERNEL_VER}/linux-${KERNEL_VER_FULL}.tar.sign"
  curl -SLO --fail https://www.kernel.org/pub/linux/kernel/${KERNEL_VER}/linux-${KERNEL_VER_FULL}.tar.xz
  curl -SLO --fail https://www.kernel.org/pub/linux/kernel/${KERNEL_VER}/linux-${KERNEL_VER_FULL}.tar.sign
  xz -d linux-${KERNEL_VER_FULL}.tar.xz
  tar xf linux-${KERNEL_VER_FULL}.tar
}

# Download and extract the PREEMPT_RT patch
function download_and_extract_preemptrt {
  echo "Downloading PREEMPT_RT patch '${PREEMPT_RT_VER_FULL}'..."
  echo "https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${PREEMPT_RT_VER}/patch-${PREEMPT_RT_VER_FULL}.patch.xz"
  echo "https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${PREEMPT_RT_VER}/patch-${PREEMPT_RT_VER_FULL}.patch.sign"
  curl -SLO --fail https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${PREEMPT_RT_VER}/patch-${PREEMPT_RT_VER_FULL}.patch.xz
  curl -SLO --fail https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${PREEMPT_RT_VER}/patch-${PREEMPT_RT_VER_FULL}.patch.sign 
  xz -d patch-${PREEMPT_RT_VER_FULL}.patch.xz
}

# Apply the patch to the kernel
function apply_patch_to_kernel {
  echo "Applying PREEMPT_RT patch '${PREEMPT_RT_VER_FULL}' to kernel '${KERNEL_VER_FULL}'..."
  cd linux-${KERNEL_VER_FULL}
  patch -p1 < ../patch-${PREEMPT_RT_VER_FULL}.patch
}

# Generate a new kernel configuration
function generate_new_kernel_configuration {
  make oldconfig
}

# Select the installation modality
function select_installation_mode {
  echo $(dialog --stdout --default-item "Debian package" --menu "Select the desired installation mode:" 30 40 10 "Debian" "Debian package" "Classic" "Install directly")
}

# Generate a debian package for easier installation
function generate_preemptrt_debian_package {
  echo "Generating Debian package..."
  make-kpkg clean
  fakeroot make-kpkg -j$(nproc) --initrd --revision=1.0.custom kernel_image
}

# Install PREEMPT_RT from the Debian package
function install_preemptrt_kernel_as_debian_package {
  echo "Installing Debian package..."
  #sudo dpkg -i ../linux-image-${PREEMPT_RT_VER_FULL}_1.0.custom_amd64.deb
}

# Install the kernel directly without creating a Debian package first
function install_preemptrt_kernel_directly {
  echo "Installing in the classic way..."
  make -j$(nproc)
  sudo make modules_install -j$(nproc)
  sudo make install -j$(nproc)
}


function main {
  {
    install_dependencies
  } || {
    echo "Warning: Could not install dependencies. Installation might fail!"
  }

  # Get patch version via dialog
  local PREEMPT_RT_VER=$(select_preemptrt_major_version) # e.g. 5.10
  local PREEMPT_RT_VER_FULL=$(select_preemptrt_full_version) # e.g. 5.10.78-rt55
  local KERNEL_VER=$(reconstruct_kernel_major_version) # e.g. v5.x
  local KERNEL_VER_FULL=$(echo "${PREEMPT_RT_VER_FULL}" | sed 's/-rt.*//g') # e.g. 5.10.78

  # Download and extract the files
  download_and_extract_kernel
  download_and_extract_preemptrt

  # Apply patch to kernel
  apply_patch_to_kernel
  generate_new_kernel_configuration

  # Choose between Debian package and installing directly
  local INSTALLATION_MODE=$(select_installation_mode)
  if [ "$INSTALLATION_MODE" == "Debian" ]; then
    generate_preemptrt_debian_package
    install_preemptrt_kernel_as_debian_package
  else
    install_preemptrt_kernel_directly
  fi

  exit 0
}

main $@

