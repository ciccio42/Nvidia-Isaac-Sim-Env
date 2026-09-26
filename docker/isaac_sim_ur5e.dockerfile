# Digital twin image: UR5e + Robotiq 2F-85 + platform/table description for Isaac Sim.
#
# Build (context = repo root, so the COPY paths below resolve):
#   cd /home/asus-mivia/Desktop/Isaac-Sim/Nvidia-Isaac-Sim-Env
#   docker build -t isaac-sim-ur5e:5.1.0 -f docker/isaac_sim_ur5e.dockerfile .
#
# NOTE: keep robot/UR5e-2f-85 in sync with
#   /home/asus-mivia/Desktop/UR-Control/UR5e-2f-85
# before building, since the description package is copied from there.
FROM isaac-sim-custom:5.1.0

USER root
ENV RMW_IMPLEMENTATION=rmw_fastrtps_cpp
SHELL ["/bin/bash", "-c"]
ARG WS_NAME=build_ws

# Flattened URDF generated at build time and consumed by the Isaac Sim
# URDF Importer plugin / generate_ur5e_2f_85_urdf helper script.
ENV UR5E_2F_85_URDF=/workspace/isaac_assets/ur5e_2f_85/ur5e_2f_85_platform.urdf
ENV UR5E_2F_85_ISAAC_URDF=/workspace/isaac_assets/ur5e_2f_85/ur5e_2f_85_platform_isaac.urdf

# # Robotiq gripper description used by ur5e_2f_85_description.
# WORKDIR /workspace/${WS_NAME}/src
# RUN git clone https://github.com/PickNikRobotics/ros2_robotiq_gripper.git

# Local UR5e + Robotiq + platform + camera description.
COPY robot/UR5e-2f-85/ur5e_2f_85/ur5e_2f_85_description \
    /workspace/${WS_NAME}/src/ur5e_2f_85_description

WORKDIR /workspace/${WS_NAME}
RUN source /opt/ros/${ROS_DISTRO}/setup.bash && \
    colcon build --merge-install --packages-up-to ur5e_2f_85_description

# Generate both the normal ROS URDF and the Isaac-specific URDF.
COPY docker/generate_ur5e_2f_85_urdf.sh /usr/local/bin/generate_ur5e_2f_85_urdf
RUN chmod +x /usr/local/bin/generate_ur5e_2f_85_urdf && \
    /usr/local/bin/generate_ur5e_2f_85_urdf

# ============================================================================
# Default shell
# ============================================================================

COPY docker/isaac_sim_entrypoint.sh /isaac_sim_entrypoint.sh
ENTRYPOINT ["/isaac_sim_entrypoint.sh"]