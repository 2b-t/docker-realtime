# Docker real-time guide for `PREEMPT_RT`

Author: [Tobit Flatscher](https://github.com/2b-t) (March 2022)



## 0. Overview

This guide first gives a brief overview over common ways of increasing the **real-time** performance of a **Linux** operating system and then shows how one can have real-time performance from inside a [**Docker** container](https://www.docker.com/) with the [**`PREEMPT_RT` patch**](https://wiki.linuxfoundation.org/realtime/start).

This might be in particular desirable for **robotic systems** such as commanding a [Franka Emika Panda](https://www.franka.de/) collaborative robotic arm from a Docker container instead having to install all the different libraries on your system directly.

## 1. Real-time Linux

There are different approaches for real-time Linux which can be divided in dual and single (`PREEMPT_RT`) kernel approaches. The main differences between them are discussed in the document [`/doc/RealTimeLinuxGuide.md`](./doc/RealTimeLinuxGuide.md).

## 2. Real-time Docker with `PREEMPT_RT`

As outlined in the document linked above `PREEMPT_RT` is likely the most future-proof open-source way of achieving real-time performance. The guide shows how a Docker can be used in combination with an Linux operating system with `PREEMPT_RT` patch.

### 2.1 Installing `PREEMPT_RT`

The installation procedure either by compilation from source or from an existing [Debian package](https://packages.debian.org/buster/linux-image-rt-amd64) is lined out in [`/doc/InstallPreemptRt.md`](./doc/InstallPreemptRt.md).

### 2.3 Launching the Docker

**After having successfully installed `PREEMPT_RT`**, it is sufficient to execute the Docker with the options **`--privileged --net=host`**, or the Docker-compose equivalent `privileged: true network_mode: host`. Then **any process from inside the Docker can set real-time priorities `rtprio`** (e.g. by calling [`::pthread_setschedparam`](https://man7.org/linux/man-pages/man3/pthread_getschedparam.3.html) from inside the code or by using [`chrt`](https://askubuntu.com/a/51285) from the command line).

### 2.2 Setting up real-time privileges

In case you are [not using the `root` as user inside the Docker](https://medium.com/jobteaser-dev-team/docker-user-best-practices-a8d2ca5205f4) you furthermore will have to have give yourself a name of a user that belongs to a group with **real-time privileges on your host computer** (see `$ ulimit -r`). This can be done by configuring the [PAM limits](https://wiki.gentoo.org/wiki/Project:Sound/How_to_Enable_Realtime_for_Multimedia_Applications) (`/etc/security/limits.conf` file, as previously described in the installation document [`/doc/InstallPreemptRt.md`](./doc/InstallPreemptRt.md)) accordingly by copying the section of the `@realtime` user group and creating a new group (e.g. `@some_group`) or adding the user (e.g. `some_user`) directly:

```
@some_group     soft    rtprio          99
@some_group     soft    priority        99
@some_group     hard    rtprio          99
@some_group     hard    priority        99
```

## 3. Example

This Github repository comes with a simple example that can be used to try it out. Inside the Docker container a cyclic test is run to assess the real-time performance of the system.
