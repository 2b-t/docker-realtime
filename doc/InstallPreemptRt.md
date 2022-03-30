# Docker real-time guide for `PREEMPT_RT`

Author: [Tobit Flatscher](https://github.com/2b-t) (March 2022)



### 2.1 Setting-up `PREEMPT_RT`

The set-up of `PREEMPT_RT` basically consists in **installing a new kernel** either from an existing Debian package or by creating a Debian package yourself, **restarting** and booting into that freshly installed kernel, potentially changing the boot order.

#### 2.1.1 Known issues

The `PREEMPT_RT` kernels are known for causing a headache with nVidia graphics cards. Please have a look yourself before deciding to continue. Potentially you might be stuck with a lower refresh rate or lower resolution and for laptops you might lose access to your external display depending on the precise computer architecture.

#### 2.1.2 Installation

The installation can be performed either by installing the patch from an existing Debian package or by re-compiling the kernel yourself. While the first option should be preferred for having a more detailed control over the kernel set-up latter might be desired or might be your only options in rare cases of lacking compatibility.

##### 2.1.2.1 Installation from Debian package (recommended)

The installation from a Debian package is way **simpler** than the recompilation listed below but is at the same time **less flexible** as it is only available for a limited number of kernels and kernel configurations. You might not be able to make the Debian package work with your particular system and might have to re-compile the image anyways. Nonetheless it is highly advised that you follow these simple steps before turning to a full re-compilation of the kernel.

Have a look at the search results resulting from [this query on package.debian.org](https://packages.debian.org/search?keywords=linux-image-rt-amd64) and see if you can find a kernel close to yours, e.g. [this one](https://packages.debian.org/bullseye/linux-image-rt-amd64). If you can find one click on the architecture `amd64` under `Download linux-image-rt-amd64` on the bottom and select a geographically suiting mirror and save the image in a location of your choice.

Finally install it with

```shell
$ sudo dpkg -i linux-image-rt-amd64_5.10.106-1_amd64.deb
$ sudo apt-get install -f
```

Jump to section 2.1.3 and 2.1.4 and then try to reboot. In case it does not work for a few versions you will have to go for the full recompilation of the kernel as described in the section below.

##### 2.1.2.2 Re-compilation of the kernel

The re-compilation of the kernel is described in the [official Ubuntu installation guide](https://help.ubuntu.com/lts/installation-guide/amd64/install.en.pdf#page=98) but [might depend on the precise version](https://stackoverflow.com/a/51709420). Furthermore I ran into several issues which required me to change several parameters before compiling the kernel. These are described in more detail below but in case you can refer to [this](https://askubuntu.com/a/1338150) and [this](https://askubuntu.com/a/1329625) post for more details.

Start by installing the Debian packages required for the re-compilation

```shell
$ sudo apt-get install -y fakeroot kernel-package linux-source libncurses-dev libssl-dev equivs gcc flex bison dpkg-dev
```

Then have a look at [this webpage](https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/) and select a **patch version to install**, e.g. `5.10.78-rt55` under `5.10` (the versions are updated quite frequently, so this precise version might not work when you read this). Ideally the selected kernel version should be close to your current kernel version.

```shell
$ PATCH_VER_FULL="5.10.78-rt55" # Modify the patch version here (e.g. 5.10.78-rt55)
$ KERNEL_VER_FULL=$(echo "${PATCH_VER_FULL}" | sed 's/-rt.*//g') # e.g. 5.10.78
$ PATCH_VER=$(echo "${KERNEL_VER_FULL}" | sed 's/\.[^\.]*//2g') # e.g. 5.10
$ KERNEL_VER=$(echo "${PATCH_VER_FULL}" | sed -n 's/\(.*\)[.]\(.*\)[.]\(.*\)/\1.x/p') #e.g. 5.x
```

The lines above will create several variables that will be handy in the next steps. If the lines fail, print the values of the variables with `$ echo ${PATCH_VER_FULL}` and then make sure that the following links exist on the [server](https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/).

**Download and extract the wished kernel and real-time patch** as follows:

```shell
$ curl -SLO https://www.kernel.org/pub/linux/kernel/v${KERNEL_VER}/linux-${KERNEL_VER_FULL}.tar.xz
$ curl -SLO https://www.kernel.org/pub/linux/kernel/v${KERNEL_VER}/linux-${KERNEL_VER_FULL}.tar.sign

$ curl -SLO https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${PATCH_VER}/patch-${PATCH_VER_FULL}.patch.xz
$ curl -SLO https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${PATCH_VER}/patch-${PATCH_VER_FULL}.patch.sign 

$ xz -d linux-${KERNEL_VER_FULL}.tar.xz
$ tar xf linux-${KERNEL_VER_FULL}.tar

$ xz -d patch-${PATCH_VER_FULL}.patch.xz
```

then continue to patch the freshly extracted kernel.

 ```shell
 $ cd linux-${KERNEL_VER_FULL}
 $ patch -p1 < ../patch-${PATCH_VER_FULL}.patch
 ```

and **generate a new configuration** `.config` file with

```shell
$ make oldconfig
```

Go ahead and **change the relevant configuration parameters** if needed. This can be done graphically with `$ make xconfig`, `$ make menuconfig` or manually by modifying the `.config` file.

If the compilation later on fails you might have to try to change the following flags:

```shell
# Find and replace
CONFIG_MODULE_SIG=n
CONFIG_MODULE_SIG_ALL=n
CONFIG_MODULE_SIG_FORCE=n
CONFIG_MODULE_SIG_KEY=""
CONFIG_SYSTEM_TRUSTED_KEYS=""
```

Now it is time to build the kernel:

- If you want to build a **Debian package** then perform:

  ```shell
  $ make-kpkg clean # Optional to remove old relicts (from previously failed compilations)
  # The following command might take very long!
  $ fakeroot make-kpkg -j$(nproc) --initrd --revision=1.0.custom kernel_image
  $ sudo dpkg -i ../linux-image-${PATCH_VER_FULL}_1.0.custom_amd64.deb
  ```

  where the [`revision` parameter is just for keeping track of the version number of your kernel builds](https://www.debian.org/releases/wheezy/amd64/ch08s06.html.en) and can be changed at will, similarly for the `custom` word.

  In case you want to remove it again this can be easily done with:

  ```shell
  $ PATCH_VER_FULL="5.10.78-rt55" #Modify the kernel version here
  $ sudo dpkg -r linux-image-${PATCH_VER_FULL}
  ```

- Alternatively you can build and **install it directly** without creating a Debian package first

  ```shell
  $ make -j$(nproc)
  $ sudo make modules_install -j$(nproc)
  $ sudo make install -j$(nproc)
  ```

In order to check if the kernel compiled correctly you can output the kernel flags with [this tool](https://raw.githubusercontent.com/docker/docker/master/contrib/check-config.sh).

#### 2.1.3 Allowing the user to set real-time permissions

By default only your super-user will be able to set real-time priorities. In order to remove this restriction we will add a group named `realtime` and add our current user to it as described in the [Franka Emika Linux installation guide](https://frankaemika.github.io/docs/installation_linux.html)

```
sudo addgroup realtime
sudo usermod -a -G realtime $(whoami)
```

Adapt the [PAM limits](https://wiki.gentoo.org/wiki/Project:Sound/How_to_Enable_Realtime_for_Multimedia_Applications) located under `/etc/security/limits.conf` (as described [here](https://serverfault.com/questions/487602/linux-etc-security-limits-conf-explanation)) in the following way:

```
@some_group     soft    rtprio          99
@some_group     soft    priority        99
@some_group     hard    rtprio          99
@some_group     hard    priority        99
```

In this context `rtprio` is the maximum real-time priority allowed for non-privileged processes. The `hard` limit is the real limit to which the `soft` limit can be set to. The `hard` limits are set by the super-user and enforce by the kernel. The user cannot raise his code to run with a higher priority than the `hard` limit. The `soft` limit on the other hand is the default value limited by the `hard` limit. For more information see e.g. [here](https://linux.die.net/man/5/limits.conf).

#### 2.1.4 Changing boot order in Grub

Likely you will want to boot automatically into the real-time kernel. This can be done by **changing the Grub boot order** either [manually](https://askubuntu.com/a/110738) or by [using the graphical tool by Daniel Richter](https://askubuntu.com/a/100246) (recommended). Latter can be installed with the following commands

````sh
$ sudo add-apt-repository ppa:danielrichter2007/grub-customizer
$ sudo apt-get update
$ sudo apt-get install grub-customizer
````

and then launched

````sh
$ sudo grub-customizer
````

Select the desired kernel as default under `General/predefined`, close the GUI and restart your computer.

You can verify if you booted into the correct kernel by executing `$ uname -r` in the console. If set-up correctly your kernel should contain `rt` in its version.

Depending on the chosen installation procedure and BIOS set-up you **might have to turn off secure boot** in your UEFI BIOS menu or else you might not be able to boot.
