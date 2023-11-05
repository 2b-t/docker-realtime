# Real-time Basics

Author: [Tobit Flatscher](https://github.com/2b-t) (November 2023)



## 0. Introduction

When I started working on coding for real-time systems I had a hard time finding suitable resources. While one can find quite a few resources that discuss some aspects of real-time systems in depth, in particular from people working in high-frequency trading, there is a lack of beginner-friendly resources.

I think one of the main problems is that working with real-time systems requires knowledge from different domains:

- Hands-on experience with **hardware** which in particular in software engineering people are often not familiar with
- **Operating systems**, in particular task scheduling on Linux operating systems
- A deep understanding of **programming languages** as well as implementation details
- **Time and space complexity of algorithms** of underlying library implementations as well as your own code
- **Benchmarking** of real-time systems in order to determine if they meet the desired requirements.

These are some notes that I have taken for myself over the years that might help you getting started with the topic.



## 1. Definition of real-time

**Real-time** is vaguely defined as being able to execute a certain task **within a given deadline**. Commonly people distinguish between:

- **Soft real-time** systems: Nothing catastrophic happens if you do not respect the deadline but it is desirable to have real-time behavior as else the functionality is not guaranteed.
- **Firm real-time** systems: Sometimes the term firm is used to characterize the domain somewhat in between hard- and soft real-time systems: Some deadlines can be missed which might degrade the quality of the task. If several deadlines as missed the system might start to fail.
- **Hard real-time** systems: If something goes wrong this will have catastrophic consequences such as a failure of the entire system. This might cause harm to the machine and/or humans.

It is essential to mention the desired deadline when talking about a real-time system. This can be largely different depending on the application. For **control of robotics actuators** the control loops generally run at up to 1000-2000Hz and the corresponding desired deadline lies somewhere **between 100us and 1ms**.



## 2. Different sources of latency

There are different sources that contribute to the overall latency of a system:

- **Hardware**: This includes access to hardware limited by physics as well as the involved **communication protocols**
- **Firmware:** The hardware drivers embedded into the hardware devices
- **Operating system**: The operating system managing all software and hardware n the computer. One of the main causes of latency is the way it handles task scheduling and preemption.
- **Software libraries**: The software libraries written by other authors that we are embedding into our user code
- **User code**: The application code we are writing, the language features of the programming language we use as well as the time and space complexity of the chosen algorithms.

For all layers a certain bounded **maximum latency** has to be ensured for real-time systems. This is contrary to most common non real-time applications that try to optimize for the average latency.

### 2.1 Hardware latency

Modern x86 processors (so all the common CISC-based Intel and AMD processors) have a special unmaskable (can't be disabled) operating mode, the so called [system management mode (SMM)](https://en.wikipedia.org/wiki/System_Management_Mode) in which all normal execution is suspended. This mode is used for power management, temperature control as well as USB and Thunderbolt hot-swapping. It takes away processing time from applications and the operating system and forces the CPU to store the current state in memory.

The system enters this mode through [**system management interrupts** (SMI)](https://wiki.linuxfoundation.org/realtime/documentation/howto/debugging/smi-latency/smi) which can be either signalled by the motherboard hardware or in the form of software SMIs. These interrupts will make the CPU suspend all activities and go into system management mode and let the firmware (BIOS, UEFI) handle the interrupt.

The operating system has no control over when these SMIs happen, how long the processor will stay in this mode and generally does not even know that this is happening. There is though a register on Intel CPUs that allows you to count the number of interrupts and furthermore in the BIOS one can adjust the SMI timeout, the time frame within which the control should return to the operating system or the system will freeze.

This mechanism is one of the main causes of hardware-related latency with real-time systems and therefore any system should be **tested thoroughly with tools like [`cyclictest`](https://wiki.linuxfoundation.org/realtime/documentation/howto/tools/cyclictest/start) and [`hwlatdetect`](https://manpages.ubuntu.com/manpages/xenial/en/man8/hwlatdetect.8.html)**. If your system shows high latencies you might have to change the system and use a different one.

Similarly we will want to disable all hardware features that lead to non-uniform hardware performance over time like dynamic frequency scaling and simultaneous multi-threading.

### 2.2 Operating system latency

The operating system is the glue between hardware and user code. The main cause for latencies caused by the operating system is **task scheduling**. Scheduling is very complex on modern multi-core processors. Every time the operating system switches task (context) the system will have to save register values to RAM and then later restore them. Furthermore there are some parts of the kernel and drivers that can't be interrupted. There are different ways to reduce this latency that are discussed in the dedicated real-time Linux page.

### 2.3 Latency cause by software libraries and user code

This repository contains a dedicated section on writing user code and what to be aware of when using third-party libraries. Refer to the corresponding page for more details.
