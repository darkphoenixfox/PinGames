// LeiaSR bridge for PinGames (D-418): lets GDScript drive the Leia SR SDK's
// DirectX 12 weaver on Godot's own D3D12 device. GDScript passes native
// handles as ints (window, device, command queue, textures); this class owns
// the SR context, the weaver and a small command list ring of its own.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class LeiaSR : public RefCounted {
	GDCLASS(LeiaSR, RefCounted)

public:
	LeiaSR();
	~LeiaSR();

	// True when the SR runtime DLLs can be loaded (an SR PC).
	static bool runtime_installed();
	// Connects to the SR service (waits up to `timeout_s`) and finds the
	// display. Returns false when there is no SR service or display.
	bool open(double timeout_s);
	// Creates the weaver on Godot's D3D12 device for this window.
	bool create_weaver(int64_t hwnd, int64_t d3d12_device);
	// [left, top, width, height (px), width, height (cm), view width,
	//  view height (px), default eye x, y, z (mm)]
	PackedFloat64Array display_info();
	// [left x, y, z, right x, y, z] in mm, display centre origin.
	PackedFloat64Array eyes();
	// Weaves the side-by-side `input` into `output` (both ID3D12Resource*),
	// on Godot's command queue. Formats are DXGI_FORMAT values.
	bool weave(int64_t queue, int64_t input, int in_w, int in_h, int in_format,
			int64_t output, int out_w, int out_h, int out_format);
	// Weaver colour handling and timing: `srgb` = the input is sRGB-encoded
	// (crosstalk is cancelled in linear light, then re-encoded); latency in
	// frames from weave() to the picture on screen (eye prediction).
	void configure(bool srgb, int latency_frames);
	void close();
	String last_error() const;

protected:
	static void _bind_methods();

private:
	struct Impl;
	Impl *impl = nullptr;
};

} // namespace godot
