# ROS inside Docker

Author: [Tobit Flatscher](https://github.com/2b-t) (August 2021 - September 2022)



## 1. ROS with Docker

I personally think that Docker is a good choice for **developing** robotic applications as it allows you to quickly switch between different projects but **less so for deploying** software. Refer to [this Canonical article](https://ubuntu.com/blog/ros-docker) to more details about the drawbacks of deploying software with Docker, in particular regarding security. For the deployment I personally would rather turn to Debian or Snap packages (see e.g. [Bloom](http://wiki.ros.org/bloom/Tutorials/FirstTimeRelease)).

The ROS Wiki offers tutorials on ROS and Docker [here](http://wiki.ros.org/docker/Tutorials), there is also a very useful [tutorial paper](https://www.researchgate.net/publication/317751755_ROS_and_Docker) out there and another interesting article can be found [here](https://roboticseabass.com/2021/04/21/docker-and-ros/). Furthermore a list of important commands can be found [here](https://tuw-cpsg.github.io/tutorials/docker-ros/). After installing Docker one simply pulls an image of ROS, specifying the version tag:

```bash
$ sudo docker pull ros
```

gives you the latest ROS2 version whereas 

```bash
$ sudo docker pull ros:noetic-robot
```

will pull the latest version of ROS1.

Finally you can run it with 

```bash
$ sudo docker run -it ros
```

(where `ros` should be replaced by the precise version tag e.g. `ros:noetic-robot`).

In case of a Docker you do **not source the `/opt/ros/<distro>/setup.bash` file but instead the entrypoint script**:

```bash
$ source ros_entrypoint.sh
```

### 1.1 Folder structure

I generally structure Dockers for ROS in the following way:

```
ros_ws
├─ docker
|  ├─ Dockerfile
|  └─ docker-compose.yml # Context is chosen as ..
└─ src # Only this folder is mounted into the Docker
   ├─ .repos # Configuration file for VCS tool
   └─ packages_as_submodules
```

Each ROS-package or a set of ROS packages are bundled together in a Git repository. These are then included as submodules in the `src` folder or by using [VCS tool](https://github.com/dirk-thomas/vcstool). Inside the `docker-compose.yml` file one then **mounts only the `src` folder as volume** so that it can be also accessed from within the container. This way the build and devel folders remain inside the Docker container and you can compile the code inside the Docker as well as outside (e.g. having two version of Ubuntu and ROS for testing).

Generally I have more than a single `docker-compose.yml` as discussed in [`Gui.md`](./Gui.md) and I will add configuration folders for Visual Studio Code and a configuration for the Docker itself, as well as dedicated tasks. I usually work inside the container and install new software there first. I will keep then track of the installed software manually and add it to the Dockerfile.

### 1.2 External ROS master

Sometimes you want to run nodes inside the Docker and communicate with a ROS master outside of it. This can be done by adding the following **environment variables** to the `docker-compose.yml` file

```bash
 9    environment:
10      - ROS_MASTER_URI=http://localhost:11311
11      - ROS_HOSTNAME=localhost
```

where in this case `localhost` stands for your local machine (the loop-back device `127.0.0.1`). If the Docker should act as the master this might be more complicated and one might have to turn to virtual networking in Linux as described [here](https://developers.redhat.com/blog/2018/10/22/introduction-to-linux-interfaces-for-virtual-networking).

#### 1.2.1 Multiple machines

In case you want the Docker to communicate with another device on the network be sure to activate the option

```bash
15    network_mode: host
16    extra_hosts:
17      - "my_device:192.168.100.1"
```

as well, where `my_device` corresponds to the host name followed by its IP. The **`extra_hosts`** option basically adds another entry to your **`/etc/hosts` file inside the container**, similar to what you would do manually normally in the [ROS network setup guide](https://wiki.ros.org/ROS/NetworkSetup).

Make sure that pinging works **in both directions**. ROS relies on the correct host name being set: If it does not correspond to the name of the remote computer the communication won't work. In case your set-up is faulty, pinging might only work in one direction. If you would continue with your set-up you might be able to receive information (e.g. visualize the robot and its sensors) but not send it (e.g. command the robot). In particular for time synchronization of multiple machines it should be possible to run [`chrony`](https://robofoundry.medium.com/how-to-sync-time-between-robot-and-host-machine-for-ros2-ecbcff8aadc4) from inside a container without any issues. After setting it up use `$ chronyc sources` as well as `$ chronyc tracking` to verify the correct set-up.

You can test the communication between the two machines by sourcing the environment, launching a `roscore` on your local or remote computer, then launch the Docker source the local environment and see if you can see any topics inside `$ rostopic list`. Then you can start publishing a topic `$ rostopic pub /testing std_msgs/String "Testing..." -r 10` on one side (either Docker or host) and check if you receive the messages on the other side with `$ rostopic echo /testing`. If that works fine you should be ready to go.

As a best practice I normally use a  [`.env` file](https://vsupalov.com/docker-arg-env-variable-guide/) that I place in the same folder as the `Dockerfile` and the `docker-compose.yaml` containing the IPs:

```bash
REMOTE_IP="192.168.100.1"
REMOTE_HOSTNAME="some_host"
LOCAL_IP="192.168.100.2"
```

The IPs inside this file can then be modified and are used inside the Docker-Compose file to set-up the container: The `/etc/hosts` file as well as the `ROS_MASTER_URI` and the `ROS_HOSTNAME`:

```yaml
version: "3.9"
services:
  ros_docker:
    build:
      context: ..
      dockerfile: docker/Dockerfile
    environment:
      - ROS_MASTER_URI=http://${REMOTE_IP}:11311
      - ROS_HOSTNAME=${LOCAL_IP}
    network_mode: "host"
    extra_hosts:
      - "${REMOTE_HOSTNAME}:${REMOTE_IP}"
    tty: true
    volumes:
      - ../src:/ros_ws/src
```

#### 1.2.2 Combining different package and ROS versions

Combining different ROS versions is not officially supported but largely works as long as message definitions have not changed. This is problematic with constantly evolving packages such as [Moveit](https://moveit.ros.org/). The interface between the containers in this case has to be chosen wisely such that the used messages do not change across between the involved distributions. You can use [`rosmsg md5 <message_type>`](https://wiki.ros.org/rosmsg#rosmsg_md5) in order to verify quickly if the message definitions have changed: If the two `md5` hashes are the same then the two distributions should be able to communicate via this message.

### 1.3 Docker configurations

You will find quite a few Docker configurations for ROS online, in particular [this one](https://github.com/athackst/vscode_ros2_workspace) for ROS2 is quite well made.

### 1.4 Larger software stacks

When working with larger software stacks tools like [Docker-Compose](https://docs.docker.com/compose/) and [Docker Swarm](https://docs.docker.com/engine/swarm/stack-deploy/) might be useful for **orchestration**.
