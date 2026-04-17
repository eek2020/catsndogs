@tool
extends SceneTree

# Headless validator for CC0-UAL retargeted character GLBs.
#
# Run:
#   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
#     --script res://tools/validate_rigged_glb.gd \
#     -- res://assets/characters/crew/nine_lives/3d/rigged.glb
#
# Exits 0 on PASS, 1 on FAIL. Writes <glb>.validate.json next to the GLB.

const DEFAULT_TARGET := "res://assets/characters/crew/nine_lives/3d/rigged.glb"

# NOTE: Godot's glTF importer (gltf/naming_version=2) strips the "_Loop"
# suffix from any animation whose name ends in _Loop and sets its loop_mode
# to LINEAR automatically. These are the POST-IMPORT names we expect to see
# in the AnimationPlayer at runtime, paired with the loop_mode we expect:
#   loop_mode 0 = NONE (one-shot), 1 = LINEAR, 2 = PINGPONG
const EXPECTED_ANIMS := {
    "A_TPose": 0,
    "Crouch_Fwd": 1,
    "Crouch_Idle": 1,
    "Dance": 1,
    "Death01": 0,
    "Driving": 1,
    "Fixing_Kneeling": 0,
    "Hit_Chest": 0,
    "Hit_Head": 0,
    "Idle": 1,
    "Idle_Talking": 1,
    "Idle_Torch": 1,
    "Interact": 0,
    "Jog_Fwd": 1,
    "Jump": 1,
    "Jump_Land": 0,
    "Jump_Start": 0,
    "PickUp_Table": 0,
    "Pistol_Aim_Down": 0,
    "Pistol_Aim_Neutral": 0,
    "Pistol_Aim_Up": 0,
    "Pistol_Idle": 1,
    "Pistol_Reload": 0,
    "Pistol_Shoot": 0,
    "Punch_Cross": 0,
    "Punch_Jab": 0,
    "Push": 1,
    "Roll": 0,
    "Roll_RM": 0,
    "Sitting_Enter": 0,
    "Sitting_Exit": 0,
    "Sitting_Idle": 1,
    "Sitting_Talking": 1,
    "Spell_Simple_Enter": 0,
    "Spell_Simple_Exit": 0,
    "Spell_Simple_Idle": 1,
    "Spell_Simple_Shoot": 0,
    "Sprint": 1,
    "Swim_Fwd": 1,
    "Swim_Idle": 1,
    "Sword_Attack": 0,
    "Sword_Attack_RM": 0,
    "Sword_Idle": 0,
    "Walk": 1,
    "Walk_Formal": 1,
}

const PLAY_TEST_ANIMS := [
    "A_TPose",
    "Idle",
    "Walk",
    "Sword_Attack",
    "Death01",
]


func _init() -> void:
    var target: String = DEFAULT_TARGET
    var user_args: PackedStringArray = OS.get_cmdline_user_args()
    for a in user_args:
        if a.begins_with("res://") and (a.ends_with(".glb") or a.ends_with(".gltf")):
            target = a
            break

    var expected: Dictionary = _resolve_expected(target)
    var report: Dictionary = _validate(target, expected)
    _emit(report)

    var exit_code: int = 0 if String(report.get("status", "FAIL")) == "PASS" else 1
    quit(exit_code)


# Resolve the expected-animations map. Looks for a sidecar
# `<glb>.expected.json` (a JSON object of {anim_name: loop_mode}) and falls
# back to the bundled CC0 UAL default. This lets Mixamo-rigged characters
# validate against their own anim set without touching this script.
func _resolve_expected(target_path: String) -> Dictionary:
    var sidecar: String = target_path.get_basename() + ".expected.json"
    if FileAccess.file_exists(sidecar):
        var f: FileAccess = FileAccess.open(sidecar, FileAccess.READ)
        if f != null:
            var txt: String = f.get_as_text()
            f.close()
            var parsed: Variant = JSON.parse_string(txt)
            if typeof(parsed) == TYPE_DICTIONARY:
                return parsed
            push_warning("expected sidecar %s did not parse to a Dictionary" % sidecar)
    return EXPECTED_ANIMS.duplicate()


func _validate(path: String, expected: Dictionary) -> Dictionary:
    var report: Dictionary = {
        "target": path,
        "issues": [],
    }

    if not ResourceLoader.exists(path):
        report["status"] = "FAIL"
        report["issues"].append("resource does not exist: %s" % path)
        return report

    var scn: PackedScene = ResourceLoader.load(path) as PackedScene
    if scn == null:
        report["status"] = "FAIL"
        report["issues"].append("ResourceLoader.load returned null (not a PackedScene?)")
        return report

    var instance: Node = scn.instantiate()
    if instance == null:
        report["status"] = "FAIL"
        report["issues"].append("PackedScene.instantiate returned null")
        return report

    var all_nodes: Array = []
    _collect_descendants(instance, all_nodes)
    report["node_count"] = all_nodes.size()
    report["root_node"] = {
        "name": String(instance.name),
        "class": instance.get_class(),
    }

    var skeletons: Array = []
    var anim_players: Array = []
    var mesh_instances: Array = []
    for n in all_nodes:
        if n is Skeleton3D:
            skeletons.append(n)
        elif n is AnimationPlayer:
            anim_players.append(n)
        elif n is MeshInstance3D:
            mesh_instances.append(n)

    report["skeleton_count"] = skeletons.size()
    report["animation_player_count"] = anim_players.size()
    report["mesh_instance_count"] = mesh_instances.size()

    if skeletons.is_empty():
        report["issues"].append("no Skeleton3D node in scene")
    else:
        var sk: Skeleton3D = skeletons[0]
        report["skeleton"] = {
            "node_path": String(instance.get_path_to(sk)),
            "bone_count": sk.get_bone_count(),
        }
        if sk.get_bone_count() == 0:
            report["issues"].append("Skeleton3D has zero bones")

    if mesh_instances.is_empty():
        report["issues"].append("no MeshInstance3D in scene")
    else:
        var mi: MeshInstance3D = _largest_mesh(mesh_instances)
        var surface_count: int = 0
        if mi.mesh != null:
            surface_count = mi.mesh.get_surface_count()
        report["mesh_instance"] = {
            "node_path": String(instance.get_path_to(mi)),
            "surface_count": surface_count,
            "has_skin": mi.skin != null,
        }
        if mi.mesh == null:
            report["issues"].append("primary MeshInstance3D has no mesh")
        if mi.skin == null:
            report["issues"].append("primary MeshInstance3D has no skin (will not deform)")

    var anim_info: Dictionary = {}
    if anim_players.is_empty():
        report["issues"].append("no AnimationPlayer node in scene")
    else:
        var ap: AnimationPlayer = anim_players[0]
        anim_info = _inspect_animation_player(ap, report, expected)
        # Mount the instance so AnimationPlayer.play()/advance() actually ticks.
        self.root.add_child(instance)
        anim_info["play_test"] = _play_test(ap, anim_info["names"], report)
        self.root.remove_child(instance)

    report["animations"] = anim_info
    instance.free()

    if report["issues"].is_empty():
        report["status"] = "PASS"
    else:
        report["status"] = "FAIL"
    return report


func _inspect_animation_player(ap: AnimationPlayer, report: Dictionary, expected: Dictionary) -> Dictionary:
    var names_raw: PackedStringArray = ap.get_animation_list()
    var names: Array[String] = []
    for n in names_raw:
        names.append(String(n))

    var details: Array = []
    for n in names:
        var anim: Animation = ap.get_animation(n)
        if anim == null:
            report["issues"].append("animation '%s' missing resource" % n)
            continue
        var track_count: int = anim.get_track_count()
        details.append({
            "name": n,
            "length": anim.length,
            "track_count": track_count,
            "loop_mode": anim.loop_mode,
        })
        if anim.length <= 0.0:
            report["issues"].append("animation '%s' has zero length" % n)
        if track_count == 0:
            report["issues"].append("animation '%s' has zero tracks" % n)
        if expected.has(n):
            var want_loop: int = int(expected[n])
            if int(anim.loop_mode) != want_loop:
                report["issues"].append(
                    "animation '%s' loop_mode=%d (expected %d)"
                    % [n, int(anim.loop_mode), want_loop]
                )

    var actual_set: Dictionary = {}
    for n in names:
        actual_set[n] = true
    var missing: Array[String] = []
    var extra: Array[String] = []
    for n in expected.keys():
        if not actual_set.has(n):
            missing.append(String(n))
    for n in names:
        if not expected.has(n):
            extra.append(n)

    if not missing.is_empty():
        report["issues"].append(
            "missing expected animations (%d): %s" % [missing.size(), ", ".join(missing)]
        )
    if not extra.is_empty():
        report["issues"].append(
            "unexpected extra animations (%d): %s" % [extra.size(), ", ".join(extra)]
        )

    return {
        "count": names.size(),
        "expected_count": expected.size(),
        "names": names,
        "details": details,
        "missing_expected": missing,
        "extra_unexpected": extra,
    }


func _play_test(ap: AnimationPlayer, names: Array, report: Dictionary) -> Dictionary:
    var results: Dictionary = {}
    var name_set: Dictionary = {}
    for n in names:
        name_set[n] = true

    for play_name in PLAY_TEST_ANIMS:
        if not name_set.has(play_name):
            results[play_name] = {"outcome": "NOT_FOUND"}
            continue
        var anim: Animation = ap.get_animation(play_name)
        var step: float = minf(0.033, anim.length * 0.1)
        ap.stop()
        ap.play(play_name)
        ap.advance(step)
        var pos: float = ap.current_animation_position
        results[play_name] = {
            "outcome": "OK",
            "length": anim.length,
            "advanced_by": step,
            "current_position": pos,
            "is_playing": ap.is_playing(),
        }
        if pos <= 0.0:
            report["issues"].append("animation '%s' did not advance" % play_name)
    ap.stop()
    return results


func _largest_mesh(mesh_instances: Array) -> MeshInstance3D:
    var best: MeshInstance3D = mesh_instances[0]
    var best_count: int = 0
    if best.mesh != null:
        for s in range(best.mesh.get_surface_count()):
            best_count += _surface_vertex_count(best.mesh, s)
    for i in range(1, mesh_instances.size()):
        var mi: MeshInstance3D = mesh_instances[i]
        if mi.mesh == null:
            continue
        var total: int = 0
        for s in range(mi.mesh.get_surface_count()):
            total += _surface_vertex_count(mi.mesh, s)
        if total > best_count:
            best = mi
            best_count = total
    return best


func _surface_vertex_count(mesh: Mesh, surface: int) -> int:
    var arr: Array = mesh.surface_get_arrays(surface)
    if arr.is_empty():
        return 0
    var verts = arr[Mesh.ARRAY_VERTEX]
    if verts == null:
        return 0
    return verts.size()


func _collect_descendants(node: Node, out: Array) -> void:
    out.append(node)
    for child in node.get_children():
        _collect_descendants(child, out)


func _emit(report: Dictionary) -> void:
    var status: String = String(report.get("status", "UNKNOWN"))
    var target: String = String(report.get("target", "?"))

    print("=== RIGGED GLB VALIDATION ===")
    print("target : %s" % target)
    print("status : %s" % status)
    print("nodes  : %d" % int(report.get("node_count", -1)))

    if report.has("skeleton"):
        var sk: Dictionary = report["skeleton"]
        print("skeleton    : %s (%d bones)" % [sk["node_path"], sk["bone_count"]])
    if report.has("mesh_instance"):
        var mi: Dictionary = report["mesh_instance"]
        print(
            "mesh        : %s (surfaces=%d, has_skin=%s)"
            % [mi["node_path"], mi["surface_count"], mi["has_skin"]]
        )
    if report.has("animations") and not (report["animations"] as Dictionary).is_empty():
        var a: Dictionary = report["animations"]
        print("animations  : %d (expected %d)" % [int(a.get("count", 0)), int(a.get("expected_count", 0))])
        if a.has("missing_expected") and not (a["missing_expected"] as Array).is_empty():
            print("  missing   : %s" % ", ".join(a["missing_expected"]))
        if a.has("extra_unexpected") and not (a["extra_unexpected"] as Array).is_empty():
            print("  extra     : %s" % ", ".join(a["extra_unexpected"]))
        if a.has("play_test"):
            var pt: Dictionary = a["play_test"]
            for pn in pt.keys():
                var r: Dictionary = pt[pn]
                if String(r.get("outcome", "?")) == "OK":
                    print(
                        "  play %-20s -> pos=%0.4f / len=%0.4f"
                        % [pn, float(r["current_position"]), float(r["length"])]
                    )
                else:
                    print("  play %-20s -> %s" % [pn, String(r["outcome"])])

    var issues: Array = report.get("issues", [])
    if not issues.is_empty():
        print("-- issues (%d) --" % issues.size())
        for iss in issues:
            print("  * %s" % String(iss))

    var fs_path: String = ProjectSettings.globalize_path(target).get_basename() + ".validate.json"
    var fp: FileAccess = FileAccess.open(fs_path, FileAccess.WRITE)
    if fp != null:
        fp.store_string(JSON.stringify(report, "  "))
        fp.close()
        print("report -> %s" % fs_path)
    else:
        print("WARN: could not write report to %s" % fs_path)
