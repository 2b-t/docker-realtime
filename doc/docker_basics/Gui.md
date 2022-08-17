# Graphic user interfaces inside Docker

Author: [Tobit Flatscher](https://github.com/2b-t) (August 2021 - August 2022)



## 1. Different approaches 

Running user interfaces from inside a Docker might not be its intended usage but as of now there are several options available. The problem with all of them is that they are not portable to other operating systems. On the the [ROS Wiki](http://wiki.ros.org/docker/Tutorials/GUI) the different options are discussed in more detail. The options that I am aware of are the following:

- In Linux there are several ways of connecting a containers output to a host's **X server** resulting in an output which is indistinguishable from a program running on the host directly. This is the approach chosen for this tutorial. It is quite portable but requires additional steps for graphics cards running with nVidia hardware acceleration rather than the Linux Nouveau display driver.
- Other common approaches are less elegant and often use some sort of **Virtual Network Computing (VNC)** which streams the entire desktop to the host over a dedicated window similar to connecting virtually to a remote machine.

## 2. Using X-Server

As pointed out before this guide uses the Ubuntu X-Server for outputting dialogs from a Docker. The Docker-Compose file with and without Nvidia hardware acceleration look differently and Nvidia hardware acceleration requires a few additional setup steps. These differences are briefly outlined in the sections below. It is worth mentioning that **just having an Nvidia card does not necessitate the Nvidia setup** but instead what matters is the **driver** used for the graphics card. If you are using a Nouveau driver for an Nvidia card then a Docker-Compose file written for hardware acceleration won't work and instead you will have to turn to the Docker-Compose file without it. And vice versa, if your card is managed by the Nvidia driver then the first approach won't work for you. This fact is in particular important for the `PREEMPT_RT` patch: You won't be able to use your Nvidia driver when running the patch. Your operating system might mistakenly tell you that it is using the Nvidia driver but it might not. It is therefore important to check the output of `$ nvidia-smi`. If it outputs a managed graphics card, then you will have to go for the second approach with hardware acceleration. If it does not output anything or is not even installed go for the Nouveau driver setup.

In any case before being able to stream to the X-Server on the host system you will have to run the following command inside the **host system**:

```bash
$ xhost +local:root
```

where `root` corresponds to the user-name of the user used inside the Docker container. This command has to be **repeated after each restart**.

### 2.1 Nouveau and AMD driver

As pointed out in the second before this type of setup applies to any card that is not managed by an Nvidia driver, even if the card is an Nvidia card.

In such a case it is sufficient to share the following few folders with the host system. The `docker-compose.yml` might look as follows:

```yaml
version: "3.9"
services:
  some_name:
    build:
      context: .
      dockerfile: Dockerfile
    tty: true
    environment:
     - DISPLAY=${DISPLAY} # Option for sharing the display
     - QT_X11_NO_MITSHM=1 # For Qt
    volumes:
      - /tmp/.X11-unix:/tmp/.X11-unix:rw # Share system folder
      - /tmp/.docker.xauth:/tmp/.docker.xauth:rw # Share system folder
```

### 2.2 Hardware acceleration with Nvidia cards

This section is only relevant for Nvidia graphic cards managed by the Nvidia driver or if you want to have hardware acceleration inside the Docker, e.g. for using CUDA or OpenGL. As pointed out [here](http://wiki.ros.org/docker/Tutorials/Hardware%20Acceleration) this is more tricky! Nvidia offers a dedicated [`nvidia-docker`](https://github.com/NVIDIA/nvidia-docker) (with two different options `nvidia-docker-1` and `nvidia-docker-2` which differ sightly) as well as the [`nvidia-container-runtime`](https://nvidia.github.io/nvidia-container-runtime/). Latter was chosen for this guide and will be discussed below.

#### 2.2.1 Installing the `nvidia-container-runtime`

The installation process of the [`nvidia-container-runtime`](https://nvidia.github.io/nvidia-container-runtime/) is described [here](https://stackoverflow.com/a/59008360). Before following through with the installation make sure it is not already set-up on your system. For this check the `runtime` field from the output of `$ docker info`. If `nvidia` is available as an option already you should be already good to go.

If it is not available you should be able to install it with the following steps:

```bash
$ curl -s -L https://nvidia.github.io/nvidia-container-runtime/gpgkey | \
  sudo apt-key add -
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
$ curl -s -L https://nvidia.github.io/nvidia-container-runtime/$distribution/nvidia-container-runtime.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-runtime.list
$ sudo apt-get update
$ sudo apt-get install nvidia-container-runtime
```

and then [set-up the Docker runtime](https://github.com/NVIDIA/nvidia-container-runtime#docker-engine-setup):

```bash
$ sudo tee /etc/docker/daemon.json <<EOF
{
    "runtimes": {
        "nvidia": {
            "path": "/usr/bin/nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
EOF
$ sudo pkill -SIGHUP dockerd
```

After these steps you might will have to restart the system or at least the Docker daemon with `$ sudo systemctl daemon-reload` and `$ sudo systemctl restart docker`. Then `$ docker info` should output at least two different runtimes, the default `runc` as well as `nvidia`. This runtime can be set in the Docker-Compose file and one might have to set the `environment variables` `NVIDIA_VISIBLE_DEVICES=all` and `NVIDIA_DRIVER_CAPABILITIES=all`. Be aware that this will make fail launching it on other systems without that runtime. You will need another dedicated Docker-Compose file for it!

A Docker-Compose file now looks as follows:

```yaml
version: "3.9"
services:
  some_name:
    build:
      context: .
      dockerfile: Dockerfile
    tty: true
    environment:
     - DISPLAY=${DISPLAY}
     - QT_X11_NO_MITSHM=1
     - NVIDIA_VISIBLE_DEVICES=all # Share devices of host system
    runtime: nvidia # Specify runtime for container
    volumes:
      - /tmp/.X11-unix:/tmp/.X11-unix:rw
      - /tmp/.docker.xauth:/tmp/.docker.xauth:rw
```

### 2.3 Best practice

You can already see that there are quite a few common options between the two. While sadly Docker-Compose does not have conditional execution (yet) one might [override or extend an existing configuration file](https://github.com/Yelp/docker-compose/blob/master/docs/extends.md) (see also [`extends`](https://docs.docker.com/compose/extends/) as well this [Visual Studio Code guide](https://code.visualstudio.com/docs/remote/create-dev-container#_extend-your-docker-compose-file-for-development)).

I normally start by creating a base Docker-Compose file `docker-compose.yml`

```yaml
version: "3.9"
services:
  some_name:
    build:
      context: .
      dockerfile: Dockerfile
    tty: true
```

that is then extended for graphic user interfaces without Nvidia driver `docker-compose-gui.yml`,

```yaml
version: "3.9"
services:
  some_name:
    extends:
      file: docker-compose.yml
      service: some_name
    environment:
     - DISPLAY=${DISPLAY}
     - QT_X11_NO_MITSHM=1
    volumes:
      - /tmp/.X11-unix:/tmp/.X11-unix:rw
      - /tmp/.docker.xauth:/tmp/.docker.xauth:rw
```

on top of that goes another Docker-Compose file with Nvidia acceleration `docker-compose-gui-nvidia.yml`

```yaml
version: "3.9"
services:
  some_name:
    extends:
      file: docker-compose-gui.yml
      service: some_name
    environment:
     - NVIDIA_VISIBLE_DEVICES=all
    runtime: nvidia
```

and finally I have yet another file which can be launched for hardware acceleration without graphic user interfaces `docker-compose-nvidia.yml`

```yaml
version: "3.9"
services:
  some_name:
    extends:
      file: docker-compose.yml
      service: some_name
    environment:
     - NVIDIA_VISIBLE_DEVICES=all
    runtime: nvidia
```

This way if I need to add additional options, I only have to modify the base Docker-Compose file `docker-compose.yml` and the others will simply adapt.

I can then specify which file should be launched to Docker-Compose with e.g.

```
$ docker-compose -f docker-compose-gui-nvidia.yml up
```

