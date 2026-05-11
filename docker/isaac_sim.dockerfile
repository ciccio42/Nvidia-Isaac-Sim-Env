FROM nvcr.io/nvidia/isaac-sim:5.1.0

USER root

SHELL ["/bin/bash", "-c"]
ARG WS_NAME=build_ws

# ============================================================================
# Isaac Python
# ============================================================================

ENV ISAAC_PYTHON=/isaac-sim/kit/python/bin/python3
ENV ISAAC_PYTHON_INCLUDE=/isaac-sim/kit/python/include/python3.11
ENV ISAAC_PYTHON_LIBDIR=/isaac-sim/kit/python/lib
ENV ISAAC_PYTHON_LIB=/isaac-sim/kit/python/lib/libpython3.11.so

ENV PYTHONPATH=/isaac-sim/kit/python/lib/python3.11/site-packages
ENV CMAKE_POLICY_VERSION_MINIMUM=3.5

# ============================================================================
# ROS2
# ============================================================================

ENV ROS_DISTRO=jazzy
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ENV ROS_DOMAIN_ID=0
ENV WS_NAME=${WS_NAME}


# ============================================================================
# PATHS
# ============================================================================

ENV PATH=/isaac-sim/kit/python/bin:/opt/ros/jazzy/bin:$PATH
ENV LD_LIBRARY_PATH=/isaac-sim/kit/python/lib:/opt/ros/jazzy/lib:$LD_LIBRARY_PATH

# ============================================================================
# Locale
# ============================================================================

RUN apt-get update && apt-get install -y locales && \
    locale-gen en_US en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

ENV LANG=en_US.UTF-8

# ============================================================================
# ROS2 Repository
# ============================================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg2 \
    lsb-release \
    software-properties-common && \
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
      -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
      http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
      > /etc/apt/sources.list.d/ros2.list

# ============================================================================
# System dependencies
# ============================================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    git \
    pkg-config \
    wget \
    vim \
    nano \
    iputils-ping \
    net-tools \
    libacl1-dev \
    libasio-dev \
    libtinyxml2-dev \
    liblttng-ust1t64 \
    liblttng-ust-dev \
    lttng-tools \
    python3-dev \
    python3-pip \
    python3-setuptools \
    python3-empy \
    python3-numpy \
    python3-yaml \
    python3-packaging \
    python3-pyparsing \
    python3-psutil \
    python3-catkin-pkg \
    python3-lark \
    python3-colcon-common-extensions \
    python3-vcstool \
    python3-argcomplete \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# Install ROS2 packages
# ============================================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-${ROS_DISTRO}-ros-base \
    ros-${ROS_DISTRO}-ament-cmake \
    ros-${ROS_DISTRO}-rmw-fastrtps-cpp \
    ros-${ROS_DISTRO}-ros2cli \
    ros-${ROS_DISTRO}-ros2cli-common-extensions \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# Python symlinks -> Isaac Python 3.11
# ============================================================================

RUN ln -sf ${ISAAC_PYTHON} /usr/local/bin/python3 && \
    ln -sf ${ISAAC_PYTHON} /usr/local/bin/python

# ============================================================================
# Install Python packages into Isaac Python
# ============================================================================

RUN ${ISAAC_PYTHON} -m pip install --upgrade pip setuptools wheel

RUN ${ISAAC_PYTHON} -m pip install \
    empy \
    catkin-pkg \
    numpy \
    pyyaml \
    packaging \
    psutil \
    lark \
    argcomplete \
    vcstool \
    colcon-common-extensions \
    colcon-ros \
    cmake

# ============================================================================
# ROS environment
# ============================================================================

RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /root/.bashrc

# ============================================================================
# Workspace
# ============================================================================

COPY build_ws/${ROS_DISTRO}/${ROS_DISTRO}_ws /workspace/${ROS_DISTRO}_ws

WORKDIR /workspace/${ROS_DISTRO}_ws

# ============================================================================
# Build
# ============================================================================

RUN source /opt/ros/${ROS_DISTRO}/setup.bash && \
    rm -rf build install log && \
    colcon build \
        --executor sequential \
        --cmake-args \
            -DPython3_EXECUTABLE=${ISAAC_PYTHON} \
            -DPython3_FIND_STRATEGY=LOCATION \
            -DPython3_ROOT_DIR=/isaac-sim/kit/python \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5


# Install UR ROS2 packages
RUN echo "Running apt-get update and installing xacro..."
RUN apt-get update && apt install ros-$ROS_DISTRO-xacro -y
RUN apt-get update && apt-get install -y \
    ros-${ROS_DISTRO}-ament-package \
    python3-colcon-common-extensions \
    ros-${ROS_DISTRO}-rmw-cyclonedds-cpp -y 
WORKDIR /workspace/${WS_NAME}/src
RUN git clone https://github.com/UniversalRobots/Universal_Robots_ROS2_Description.git
WORKDIR /workspace/${WS_NAME}/src/Universal_Robots_ROS2_Description
RUN git checkout $ROS_DISTRO
WORKDIR /workspace/${WS_NAME}
RUN source /opt/ros/${ROS_DISTRO}/setup.bash && \
    colcon build --merge-install && \
    source install/setup.bash

# ============================================================================
# Default shell
# ============================================================================
COPY isaac_sim_entrypoint.sh /isaac_sim_entrypoint.sh
ENTRYPOINT ["/isaac_sim_entrypoint.sh"]