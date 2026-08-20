#!/usr/bin/env python3

import omni.usd
from pxr import UsdPhysics, PhysxSchema, Sdf

MIMIC_JOINT_PATH = (
    "/World/ur5e_2f_85/joints/"
    "robotiq_85_left_inner_knuckle_joint"
)

REFERENCE_JOINT_PATH = (
    "/World/ur5e_2f_85/joints/"
    "robotiq_85_left_knuckle_joint"
)

LOWER_LIMIT_DEG = 0.0
UPPER_LIMIT_DEG = 45.836624


def patch_robotiq_mimic():
    stage = omni.usd.get_context().get_stage()

    if stage is None:
        raise RuntimeError("No USD stage is currently open.")

    mimic_prim = stage.GetPrimAtPath(MIMIC_JOINT_PATH)
    reference_prim = stage.GetPrimAtPath(REFERENCE_JOINT_PATH)

    if not mimic_prim.IsValid():
        raise RuntimeError(f"Mimic joint not found: {MIMIC_JOINT_PATH}")

    if not reference_prim.IsValid():
        raise RuntimeError(f"Reference joint not found: {REFERENCE_JOINT_PATH}")

    print("=== ROBOTIQ ISAAC PATCH ===")
    print(f"Mimic joint    : {MIMIC_JOINT_PATH}")
    print(f"Reference joint: {REFERENCE_JOINT_PATH}")
    print()

    # 1. Fix finite limits required by PhysX mimic joints.
    revolute_joint = UsdPhysics.RevoluteJoint(mimic_prim)

    if not revolute_joint:
        raise RuntimeError(
            f"Prim is not a valid UsdPhysics.RevoluteJoint: {MIMIC_JOINT_PATH}"
        )

    print("Joint limits BEFORE:")
    print("  lower:", revolute_joint.GetLowerLimitAttr().Get())
    print("  upper:", revolute_joint.GetUpperLimitAttr().Get())

    revolute_joint.GetLowerLimitAttr().Set(LOWER_LIMIT_DEG)
    revolute_joint.GetUpperLimitAttr().Set(UPPER_LIMIT_DEG)

    print("Joint limits AFTER:")
    print("  lower:", revolute_joint.GetLowerLimitAttr().Get())
    print("  upper:", revolute_joint.GetUpperLimitAttr().Get())
    print()

    # 2. Restore the PhysX mimic referenceJoint relationship.
    mimic_apis = PhysxSchema.PhysxMimicJointAPI.GetAll(mimic_prim)

    if len(mimic_apis) != 1:
        raise RuntimeError(
            f"Expected exactly 1 PhysxMimicJointAPI, found {len(mimic_apis)}"
        )

    mimic_api = mimic_apis[0]

    reference_rel = mimic_api.CreateReferenceJointRel()

    print("referenceJoint BEFORE:")
    print(" ", reference_rel.GetTargets())

    reference_rel.SetTargets([Sdf.Path(REFERENCE_JOINT_PATH)])

    print("referenceJoint AFTER:")
    print(" ", reference_rel.GetTargets())
    print()

    print("Mimic parameters:")
    print("  gearing:", mimic_api.GetGearingAttr().Get())
    print("  offset :", mimic_api.GetOffsetAttr().Get())
    print()

    expected_target = Sdf.Path(REFERENCE_JOINT_PATH)

    lower = revolute_joint.GetLowerLimitAttr().Get()
    upper = revolute_joint.GetUpperLimitAttr().Get()
    targets = reference_rel.GetTargets()

    if lower != LOWER_LIMIT_DEG:
        raise RuntimeError(f"Unexpected lower limit after patch: {lower}")

    if abs(upper - UPPER_LIMIT_DEG) > 1e-4:
        raise RuntimeError(f"Unexpected upper limit after patch: {upper}")

    if targets != [expected_target]:
        raise RuntimeError(
            f"Unexpected referenceJoint after patch: {targets}"
        )

    print("PATCH COMPLETE")
    print("Apply this patch BEFORE the first Physics Play.")


if __name__ == "__main__":
    patch_robotiq_mimic()