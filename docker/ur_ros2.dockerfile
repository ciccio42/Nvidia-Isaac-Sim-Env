# Isaac Sim Base
FROM isaac_sim_ros:ubuntu_24_jazzy

ARG ROS_DISTRO=jazzy
ARG WS_NAME=build_ws

ENV ROS_DISTRO=${ROS_DISTRO}
ENV WS_NAME=${WS_NAME}
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

SHELL ["/bin/bash", "-c"]
WORKDIR /workspace/${WS_NAME}
RUN apt-get update
RUN rosdep install --from-paths src --ignore-src --rosdistro=$ROS_DISTRO -y
RUN rm -rf build log install && \
    source /workspace/${ROS_DISTRO}_ws/install/setup.bash && colcon build --merge-install && \
    source install/local_setup.bash

RUN apt install ros-${ROS_DISTRO}-rmw-cyclonedds-cpp -y 
# ENV ISAAC_PYTHON=/isaac-sim/kit/python/bin/python3
# ENV ROS_PYTHON_VERSION=3
# ENV PYTHON_EXECUTABLE=${ISAAC_PYTHON}


# Install UR ROS2 packages
RUN echo "Running apt-get update and installing xacro..."
RUN apt install ros-$ROS_DISTRO-xacro -y
WORKDIR /workspace/${WS_NAME}/src
RUN git clone https://github.com/UniversalRobots/Universal_Robots_ROS2_Description.git
WORKDIR /workspace/${WS_NAME}/src/Universal_Robots_ROS2_Description
RUN git checkout $ROS_DISTRO
WORKDIR /workspace/${WS_NAME}
RUN source install/setup.bash && \
    colcon build --merge-install && \
    source install/setup.bash


RUN apt-get install -y \
  ros-${ROS_DISTRO}-ros2launch \
  ros-${ROS_DISTRO}-launch \
  ros-${ROS_DISTRO}-launch-ros \
  ros-${ROS_DISTRO}-launch-xml \
  ros-${ROS_DISTRO}-launch-yaml
RUN apt-get install -y \
  ros-${ROS_DISTRO}-joint-state-publisher-gui \
  ros-${ROS_DISTRO}-joint-state-publisher \
  ros-${ROS_DISTRO}-robot-state-publisher \
  ros-${ROS_DISTRO}-rviz2 \
  ros-${ROS_DISTRO}-xacro

RUN apt-get install -y  ros-${ROS_DISTRO}-rqt \
                        ros-${ROS_DISTRO}-rqt-graph \
                        ros-${ROS_DISTRO}-rqt-common-plugins

# # RUN rm -rf /workspace/jazzy_ws/install /workspace/jazzy_ws/build /workspace/jazzy_ws/log && \
# #     cd /workspace/jazzy_ws && \
# #     bash /opt/ros/jazzy/setup.bash && \
# #     colcon build \
# #       --merge-install \
# #       --cmake-args \
# #         -DPYTHON_EXECUTABLE=${ISAAC_PYTHON} \
# #         -DPYTHON_INCLUDE_DIR=$(${ISAAC_PYTHON} -c "import sysconfig; print(sysconfig.get_path('include'))") \
# #         -DPYTHON_LIBRARY=$(${ISAAC_PYTHON} -c "import sysconfig; print(sysconfig.get_config_var('LIBDIR'))")/libpython3.11.so
# WORKDIR /workspace/${WS_NAME}
# RUN . install/setup.bash && \
#     colcon build --merge-install && \
#     . ./install/setup.bash


ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]