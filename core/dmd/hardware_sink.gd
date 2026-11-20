## Real LED DMD output (ZeDMD, Pin2DMD, ...) via libdmdutil's `dmdserver` over TCP.
## STUB: the dmdserver wire protocol must be verified before implementing (M5, D-008).
extends RefCounted

var host: String
var port: int
var _warned := false


func _init(p_host: String, p_port: int) -> void:
	host = p_host
	port = p_port


func send_frame(_frame: Image) -> void:
	if not _warned:
		_warned = true
		push_warning("DMD hardware sink not implemented yet (target %s:%d)" % [host, port])
