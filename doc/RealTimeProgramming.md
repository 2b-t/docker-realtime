# Introduction to Real-time Programming

Author: [Tobit Flatscher](https://github.com/2b-t) (2023 - 2024)



## 0. Introduction

This guide gives an introduction into programming of real-time systems focussing on C++ and ROS 2. As such it outlines common mistakes that beginners make when starting to program real-time applications and tips to what pay attention to when programming with ROS. The ROS part is strongly influenced by the ROS 2 real-time working group presentation at [ROSCon 2023](https://docs.google.com/presentation/d/1yHaHiukJe-87RhiN8WIkncY23HxFkJynCQ8j3dIFx_w/edit#slide=id.p).

## 1. Basics

Real-time programming requires a good understanding of how computers, their operating systems and programming languages work under the hood. While you will find several books and articles, in particular from people working in high-frequency trading, that discuss advanced aspects of low-latency programming, there is only little beginner-friendly literature.

One can find a few developer checklists for real-time programming such as [this](https://lwn.net/Articles/837019/) and [this one](https://shuhaowu.com/blog/2022/01-linux-rt-appdev-part1.html). Here a more complete checklist and important aspects to consider when programming code for low-latency. The examples make use of C/C++ but these paradigms apply to all programming languages:

- Take care when designing your own code and implementing your own **algorithms**:

  - Select algorithms by their **worst-case latency** and not their average latency
  - **Split your code** into parts that have to be **real-time** and a **non real-time** part

- **Set a priority** (nice values) to your real-time code (see [here](https://medium.com/@chetaniam/a-brief-guide-to-priority-and-nice-values-in-the-linux-ecosystem-fb39e49815e0)). `80` is a good starting point. It is not advised to use too high priorities as this might result in problems with kernel threads:

  ```c++
  #include <pthread.h>
  #include <sched.h>
  
  ::pthread_t const current_thread {::pthread_self()}; // or t.native_handle() for an std::thread
  int policy {};
  struct ::sched_param param {};
  ::pthread_getschedparam(current_thread, &policy, &param);
  param.sched_priority = 80; // or use ::sched_get_priority_max(some_policy)
  if (::pthread_setschedparam(current_thread, policy, &param) == 0) {
    std::cout << "Set thread priority to '" << param.sched_priority << "'." << std::endl;
  } else {
    std::cerr << "Failed to set thread priority to '" << param.sched_priority << "'!" << std::endl;
  }
  ```

- Set a **scheduling policy** that fits your needs (see [here](https://man7.org/linux/man-pages/man7/sched.7.html)). **`SCHED_FIFO`** is likely the one you want to go for if you do not have a particular reason to do otherwise:
  ```c++
  #include <pthread.h>
  #include <sched.h>
  
  ::pthread_t const current_thread {::pthread_self()};
  int policy {};
  struct ::sched_param param {};
  ::pthread_getschedparam(current_thread, &policy, &param);
  policy = SCHED_FIFO;
  if (::pthread_setschedparam(current_thread, policy, &param) == 0) {
    std::cout << "Set scheduling policy to '" << policy << "'." << std::endl;
  } else {
    std::cerr << "Failed to set scheduling policy to '" << policy << "'!" << std::endl;
  }
  ```
  
- **Pin the thread to an isolated CPU core** (which was previously isolated on the operating system). This way the process does not have to fight over resources with other processes running on the same core.

  ```c++
  #include <pthread.h>
  #include <sched.h>
  
  constexpr int cpu_core {0};
  ::pthread_t const current_thread {::pthread_self()};
  ::cpu_set_t cpuset {};
  CPU_ZERO(&cpuset);
  CPU_SET(cpu_core, &cpuset);
  if (::pthread_setaffinity_np(current_thread, sizeof(::cpu_set_t), &cpuset) == 0) {
    std::cout << "Set thread affinity to cpu '" << cpu_core << "'!" << std::endl;
  } else {
    std::cerr << "Failed to set thread affinity to cpu '" << cpu_core << "'!" << std::endl;
  }
  ```

  This can be tested by stressing the system e.g. with `stress-ng`. In a process viewer like `htop` you should see that the unisolated cores will be fully used while the isolated CPU cores should just be running the intended code and should only be partially used:

- Dynamic memory allocation (reserving virtual and physical memory) is slow and so is copying. Both are generally not real-time safe. **Avoid any form of dynamic memory allocation inside real-time code**:

  - Do not use explicit dynamic memory allocation. Use functions for **statically allocating memory before entering a real-time section** (e.g. [`std::vector<T,Alloc>::reserve`](https://en.cppreference.com/w/cpp/container/vector/reserve)).

  - Also avoid structures that are using dynamic memory allocation under the hood such as `std::string` in C++. [Mutate strings](https://www.oreilly.com/library/view/optimized-c/9781491922057/ch04.html) to eliminate temporary copies.

  - **Lock memory pages with [`mlock`](https://man7.org/linux/man-pages/man2/mlock.2.html)**. This locks the process's virtual address space into RAM, preventing that memory from being paged to the swap area.

    ```c
    #include <sys/mman.h>
    
    ::mlockall(MCL_CURRENT | MCL_FUTURE);
    ```

- Generally real-time processes need to communicate with other non real-time processes. **Do not use standard mutexes (e.g. `std::mutex`) when communicating between threads with different priorities** as this is known to potentially result in [priority inversion](https://en.wikipedia.org/wiki/Priority_inversion): A low-priority task might only run after another task with same or slightly higher priority and therefore block the high-priority task that relies on the low-priority task to complete

  - Use **lockless programming techniques**: These are different techniques to share data between two cores without using explicit locks
    - **Atomic variables** for small amount of data and make sure that [`std::atomic<T>::is_always_lock_free`](https://en.cppreference.com/w/cpp/atomic/atomic/is_always_lock_free)
    - Lockless queues (ring buffer) for large amounts of data, see e.g. [Boost Lockfree](https://www.boost.org/doc/libs/1_76_0/doc/html/lockfree.html)
  - Use [**priority inheritance mutexes**](https://www.ibm.com/docs/en/aix/7.2?topic=programming-synchronization-scheduling) e.g. by writing a wrapper around the [Linux pthread one](http://www.qnx.com/developers/docs/qnxcar2/index.jsp?topic=%2Fcom.qnx.doc.neutrino.sys_arch%2Ftopic%2Fkernel_Priority_inheritance_mutexes.html)

- Take **special care when logging from real-time processes**. Traditional logging tools generally involve mutexes and dynamic memory allocation.

  - **Do not log from real-time sections** if it can be avoided
  - Use **dedicated real-time logging tools**, these will use asynchronous logging that passes format string pointer and format arguments from a real-time thread to non real-time thread in a lockless way. Here a few libraries that might be helpful for this:
    - [Quill](https://github.com/odygrd/quill): An asynchronous low-latency logger for C++
    - [PAL statistics](https://github.com/pal-robotics/pal_statistics): A real-time logging framework for ROS

- Similarly writing to files is multiple magnitudes slower than RAM access. **Do not write to files.**

  - Use a dedicated **asynchronous logger** framework for it as discussed above.
  - An acceptable solution might also be a [**RAM disk**](https://www.linuxbabe.com/command-line/create-ramdisk-linux) where a part of memory is formated with a file system.

- Make sure all of your **external library calls** respect the above criteria as well.

  - Read their documentation and review their source code making sure that their latencies are bounded, they do not dynamically allocate memory, do not use normal mutexes, non O(1) algorithms and if they call IO/logging during the calls.
  - Likely you will have to refactor external code to make sure that it is useable inside real-time capable code.

- Take care when using **timing libraries**: Linux has [multiple clocks](https://linux.die.net/man/2/clock_gettime). While `CLOCK_REALTIME` might sounds like the right choice for a real-time system it is not as it can [jump forwards and backwards due to time synchronization](https://stackoverflow.com/questions/3523442/difference-between-clock-realtime-and-clock-monotonic) (e.g. [NTP](https://ubuntu.com/server/docs/network-ntp)). [You will want to **use `CLOCK_MONOTONIC`**](https://github.com/OpenEtherCATsociety/SOEM/issues/391) or `CLOCK_BOOTTIME`.

  - Take care when relying on external libraries to time events and stop times, e.g. [`std::chrono`](https://www.modernescpp.com/index.php/the-three-clocks/).

- Benchmark performance of your code and use tracing library to track you real-time performance. You can always test with simulated load.

A good resource for real-time programming is the book ["Building Low Latency Applications with C++"](https://www.packtpub.com/product/building-low-latency-applications-with-c/9781837639359) as well as [this CppCon 2021 talk](https://www.youtube.com/watch?v=Tof5pRedskI). You might also want to have a look at the following two-part guide for audio-developers ([1](https://www.youtube.com/watch?v=Q0vrQFyAdWI) and [2](https://www.youtube.com/watch?v=PoZAo2Vikbo)).
