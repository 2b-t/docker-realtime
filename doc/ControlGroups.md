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

Before running a **process** with real-time scheduling it must be joined with a **real-time group** else the error `Unable to change scheduling policy! either run as root or join realtime group` will be shown.

[Running the process in the real-time `cgroup`](https://stackoverflow.com/a/60665456) can be performed as follows:

Install **`cgexec`** from the `cgroup-tools`

```shell
$ sudo apt-get install cgroup-tools
```

and then **launch a process** with

```shell
$ cgexec -g subsystems:path_to_cgroup command arguments
```

e.g. for the cyclictest:

```shell
$ sudo cgexec -g cpu:system.slice cyclictest -m -sp99 -d0
```

## 1. Control groups with `PREEMPT`

As already pointed out in [`realtime_basics/ControlGroups.md`](../realtime_basics/ControlGroups.md) real-time groups require the kernel flag `CONFIG_RT_GROUP_SCHED` and therefore you will likely have to recompile your kernel. Follow the installation in that guide before continuing.

Be warned: **Control groups are known to have a high amount of jitter** and are mentioned here just for completeness. They are unlikely to be sufficient for real-time robotics.

### 1.1 Launching a real-time Docker with control groups

In order to run a real-time Docker you will first have to **kill the Docker daemon** if it is already running with

```shell
$ sudo systemctl stop docker
$ sudo systemctl stop docker.socket
```

and then re-open it **assigning its control group a large time slice** such as `950000`:

```shell
$ sudo dockerd --cpu-rt-runtime=950000
```

The changes can also be made permanent by configuring the Docker daemon as described [here](https://docs.docker.com/config/containers/resource_constraints/#configure-the-docker-daemon) and [here](https://docs.docker.com/config/daemon/).

Finally you can also **launch the container with the real-time scheduler**

```shell
$ sudo docker run -it --cpu-rt-runtime=950000 --ulimit rtprio=99 --cap-add=sys_nice ubuntu:focal
```

Similarly in a Docker-Compose file this can be achieved with (see the official Docker-Compose specifications [here](https://github.com/compose-spec/compose-spec/blob/master/spec.md#cpu_rt_runtime) and [here](https://github.com/compose-spec/compose-spec/blob/master/spec.md#ulimits) as well as [this Github repository](https://github.com/ba-st/docker-pharo/blob/master/docs/rtprio.md) and [the official documentation for real-time privileges](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities) for more details):

```yml
    privileged: true
    cpu_rt_runtime: 950000
    ulimits:
      rtprio: 99
```

The real-time runtime `cpu.rt_runtime_us` allocated for each group can be inspected in `/sys/fs/cgroup/cpu,cpuacct`. In case you have already allocated a large portion of real-time runtime to another cgroup this might result in the error message `failed to write 95000 to cpu.rt_runtime_us: write /sys/fs/cgroup/cpu,cpuacct/system.slice/.../cpu.rt_runtime_us: invalid argument` or similar (as discussed [here](https://stackoverflow.com/questions/28493333/error-writing-to-cgroup-parameter-cpu-rt-runtime-us) and [here](https://github.com/moby/moby/issues/31411)). For more details on control groups in Linux see [here](https://www.kernel.org/doc/html/latest/scheduler/sched-rt-group.html) and [here](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v1/cgroups.html). Now any process that is launched should be assigned to the corresponding real-time control group.
