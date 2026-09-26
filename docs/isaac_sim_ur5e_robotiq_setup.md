# Isaac Sim 5.1 – UR5e + Robotiq 2F-85 Digital Twin Setup and Validation

## Objective

This document describes the setup, import, validation, and fixes required to use the UR5e + Robotiq 2F-85 digital twin in NVIDIA Isaac Sim 5.1.

The goal is to keep the original ROS 2 robot description unchanged and generate an Isaac-specific import artifact that can later be used as the simulated hardware backend for the SeeDo / MoveIt 2 stack.

The intended high-level architecture is:

```text
AIControllerNode / SeeDo
        |
        | GoToPose
        v
custom moveit_controller
        |
        v
MoveIt 2
        |
        | FollowJointTrajectory
        v
ros2_control
        |
        | topic_based_ros2_control
        |
        | /isaac_joint_commands
        | /isaac_joint_states
        v
NVIDIA Isaac Sim
        |
        v
UR5e + Robotiq 2F-85 articulation
```

## 1. Source description synchronization

The Isaac repository contains a copy of the robot description used by the main UR5e project. Before rebuilding the Isaac image, the description directory was synchronized with the main project and verified with `diff -qr`.

The original ROS 2 description remains the source of truth.

## 2. Isaac Sim Docker image

The Isaac image is built from:

```text
docker/isaac_sim_ur5e.dockerfile
```

Build:

```bash
cd /home/asus-mivia/Desktop/Isaac-Sim/Nvidia-Isaac-Sim-Env

docker build -t isaac-sim-ur5e:5.1.0 \
  -f docker/isaac_sim_ur5e.dockerfile .
```

The image contains the UR5e description, Robotiq 2F-85 description, platform/table meshes, camera attachment, and generated flattened URDFs.

## 3. Flattened URDF validation

Inside the container:

```bash
check_urdf "$UR5E_2F_85_URDF"
```

The URDF parsed successfully and contained the six UR5e joints:

```text
shoulder_pan_joint
shoulder_lift_joint
elbow_joint
wrist_1_joint
wrist_2_joint
wrist_3_joint
```

and the Robotiq joints:

```text
robotiq_85_left_knuckle_joint
robotiq_85_left_inner_knuckle_joint
robotiq_85_left_finger_tip_joint
robotiq_85_right_knuckle_joint
robotiq_85_right_inner_knuckle_joint
robotiq_85_right_finger_tip_joint
```

The description also contains `base_link`, `tcp_link`, `table_1`, camera attachment links, platform geometry, and the complete Robotiq chain.

## 4. Problem: Isaac imported the articulation but not the meshes

The original flattened URDF used ROS package URIs such as:

```text
package://ur5e_2f_85_description/meshes/...
package://ur_description/meshes/...
package://robotiq_description/meshes/...
```

Isaac successfully created links, joints, and the articulation, but the model geometry was initially invisible.

A normal USD traversal returned:

```text
TOTAL MESHES: 0
```

The ROS packages and mesh files were confirmed to exist in the container. The issue was therefore the resolution of `package://` URIs during Isaac URDF import.

## 5. Permanent Isaac-specific URDF generation

The original ROS flattened URDF is preserved. A second file is generated specifically for Isaac:

```text
/workspace/isaac_assets/ur5e_2f_85/ur5e_2f_85_platform_isaac.urdf
```

The generation script is:

```text
docker/generate_ur5e_2f_85_urdf.sh
```

It creates:

```text
ur5e_2f_85_platform.urdf
    -> normal ROS flattened URDF

ur5e_2f_85_platform_isaac.urdf
    -> Isaac-compatible URDF
```

For the Isaac version, every:

```text
package://<package>/...
```

is converted to:

```text
file:///absolute/path/to/package/share/...
```

The packages currently resolved are:

```text
robotiq_description
ur5e_2f_85_description
ur_description
```

Validation:

```bash
grep -o 'package://[^/"]*' \
  /workspace/isaac_assets/ur5e_2f_85/ur5e_2f_85_platform_isaac.urdf \
  | sort -u
```

Expected result: no output.

Both generated URDFs are validated with `check_urdf`.

## 6. Dockerfile integration

The Docker image defines both generated URDF paths:

```dockerfile
ENV UR5E_2F_85_URDF=/workspace/isaac_assets/ur5e_2f_85/ur5e_2f_85_platform.urdf
ENV UR5E_2F_85_ISAAC_URDF=/workspace/isaac_assets/ur5e_2f_85/ur5e_2f_85_platform_isaac.urdf
```

The workspace is built first:

```dockerfile
WORKDIR /workspace/${WS_NAME}
RUN source /opt/ros/${ROS_DISTRO}/setup.bash && \
    colcon build --merge-install --packages-up-to ur5e_2f_85_description
```

Then the URDF generation helper is installed and executed:

```dockerfile
COPY docker/generate_ur5e_2f_85_urdf.sh /usr/local/bin/generate_ur5e_2f_85_urdf
RUN chmod +x /usr/local/bin/generate_ur5e_2f_85_urdf && \
    /usr/local/bin/generate_ur5e_2f_85_urdf
```

This makes the ROS and Isaac URDF generation reproducible at image build time.

## 7. Starting Isaac Sim

From a graphical/VNC session:

```bash
cd /home/asus-mivia/Desktop/Isaac-Sim/Nvidia-Isaac-Sim-Env

xhost +local:

docker run --name isaac-sim-ur5e \
  -it \
  --rm \
  --net=host \
  --ipc=host \
  --gpus all \
  -e ACCEPT_EULA=Y \
  -e ROS_DOMAIN_ID=0 \
  -e RMW_IMPLEMENTATION=rmw_fastrtps_cpp \
  -e PRIVACY_CONSENT=Y \
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

Then:

```bash
/isaac-sim/isaac-sim.sh --allow-root \
  --enable isaacsim.asset.importer.urdf \
  --enable isaacsim.asset.exporter.urdf \
  --enable isaacsim.ros2.urdf \
  --enable isaacsim.ros2.bridge
```

## 8. URDF import settings

Import:

```text
/workspace/isaac_assets/ur5e_2f_85/ur5e_2f_85_platform_isaac.urdf
```

Settings used during validation:

```text
Referenced Model       ON
Static Base            ON
Allow Self-Collision   OFF
Collision From Visuals OFF
```

After switching to the Isaac-specific URDF, the complete robot became visible. Traversal including instance proxies reported:

```text
TOTAL MESHES INCLUDING INSTANCE PROXIES: 62
```

The imported geometry includes the platform, table, UR5e visuals/collisions, camera attachment, and Robotiq visuals/collisions.

## 9. Articulation validation

The imported robot contains an articulation root at:

```text
/World/ur5e_2f_85/root_joint
```

The six UR5e joints were individually commanded using `SingleArticulation` and `ArticulationAction`.

Validated:

```text
shoulder_pan_joint   PASS
shoulder_lift_joint  PASS
elbow_joint          PASS
wrist_1_joint        PASS
wrist_2_joint        PASS
wrist_3_joint        PASS
```

Test movements were typically `+0.1 rad`, followed by a `-0.1 rad` reset. The articulation remained stable.

## 10. Robotiq mimic issue

Isaac initially reported:

```text
Usd Physics: the revolute joint at prim
/World/ur5e_2f_85/joints/robotiq_85_left_inner_knuckle_joint
needs a finite limit set to be used by the mimic joint feature.
```

Inspection showed:

```text
robotiq_85_left_inner_knuckle_joint
lower = -inf
upper = inf
```

However, the original URDF correctly defines:

```xml
<joint name="robotiq_85_left_inner_knuckle_joint" type="revolute">
    ...
    <mimic joint="robotiq_85_left_knuckle_joint"/>
    <limit effort="50" lower="0.0" upper="0.8" velocity="0.5"/>
</joint>
```

The source description is therefore correct; the issue appears during Isaac import.

## 11. Robotiq finite-limit fix

The corresponding USD revolute joint was patched before the first Physics `Play`:

```python
joint.GetLowerLimitAttr().Set(0.0)
joint.GetUpperLimitAttr().Set(45.836624)
```

For this imported joint, the USD angular limits are represented in degrees:

```text
0.8 rad = 45.836624 deg
```

After this fix, the previously uncontrolled gripper component stopped rotating indefinitely.

## 12. Robotiq mimic referenceJoint fix

A second error then appeared:

```text
PhysxMimicJointAPI ... must have exactly 1
"referenceJoint" relationship defined
```

Inspection showed:

```text
Applied schemas:
PhysicsJointStateAPI:angular
PhysxJointAPI
PhysxMimicJointAPI:rotY
IsaacJointAPI

Mimic API count: 1
Reference targets: []
Gearing: -1.0
Offset: 0.0
```

The correct master joint, according to the URDF, is:

```text
robotiq_85_left_knuckle_joint
```

The relationship was restored with:

```python
rel.SetTargets([
    Sdf.Path(
        "/World/ur5e_2f_85/joints/"
        "robotiq_85_left_knuckle_joint"
    )
])
```

The final reference became:

```text
/World/ur5e_2f_85/joints/robotiq_85_left_knuckle_joint
```

This patch must be applied after import but before the first Physics `Play`.

After both fixes:

```text
finite-limit error          FIXED
missing referenceJoint      FIXED
uncontrolled gripper motion FIXED
```

## 13. Robotiq validation

The master joint was commanded:

```text
robotiq_85_left_knuckle_joint
```

A small test at `0.1 rad` caused both gripper fingers to move naturally.

Observed positions included:

```text
robotiq_85_left_inner_knuckle_joint    0.145975
robotiq_85_left_knuckle_joint          0.099105
robotiq_85_right_inner_knuckle_joint  -0.075503
robotiq_85_right_knuckle_joint        -0.095298
robotiq_85_left_finger_tip_joint      -0.065901
robotiq_85_right_finger_tip_joint      0.126474
```

A full-close command was then tested with:

```text
target = 0.8 rad
```

Settled values:

```text
robotiq_85_left_inner_knuckle_joint    0.799999
robotiq_85_left_knuckle_joint          0.800001
robotiq_85_right_inner_knuckle_joint  -0.737432
robotiq_85_right_knuckle_joint        -0.772630
robotiq_85_left_finger_tip_joint      -0.759196
robotiq_85_right_finger_tip_joint      0.801513
```

The closing motion was visually correct. The gripper was then reset by commanding the master joint back to `0.0 rad`, and reopened correctly.

## 14. Current validation status

### UR5e

```text
[x] URDF parses correctly
[x] meshes load in Isaac
[x] articulation root exists
[x] shoulder_pan_joint validated
[x] shoulder_lift_joint validated
[x] elbow_joint validated
[x] wrist_1_joint validated
[x] wrist_2_joint validated
[x] wrist_3_joint validated
```

### Robotiq 2F-85

```text
[x] master joint controllable
[x] mimic finite-limit issue identified
[x] mimic referenceJoint issue identified
[x] finite limits patched
[x] referenceJoint patched
[x] small close movement validated
[x] full close validated
[x] full open/reset validated
[x] no uncontrolled joint rotation
```

### Remaining integration work

```text
[ ] make Robotiq USD patch reproducible
[ ] save patched digital twin as persistent USD
[ ] publish /isaac_joint_states
[ ] subscribe to /isaac_joint_commands
[ ] integrate topic_based_ros2_control
[ ] publish /joint_states
[ ] validate controller naming
[ ] MoveIt plan-only test
[ ] MoveIt execution test in Isaac
[ ] validate base_link -> tcp_link TF
[ ] integrate simulated gripper control
[ ] integrate RGB-D camera
[ ] provide /camera_info
[ ] reproduce/validate table_0 calibrated frame
[ ] SeeDo inference test
[ ] SeeDo plan-only test
[ ] full SeeDo execution in Isaac
```

## 15. Important design decisions

### Do not modify the original robot description for Isaac-only fixes

The ROS 2 description remains the source of truth.

Isaac-specific adaptations are kept separate:

```text
ROS description
    |
    v
flattened ROS URDF
    |
    +--> normal ROS usage
    |
    +--> Isaac preprocessing
            |
            +--> package:// -> file://
            |
            +--> Isaac import
            |
            +--> Robotiq USD patch
            |
            v
        persistent USD
```

### Do not use fake hardware

Isaac is intended to be the simulated hardware backend. The final stack should use:

```text
topic_based_ros2_control/TopicBasedSystem
```

rather than:

```text
mock_components/GenericSystem
```

### Preserve the real control pipeline

The objective is to keep:

```text
SeeDo
  -> AIControllerNode
  -> GoToPose / gripper command
  -> MoveIt 2
  -> ros2_control
  -> Isaac Sim
```

so that simulation remains structurally close to the real robot execution path.

## 16. Next step

Create a reproducible Isaac-side patch script for the Robotiq mimic issue.

Suggested file:

```text
docker/patch_isaac_robotiq.py
```

It must be run:

```text
after URDF import
before the first Physics Play
```

and must apply:

```text
robotiq_85_left_inner_knuckle_joint
    lower = 0 deg
    upper = 45.836624 deg

PhysxMimicJointAPI
    referenceJoint =
    /World/ur5e_2f_85/joints/robotiq_85_left_knuckle_joint
```

After patching, the final stage should be saved as a persistent USD under the repository `usd/` directory.
