# Introduction to Docker

Author: [Tobit Flatscher](https://github.com/2b-t) (August 2021 - September 2022)



## 1. Issues with (source) code deployment

Deploying a compiled application in a portable manner is not easy. Clearly there are different operating system and different software architectures which require different binary code, but even if these match you have to make sure that the compiled code can be executed on another machine by supplying all its **dependencies**. This is apparent for binary packages but is even more tricky for source code.

Linux is traditionally organised in repositories which contain the application as well as all the dependencies to run them. Over the years several different packaging systems have emerged such as [`snap`](https://snapcraft.io/) and [`apt`](https://wiki.debian.org/Apt). A `snap` package uses self-contained packages which pack all the dependencies that a program requires to run, rendering it system-agnostic. `apt` on the other hand is only available on Debian-based systems such as Ubuntu and handles retrieving, configuring, installing as well as removing packages in an automated manner. When installing an  `apt` package it checks the existing dependencies and installs only those that are not available yet on the system. This means the dependencies are shared, making the packages smaller but not allowing for multiple installations of the same library and potentially causing issues between applications requiring different versions of the same library. `snap` on the other hand is self-contained, it works in its own box, and allows for multiple installations of the same library.  **Self-contained** boxes like these are called **containers**, as they do not pollute the rest of the system.

## 2. Docker to the rescue

[**Docker**](https://www.docker.com/) is another **framework** for working with **containers**. A [Docker - contrary to `snap`](https://www.youtube.com/watch?v=0z3yusiCOCk) - is not integrated in terms of hardware and networking but instead has its own IP address. Therefore Docker inherently struggles with networking and graphical user interfaces, but these limitations can be worked around as discussed in this repository. In some way a Docker container is similar to a virtual machine but the containers share the same kernel: Docker does not **virtualise** on a hardware level but on an **app level** (OS-level virtualisation).

This results in a couple of advantages:

- **Portability**: You can run code not intended for your particular Linux kernel (e.g packages for Ubuntu 20.04 on Ubuntu 18.04 and vice versa) and you can mix them, launching several containers with different requirements on the same host system by means of dedicated [orchestration tools](https://docs.docker.com/get-started/orchestration/) such as [Kubernetes](https://kubernetes.io/) or [Swarm](https://docs.docker.com/engine/swarm/). This is a huge advantage for robotics applications as one can mix containers with different ROS distributions on the same computer running in parallel.
- **Performance**: Contrary to a virtual machine the performance penalty is small and if run with certain run options it is almost indistinguishable from running code on the host system.
- Furthermore as [Docker on Windows 10](https://hub.docker.com/editions/community/docker-ce-desktop-windows) uses virtualisation one can also run a **Linux container on a Windows operating system**. This way you lose though a couple of advantages of Docker such as being able to run real-time code as there will be a virtual machine underneath.

The most interesting thing about the Docker is that its environment is described by a standardised file, the so called `Dockerfile` which allows you to construct it environment on the fly, store its state and destroy it again. This way one can guarantee a **clean, consistent and standardised build environment**. This file might help also somebody reconstruct the steps required to get a code up and running on a vanilla host system without the Docker.

This makes Docker in particular suiting for **deploying source code in a replicable manner** and will likely speed-up your development workflow. Furthermore one can use the description to perform tests or compile the code on a remote machine in terms of [continuous integration](https://en.wikipedia.org/wiki/Continuous_integration).

The toolchain consists of three main **components**:

- The Docker **daemon** software manages the different containers that are available on the system
- Objects that an application can be constructed from, namely
  - *Immutable read-only templates*, so called **images**, that hold source code, libraries and dependencies. These can be layered over each other to form more complex images, improving efficiency.
  - **Containers** are the *writable layer* on top of the read-only images. By starting an image you obtain a container: They are rather different phases of building a containerised application.
- **Docker registries** (such as the Docker Hub): Repositories for Docker images. These hold different images so that one does not have to go through the build process but instead can upload and download them directly, speeding up deployment.

## 3. Installing Docker

Docker is pretty easily installed. The installation guide for **Ubuntu** can be found [here](https://docs.docker.com/engine/install/ubuntu/). It basically boils down to a single command line command

```bash
$ sudo apt-get install docker-ce docker-ce-cli containerd.io
```

## 4. Usage

Similarly the usage is very simple, you need a few simple commands to get a Docker up and running which are discussed in the file below.

### 4.1 Launching a container from an image

As discussed above you can pull an image from the [Dockerhub](https://hub.docker.com/) and launch it as a container. This can be done by opening a console and typing.

```bash
$ docker run hello-world
```

`hello-world` is an image intended for testing purposes. After executing the command you should see some output to the console that does not contain any error messages.

If you want to find out what other images you could start from just [browse the Dockerhub](https://hub.docker.com/), e.g. for [Ubuntu](https://hub.docker.com/_/ubuntu)

You will see that there are different versions with corresponding tags available. For example to run a Docker with Ubuntu 20.04 installed you could use the tag `20.04` or `focal` resulting in the command

```bash
$ docker run ubuntu:focal
```

This should not output anything and should immediately return. The reason for this is that each container has an [entrypoint](https://docs.docker.com/engine/reference/builder/#entrypoint). This command or script will be run and as soon as it terminates the container will return to the command line.

If you want to keep the container open you have to open it in **interactive** mode by specifying the flag `-i` and the `-t` for opening a terminal

```bash
$ docker run -it ubuntu:focal
```

In case you need to run another command in parallel you might have to open a second terminal and connect to this Docker. In this case we will though have to relaunch the container with a specified `name`

```bash
$ docker run -it --name ubuntu_test ubuntu:focal
```

Now we can connect to it from another console with

```bash
$ docker exec -it ubuntu_test sh
```

The last command `sh` corresponds to the type of connection, in our case `shell`.

With `$ exit` command the Docker can be shut down.

### 4.2 Setting-up a `Dockerfile`

Now that we have seen how to start a container from an existing image let us build a `Dockerfile` that defines steps that should be executed on the image.

```dockerfile
# Base image
FROM ubuntu:focal

# Define workspace folder (e.g. where to place your code)
WORKDIR /code

# Copy your code into the folder (see later for better alternatives!)
COPY . WORKDIR

# Use bash as default shell
SHELL ["/bin/bash", "-c"] 

# Disable user dialogs in installation messages
ARG DEBIAN_FRONTEND=noninteractive

# Commands to perform on base image
RUN apt-get -y update \
    && apt-get -y install some_package \
    && git clone https://github.com/some_user/some_repository some_repo \
    && cd some_repo \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make -j$(nproc) \
    && make install

# Enable user dialogs again
ARG DEBIAN_FRONTEND=dialog
```

When saving this as `Dockerfile` (without a file ending), you can launch it with

```bash
$ docker run -it --name ubuntu_test
```

As soon as you starting building complex containers you will see that the compilation might be quite slow as a lot of data might have be to installed. If you want to execute it again though or you add a command to the `Dockerfile` the container will start pretty quickly. Docker itself caches the compiled images and re-uses them if possible. In fact each individual `RUN` command forms a layer of its own that might be re-used. It is therefore crucial to avoid conflicts between different layers, e.g. by [introducing each `apt-get -y install` with an `apt-get -y update`](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#run). They have to be combined in the same RUN command though to be effective. Similarly you can benefit from this caching (multi-stage build process) by [ordering the different layers from less frequent to most frequently changed](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#use-multi-stage-builds). This way you might reduce the time you spend re-compiling significantly.

### 4.3 Managing data

As you have seen above we copied the data of the current directory into the container with the `COPY` command. This means though that our changes will not affect the local code, instead we are working on a copy of it. This is often not desirable. Most f the time you actually want to mount to share your folders on the host system with the container. 

There are several approaches for [managing data](https://docs.docker.com/storage/) with a Docker container. Generally one stores the relevant code outside the Docker on the host system, mounting files and directories into the container, while leaving any built files inside it. This way the files relevant to both systems can be accessed inside and outside the Docker, something one generally does with [volumes](https://docs.docker.com/storage/volumes/). This results in [additional flags](https://docs.docker.com/storage/volumes/) that have to be supplied when running the Docker.

### 4.4 Build and run scripts

As you can imagine when specifying start-up options like `-it`, mounting volumes, setting up the network configuration, display settings for graphic user interfaces, passing a user name to be used inside the Docker etc. the commands for building and running Docker containers can get pretty lengthy and complicated.

To simplify this process people often create bash scripts that store these arguments for them. Instead of typing a long command they just call scripts like `build_image.bash` and `container_start.bash`. This can though be quite unintuitive for other users as there does not exist a common convention for doing so. Therefore tools like Docker-Compose, which is discussed in the next section, try to simplify this process.

## 5. Docker-Compose

There are different tools available which simplify the management and the orchestration of these Docker containers, such as [Docker-Compose](https://docs.docker.com/compose/reference/up/). As said supplying arguments to Docker for building and running a `Dockerfile` often results in lengthy `shell` scripts. One way of decreasing complexity and [tidying up the process](https://docs.docker.com/compose/) is by using [**Docker Compose**](https://docs.docker.com/compose/). It is a tool that can be used for defining and running multi-container Docker applications but is also very useful for a single container. In a Yaml file such as **`docker-compose.yml`** one describes the services that an app consists of (see [here](https://github.com/compose-spec/compose-spec/blob/master/spec.md) for the syntax).

### 5.1 Installation

The offical installation guide for Ubuntu can be found [here](https://docs.docker.com/compose/install/). At the time of the writing these would be

```bash
$ sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
$ sudo chmod +x /usr/local/bin/docker-compose
```

Afterwards you should be able to open Docker-Compose with 

```bash
$ docker-compose --version
```

### 5.2 Writing and launching a Docker-Compose file

A Docker-Compose file is written in form of an hierarchical `yml` file, generally named `docker-compose.yml`. Such a file might look like this:

```yaml
version: "3.9"
services:
  an_image: # Name of the particular service (Equivalent to the Docker --name option)
    build: # Use Dockerfile to build image
      context: . # The folder that should be used as a reference for the Dockerfile and mounting volumes
      dockerfile: Dockerfile # The name of the Dockerfile
    stdin_open: true # Equivalent to the Docker -i option
    tty: true # Equivalent to the Docker docker run -t option
    volumes:
      - /a_folder_on_the_host:/a_folder_inside_the_container # Source folder on host : Destination folder inside the container
  another_image:
    image: ubuntu/20.04 # Use a Docker image from Dockerhub
    volumes:
      - /another_folder_on_the_host:/another_folder_inside_the_container
volumes:
  - ../yet_another_folder_on_host:/a_folder_inside_both_containers # Another folder to be accessed by both images
```

### 5.3 Usage

After having installed Docker-Compose and having created both a `Dockerfile` as well as a `docker-compose.yml` you can launch it with

```bash
$ docker-compose up
```

where with `-f` a Docker-Compose file with a different filename can be provided.

Then similarly to Docker alone one is able to connect to the container from another console with

```bash
$ docker-compose exec <docker_name> sh
```

where `<docker_name>` is given by the name specified in the `docker-compose.yml` file and `sh` stands for the type of connection, in this case `shell`.

## 6. Selected topics

If you have followed this guide so far, then you should have understood the basics of Docker. There are still some topics I would like to discuss that might be helpful for others. This section links to the corresponding documents.

### 6.1 Users and safety

A few problems emerge with user rights when working from a Docker as discussed [in this Stackoverflow post](https://stackoverflow.com/questions/68155641/should-i-run-things-inside-a-docker-container-as-non-root-for-safety) and in more detail [in this blog post](https://jtreminio.com/blog/running-docker-containers-as-current-host-user/). As outlined in the latter, there are ways to work around this, passing the current user id and group as input arguments to the container. In analogy with Docker-Compose one might default to the root user or change to the current user if [arguments are supplied](https://stackoverflow.com/questions/34322631/how-to-pass-arguments-within-docker-compose).

I personally use Dockers in particular for developing and I am not too bothered about being super-user inside the container. If you are then have a look at the linked posts as well as the [Visual Studio Code guide on this](https://code.visualstudio.com/remote/advancedcontainers/add-nonroot-user).

### 6.2 Graphic user interfaces

As pointed out earlier Docker was never intended for graphic user interfaces but that does not mean that they can't be done. It is particularly useful for development with ROS. The disadvantage of it is though that there is no real portable way of doing so. It highly depends on the operating system that you are using and the manufacturer of your graphics card. The document [`Gui.md`](./Gui.md) discusses a simple way of doing so.

### 6.3 Real-time code

As mentioned another point that is often not discussed is what steps are necessary for running real-time code from inside a Docker. This is what the rest of the documents in this repository is concerned with. As outlined in [this IBM research report](https://domino.research.ibm.com/library/cyberdig.nsf/papers/0929052195DD819C85257D2300681E7B/$File/rc25482.pdf), the impact of Docker on the performance can be very low if launched with the correct options.

### 6.4 ROS inside Docker

Working with the Robot Operating System (ROS) might pose particular challenges. I have written down some notes of how I generally structure my Dockers in [`Ros.md`](./Ros.md).

### 6.5 Setting up Visual Studio Code

In the last few years Microsoft Visual Studio Code has become the most used editor, potentially becoming the first Microsoft product to be widely accepted by programmers. The guide [`VisualStudioCodeSetup.md`](./VisualStudioCodeSetup.md) walks you through the set-up of a Docker with Visual Studio Code.

### 6.6 Multi-stage builds

Another interesting topic for **slimming down the resulting containers** are [multi-stage builds](https://docs.docker.com/build/building/multi-stage/) where only the files necessary for running are kept and every unnecessary ballast is removed.
