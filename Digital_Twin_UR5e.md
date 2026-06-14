# Digital Twin – UR5e + Robotiq 2F-85 + Table

Goal: load the UR5e + Robotiq 2F-85 + table/platform description from
`UR-Control/UR5e-2f-85/ur5e_2f_85/ur5e_2f_85_description` into Isaac Sim 5.1
using the **URDF Importer** plugin, while the robot's
`robot_state_publisher` runs in its own ROS2 container.

The setup uses two containers, on the same Docker network / `ROS_DOMAIN_ID`:

| Container | Image | Role |
|---|---|---|
| `ur5e_digital_twin_rsp` | `ur_robotiq_teleoperation` | Runs `robot_state_publisher` (+ `joint_state_publisher_gui`) for the UR5e + Robotiq + table description, publishing `/robot_description`, `/tf`, `/joint_states`. |
| `isaac-sim-ur5e` | `isaac-sim-ur5e:5.1.0` | Isaac Sim 5.1 with the URDF Importer / ROS2 bridge extensions, used to import and visualize the digital twin. |

## 0. Prerequisites

- Build the base `isaac-sim-custom:5.1.0` image (see "Pull Nvidia-Isaac Sim
  Docker" / "Isaac-Sim + ROS" in [README.md](README.md)).
- Keep `robot/UR5e-2f-85` in sync with
  `/home/asus-mivia/Desktop/UR-Control/UR5e-2f-85` (e.g. `git pull` inside
  `robot/UR5e-2f-85`, or re-copy the `ur5e_2f_85` folder) — it is used as the
  build context for `docker/isaac_sim_ur5e.dockerfile`.
- Build the `ur_robotiq_teleoperation` image following
  `docs/teleoperation.md` in `UR-Control/UR5e-2f-85`.

## 1. Build the Isaac Sim UR5e digital twin image

```bash
cd /home/asus-mivia/Desktop/Isaac-Sim/Nvidia-Isaac-Sim-Env
docker build -t isaac-sim-ur5e:5.1.0 -f docker/isaac_sim_ur5e.dockerfile .
```

This image extends `isaac-sim-custom:5.1.0` with the UR5e + Robotiq + table
description package (and its `ur_description`/`robotiq_description`
dependencies), builds it with `colcon`, and pre-generates the flattened URDF
at `$UR5E_2F_85_URDF`
(`/workspace/isaac_assets/ur5e_2f_85/ur5e_2f_85_platform.urdf`).

## 2. Terminal 1 – UR5e `robot_state_publisher` container

```bash
export UR5e_2f_85_PATH=/home/asus-mivia/Desktop/UR-Control/UR5e-2f-85

xhost +local:docker
docker run -it --rm \
  --net=host \
  --ipc=host \
  -e ROS_DOMAIN_ID=0 \
  --gpus all \
  --privileged \
  -e DISPLAY=$DISPLAY \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v ${UR5e_2f_85_PATH}/ur5e_2f_85:/home/ros2_ws/src/ur5e_2f_85 \
  -v ${UR5e_2f_85_PATH}/dataset_collector:/home/ros2_ws/src/dataset_collector \
  -v ${UR5e_2f_85_PATH}/moveit_controller:/home/ros2_ws/src/moveit_controller \
  --name ur5e_digital_twin_rsp \
  ur_robotiq_teleoperation
```

The entrypoint builds/sources the workspace automatically. Then launch the
description:

```bash
ros2 launch ur5e_2f_85_description ur5e_2f_85_display.launch.py &
```

This starts `robot_state_publisher` + `joint_state_publisher_gui` (+ RViz),
publishing `/robot_description`, `/tf` and `/joint_states` for the
UR5e + Robotiq 2F-85 + table/platform model. Move the sliders in
`joint_state_publisher_gui` to drive the joints.

## 3. Terminal 2 – Isaac Sim container

```bash
xhost +local:
docker run --name isaac-sim-ur5e \
    -it \
    --rm \
    --net=host \
    --ipc=host \
    --gpus all \
    -e "ACCEPT_EULA=Y" \
    -e ROS_DOMAIN_ID=0 \
    -e RMW_IMPLEMENTATION=rmw_fastrtps_cpp \
    -e "PRIVACY_CONSENT=Y" \
    -v $HOME/.Xauthority:/isaac-sim/.Xauthority \
    -e DISPLAY \
    -v ~/docker/isaac-sim/cache/main:/isaac-sim/.cache:rw \
    -v ~/docker/isaac-sim/cache/computecache:/isaac-sim/.nv/ComputeCache:rw \
    -v ~/docker/isaac-sim/logs:/isaac-sim/.nvidia-omniverse/logs:rw \
    -v ~/docker/isaac-sim/config:/isaac-sim/.nvidia-omniverse/config:rw \
    -v ~/docker/isaac-sim/data:/isaac-sim/.local/share/ov/data:rw \
    -v ~/docker/isaac-sim/pkg:/isaac-sim/.local/share/ov/pkg:rw \
    -v /home/asus-mivia/Desktop/Isaac-Sim/Nvidia-Isaac-Sim-Env/usd:/isaac-sim/usd \
    isaac-sim-ur5e:5.1.0
```

The entrypoint sources ROS2 Jazzy plus the `jazzy_ws`/`build_ws` workspaces
(so `AMENT_PREFIX_PATH` includes the UR5e + Robotiq + table meshes, needed by
the URDF importer to resolve `package://` URIs), then drops into `bash`.

```bash
# (optional) regenerate the flattened URDF if the description package changed
generate_ur5e_2f_85_urdf

# Launch Isaac Sim with the URDF importer + ROS2 bridge extensions enabled
/isaac-sim/isaac-sim.sh --allow-root \
    --enable isaacsim.asset.importer.urdf \
    --enable isaacsim.asset.exporter.urdf \
    --enable isaacsim.ros2.urdf \
    --enable isaacsim.ros2.bridge
```

## 4. Load the model with the URDF Importer plugin

1. In Isaac Sim, go to **File > Import** and pick the generated file at
   `$UR5E_2F_85_URDF`
   (`/workspace/isaac_assets/ur5e_2f_85/ur5e_2f_85_platform.urdf`) — the URDF
   Importer dialog opens automatically.
2. Import settings: leave **Fix Base Link** checked (the platform/table is
   bolted to `world`), enable **Self Collision** if needed for the gripper.
3. Click **Import** — the UR5e + Robotiq 2F-85 + table appears in the stage.
4. (optional) Save the stage under `/isaac-sim/usd/ur5e_2f_85/...` for reuse.

## 5. Networking notes

- Both containers must run with `--net=host`/`--network=host` and the same
  `ROS_DOMAIN_ID` to see each other's ROS2 topics.
- `isaac-sim-custom`/`isaac-sim-ur5e` default to
  `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`, while the UR5e teleoperation image
  uses the ROS2 default `rmw_fastrtps_cpp`. Override `RMW_IMPLEMENTATION` so
  both containers use the same RMW implementation (as in the commands above)
  — otherwise `/robot_description`/`/joint_states` won't be visible from the
  Isaac Sim ROS2 bridge.
- With the ROS2 bridge enabled, `/joint_states` from the UR5e container can
  drive the imported articulation via an Action Graph
  (`ROS2 Subscribe JointState` -> `Articulation Controller`) for live
  digital-twin synchronization.
