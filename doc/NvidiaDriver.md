# Nvidia driver and real-time kernel

Author: [Tobit Flatscher](https://github.com/2b-t) (July 2023)



## 0. Introduction

For the Nvidia driver to work with `PREEMPT_RT` the environment variable [`IGNORE_PREEMPT_RT_PRESENCE`](https://developer.nvidia.com/docs/drive/drive-os/archives/6.0.3/linux/sdk/oxy_ex-1/common/topics/sys_programming/Recompiling_Display_Kernel_Modules.html) has to be set when installing the driver. Before starting the installation type the following in the terminal: **`export IGNORE_PREEMPT_RT_PRESENCE=1`**. Then (in the same terminal you set the environment variable in) install the Nvidia driver either from a [Debian package](https://gist.github.com/pantor/9786c41c03a97bca7a52aa0a72fa9387?permalink_comment_id=4230681#gistcomment-4230681)

```bash
$ export IGNORE_PREEMPT_RT_PRESENCE=1
$ sudo -E apt-get install nvidia-driver-XXX # where XXX is the driver version e.g. 535
```

or a `*.run` package as described [here](https://gist.github.com/pantor/9786c41c03a97bca7a52aa0a72fa9387), potentially compiling the recently released Nvidia open GPU kernel modules from source as described [here](https://github.com/NVIDIA/open-gpu-kernel-modules). For finding out which drivers are available for your graphics card (and which are recommended) you might check the `Software & Updates/Additional Drivers` menu.

Be sure that you [export the environment variable for use with `sudo`](https://unix.stackexchange.com/questions/337819/how-to-export-variable-for-use-with-sudo) with the flag `-E` or by setting the environment variable right before the command `$ sudo IGNORE_PREEMPT_RT_PRESENCE=1 apt-get install some-package`.

For more information on working with the Nvidia driver with Docker refer to [this guide](https://github.com/2b-t/docker-for-robotics/blob/main/doc/Gui.md).
