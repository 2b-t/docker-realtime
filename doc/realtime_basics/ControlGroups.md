# Linux control groups

Author: [Tobit Flatscher](https://github.com/2b-t) (August 2021 - April 2022)



## 1. Control groups

As pointed out in the guide [`RealTimeLinux.md`](./RealTimeLinux.md) one way of real-time Linux are so called control groups. This requires though that the kernel is compiled with the flag **`CONFIG_RT_GROUP_SCHED`**. This is not the case by default for Ubuntu and neither are there public Debian packages. In case you are not sure if your kernel already has it set, launch [this script](https://raw.githubusercontent.com/docker/docker/master/contrib/check-config.sh). In case you do not have it, you will have to recompile your kernel. This is discussed in the next section.

As stated [here](https://wiki.linuxfoundation.org/realtime/documentation/known_limitations) `PREEMPT_RT` currently can't be compiled with the `CONFIG_RT_GROUP_SCHED` and therefore you can't combine control groups with the `PREEMPT_RT` patch (see [here for a comparison](https://stackoverflow.com/questions/62932857/difference-between-config-rt-group-sched-and-preempt-rt)).

### 1.1 Compile the kernel

The recompilation of the kernel is very similar to the one described in [`PreemptRt.md`](./PreemptRt.md) but clearly one has to skip every step involving the `PREEMPT_RT` patch. Therefore the steps in common are left out and instead only the differences are discussed. After having **generate a new configuration** `.config` file with

```shell
$ make oldconfig
```

Go ahead and **change the relevant configuration parameters**, unsigning the kernel and also adding the last two options on the bottom:

```shell
# Find and replace
CONFIG_MODULE_SIG=n
CONFIG_MODULE_SIG_ALL=n
CONFIG_MODULE_SIG_FORCE=n
CONFIG_MODULE_SIG_KEY=""
CONFIG_SYSTEM_TRUSTED_KEYS=""

# Add or replace
CONFIG_PREEMPT=y # Optional
CONFIG_RT_GROUP_SCHED=y
```

Then you can follow through with the compilation. You have the same options as without the patch, just the filenames change (as obviously there is no patch).

### 1.2 Launching control groups

Before running a process with real-time scheduling it must be joined with a real-time group else the error `Unable to change scheduling policy! either run as root or join realtime group` will be shown.

[Running the process in the real-time `cgroup`](https://stackoverflow.com/a/60665456) can be performed as follows:

Install **`cgexec`** from the `cgroup-tools`

```shell
$ sudo apt-get install cgroup-tools
```

andthen **launch a process** with

```shell
$ cgexec -g subsystems:path_to_cgroup command arguments
```

e.g. for the cyclictest:

```shell
$ sudo cgexec -g cpu:system.slice cyclictest -m -sp99 -d0
```

