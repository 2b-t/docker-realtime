# Real-time Optimizations

Author: [Tobit Flatscher](https://github.com/2b-t) (August 2022)



## 1. Introduction

The following sections will outline a few things to consider when setting up a real-time capable systems and optimizations that might help improve its real-time performance. This guide is largely based on the exhaustive [**Red Hat optimisation guide**](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/8/html-single/optimizing_rhel_8_for_real_time_for_low_latency_operation/index), focusing on particular aspects of it.

## 2. Selecting hardware

The latency on most computers that are optimised for energy efficiency - like laptops - will be magnitudes larger than the one of a desktop system as can also clearly be seen [browsing the OSADL latency plots](https://www.osadl.org/Latency-plots.latency-plots.0.html). **It is therefore generally not advisable to use laptops for real-time tests** (with and without a Docker). Some single-board computers like the Raspberry Pi, [seem to be surprisingly decent](https://metebalci.com/blog/latency-of-raspberry-pi-3-on-standard-and-real-time-linux-4.9-kernel/) but still can't compete with a desktop computer. The Open Source Automation Development Lab eG (OSADL) performs long-term tests on several systems that can be inspected [on their website](https://www.osadl.org/OSADL-QA-Farm-Real-time.linux-real-time.0.html) in case you want to compare the performance of your system to others.

## 3. Kernel parameters

Real-time performance might be improved by **changing kernel parameters when recompiling the kernel**. On the [OSADL long-term test farm website](https://www.osadl.org/Real-time-optimization.qa-farm-latency-optimization.0.html) you can inspect and download the kernel configuration for a particular system (e.g. [here](https://www.osadl.org/?id=1312#kernel)). Important settings that might help reduce latency include disabling all irrelevant debugging feature.

## 4. CPU frequency scaling

During operation the **operating system may scale the CPU frequency up and down** in order to improve performance or save energy. Responsible for this are

- The **scaling governor**: Algorithms that compute the CPU frequency depending on the load etc.
- The **scaling driver** that interacts with the CPU to enforce the desired frequency 

For more detailed information see e.g. [Arch Linux](https://wiki.archlinux.org/title/CPU_frequency_scaling).

While these settings might help save energy, they generally increase latency and should thus be **de-activated on real-time systems**. This will be discussed for Intel systems in more detail in the next section. This should work quite similar on AMD processors as outlined [here](https://www.kernel.org/doc/html/latest/admin-guide/pm/amd-pstate.html).

### 4.1 Intel processors

On Intel CPUs the driver offers two possibilities to do so (see e.g. [here](https://vstinner.github.io/intel-cpus.html) and [here](https://docs.01.org/clearlinux/latest/guides/maintenance/cpu-performance.html) as well as the documentation on the Linux kernel [here](https://docs.kernel.org/admin-guide/pm/intel_pstate.html) or [here](https://metebalci.com/blog/a-minimum-complete-tutorial-of-cpu-power-management-c-states-and-p-states/) for a technical in-depth overview):

- **P-states**: The processor can be run at lower voltages and/or frequency levels in order to decrease power consumption
- **C-states**: Idle states, where subsystems are powered down.

Both states are numbered, where 0 corresponds to operational state with maximum performance, and the higher levels corresponding to power-saving (likely latency-increasing) modes.

Additionally there are other dynamic frequency scaling features, like [**Turbo-Boost**](https://en.wikipedia.org/wiki/Intel_Turbo_Boost) that allow to temporarily raise the operating frequency above the nominal frequency when demanding tasks are run. To what degree this is possible depends on the number of active cores, current and power consumption as well as CPU temperature. Values for different processors can be found e.g. on [WikiChip](https://en.wikichip.org/wiki/intel). This feature can be deactivated inside the operating system as well as the BIOS and is often de-activated on servers that are supposed to run 24/7 on full load.

For a better real-time performance the **idle states should be turned off and the P-states changed to performance**! How this can be done is described [here](https://wiki.bu.ost.ch/infoportal/_media/embedded_systems/ethercat/controlling_processor_c-state_usage_in_linux_v1.1_nov2013.pdf#page=5) in more detail.

## 5. Isolating CPUs

Typically one will reserve a CPU core for a particular real-time task as described for Grub and Linux [here](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/7/html/tuning_guide/isolating_cpus_using_tuned-profiles-realtime) and [here](http://doc.dpdk.org/spp-18.02/setup/performance_opt.html). If [hyper-threading](https://www.xmodulo.com/check-hyper-threading-enabled-linux.html) is activated in the BIOS also the corresponding virtual core has to be isolated. The indices of the second virtual cores follow the physical ones.

Additionally it makes sense to also **isolate the corresponding [hardware interrupts (IRQs)](https://en.wikipedia.org/wiki/Interrupt_request_(PC_architecture))** (on the same CPU), disabling the irqbalance daemon and binding the process to a particular CPU as described [here](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/8/html-single/optimizing_rhel_8_for_real_time_for_low_latency_operation/index#assembly_binding-interrupts-and-processes_optimizing-RHEL8-for-real-time-for-low-latency-operation). This is in particular crucial for applications that include network and EtherCAT communication.
