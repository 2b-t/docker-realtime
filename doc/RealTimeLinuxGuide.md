# Docker real-time guide for `PREEMPT_RT`

Author: [Tobit Flatscher](https://github.com/2b-t) (March 2022)



## 1. Real-time Linux

Task scheduling on standard operating systems is to some extend non-deterministic, meaning one cannot give a guaranteed - mathematically proovable - upper bound for the execution time.

But for any real-time system one wants to be able to give such an upper bound that a given task will never exceed. Rather than executing something as fast as possible the aim is to **execute tasks consistently**: What matters is the **worst case latency** rather than the average latency. There are different approaches for rendering (Linux) operating systems real-time capable. These will be discussed in the next section.

### 1.1 Approaches: Dual and single kernels

When talking about real-time kernels one differentiates between single kernel approaches, like [`PREEMPT_RT`](https://wiki.linuxfoundation.org/realtime/start), and [dual-kernel approaches](https://linuxgizmos.com/real-time-linux-explained/), such as [Xenomai](https://en.wikipedia.org/wiki/Xenomai). You can use real-time capable Dockers in combination with all of them from what I have heard to produce  real-time capable systems but the approaches differ. Clearly this does not depend on the Docker itself but on the **underlying host system**, meaning you still have to properly configure the host system, likely re-compiling its kernel.

#### 1.1.1 Dual kernels

**Dual kernel** approaches predate single-kernel ones by several years. In this case a **separate real-time micro-kernel runs in parallel to the traditional Linux kernel**. The real-time code is given priority over the user space which is only allowed to run if no real-time code is executed. The following two dual-kernel approaches are commonly used:

- **RTAI** (Real-time Application Interface) was developed by the Politecnico di Milano. One has to program in kernel space instead of the user space and therefore can't use the standard C libraries but instead must use special libraries that do not offer the full functionality of its standard counterparts. The interaction with the user space is handled over special interfaces, rendering programming much more difficult. New drivers for the micro-kernel have to be developed for new hardware making the code always lack slightly behind. For commercial codes also licensing might be an issue as kernel modules are generally licensed under the open-source Gnu Public License (GPL).
- With the **Xenomai** real-time operating system it has been tried to improve the separation between kernel and user space. The programmer works in user space and then abstractions, so called skins are added that emulate different APIs (e.g. that implement a subset of Posix threads) which have to be linked against when compiling.

#### 1.1.2 Single kernels

While having excellent real-time performance the main disadvantage of dual-kernel approaches is the inherent complexity. As [stated by Jan Altenberg](https://www.youtube.com/watch?v=BKkX9WASfpI) from the German embedded development firm [Linutronix](https://linutronix.de/), one of the main contributors behind `PREEMPT_RT`:

```
“The problem is that someone needs to maintain the microkernel and support  it on new hardware. This is a huge effort, and the development  communities are not very big. Also, because Linux is not running directly on the hardware, you need a  hardware abstraction layer (HAL). With two things to maintain, you’re  usually a step behind mainline Linux development.”
```

This drawback has led to different developments trying to patch the existing Linux kernel by modifying task scheduling, so called **single-kernel** systems. The **kernel itself is adapted** to be real-time capable.

By **default** the Linux kernel can be [compiled with different levels of preempt-ability](https://help.ubuntu.com/lts/installation-guide/amd64/install.en.pdf#page=98) (see e.g. [Reghenzani et al. - "The real-time Linux kernel: a Survey on PREEMPT_RT"](https://re.public.polimi.it/retrieve/handle/11311/1076057/344112/paper.pdf#page=8)):

- `PREEMPT_NONE` has no way of forced preemption
- `PREEMPT_VOLUNTARY` where preemption is possible in some locations in order to reduce latency
- `PREEMPT` where preemption can occur in any part of the kernel (excluding [spinlocks](https://en.wikipedia.org/wiki/Spinlock) and other critical sections)

These can be combined with the feature of [control groups (`cgroups` for short)](https://man7.org/linux/man-pages/man7/cgroups.7.html) by setting [`CONFIG_RT_GROUP_SCHED=y` during kernel compilation](https://stackoverflow.com/a/56189862/9938686), which reserves a certain fraction of CPU-time for processes of a certain (user-defined) group. This seems to be though connected to [high latency spikes](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/8/html-single/optimizing_rhel_8_for_real_time_for_low_latency_operation/index#further_considerations), something that can be observed with control groups by means of [`cyclicytest`s](https://wiki.linuxfoundation.org/realtime/documentation/howto/tools/cyclictest/start).

**`PREEMPT_RT`** developed from `PREEMPT` and is a set of patches that aims at making the kernel fully preemptible, even in critical sections (`PREEMPT_RT_FULL`). For this purpose e.g. [spinlocks are largely replaced by mutexes](https://wiki.linuxfoundation.org/realtime/documentation/technical_details/sleeping_spinlocks). This way there is no need for kernel space programming - instead on can use the standard C and Posix threading libraries. In mid 2021 Linux lead developer Linus Torvalds [merged 70 of the outstanding 220 patches](https://linutronix.de/news/The-PREEMPT_RT-Locking-Code-Is-Merged-For-Linux-5.15) into the Linux mainline. In the near future `PREEMPT_RT` should be available by default to the Linux community without needing to patch the system, guaranteeing also the maintenance of the patch.

#### 1.1.3 Performance

The dispute on which of two approaches is faster has not been completely settled. Most of the literature claims that Xenomai is slightly faster. Jan Altenberg though claims that he could not replicate these studies:

```
"I figured out that most of the time PREEMPT_RT was poorly configured. So we brought in both a Xenomai expert and a PREEMPT_RT expert, and let them configure their own  platforms.”
```

[Their tests](https://www.youtube.com/watch?v=BKkX9WASfpI) showed that the maximum thread wakeup time was of similar magnitude while the average was slightly slower when comparing real-world scenarios in userspace.
