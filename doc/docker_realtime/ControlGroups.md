# Linux control groups inside Docker

Author: [Tobit Flatscher](https://github.com/2b-t) (August 2021 - August 2022)



## 1. Control groups with `PREEMPT`

As already pointed out in [`realtime_basics/ControlGroups.md`](../realtime_basics/ControlGroups.md) real-time groups require the kernel flag `CONFIG_RT_GROUP_SCHED` and therefore you will likely have to recompile your kernel. Follow the installation in that guide before continuing.

Be warned: **Control groups are known to have a high amount of jitter** and are mentioned here just for completeness. They are unlikely to be sufficient for real-time robotics.

### 1.1 Launching a real-time Docker with control groups

In order to run a real-time Docker you will first have to **kill the Docker daemon** if it is already running with

```shell
$ sudo systemctl stop docker
$ sudo systemctl stop docker.socket
```

and then re-open it assigning its control group a large time slice such as `950000`:

```shell
$ sudo dockerd --cpu-rt-runtime=950000
```

The changes can also be made permanent by configuring the Docker daemon as described [here](https://docs.docker.com/config/containers/resource_constraints/#configure-the-docker-daemon) and [here](https://docs.docker.com/config/daemon/).

Finally you can also launch the container with the real-time scheduler

```shell
$ sudo docker run -it --cpu-rt-runtime=950000 --ulimit rtprio=99 --cap-add=sys_nice ubuntu:focal
```

Similarly in a Docker-Compose file this can be achieved with (see [here](https://github.com/compose-spec/compose-spec/blob/master/spec.md#cpu_rt_runtime), [here](https://github.com/compose-spec/compose-spec/blob/master/spec.md#ulimits) as well as [here](https://github.com/ba-st/docker-pharo/blob/master/docs/rtprio.md) and [here](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities) for more details):

```yml
privileged: true
cpu_rt_runtime: 950000
ulimits:
  rtprio: 99
```

The real-time runtime `cpu.rt_runtime_us` allocated for each group can be inspected in `/sys/fs/cgroup/cpu,cpuacct`. In case you have already allocated a large portion of real-time runtime to another cgroup this might result in the error message `failed to write 95000 to cpu.rt_runtime_us: write /sys/fs/cgroup/cpu,cpuacct/system.slice/.../cpu.rt_runtime_us: invalid argument` or similar (as discussed [here](https://stackoverflow.com/questions/28493333/error-writing-to-cgroup-parameter-cpu-rt-runtime-us) and [here](https://github.com/moby/moby/issues/31411)). For more details on control groups in Linux see [here](https://www.kernel.org/doc/html/latest/scheduler/sched-rt-group.html) and [here](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v1/cgroups.html). Now any process that is launched should be assigned to the corresponding real-time control group.
