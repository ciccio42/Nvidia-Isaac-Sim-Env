#!/bin/bash
set -eo pipefail

OUTPUT_PATH="${1:-${UR5E_2F_85_URDF:-/workspace/isaac_assets/ur5e_2f_85/ur5e_2f_85_platform.urdf}}"

ISAAC_OUTPUT_PATH="${2:-${UR5E_2F_85_ISAAC_URDF:-/workspace/isaac_assets/ur5e_2f_85/ur5e_2f_85_platform_isaac.urdf}}"

XACRO_PATH="/workspace/${WS_NAME:-build_ws}/src/ur5e_2f_85_description/urdf/ur5e_2f_85_platform.urdf.xacro"

source /opt/ros/${ROS_DISTRO:-jazzy}/setup.bash
source "/workspace/${WS_NAME:-build_ws}/install/setup.bash"

set -u

mkdir -p "$(dirname "${OUTPUT_PATH}")"
mkdir -p "$(dirname "${ISAAC_OUTPUT_PATH}")"

echo "=== Generating standard flattened URDF ==="

xacro "${XACRO_PATH}" -o "${OUTPUT_PATH}"
check_urdf "${OUTPUT_PATH}"

echo
echo "=== Generating Isaac-compatible URDF ==="

python3 - "${OUTPUT_PATH}" "${ISAAC_OUTPUT_PATH}" <<'PY'
from pathlib import Path
import re
import sys

from ament_index_python.packages import get_package_share_directory

src = Path(sys.argv[1])
dst = Path(sys.argv[2])

text = src.read_text()

packages = sorted(
    set(re.findall(r'package://([^/"]+)', text))
)

print("ROS packages referenced by URDF:")

for pkg in packages:
    share = Path(get_package_share_directory(pkg)).resolve()

    old = f"package://{pkg}/"
    new = f"file://{share}/"

    print(f"  {old}")
    print(f"    -> {new}")

    text = text.replace(old, new)

remaining = sorted(
    set(re.findall(r'package://([^/"]+)', text))
)

if remaining:
    raise RuntimeError(
        f"Unresolved package:// URIs remain: {remaining}"
    )

dst.write_text(text)

print()
print(f"Generated Isaac URDF: {dst}")
PY

check_urdf "${ISAAC_OUTPUT_PATH}"

echo
echo "Generated:"
echo "  ROS URDF:   ${OUTPUT_PATH}"
echo "  Isaac URDF: ${ISAAC_OUTPUT_PATH}"
