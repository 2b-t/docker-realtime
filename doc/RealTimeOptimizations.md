# Real-time Optimizations

Author: [Tobit Flatscher](https://github.com/2b-t) (August 2022 - February 2023)



## 1. Introduction

The following sections will outline a few things to consider when setting up a real-time capable systems and optimizations that should help improve its real-time performance significantly. This guide is largely based on the exhaustive [**Red Hat optimisation guide**](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/8/html-single/optimizing_rhel_8_for_real_time_for_low_latency_operation/index), focusing on particular aspects of it. Additional information can be found in the [Ubuntu real-time kernel tuning guide](https://ubuntu.com/blog/real-time-kernel-tuning).

## 2. Selecting hardware

The latency on most computers that are optimised for energy efficiency - like laptops - will be a magnitude or two larger than the one of a desktop system as can also clearly be seen [browsing the OSADL latency plots](https://www.osadl.org/Latency-plots.latency-plots.0.html). **It is therefore generally not advisable to use laptops for real-time tests** (with and without a Docker): Some might have decent performance most of the time but might result in huge latencies in the magnitude of milliseconds when run over an extended period. Some single-board computers like the Raspberry Pi, [seem to be surprisingly decent](https://metebalci.com/blog/latency-of-raspberry-pi-3-on-standard-and-real-time-linux-4.9-kernel/) but still can't compete with a desktop computer. The Open Source Automation Development Lab eG (OSADL) performs long-term tests on several systems that can be inspected [on their website](https://www.osadl.org/OSADL-QA-Farm-Real-time.linux-real-time.0.html) in case you want to compare the performance of your system to others.

## 3. Kernel parameters

Real-time performance might be improved by **changing kernel parameters when recompiling the kernel**. On the [OSADL long-term test farm website](https://www.osadl.org/Real-time-optimization.qa-farm-latency-optimization.0.html) you can inspect and download the kernel configuration for a particular system (e.g. [here](https://www.osadl.org/?id=1312#kernel)). Important settings that might help reduce latency include disabling all irrelevant debugging feature. The parameters of your current configuration can be displayed with  [`$ cat /boot/config-$(uname -r)`](https://www.baeldung.com/linux/kernel-config). One of the most significant parameters is arguably [setting the timer interrupt to 1000Hz](https://ubuntu.com/blog/industrial-embedded-systems-ii) with the options:

```shell
CONFIG_HZ_1000=y # Requires to comment the other entries such as CONFIG_HZ=250
CONFIG_HZ=1000
```

## 4. CPU frequency scaling and sleep states

During operation the **operating system may scale the CPU frequency up and down** in order to improve performance or save energy. Responsible for this are

- The **scaling governor**: Algorithms that compute the CPU frequency depending on the load etc.
- The **scaling driver** that interacts with the CPU to enforce the desired frequency 

For more detailed information see e.g. [Arch Linux](https://wiki.archlinux.org/title/CPU_frequency_scaling).

While these settings might help save energy, they generally increase latency and should thus be **de-activated on real-time systems**.

On Intel CPUs (and [similarly on AMD processors](https://www.kernel.org/doc/html/latest/admin-guide/pm/amd-pstate.html)) the driver offers [two possibilities](https://lenovopress.lenovo.com/lp0632.pdf) to reduce the power consumption (see e.g. [here](https://vstinner.github.io/intel-cpus.html) and [here](https://docs.01.org/clearlinux/latest/guides/maintenance/cpu-performance.html) as well as the documentation on the Linux kernel [here](https://docs.kernel.org/admin-guide/pm/intel_pstate.html) or [here](https://metebalci.com/blog/a-minimum-complete-tutorial-of-cpu-power-management-c-states-and-p-states/) for a technical in-depth overview):

- **P-states**: The processor can be run at lower voltages and/or frequency levels in order to decrease power consumption
- **C-states**: Idle states, where subsystems are powered down.

Both states are numbered, where 0 corresponds to operational state with maximum performance, and the higher levels corresponding to power-saving (likely latency-increasing) modes.

From my experience the major impact on latency have the C-states while changing the P-states to performance has only a minor influence if any. Often one can change both of these settings in the BIOS but the Linux operating systems often discard the corresponding BIOS settings. It is therefore important to configure the operating system accordingly as we will see in the next section.

Additionally there are other dynamic frequency scaling features, like [**Turbo-Boost**](https://en.wikipedia.org/wiki/Intel_Turbo_Boost) that allow to temporarily raise the operating frequency above the nominal frequency when demanding tasks are run. To what degree this is possible depends on the number of active cores, current and power consumption as well as CPU temperature. Values for different processors can be found e.g. on [WikiChip](https://en.wikichip.org/wiki/intel). This feature can be deactivated inside the operating system as well as the BIOS and is often de-activated on servers that are supposed to run 24/7 on full load. For best real-time performance you should **turn hyperthreading off**.

### 4.1 C-states

It is essential to low latencies to disable the idle states of the processor (see the section below for actual benchmarks). This can be done in several different ways as described [here](https://wiki.bu.ost.ch/infoportal/_media/embedded_systems/ethercat/controlling_processor_c-state_usage_in_linux_v1.1_nov2013.pdf#page=5):

- One can use **kernel parameters** such as `intel_idle.max_cstate=0` for disabling the Intel driver or `processor.max_cstate=0 idle=poll` for keeping the processor constantly in C0. These approaches are permanent and can only be changed after a reboot.

- One can control them **dynamically through the [`/dev/cpu_dma_latency` file](https://access.redhat.com/articles/65410)**. One opens it and writes the maximum allowable latency. With the [following command](https://www.golinuxhub.com/2018/06/what-cpu-c-states-check-cpu-core-linux/) the latency values of the different states can be determined

  ```shell
  $ cd /sys/devices/system/cpu/cpu0/cpuidle
  $ for state in state{0..4} ; do echo c-$state `cat $state/name` `cat $state/latency` ; done
  ```

   If `0` is set this will keep the processor in `C0`. It is important that this file must be kept open when closing it the processor will be allowed to idle again.
  The [value of the `/dev/cpu_dma_latency` file is given in hexadecimal](https://www.golinuxhub.com/2018/06/what-cpu-c-states-check-cpu-core-linux/) and can be read with: 

  ```bash
  $ HEX_LATENCY=$(sudo xxd -p /dev/cpu_dma_latency | tac -rs .. | echo "$(tr -d '\n')") && echo $((0x${HEX_LATENCY}))
  ```

  Finally one can also set the C-states for **each core independently dynamically** by writing to `/sys/devices/system/cpu/cpu${i}/cpuidle/${cstate}/disable` for each CPU core `${i}` in `$(nproc)` and each [`${cstate}` in `ls /sys/devices/system/cpu/cpu0/cpuidle | grep state`](https://askubuntu.com/a/1242574).

I personally prefer the first option as when I am working on real-time relevant code I do not want to call a script every time. Instead I will boot into a **dedicated kernel with the corresponding kernel parameters activated**. I will generate another boot entry using [Grub-Customizer](https://itsfoss.com/install-grub-customizer-ubuntu/) (see screenshots below), called `Ubuntu 22.04 real-time` where I basically clone the `X.XX.XX-rtXX` configuration [adding `processor.max_cstate=0 intel_idle.max_cstate=0 idle=poll`](https://access.redhat.com/articles/65410) (see second-last line of the screenshot on the right).

| ![Grub-Customizer settings](../media/grub_customizer_0.png) | ![Grub-Customizer settings](../media/grub_customizer_1.png) |
| :---------------------------------------------------------- | ----------------------------------------------------------- |
| Grub configuration                                          | Disabling C-states just for the PREEMPT_RT kernel           |

After boot you can use [`$ cat /proc/cmdline` to double check the settings](https://askubuntu.com/a/19487). 

Additionally [`i7z` can be very useful for monitoring the C-states](https://wiki.bu.ost.ch/infoportal/_media/embedded_systems/ethercat/controlling_processor_c-state_usage_in_linux_v1.1_nov2013.pdf#page=5). After installing it with

```bash
$ sudo apt-get install i7z
```

continue to run it with

```bash
$ sudo i7z
```

It will show you the percentage of time that each individual core is spending in a particular C-state:

![i7z preview](../media/i7z.png)

Additionally there is [`cpupower`](https://manpages.ubuntu.com/manpages/impish/man1/cpupower-idle-set.1.html). The problem with it is though that it is specific for a kernel, meaning it has be downloaded through `$ sudo apt-get install linux-tools-$(uname -r)` and is generally not available for a real-time kernel that you compiled from source, meaning you would have to compile it as well when compiling the kernel!

### 4.2 Cyclictest

An important test for **evaluating the latencies of a real-time system caused by hardware, firmware and operating system as a whole** is the [`cyclictest`](https://wiki.linuxfoundation.org/realtime/documentation/howto/tools/cyclictest/start). It repeatedly measures the difference between a thread's intended and actual wake-up time (see [here](https://events.static.linuxfound.org/sites/events/files/slides/cyclictest.pdf) for more details). For real-time purposes the **worst-case latency** is actually far more important than the average latency as any violation of a deadline might be fatal.

The effectiveness of turning the C-states off is evaluated for two systems, a [**Lenovo ThinkStation P500 tower**](https://www.getech.co.uk/pdf/p5001.pdf) (with an [Intel(R) Xeon(R) E5-2680 v3 @ 2.50GHz twelve-core CPU](https://ark.intel.com/content/www/us/en/ark/products/81908/intel-xeon-processor-e52680-v3-30m-cache-2-50-ghz.html) and 32GB of ECC-DDR4-RAM) and a [**Lenovo ThinkPad T14 Gen1 notebook**](https://psref.lenovo.com/syspool/Sys/PDF/ThinkPad/ThinkPad_T14_Gen_1_Intel/ThinkPad_T14_Gen_1_Intel_Spec.PDF) (with an [Intel(R) Core(TM) i5-10210U quad-core CPU](https://www.intel.co.uk/content/www/uk/en/products/sku/195436/intel-core-i510210u-processor-6m-cache-up-to-4-20-ghz/specifications.html) and 16GB of DDR4-RAM). In both cases a `cyclictest` with the following parameters is performed:

```bash
$ cyclictest --latency=750000 -D5m -m -Sp90 -i200 -h400 -q
```

The parameter `latency` here is essential as per default `cyclictest` writes to `/dev/cpu_dma_latency`, effectively disabling the C-states. This way one has a realistic overview of what the system might be capable of but not how another program will behave that does not use the same optimization!

The test duration with five minutes is quite short. For true real-time systems the system latency is generally investigated over the course of days or weeks (generally also applying [stress tests](https://www.cyberciti.biz/faq/stress-test-linux-unix-server-with-stress-ng/) to the system) as certain driver-related issues might only manifest themselves over time. Nonetheless the following test should be sufficient to illustrate the differences in latency.

Both systems use the same self-compiled version of an **Ubuntu 22.04 5.15.86-rt56 kernel**. **Intel Turbo-boost** is **disabled** in the BIOS. Furthermore all tests for Docker are ran with Docker-Compose directly (without Visual Studio Code in between). Finally for best performance the T14 notebook was plugged in during the entire test.

| ![P500 with C-states enabled](../media/p500_rt_cstates_on.png) | ![P500 with C-states disabled](../media/p500_rt_cstates_off.png) |
| :----------------------------------------------------------- | ------------------------------------------------------------ |
| Lenovo ThinkStation P500 running `PREEMPT_RT` with **C-states enabled** | Lenovo ThinkStation P500 running `PREEMPT_RT` with **C-states disabled** |

| ![T14 with C-states enabled](../media/t14_rt_cstates_on.png) | ![T14 with C-states disabled](../media/t14_rt_cstates_off.png) |
| :----------------------------------------------------------- | ------------------------------------------------------------ |
| Lenovo ThinkPad T14 Gen1 running `PREEMPT_RT` with **C-states enabled** | Lenovo ThinkPad T14 Gen1 running `PREEMPT_RT` with **C-states disabled** |

While latencies in the sub 100us region are generally far than enough for robotics, we can see that the **latency is greatly reduced for both systems when de-activating the C-states**, even halfed in the case of the Lenovo ThinkStation P500. These differences are also visible when using a Docker, as the latencies from real-time capable code ran inside a Docker are virtually indistinguishable from processes ran on the host system. It should be mentioned that the T14 has a remarkable performance for a notebook (several notebooks I used suffered from severe and regular latency spikes in the 500us region) but when running the test for extended periods rare latency spikes of up to two milliseconds were observed.



## 5. Isolating CPUs

Typically one will reserve a CPU core for a particular real-time task as described for Grub and Linux [here](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/7/html/tuning_guide/isolating_cpus_using_tuned-profiles-realtime) and [here](http://doc.dpdk.org/spp-18.02/setup/performance_opt.html). If [hyper-threading](https://www.xmodulo.com/check-hyper-threading-enabled-linux.html) is activated in the BIOS also the corresponding virtual core has to be isolated. The indices of the second virtual cores follow the physical ones.

Additionally it makes sense to also **isolate the corresponding [hardware interrupts (IRQs)](https://en.wikipedia.org/wiki/Interrupt_request_(PC_architecture))** (on the same CPU), disabling the irqbalance daemon and binding the process to a particular CPU as described [here](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/8/html-single/optimizing_rhel_8_for_real_time_for_low_latency_operation/index#assembly_binding-interrupts-and-processes_optimizing-RHEL8-for-real-time-for-low-latency-operation). This is in particular crucial for applications that include network and EtherCAT communication.
