## Per-object shader values that also work in the browser (D-175).
## Desktop and Quest use `instance uniform`s (one shared material). In the
## Compatibility renderer (WebGL) instance uniforms read as their defaults, so
## the shaders declare plain uniforms there (see the INST macro at the top of
## each shader) and each object gets its own copy of the material instead.
## Always set per-object values through set_param(), never
## set_instance_shader_parameter() directly.
extends RefCounted

static var _per_material := -1


static func per_material() -> bool:
	if _per_material == -1:
		_per_material = 1 if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 0
	return _per_material == 1


static func set_param(gi: GeometryInstance3D, pname: StringName, value: Variant) -> void:
	if not per_material():
		gi.set_instance_shader_parameter(pname, value)
		return
	var m := gi.material_override as ShaderMaterial
	if m == null:
		return
	# A copy of its own the first time; again if the code swapped the material since.
	if not gi.has_meta(&"inst_param_base") or gi.get_meta(&"inst_param_base") != m:
		m = m.duplicate()
		gi.material_override = m
		gi.set_meta(&"inst_param_base", m)
	m.set_shader_parameter(pname, value)
