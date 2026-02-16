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
    -u 1234:1234 \
    nvcr.io/nvidia/isaac-sim:5.1.0
```

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
```



# Usefull commands
```bash
# Remove build cache
docker builder prune
```