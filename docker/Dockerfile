FROM ubuntu:focal

ENV WS_DIR="/benchmark"
WORKDIR ${WS_DIR}

SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# Dependencies for latency plot
RUN apt-get update && apt-get install -y \
    apt-utils \
    curl \
    grep \
    sed \
    build-essential \
    make \
    libnuma-dev \
    python3 \
    python3-distutils \
    gnuplot-qt

# Fetch most recent version of rt-tests and mklatencyplot
RUN cd ${WS_DIR} \
 && RT_TESTS=$(echo $(curl -Ls https://mirrors.edge.kernel.org/pub/linux/utils/rt-tests | grep -o -P '(?<=href\=\")(rt-tests-2.*)(?=.tar.xz\">)')) \
 && curl -SLO --fail https://mirrors.edge.kernel.org/pub/linux/utils/rt-tests/${RT_TESTS}.tar.xz \
 && tar -xf ${RT_TESTS}.tar.xz \
 && cd ${RT_TESTS} \
 && make \
 && make install \
 && cd .. \
 && rm -r ${RT_TESTS} \
 && rm ${RT_TESTS}.tar.xz \
 && curl -SLO --fail https://www.osadl.org/uploads/media/mklatencyplot.bash \
 && chmod +x mklatencyplot.bash

ENV DEBIAN_FRONTEND=dialog

