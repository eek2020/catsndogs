class_name MaterialApplicator
extends RefCounted

## Runtime material applicator for untextured 3D cutscene geometry.
##
## Recursively walks a Node3D subtree, finds every MeshInstance3D, and assigns
## a StandardMaterial3D using geometry-based heuristics (AABB position, size,
## orientation) combined with name matching.  Materials use Godot's built-in
## NoiseTexture2D for procedural detail — no external image files required.
##
## Usage:
##   var applicator := MaterialApplicator.new()
##   applicator.apply(outpost_root_node)

# ── Name-based keyword rules (checked first) ─────────────────────────────────
# Keywords are checked in order; first match wins.

const MATERIAL_RULES: Array[Dictionary] = [
	# Ground / terrain — dusty warm regolith with fine grain
	{
		"keywords": ["ground", "terrain", "floor_ext", "dirt", "sand", "plane"],
		"albedo": Color(0.34, 0.26, 0.17),
		"roughness": 0.95,
		"metallic": 0.0,
		"noise_scale": 18.0,
		"normal_strength": 0.6,
		"role": "ground",
	},
	# Rocks / boulders — cool grey stone, matte, chunky noise
	{
		"keywords": ["rock", "boulder", "stone"],
		"albedo": Color(0.38, 0.36, 0.34),
		"roughness": 0.88,
		"metallic": 0.02,
		"noise_scale": 3.5,
		"normal_strength": 0.9,
		"role": "rock",
	},
	# Hills / background terrain — darker dusty stone
	{
		"keywords": ["hill", "mound", "ridge"],
		"albedo": Color(0.28, 0.23, 0.17),
		"roughness": 0.93,
		"metallic": 0.0,
		"noise_scale": 2.5,
		"normal_strength": 0.7,
		"role": "hill",
	},
	# Concrete / foundations
	{
		"keywords": ["concrete", "foundation", "base", "slab", "platform"],
		"albedo": Color(0.30, 0.28, 0.26),
		"roughness": 0.85,
		"metallic": 0.05,
		"noise_scale": 10.0,
		"normal_strength": 0.4,
		"role": "structure",
	},
	# Metal walls / panels / hull
	{
		"keywords": ["wall", "panel", "hull", "plate", "armor", "bulkhead", "side"],
		"albedo": Color(0.25, 0.24, 0.22),
		"roughness": 0.55,
		"metallic": 0.65,
		"noise_scale": 14.0,
		"normal_strength": 0.6,
		"role": "wall",
	},
	# Door
	{
		"keywords": ["door", "gate", "hatch", "blast"],
		"albedo": Color(0.18, 0.17, 0.16),
		"roughness": 0.45,
		"metallic": 0.75,
		"noise_scale": 18.0,
		"normal_strength": 0.7,
		"role": "door",
	},
	# Roof / ceiling
	{
		"keywords": ["roof", "ceiling", "top", "canopy"],
		"albedo": Color(0.20, 0.19, 0.17),
		"roughness": 0.7,
		"metallic": 0.4,
		"noise_scale": 12.0,
		"normal_strength": 0.4,
		"role": "roof",
	},
	# Window / glass
	{
		"keywords": ["window", "glass", "viewport", "porthole"],
		"albedo": Color(0.08, 0.14, 0.22),
		"roughness": 0.1,
		"metallic": 0.2,
		"noise_scale": 20.0,
		"normal_strength": 0.1,
		"role": "glass",
	},
	# Wreckage / debris / scrap
	{
		"keywords": [
			"wreck", "debris", "scrap", "ruin", "damage", "scout", "gunship", "hull_wreck",
		],
		"albedo": Color(0.18, 0.15, 0.10),
		"roughness": 0.8,
		"metallic": 0.5,
		"noise_scale": 8.0,
		"normal_strength": 0.8,
		"role": "wreckage",
	},
	# Rust / weathered metal
	{
		"keywords": ["rust", "corrode", "weather", "aged", "old"],
		"albedo": Color(0.35, 0.18, 0.06),
		"roughness": 0.9,
		"metallic": 0.3,
		"noise_scale": 7.0,
		"normal_strength": 0.7,
		"role": "rust",
	},
	# Pipes / conduit / mechanical
	{
		"keywords": ["pipe", "conduit", "tube", "vent", "mech", "cable", "wire", "cylinder"],
		"albedo": Color(0.22, 0.22, 0.24),
		"roughness": 0.5,
		"metallic": 0.7,
		"noise_scale": 16.0,
		"normal_strength": 0.5,
		"role": "pipe",
	},
	# Light / lamp / emissive fixtures
	{
		"keywords": ["light", "lamp", "glow", "emissive", "beacon", "signal"],
		"albedo": Color(0.9, 0.15, 0.1),
		"roughness": 0.3,
		"metallic": 0.1,
		"noise_scale": 20.0,
		"normal_strength": 0.0,
		"emission": Color(1.0, 0.15, 0.1),
		"emission_energy": 2.5,
		"role": "light",
	},
	# Crate / barrel / container
	{
		"keywords": ["crate", "barrel", "box", "container", "cargo", "supply"],
		"albedo": Color(0.28, 0.22, 0.12),
		"roughness": 0.8,
		"metallic": 0.15,
		"noise_scale": 9.0,
		"normal_strength": 0.6,
		"role": "crate",
	},
	# Antenna / tower / mast
	{
		"keywords": ["antenna", "tower", "mast", "dish", "comm"],
		"albedo": Color(0.32, 0.30, 0.28),
		"roughness": 0.4,
		"metallic": 0.8,
		"noise_scale": 20.0,
		"normal_strength": 0.4,
		"role": "antenna",
	},
	# Interior floor
	{
		"keywords": ["floor", "deck", "grate"],
		"albedo": Color(0.18, 0.17, 0.16),
		"roughness": 0.65,
		"metallic": 0.55,
		"noise_scale": 15.0,
		"normal_strength": 0.5,
		"role": "floor",
	},
]

# ── Geometry-classified configs (used when name matching fails) ───────────────
# The applicator analyses each mesh's AABB to guess its role.

const GEO_GROUND: Dictionary = {
	"albedo": Color(0.22, 0.18, 0.10),
	"roughness": 0.92,
	"metallic": 0.0,
	"noise_scale": 6.0,
	"normal_strength": 0.5,
	"role": "ground",
}

const GEO_WALL: Dictionary = {
	"albedo": Color(0.25, 0.24, 0.22),
	"roughness": 0.55,
	"metallic": 0.65,
	"noise_scale": 14.0,
	"normal_strength": 0.6,
	"role": "wall",
}

const GEO_ROOF: Dictionary = {
	"albedo": Color(0.20, 0.19, 0.17),
	"roughness": 0.7,
	"metallic": 0.4,
	"noise_scale": 12.0,
	"normal_strength": 0.4,
	"role": "roof",
}

const GEO_SMALL_OBJECT: Dictionary = {
	"albedo": Color(0.28, 0.22, 0.12),
	"roughness": 0.75,
	"metallic": 0.35,
	"noise_scale": 10.0,
	"normal_strength": 0.6,
	"role": "object",
}

const GEO_THIN_STRUCTURE: Dictionary = {
	"albedo": Color(0.22, 0.22, 0.24),
	"roughness": 0.5,
	"metallic": 0.7,
	"noise_scale": 16.0,
	"normal_strength": 0.5,
	"role": "pipe",
}

const GEO_FALLBACK: Dictionary = {
	"albedo": Color(0.22, 0.20, 0.18),
	"roughness": 0.7,
	"metallic": 0.4,
	"noise_scale": 12.0,
	"normal_strength": 0.5,
	"role": "unknown",
}

# Cache: config-key → StandardMaterial3D so identical meshes share the material.
var _material_cache: Dictionary = {}
var _mesh_log: Array[String] = []


## Walk the subtree rooted at `root` and apply materials to every MeshInstance3D.
func apply(root: Node) -> void:
	_mesh_log.clear()
	_apply_recursive(root)
	print("MaterialApplicator: textured %d unique material slots across subtree '%s'" % [
		_material_cache.size(), root.name,
	])
	print("MaterialApplicator: mesh nodes found:")
	for entry in _mesh_log:
		print("  %s" % entry)


func _apply_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		_apply_to_mesh(node as MeshInstance3D)
	for child in node.get_children():
		_apply_recursive(child)


func _apply_to_mesh(mesh_inst: MeshInstance3D) -> void:
	var mesh: Mesh = mesh_inst.mesh
	if mesh == null:
		return

	# Godot's GLB importer often names MeshInstance3D children `geometry_N` and
	# keeps the original node name (e.g. `Rock_00`, `Ground`) on the parent
	# Node3D wrapper. Check the mesh name AND walk up the parent chain so
	# keyword rules still hit.
	var names_to_check: Array[String] = [mesh_inst.name.to_lower()]
	var parent: Node = mesh_inst.get_parent()
	var depth: int = 0
	while parent != null and depth < 3:
		names_to_check.append(parent.name.to_lower())
		parent = parent.get_parent()
		depth += 1

	# Try name-based matching first — against the mesh name and up to 3 ancestors.
	var config: Dictionary = {}
	for candidate in names_to_check:
		config = _match_config_by_name(candidate)
		if not config.is_empty():
			break
	var match_method: String = "name"

	# If no name match, classify by geometry.
	if config.is_empty():
		config = _classify_by_geometry(mesh_inst)
		match_method = "geometry"

	var role: String = config.get("role", "unknown")
	var aabb: AABB = mesh.get_aabb()
	_mesh_log.append("%s -> %s (%s) aabb_size=%s pos=%s" % [
		mesh_inst.name, role, match_method,
		str(aabb.size).substr(0, 30),
		str(mesh_inst.global_position).substr(0, 30)
	])

	var cache_key: String = _config_cache_key(config)

	var mat: StandardMaterial3D
	if _material_cache.has(cache_key):
		mat = _material_cache[cache_key]
	else:
		mat = _build_material(config)
		_material_cache[cache_key] = mat

	# Apply to every surface of the mesh.
	var surface_count: int = mesh.get_surface_count()
	for i in range(surface_count):
		mesh_inst.set_surface_override_material(i, mat)


## Name-based matching. Returns empty dict if nothing matched.
func _match_config_by_name(name_lower: String) -> Dictionary:
	for rule in MATERIAL_RULES:
		for keyword in rule.keywords:
			if name_lower.contains(keyword):
				return rule
	return {}


## Classify a mesh by its AABB geometry (size, position, aspect ratio).
func _classify_by_geometry(mesh_inst: MeshInstance3D) -> Dictionary:
	var mesh: Mesh = mesh_inst.mesh
	if mesh == null:
		return GEO_FALLBACK

	var aabb: AABB = mesh.get_aabb()
	var size: Vector3 = aabb.size
	var gpos: Vector3 = mesh_inst.global_position

	# Volume heuristic.
	var volume: float = size.x * size.y * size.z
	var max_dim: float = max(size.x, max(size.y, size.z))
	var min_dim: float = min(size.x, min(size.y, size.z))
	var aspect: float = max_dim / max(min_dim, 0.001)

	# Flat horizontal surface near y=0 → ground plane.
	if size.y < 0.5 and size.x > 4.0 and size.z > 4.0:
		return GEO_GROUND
	if gpos.y < 0.3 and size.y < 1.0 and (size.x > 5.0 or size.z > 5.0):
		return GEO_GROUND

	# Flat horizontal surface high up → roof.
	if size.y < 1.0 and gpos.y > 3.0 and (size.x > 2.0 or size.z > 2.0):
		return GEO_ROOF

	# Tall thin → pipe / beam / column.
	if aspect > 6.0 and volume < 2.0:
		return GEO_THIN_STRUCTURE

	# Tall & wide but thin in one axis → wall.
	if size.y > 2.0 and min_dim < 1.0 and max_dim > 2.0:
		return GEO_WALL

	# Small object.
	if volume < 3.0:
		return GEO_SMALL_OBJECT

	# Large structure — default to wall.
	if size.y > 1.5:
		return GEO_WALL

	return GEO_FALLBACK


func _config_cache_key(config: Dictionary) -> String:
	return "%s_%.2f_%.2f_%s" % [
		str(config.albedo), config.roughness, config.metallic, config.get("role", "x"),
	]


func _build_material(config: Dictionary) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = config.albedo
	mat.roughness = config.roughness
	mat.metallic = config.metallic
	mat.cull_mode = BaseMaterial3D.CULL_BACK

	# Procedural noise as albedo texture — this ensures visible texture on geometry.
	# Frequency must be high enough that features span a small fraction of the
	# texture, otherwise the whole thing is one blob and you see flat albedo.
	var albedo_noise_tex := NoiseTexture2D.new()
	var albedo_noise := FastNoiseLite.new()
	albedo_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	albedo_noise.frequency = 0.06
	albedo_noise.fractal_octaves = 4
	albedo_noise.seed = hash(config.get("role", "fallback"))
	albedo_noise_tex.noise = albedo_noise
	albedo_noise_tex.width = 256
	albedo_noise_tex.height = 256
	albedo_noise_tex.seamless = true
	# Color the noise texture by setting a gradient.
	var grad := Gradient.new()
	var base_c: Color = config.albedo
	var dark_c: Color = base_c.darkened(0.3)
	var light_c: Color = base_c.lightened(0.15)
	grad.set_color(0, dark_c)
	grad.add_point(0.5, base_c)
	grad.set_color(grad.get_point_count() - 1, light_c)
	albedo_noise_tex.color_ramp = grad
	mat.albedo_texture = albedo_noise_tex

	# Triplanar projection: the source GLB has no UV unwrap for terrain / rocks,
	# so the noise texture only renders if we project it from world-space axes
	# instead of sampling UVs. Without this, low-poly meshes show flat albedo.
	mat.uv1_triplanar = true

	# UV1 scaling controls apparent texture density (lower = larger features).
	var uv_scale: float = config.get("noise_scale", 12.0)
	mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)

	# Surface normal map for roughness / bumpiness cues. Only built when the
	# config asks for it — keeps emissive lights etc. flat.
	var normal_strength: float = config.get("normal_strength", 0.0)
	if normal_strength > 0.0:
		var normal_noise_tex := NoiseTexture2D.new()
		var normal_noise := FastNoiseLite.new()
		normal_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		normal_noise.frequency = 0.05
		normal_noise.seed = hash(config.get("role", "fallback")) + 1
		normal_noise_tex.noise = normal_noise
		normal_noise_tex.width = 128
		normal_noise_tex.height = 128
		normal_noise_tex.seamless = true
		normal_noise_tex.as_normal_map = true
		normal_noise_tex.bump_strength = 8.0
		mat.normal_enabled = true
		mat.normal_texture = normal_noise_tex
		mat.normal_scale = normal_strength

	# Emission (for lights / beacons).
	if config.has("emission"):
		mat.emission_enabled = true
		mat.emission = config.emission
		mat.emission_energy_multiplier = config.get("emission_energy", 1.0)

	return mat
