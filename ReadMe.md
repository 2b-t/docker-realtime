# Docker real-time guide for `PREEMPT_RT`

Author: [Tobit Flatscher](https://github.com/2b-t) (August 2021 - April 2022)



## 0. Overview

This is guide explains how one can **develop inside a [Docker container](https://www.docker.com/) while being able to run real-time capable code on a Linux operating system**. This is in particular desirable for **robotics**, such as commanding the [Franka Emika Panda](https://www.franka.de/) collaborative robotic arm but may also apply to software developers developing any other form of real-time capable code.

The proposed solution simply consists in having a **[`PREEMPT_RT`](https://wiki.linuxfoundation.org/realtime/start) patched host system** and launching it with the correct Docker options **`--privileged --net=host`** but this repository also discusses other useful Docker- and real-time-related issues that might be interesting for a wider audience such as:

- It provies a brief [introduction into development with Docker](./doc/docker_basics/introduction.md) as well as Docker-Compose generally and how you can [set it up in *Visual Studio Code*](./doc/docker_basics/VisualStudioCodeSetup.md), including a guide on how to use [*graphic user interfaces with Docker*](./doc/docker_basics/Gui.md) and tips on how to structure a [ROS workspace](./doc/docker_basics/Ros.md) with it.
- Give an [*overview of different real-time Linux approaches*](./doc/realtime_basics/RealTimeLinux.md), their advantages and disadvantages
- Walk you through the [*installation of `PREEMPT_RT`*](./doc/realtime_basics/PreemptRt.md) and supply a simple [*script for automatically re-compiling the kernel*](./compile_kernel_preemptrt.sh)
- Discusses [*control groups*](./doc/docker_realtime/ControlGroups.md), another common approach for real-time Linux and how to get it up and running with Docker
- *Benchmarking your real-time performance* by means of [`cyclictest`](https://wiki.linuxfoundation.org/realtime/documentation/howto/tools/cyclictest/start)

Therefore the guide should be useful for people interested in having real-time capable code inside a Docker as well as people just starting with Docker, in particular for robotics. If you fall into the latter category or simply want to revisit the Docker and Docker-Compose basics first, have a look at the guide [`doc/docker_basics/Introduction.md`](./doc/docker_basics/Introduction.md) and find out how you can use them conveniently in Visual Studio Code [`doc/docker_basics/VisualStudioCodeSetup.md`](./doc/docker_basics/VisualStudioCodeSetup.md).

## 1. Real-time Docker

When developing with Docker one soon realizes that it simplifies software development immensely but that there are some topics which are very relevant but one can't find much information on, for example how to launch graphic user interfaces from inside a Docker (refer to [`doc/docker_basics/Gui.md`](./doc/docker_basics/Gui.md) if you are interested in it) or how to run real-time processes from inside a Docker. These limitations are actually by design but might not be desirable for certain applications.

For real-time operating systems there exist several different approaches with different characteristics (see [`doc/realtime_basics/RealTimeLinux.md`](./doc/realtime_basics/RealTimeLinux.md) for a comparison). When looking at the official Docker documentation you will come across `cgroups` (see [`doc/docker_realtime/ControlGroups.md`](./doc/docker_realtime/ControlGroups.md) on how to set this up), which from my experience are not useful for robotics applications due to high jitter. Another common approach, which is used by [Franka Emika](https://frankaemika.github.io/docs/installation_linux.html), is actually the `PREEMPT_RT` patch. As outlined in [`doc/realtime_basics/RealTimeLinux.md`](./doc/realtime_basics/RealTimeLinux.md) it is likely the most future-proof possibility as it is about to be included into the mainline of Linux.

The set-up of a real-time capable Docker with `PREEMPT_RT` is particularly easy. All you need is:

- A **`PREEMPT_RT`-patched host operating system**
- An arbitrary **Docker container** launched with the **`privileged`** option with a user that has real-time privileges on the host machine. If you want to have a low latency for network communication, such as for controlling Ethercat slaves, the `network=host` should reduce any overhead to a bare minimum.

The manual set-up of `PREEMPT_RT` takes quite a while (see [`doc/realtime_basics/PreemptRt.md`](./doc/realtime_basics/PreemptRt.md)). You have two options, a custom re-compilation of the kernel or an installation from an existing Debian package. 

### 1.1 Installing `PREEMPT_RT`

The installation procedure either by compilation from source or from an existing [Debian package](https://packages.debian.org/buster/linux-image-rt-amd64) is lined out in [`doc/realtime_basics/PreemptRt.md`](./doc/realtime_basics/PreemptRt.md). The same procedure can also be performed with the provided scripts [`install_debian_preemptrt.sh`](./install_debian_preemptrt) and [`compile_kernel_preemptrt.sh`](./compile_kernel_preemptrt.sh).

[`install_debian_preemptrt.sh`](./install_debian_preemptrt) checks online if there are already precompiled `PREEMPT_RT` packages available and lets you select a suiting version graphically, while [`compile_kernel_preemptrt.sh`](./compile_kernel_preemptrt.sh) compiles the kernel from scratch from you and installs it.

#### 1.1.1 Installation from pre-compiled Debian package (recommended)

Start of by launching [`install_debian_preemptrt.sh`](./install_debian_preemptrt) and follow the installation instructions

```shell
$ ./install_debian_preemptrt.sh
```

Afterwards you can reboot your system (be sure to select the correct kernel!) and should already be ready to go. You can check the kernel version with `$ uname -r` to verify that you are using the correct kernel and the installation was indeed successful.

#### 1.1.2 Compilation of the kernel

If the installation above fails or for some good reason you have to compile the kernel yourself you can use the [`compile_kernel_preemptrt.sh`](./compile_kernel_preemptrt.sh) script.

You can launch it in two different ways:

```shell
$ ./compile_kernel_preemptrt.sh
```

will install the required dependencies and then open a dialog which lets you browse the possible versions and available options manually, reducing the copy and paste operations.

If you supply a correct real-time patch version from the list of available ones as an input argument, launching the command with superuser privileges it will download all files, patch the kernel, create a Debian package if no official one is available and install it automatically.

```shell
$ sudo ./compile_kernel_preemptrt.sh 5.10.78-rt55
```

This might be helpful for deploying a new kernel automatically on a remote system. The possible version numbers can be found at [here](https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/).

### 1.2 Setting up real-time privileges

After having patched your system and a restart booting into the freshly installed kernel (see [`doc/realtime_basics/ChangeBootOrder.md`](./doc/realtime_basics/ChangeBootOrder.md)) you should already be good to go to launch a real-time capable Docker with `sudo`. In case you do not intend to use [`root` as the user inside the Docker](https://medium.com/jobteaser-dev-team/docker-user-best-practices-a8d2ca5205f4) you furthermore will have to have give yourself a name of a user that belongs to a group with **real-time privileges on your host computer**. How this can be done can be found in [`doc/realtime_basics/PreemptRt.md`](./doc/realtime_basics/PreemptRt.md).

### 1.3 Launching the Docker

**After having successfully installed `PREEMPT_RT`**, it is sufficient to execute the Docker with the options **`--privileged --net=host`**, or the Docker-compose equivalent

```yaml
privileged: true
network_mode: host
```

Launching the container as `privileged` and `net=host` should also help minimise the overhead as discussed [here](https://pythonspeed.com/articles/docker-performance-overhead/9) and [here](https://stackoverflow.com/a/26149994).

Then **any process from inside the Docker can set real-time priorities `rtprio`** (e.g. by calling [`::pthread_setschedparam`](https://man7.org/linux/man-pages/man3/pthread_getschedparam.3.html) from inside the code or by using [`chrt`](https://askubuntu.com/a/51285) from the command line).

## 2. Examples

This Github repository comes with a simple example that can be used to try it out. Inside the Docker container a cyclic test is run to assess the real-time performance of the system.
