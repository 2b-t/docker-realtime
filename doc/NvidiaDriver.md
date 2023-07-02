# Nvidia driver and real-time kernel

Author: [Tobit Flatscher](https://github.com/2b-t) (July 2023)



## 0. Introduction

For the Nvidia driver to work with `PREEMPT_RT` the environment variable [`IGNORE_PREEMPT_RT_PRESENCE`](https://developer.nvidia.com/docs/drive/drive-os/archives/6.0.3/linux/sdk/oxy_ex-1/common/topics/sys_programming/Recompiling_Display_Kernel_Modules.html) has to be set when installing the driver.



## 1. Installation

Before starting the installation type the following in the terminal: **`export IGNORE_PREEMPT_RT_PRESENCE=1`**. Then (in the same terminal you set the environment variable in) install the Nvidia driver either from a [Debian package](https://gist.github.com/pantor/9786c41c03a97bca7a52aa0a72fa9387?permalink_comment_id=4230681#gistcomment-4230681)

```bash
$ export IGNORE_PREEMPT_RT_PRESENCE=1
$ sudo -E apt-get install nvidia-driver-XXX # where XXX is the driver version e.g. 535
```

or a `*.run` package as described [here](https://gist.github.com/pantor/9786c41c03a97bca7a52aa0a72fa9387), potentially compiling the recently released Nvidia open GPU kernel modules from source as described [here](https://github.com/NVIDIA/open-gpu-kernel-modules). For finding out which drivers are available for your graphics card (and which are recommended) you might check the `Software & Updates/Additional Drivers` menu.

Be sure that you [export the environment variable for use with `sudo`](https://unix.stackexchange.com/questions/337819/how-to-export-variable-for-use-with-sudo) with the flag `-E` or by setting the environment variable right before the command `$ sudo IGNORE_PREEMPT_RT_PRESENCE=1 apt-get install some-package`.

For more information on working with the Nvidia driver with Docker refer to [this guide](https://github.com/2b-t/docker-for-robotics/blob/main/doc/Gui.md).



## 1. Troubleshooting

In case you have trouble booting into a specific kernel after the update check which kernels with the Nvidia kernel module **`dkms status`** outputs:

```bash
$ dkms status
nvidia/535.54.03, 5.15.86-rt56, x86_64: installed
nvidia/535.54.03, 5.19.0-45-generic, x86_64: installed
```

and compare it to the output of

```bash
$ find /boot/vmli*
/boot/vmlinuz
/boot/vmlinuz-5.15.0-1040-realtime
/boot/vmlinuz-5.15.107-rt62
/boot/vmlinuz-5.15.86-rt56
/boot/vmlinuz-5.19.0-41-generic
/boot/vmlinuz-5.19.0-45-generic
/boot/vmlinuz.old
```

As you can see I have several kernels installed but the Nvidia kernel module was only successfully installed for two of them. In this case you can see that the Nvidia kernel module is not installed for `5.15.0-1040-realtime` as well as `5.15.107-rt62` and `5.19.0-41-generic`.

We can install them manually with

```bash
$ sudo dkms install nvidia/535.54.03 -k 5.19.0-41-generic
```

where the last argument corresponds to the kernel that the module should be installed for and the version of the Nvidia kernel module has to match the output from `dkms status`.

Again for the real-time kernels we will have to export `IGNORE_PREEMPT_RT_PRESENCE` first:

```bash
$ export IGNORE_PREEMPT_RT_PRESENCE=1
$ sudo -E dkms install nvidia/535.54.03 -k 5.15.0-1040-realtime
```

In case the installation fails this should at least output more information to why it failed.



