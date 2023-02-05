FROM ubuntu:focal

ENV WS_DIR="/benchmark"
WORKDIR ${WS_DIR}

SHELL ["/bin/bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

# Dependencies for latency plot
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    make \
    libnuma-dev \
    python3 \
    python3-distutils \
    gnuplot-qt
# Dependencies for Bash unit-tests
RUN apt-get update && apt-get install -y \
    bats \
    dialog \
    tmux

# Cyclictest and mklatencyplot
RUN apt-get update && apt-get install -y \
    rt-tests \
 && cd ${WS_DIR} \
 && curl -SLO --fail https://www.osadl.org/uploads/media/mklatencyplot.bash \
 && sed -i -E "s/(cores=).*/\1\$(nproc)/" mklatencyplot.bash \
 && chmod +x mklatencyplot.bash

ARG DEBIAN_FRONTEND=dialog

