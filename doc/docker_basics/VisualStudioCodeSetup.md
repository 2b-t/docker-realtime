# Docker and Visual Studio Code

Author: [Tobit Flatscher](https://github.com/2b-t) (August 2021 - April 2022)



## 1. Docker in Visual Studio Code

The following guide will walk you through the set-up for Docker inside Visual Studio Code.

### 1.1 Installation

If you do not have Visual Studio Code installed on your system then [install it](https://code.visualstudio.com/download) and follow the Docker post-installation steps given [here](https://docs.docker.com/engine/install/linux-postinstall/) so that you can run Docker without `sudo`. Finally install the [Docker](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-docker) and [Remote - Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) plugins inside Visual Studio Code and you should be ready to go.

### 1.2 Configuration

Visual Studio Code generates two folders for your project, one called `.devcontainer` contains the Docker settings while the other, `.vscode`, contains the Visual Studio code preferences.

```
repository
├─ .devcontainer # Docker settings
|  └─ devcontainer.json
└─ .vscode
```

The `.devcontainer` file let's Visual Studio Code know if it is dealing with [Docker](https://github.com/athackst/vscode_ros2_workspace/blob/foxy/.devcontainer/devcontainer.json) or [Docker Compose](https://github.com/devrt/ros-devcontainer-vscode/blob/master/.devcontainer/devcontainer.json). The contents of the Json configuration file `.devcontainer/devcontainers.json` might look as follows:

```json
{
  "name": "Docker real-time",
  "dockerComposeFile": [
    "../docker/docker-compose.yml"
  ],
  "service": "docker_realtime",
	"workspaceFolder": "/benchmark",
  "shutdownAction": "stopCompose",
  "extensions": [
  ]
}
```

The contents of `.vscode` depend on the programming language and the additional plug-ins you want to use, e.g. for Linting/static code analysis. One can configure for example tasks that can be executed with key shortcuts.

### 1.3 Usage

After opening Visual Studio Code you can open the repository with **`File/Open Folder`**. When asked if you want to **`Reopen in container`** confirm. If this dialog does not appear click on the green symbol on the very left bottom of your window and select `Remote containers: Reopen in container` from the top center. In case you are terminated with the error message "Current user does not have permission to run 'docker'. Try adding the user to the 'docker' group." follow the advice given [here](https://stackoverflow.com/questions/57840395/permission-issue-using-remote-development-extension-to-attach-to-a-docker-image). Open a new terminal on your host machine, enter `$ sudo usermod -aG docker $USER`, reboot and then retry.

As soon as you have entered the Docker you should be greeted by a terminal inside it and the green icon on the bottom left should state **`Dev Container`**. You can open a new terminal by selecting **`Terminal/New Terminal`** any time. You can now browse the Docker container just like a regular terminal and access the folders inside it as if they were on the host system.
