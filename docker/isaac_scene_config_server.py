import asyncio
import builtins
import json
import math

from pxr import UsdGeom, UsdPhysics, Gf

import omni.kit.app
import omni.timeline
import omni.usd

import rclpy
from std_msgs.msg import String


REQUEST_TOPIC = "/seedo/configure_scene_request"
RESPONSE_TOPIC = "/seedo/configure_scene_response"

EXPECTED_CUBES = {
    "cube_red",
    "cube_green",
    "cube_yellow",
    "cube_blue",
}

EXPECTED_Z = 0.036
ALLOWED_RZ = (0.0, 45.0)


# ============================================================
# USD utilities
# ============================================================

def find_unique_prim(stage, name):
    matches = [
        prim
        for prim in stage.Traverse()
        if prim.GetName() == name
    ]

    if len(matches) == 0:
        raise RuntimeError(
            f"Prim '{name}' not found in the current stage."
        )

    if len(matches) > 1:
        paths = "\n".join(str(p.GetPath()) for p in matches)

        raise RuntimeError(
            f"Multiple prims named '{name}' found:\n{paths}"
        )

    return matches[0]


def set_vec3_op(op, xyz):
    if op.GetPrecision() == UsdGeom.XformOp.PrecisionDouble:
        op.Set(Gf.Vec3d(*xyz))
    else:
        op.Set(Gf.Vec3f(*xyz))


def set_orient_z(op, angle_deg):
    rotation = Gf.Rotation(
        Gf.Vec3d(0.0, 0.0, 1.0),
        angle_deg,
    )

    qd = rotation.GetQuat()
    imag = qd.GetImaginary()

    if op.GetPrecision() == UsdGeom.XformOp.PrecisionDouble:
        q = Gf.Quatd(
            float(qd.GetReal()),
            Gf.Vec3d(
                float(imag[0]),
                float(imag[1]),
                float(imag[2]),
            ),
        )
    else:
        q = Gf.Quatf(
            float(qd.GetReal()),
            Gf.Vec3f(
                float(imag[0]),
                float(imag[1]),
                float(imag[2]),
            ),
        )

    op.Set(q)


def set_cube_pose(prim, x, y, z, rz):
    xform = UsdGeom.Xformable(prim)

    translate_op = None
    rotation_op = None

    for op in xform.GetOrderedXformOps():
        op_type = op.GetOpType()

        if op_type == UsdGeom.XformOp.TypeTranslate:
            translate_op = op

        elif op_type in (
            UsdGeom.XformOp.TypeRotateXYZ,
            UsdGeom.XformOp.TypeRotateZ,
            UsdGeom.XformOp.TypeOrient,
        ):
            rotation_op = op

    if translate_op is None:
        raise RuntimeError(
            f"{prim.GetPath()} has no xformOp:translate."
        )

    if rotation_op is None:
        raise RuntimeError(
            f"{prim.GetPath()} has no supported rotation op."
        )

    # Translation
    set_vec3_op(
        translate_op,
        (x, y, z),
    )

    # Rotation
    op_type = rotation_op.GetOpType()

    if op_type == UsdGeom.XformOp.TypeRotateXYZ:
        set_vec3_op(
            rotation_op,
            (0.0, 0.0, rz),
        )

    elif op_type == UsdGeom.XformOp.TypeRotateZ:
        rotation_op.Set(float(rz))

    elif op_type == UsdGeom.XformOp.TypeOrient:
        set_orient_z(rotation_op, rz)

    # Reset rigid-body velocities.
    if prim.HasAPI(UsdPhysics.RigidBodyAPI):
        rb = UsdPhysics.RigidBodyAPI(prim)

        velocity_attr = rb.GetVelocityAttr()
        angular_velocity_attr = rb.GetAngularVelocityAttr()

        if velocity_attr:
            velocity_attr.Set(
                Gf.Vec3f(0.0, 0.0, 0.0)
            )

        if angular_velocity_attr:
            angular_velocity_attr.Set(
                Gf.Vec3f(0.0, 0.0, 0.0)
            )


# ============================================================
# Request validation
# ============================================================

def validate_request(request):
    request_id = str(
        request.get("request_id", "")
    ).strip()

    if not request_id:
        raise ValueError("Missing request_id.")

    cubes = request.get("cubes")

    if not isinstance(cubes, dict):
        raise ValueError(
            "'cubes' must be a dictionary."
        )

    received = set(cubes.keys())

    if received != EXPECTED_CUBES:
        raise ValueError(
            "Expected exactly these cubes: "
            + ", ".join(sorted(EXPECTED_CUBES))
        )

    result = {}

    for cube_name in sorted(EXPECTED_CUBES):
        pose = cubes[cube_name]

        if not isinstance(pose, dict):
            raise ValueError(
                f"Invalid pose for {cube_name}."
            )

        try:
            x = float(pose["x"])
            y = float(pose["y"])
            z = float(pose["z"])
            rz = float(pose["rz"])
        except (KeyError, TypeError, ValueError):
            raise ValueError(
                f"Invalid numeric pose for {cube_name}."
            )

        for value in (x, y, z, rz):
            if not math.isfinite(value):
                raise ValueError(
                    f"Non-finite value for {cube_name}."
                )

        if abs(z - EXPECTED_Z) > 1e-6:
            raise ValueError(
                f"{cube_name}: z must be {EXPECTED_Z}."
            )

        if not any(
            abs(rz - allowed) < 1e-6
            for allowed in ALLOWED_RZ
        ):
            raise ValueError(
                f"{cube_name}: rz must be 0.0 or 45.0."
            )

        result[cube_name] = {
            "x": x,
            "y": y,
            "z": z,
            "rz": rz,
        }

    # No two cubes may occupy the same XY location.
    xy_positions = [
        (pose["x"], pose["y"])
        for pose in result.values()
    ]

    if len(set(xy_positions)) != 4:
        raise ValueError(
            "Two or more cubes have the same XY position."
        )

    return request_id, result


# ============================================================
# ROS 2 server
# ============================================================

class IsaacSceneConfigServer:

    def __init__(self):
        if not rclpy.ok():
            rclpy.init()

        self.node = rclpy.create_node(
            "seedo_isaac_scene_config_server"
        )

        self.publisher = self.node.create_publisher(
            String,
            RESPONSE_TOPIC,
            10,
        )

        self.subscription = self.node.create_subscription(
            String,
            REQUEST_TOPIC,
            self._request_callback,
            10,
        )

        self.pending_requests = []
        self.running = True

        self.task = asyncio.ensure_future(
            self._main_loop()
        )

        print()
        print("==============================================")
        print("SeeDo Isaac Scene Configuration Server")
        print("==============================================")
        print(f"Request topic:  {REQUEST_TOPIC}")
        print(f"Response topic: {RESPONSE_TOPIC}")
        print("Status: RUNNING")
        print("==============================================")
        print()

    def _publish_response(
        self,
        request_id,
        success,
        message,
        cubes=None,
    ):
        response = {
            "request_id": request_id,
            "success": bool(success),
            "message": str(message),
        }

        if cubes is not None:
            response["cubes"] = cubes

        msg = String()
        msg.data = json.dumps(response)

        self.publisher.publish(msg)

    def _request_callback(self, msg):
        try:
            request = json.loads(msg.data)

            request_id, cubes = validate_request(
                request
            )

            self.pending_requests.append(
                (request_id, cubes)
            )

            print(
                f"[SeeDo Scene Server] "
                f"Received request {request_id}"
            )

        except Exception as exc:
            request_id = "unknown"

            try:
                parsed = json.loads(msg.data)
                request_id = str(
                    parsed.get(
                        "request_id",
                        "unknown",
                    )
                )
            except Exception:
                pass

            print(
                "[SeeDo Scene Server] "
                f"Rejected request: {exc}"
            )

            self._publish_response(
                request_id=request_id,
                success=False,
                message=str(exc),
            )

    async def _apply_configuration(
        self,
        request_id,
        cubes,
    ):
        stage = omni.usd.get_context().get_stage()

        if stage is None:
            raise RuntimeError(
                "No USD stage is currently open."
            )

        # Resolve all prims BEFORE changing anything.
        prims = {
            cube_name: find_unique_prim(
                stage,
                cube_name,
            )
            for cube_name in EXPECTED_CUBES
        }

        timeline = (
            omni.timeline.get_timeline_interface()
        )

        was_playing = timeline.is_playing()

        # If physics is running, stop first so we author a
        # clean initial state. Afterwards restore Play.
        if was_playing:
            timeline.stop()
            await (
                omni.kit.app.get_app()
                .next_update_async()
            )

        for cube_name in sorted(EXPECTED_CUBES):
            pose = cubes[cube_name]

            set_cube_pose(
                prims[cube_name],
                x=pose["x"],
                y=pose["y"],
                z=pose["z"],
                rz=pose["rz"],
            )

        # Let Kit update the viewport/stage.
        await (
            omni.kit.app.get_app()
            .next_update_async()
        )

        if was_playing:
            timeline.play()

            # Give Isaac a few frames to re-enter simulation.
            for _ in range(3):
                await (
                    omni.kit.app.get_app()
                    .next_update_async()
                )

        print()
        print("----------------------------------------------")
        print(
            f"[SeeDo Scene Server] "
            f"Applied request {request_id}"
        )

        for cube_name in sorted(
            EXPECTED_CUBES
        ):
            p = cubes[cube_name]

            print(
                f"  {cube_name:12s} "
                f"x={p['x']:+.2f} "
                f"y={p['y']:+.2f} "
                f"z={p['z']:.3f} "
                f"rz={p['rz']:.1f}"
            )

        print("----------------------------------------------")
        print()

        self._publish_response(
            request_id=request_id,
            success=True,
            message="Isaac scene configured successfully.",
            cubes=cubes,
        )

    async def _main_loop(self):
        while self.running:

            # rclpy callbacks are executed here, on the Kit
            # event loop, instead of modifying USD from a
            # separate ROS thread.
            rclpy.spin_once(
                self.node,
                timeout_sec=0.0,
            )

            if self.pending_requests:
                request_id, cubes = (
                    self.pending_requests.pop(0)
                )

                try:
                    await self._apply_configuration(
                        request_id,
                        cubes,
                    )

                except Exception as exc:
                    print(
                        "[SeeDo Scene Server] "
                        f"ERROR: {exc}"
                    )

                    self._publish_response(
                        request_id=request_id,
                        success=False,
                        message=str(exc),
                    )

            await (
                omni.kit.app.get_app()
                .next_update_async()
            )

    def shutdown(self):
        self.running = False

        if self.task:
            self.task.cancel()

        try:
            self.node.destroy_node()
        except Exception:
            pass

        print(
            "[SeeDo Scene Server] stopped."
        )


# ============================================================
# Avoid duplicate servers when Script Editor is run twice.
# ============================================================

if hasattr(
    builtins,
    "_seedo_isaac_scene_config_server",
):
    try:
        builtins._seedo_isaac_scene_config_server.shutdown()
    except Exception:
        pass

builtins._seedo_isaac_scene_config_server = (
    IsaacSceneConfigServer()
)
