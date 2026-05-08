#!/bin/bash
# Run Isaac-SIM
export ROS_DISTRO=jazzy
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/isaac-sim/exts/isaacsim.ros2.bridge/jazzy/lib
source /workspace/jazzy_ws/install/setup.bash
# ./isaac-sim.sh --allow-root
