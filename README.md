# Nvidia-Isaac-Sim-Env

This is the main repository for any project which involve the Nvidia-Isaac Simulator running on DGX-Spark

## Pull Nvidia-Isaac Sim Docker
Follow all the instructions reported [here](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/installation/install_container.html#isaac-sim-setup-local-gui-container).

After pull
```bash
xhost +local:
docker run --name isaac-sim \
    --entrypoint bash \
    -it \
    --user root \
    --gpus all \
    -e "ACCEPT_EULA=Y" \
    --rm \
    --network=host \
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
    nvcr.io/nvidia/isaac-sim:5.1.0

# check if isaac-sim is ok
./isaac-sim.sh --allow-root
```

# Isaac-Sim + ROS
```bash
cd /home/asus-mivia/Desktop/Isaac-Sim/Nvidia-Isaac-Sim-Env
git clone git@github.com:ciccio42/IsaacSim-ros_workspaces.git
cd IsaacSim-ros_workspaces
git submodule update --init --recursive

./build_ros.sh -d jazzy -v 24.04
mv build_ws /home/asus-mivia/Desktop/Isaac-Sim/Nvidia-Isaac-Sim-Env/docker
docker run  -it \
            --rm \
            --net=host \
            --env="DISPLAY" \
            --env="ROS_DOMAIN_ID" \
            --name ros_ws_docker \
            isaac_sim_ros:ubuntu_24_jazzy  \
            /bin/bash

# test
ros2 topic pub /my_topic std_msgs/msg/String "data: 'Hello World'"
```

```bash
# Build isaac-sim against ROS2 python3.11 and include UR5e + Robotiq + platform assets
cd ~/Desktop/Isaac-Sim/Nvidia-Isaac-Sim-Env
docker build -t isaac-sim-custom:5.1.0 -f docker/isaac_sim.dockerfile .

xhost +local:
docker run --name isaac-sim \
    --entrypoint bash \
    -it \
    --gpus all \
    -e "ACCEPT_EULA=Y" \
    --rm \
    --network=host \
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
    isaac-sim-custom:5.1.0
```



```bash
cd /home/asus-mivia/Desktop/Isaac-Sim/Nvidia-Isaac-Sim-Env/docker
docker build -t ur_ros:ubuntu_24_jazzy . -f ur_ros2.dockerfile

# Run UR-ROS
xhost +local:
docker run --name ur_ros \
    -it \
    --gpus all \
    -e "ACCEPT_EULA=Y" \
    --rm \
    --network=host \
    -e "PRIVACY_CONSENT=Y" \
    -v $HOME/.Xauthority:/isaac-sim/.Xauthority \
    -e DISPLAY \
    ur_ros:ubuntu_24_jazzy

ros2 launch ur_description view_ur.launch.py ur_type:=ur10e
```

## Run commands
```bash
# 1. Regenerate the flattened URDF, if the description package changed
generate_ur5e_2f_85_urdf

# 2. Run Isaac Sim with the URDF importer enabled
/isaac-sim/isaac-sim.sh --allow-root \
    --enable isaacsim.asset.importer.urdf

# 3. In Isaac Sim, import:
# /workspace/isaac_assets/ur5e_2f_85/ur5e_2f_85_platform.urdf
# This URDF contains the UR5e, Robotiq 2F-85 gripper, table/platform, and camera attachment.

# 4. On a new terminal, if needed
docker exec -it isaac-sim bash
source /opt/ros/$ROS_DISTRO/setup.bash
source /workspace/jazzy_ws/install/setup.bash
source /workspace/build_ws/install/setup.bash
```

# Basic-Tutorial
Link for basic tutorial - [link](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/robot_setup_tutorials/index.html#isaac-sim-robot-setup-tutorials)


# Usefull links 
Link for demos - [link](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/introduction/quickstart_index.html#isaac-sim-intro-quickstart-series)


# Isaac Sim + Isaac Lab
```bash
# clone repository
git clone git@github.com:isaac-sim/IsaacLab.git
```

## Docker build
```bash
# clone repository
git clone git@github.com:isaac-sim/IsaacLab.git
cd IsaacLab/
./docker/container.py start
```


# Usefull commands
```bash
# Remove build cache
docker builder prune 
docker system prune
# Start VNC server
vncserver -geometry 1920x1080 -localhost no
# Remove VNC server
vncserver -list
vncserver -kill :[ID]
```