#!/bin/bash
set -euo pipefail

OUTPUT_PATH="${1:-${UR5E_2F_85_URDF:-/workspace/isaac_assets/ur5e_2f_85/ur5e_2f_85_platform.urdf}}"
XACRO_PATH="/workspace/${WS_NAME:-build_ws}/src/ur5e_2f_85_description/urdf/ur5e_2f_85_platform.urdf.xacro"

source /opt/ros/${ROS_DISTRO:-jazzy}/setup.bash
source "/workspace/${WS_NAME:-build_ws}/install/setup.bash"

mkdir -p "$(dirname "${OUTPUT_PATH}")"
xacro "${XACRO_PATH}" -o "${OUTPUT_PATH}"
check_urdf "${OUTPUT_PATH}"

echo "Generated ${OUTPUT_PATH}"
