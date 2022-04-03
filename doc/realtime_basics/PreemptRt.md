# `PREEMPT_RT` set-up

Author: [Tobit Flatscher](https://github.com/2b-t) (August 2021 - April 2022)

## 1. Setting-up `PREEMPT_RT`

The set-up of `PREEMPT_RT` basically consists in **installing a new kernel** either from an existing **Debian package** that was compiled by somebody else for you, by creating a Debian package yourself by recompiling the kernel or installing it directly. After that you will have to perform a restart and booting into that freshly installed kernel as well as potentially changing the boot order in order to not having to boot into it manually at start-up.

### 1.1 Known issues

The `PREEMPT_RT` kernels are known for causing a headache with the **official Nvidia graphics driver**, at least the binary versions of it. Please have a look yourself before deciding to continue if you have an Nvidia GPU. Potentially you might end up with the Nouveau Linux graphics driver potentially with a lower refresh rate or lower resolution and for laptops you might lose access to your external display depending on the precise computer architecture and graphics card.

### 1.2 Installation

The installation of `PREEMPT_RT` can be performed either by installing the patch from an existing **Debian package** or by re-compiling the kernel yourself. While the first option should be preferred for having a more detailed control over the kernel set-up latter might still be desired or might be your only options in rare cases of lacking compatibility.

In the main folder of this I have provided a **script `/compile_kernel_preemptrt.sh`** which is able to install either from an existing Debian package or by recompiling the kernel automatically. This means it should not be necessary to perform this steps manually. Nonetheless I will leave this here as a reference!

#### 1.2.1 Installation from Debian package (recommended)

The installation from a Debian package is way **simpler** than the recompilation listed below but is at the same time **less flexible** as it is only available for a limited number of kernels and kernel configurations. You might not be able to make the Debian package work with your particular system and might have to re-compile the kernel anyways. Nonetheless it is **highly advised** that you follow these simple steps before turning to a full re-compilation of the kernel.

Have a look at the search results resulting from [this query on package.debian.org](https://packages.debian.org/search?keywords=linux-image-rt-amd64) (potentially changing the architecture!) and see if you can find a kernel close to yours, e.g. [this one](https://packages.debian.org/bullseye/linux-image-rt-amd64). If you can find one click on the architecture `amd64` under `Download linux-image-rt-amd64` on the bottom and select a geographically suiting mirror and save the image in a location of your choice.

Finally install it by opening a terminal in this folder and typing

```shell
$ sudo dpkg -i linux-image-rt-amd64_5.10.106-1_amd64.deb
$ sudo apt-get install -f
```

Jump to section 2.1.3 and then try to reboot. In case it does not work you will have to go for the full recompilation of the kernel as described in the section below, else congratulations you have saved yourself some time and effort!

#### 1.2.2 Re-compilation of the kernel

The re-compilation of the kernel is described in the [official Ubuntu installation guide](https://help.ubuntu.com/lts/installation-guide/amd64/install.en.pdf#page=98) as well as on the [Franka Emika installation guide](https://frankaemika.github.io/docs/installation_linux.html#setting-up-the-real-time-kernel) page but [might depend on the precise version](https://stackoverflow.com/a/51709420). In case you are running into issues you might have to consider [this](https://askubuntu.com/a/1338150) and [this](https://askubuntu.com/a/1329625) post.

Start by installing the Debian packages required for the re-compilation. For a Debian-based Linux distribution this can be done conveniently with:

```shell
$ sudo apt-get install -y build-essential bc curl ca-certificates gnupg2 libssl-dev lsb-release libelf-dev bison flex dwarves zstd libncurses-dev fakeroot kernel-package linux-source equivs gcc dpkg-dev
```

Then have a look at [this webpage](https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/) and select a **patch version to install**, e.g. `5.10.78-rt55` under `5.10` (the versions are updated quite frequently, so this precise version might not work when you read this). Ideally the selected kernel version **should be close to your current kernel version**.

```shell
$ PREEMPT_RT_VER_FULL="5.10.78-rt55" # Modify the patch version here (e.g. 5.10.78-rt55)
$ KERNEL_VER_FULL=$(echo "${PREEMPT_RT_VER_FULL}" | sed 's/-rt.*//g') # e.g. 5.10.78
$ PREEMPT_RT_VER=$(echo "${KERNEL_VER_FULL}" | sed 's/\.[^\.]*//2g') # e.g. 5.10
$ KERNEL_VER="v"$(echo "${PREEMPT_RT_VER}" | sed -n 's/\(.*\)[.]\(.*\)/\1.x/p') # e.g. v5.x
```

The lines above will create several variables that will be handy in the next steps. If the lines fail, print the values of the variables with `$ echo ${PATCH_VER_FULL}` and then make sure that the following links exist on the [server](https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/).

**Download and extract the wished kernel and real-time patch** as follows:

```shell
$ curl -SLO --fail https://www.kernel.org/pub/linux/kernel/v${KERNEL_VER}/linux-${KERNEL_VER_FULL}.tar.xz
$ curl -SLO --fail https://www.kernel.org/pub/linux/kernel/v${KERNEL_VER}/linux-${KERNEL_VER_FULL}.tar.sign
$ xz -d linux-${KERNEL_VER_FULL}.tar.xz

$ curl -SLO --fail https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${PREEMPT_RT_VER}/patch-${PREEMPT_RT_VER_FULL}.patch.xz
$ curl -SLO --fail https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${PREEMPT_RT_VER}/patch-${PREEMPT_RT_VER_FULL}.patch.sign 
$ xz -d patch-${PREEMPT_RT_VER_FULL}.patch.xz
```

Verifying the file integrity is not necessary but highly recommended in order to make sure that the files are not corrupted and nobody modified them as described in more detail [here](https://www.kernel.org/signature.html). This can be done with `gpg2` as follows:

 ```shell
gpg2 --verify linux-${KERNEL_VER_FULL}.tar.sign
gpg2 --verify patch-${PREEMPT_RT_VER_FULL}.patch.sign
 ```

In case your output is `gpg: Can't check signature: No public key` you will have to download the public key of the person who signed the file by taking the given `RSA key ID` and obtain it:

```bash
gpg2 --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys <key>
```

After this you should be able to repeat the procedure, sign the key and proceed to extract the wished kernel:

```shell
$ tar xf linux-${KERNEL_VER_FULL}.tar
```

then continue to patch the freshly extracted kernel.

 ```shell
 $ cd linux-${KERNEL_VER_FULL}
 $ patch -p1 < ../patch-${PREEMPT_RT_VER_FULL}.patch
 ```

and **generate a new configuration** `.config` file with

```shell
$ make oldconfig
```

Go ahead and **change the relevant configuration parameters** if you want to. This can be done graphically with `$ make xconfig`, `$ make menuconfig` or manually by modifying the `.config` file located inside `linux-${KERNEL_VER_FULL}`. The [German Open Source Automation Development Lab (OSADL) ](https://www.osadl.org/) performs long-term tests on several kernel versions and publishes the results on the internet. One might want to use these parameters instead rather than working with his/her own `.config` file. An overview of the corresponding systems can be found [here](https://www.osadl.org/Real-time-optimization.qa-farm-latency-optimization.0.html) and the configuration file for a particular system can be downloaded (e.g. [this one](https://www.osadl.org/?id=1087#kernel)).

For a successful installation I have to change the following parameters inside the `.config` file:

```shell
# Find and replace
CONFIG_SYSTEM_TRUSTED_KEYS=""
CONFIG_SYSTEM_REVOCATION_KEYS=""
```

If your compilation fails nonetheless retry modifying these parameters as well:

```shell
# Find and replace if compilation fails
CONFIG_MODULE_SIG=n
CONFIG_MODULE_SIG_ALL=n
CONFIG_MODULE_SIG_FORCE=n
CONFIG_MODULE_SIG_KEY=""
CONFIG_X86_X32=""
```

Now it is time to build the kernel:

- If you want to build a **Debian package** (recommended) then perform:

  ```shell
  $ make clean # Optional to remove old relicts (from previously failed compilations)
  # The following command might take very long!
  $ sudo make -j$(nproc) deb-pkg
  ```
  
  where the [`revision` parameter is just for keeping track of the version number of your kernel builds](https://www.debian.org/releases/wheezy/amd64/ch08s06.html.en) and can be changed at will, similarly for the `custom` word.
  
  In case you want to remove it again later on this can be easily done with:
  
  ```shell
  $ PREEMPT_RT_VER_FULL="5.10.78-rt55" # Modify the kernel version here
  $ sudo dpkg -r linux-image-${PREEMPT_RT_VER_FULL}
  ```
  
  The advantage of the Debian package is that you can distribute and remove it more easily than the direct installation. 
  
- Alternatively you can build and **install it directly** without creating a Debian package first

  ```shell
  $ sudo make -j$(nproc)
  $ sudo make modules_install -j$(nproc)
  $ sudo make install -j$(nproc)
  ```

Continue to restart the computer and boot into the newly installed kernel. Depending on the chosen installation procedure and BIOS set-up you **might have to turn off secure boot** in your UEFI BIOS menu or else you might not be able to boot. You can verify if you booted into the correct kernel by executing `$ uname -r` in the console. If set-up correctly your kernel should contain `rt` in its version and `/sys/kernel/realtime` should exist and contain the value `1`. In order to check if the kernel compiled correctly you can output the kernel flags with [this tool](https://raw.githubusercontent.com/docker/docker/master/contrib/check-config.sh).

### 1.3 Allowing the user to set real-time permissions

By default only your super-user will be able to set real-time priorities (see `$ ulimit -r`). In case you do not intend to use [`root` as the user inside the Docker](https://medium.com/jobteaser-dev-team/docker-user-best-practices-a8d2ca5205f4) you will have to remove this restriction and you will have add a group named `realtime` (the name of the group is your choice and you could also only add a single user instead of a dedicated group) and add our current user to it as described in the [Franka Emika Linux installation guide](https://frankaemika.github.io/docs/installation_linux.html). First execute

```bash
$ sudo addgroup realtime
$ sudo usermod -a -G realtime $(whoami) # Or another user if you are using another name inside the Docker
```

and then adapt the [PAM limits](https://wiki.gentoo.org/wiki/Project:Sound/How_to_Enable_Realtime_for_Multimedia_Applications) located under `/etc/security/limits.conf` (as described [here](https://serverfault.com/questions/487602/linux-etc-security-limits-conf-explanation)) in the following way:

```
@realtime     soft    rtprio          99
@realtime     soft    priority        99
@realtime     soft    memlock     102400
@realtime     hard    rtprio          99
@realtime     hard    priority        99
@realtime     hard    memlock     102400
```

In this context `rtprio` is the maximum real-time priority allowed for non-privileged processes. The `hard` limit is the real limit to which the `soft` limit can be set to. The `hard` limits are set by the super-user and enforce by the kernel. The user cannot raise his code to run with a higher priority than the `hard` limit. The `soft` limit on the other hand is the default value limited by the `hard` limit. For more information on the parameters see e.g. [here](https://linux.die.net/man/5/limits.conf).
