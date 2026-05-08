FROM nvcr.io/nvidia/isaac-sim:5.1.0

USER root

SHELL ["/bin/bash", "-c"]

# ── Python paths ───────────────────────────────────────────────────────────────
ENV ISAAC_PYTHON=/isaac-sim/kit/python/bin/python3
ENV ISAAC_PYTHON_INCLUDE=/isaac-sim/kit/python/include/python3.11
ENV ISAAC_PYTHON_LIBDIR=/isaac-sim/kit/python/lib
ENV ISAAC_PYTHON_LIB=/isaac-sim/kit/python/lib/libpython3.11.so
ENV CMAKE_POLICY_VERSION_MINIMUM=3.5
ENV PYTHONPATH=/isaac-sim/kit/python/lib/python3.11/site-packages

# ── ROS2 ───────────────────────────────────────────────────────────────────────
ENV ROS_DISTRO=jazzy
ENV RMW_IMPLEMENTATION=rmw_fastrtps_cpp

# ── System PATH ────────────────────────────────────────────────────────────────
ENV PATH=/isaac-sim/kit/python/bin:/opt/ros/jazzy/bin:$PATH
ENV LD_LIBRARY_PATH=/isaac-sim/kit/python/lib:/opt/ros/jazzy/lib:$LD_LIBRARY_PATH

# ── System dependencies ────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    build-essential \
    ninja-build \
    liblttng-ust1t64 \
    liblttng-ust-dev \
    lttng-tools \
    git \
    libacl1-dev \
    libasio-dev \
    libtinyxml2-dev \
    python3-numpy \
    python3-catkin-pkg \
    python3-empy \
    python3-setuptools \
    python3-dev \
    python3-lark \
    python3-yaml \
    python3-packaging \
    python3-pyparsing \
    python3-psutil \
    pkg-config \
    # ROS2 jazzy apt packages for cmake infrastructure (python3.12, but cmake parts are fine)
    # ros-jazzy-ros-base \
    # ros-jazzy-ament-cmake \
    && rm -rf /var/lib/apt/lists/*

# ── Python symlinks → point to Isaac's python3.11 ─────────────────────────────
RUN ln -sf ${ISAAC_PYTHON} /usr/local/bin/python3 && \
    ln -sf ${ISAAC_PYTHON} /usr/local/bin/python

# ── Install build tools into Isaac's Python 3.11 ──────────────────────────────
RUN ${ISAAC_PYTHON} -m pip install --upgrade \
    colcon-ros \
    catkin-pkg \
    empy \
    lark \
    cmake \
    vcstool \
    pyyaml \
    numpy \
    setuptools \
    packaging \
    psutil \
    argcomplete \
    lark \
    colcon-common-extensions
                             

# ── Copy workspace source ──────────────────────────────────────────────────────
COPY build_ws/${ROS_DISTRO}/${ROS_DISTRO}_ws /workspace/${ROS_DISTRO}_ws

# ── Build against Python 3.11 ──────────────────────────────────────────────────
WORKDIR /workspace/${ROS_DISTRO}_ws

RUN rm -rf install build log && \
    colcon build   \
            --cmake-args \
            -DPython3_EXECUTABLE=${ISAAC_PYTHON} \
            -DPython3_FIND_STRATEGY=LOCATION \
            -DPython3_ROOT_DIR=$(dirname $(dirname ${ISAAC_PYTHON})) \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \   
        --executor sequential