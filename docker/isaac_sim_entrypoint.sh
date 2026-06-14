#!/bin/bash
# Run Isaac-SIM

source /opt/ros/jazzy/setup.bash 
source /workspace/jazzy_ws/install/setup.bash
source /workspace/build_ws/install/setup.bash
ros2 daemon stop && ros2 daemon start
cd /
bash
