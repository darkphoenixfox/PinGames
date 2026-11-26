// See leia_sr.h. The SR DLLs are delay-loaded, so this extension loads on any
// Windows PC; runtime_installed() checks for them before anything calls in.
#include "leia_sr.h"

#include <godot_cpp/core/class_db.hpp>

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <d3d12.h>

#include "sr/management/srcontext.h"
#include "sr/weaver/dx12weaver.h"
#include "sr/world/display/display.h"

#include <string>

using namespace godot;

namespace {
const int RING = 3;
const wchar_t *SR_DLLS[] = { L"simulatedreality.dll", L"SimulatedRealityCore.dll",
	L"SimulatedRealityDisplays.dll", L"SimulatedRealityDirectX.dll", L"DimencoWeaving.dll" };

void barrier(ID3D12GraphicsCommandList *cl, ID3D12Resource *r, D3D12_RESOURCE_STATES a, D3D12_RESOURCE_STATES b) {
	if (a == b) {
		return;
	}
	D3D12_RESOURCE_BARRIER rb = {};
	rb.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
	rb.Transition.pResource = r;
	rb.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
	rb.Transition.StateBefore = a;
	rb.Transition.StateAfter = b;
	cl->ResourceBarrier(1, &rb);
}
} // namespace

struct LeiaSR::Impl {
	SR::SRContext *context = nullptr;
	SR::IDisplay *display = nullptr;
	SR::IDX12Weaver1 *weaver = nullptr;
	ID3D12Device *device = nullptr;
	ID3D12CommandAllocator *alloc[RING] = {};
	ID3D12GraphicsCommandList *list = nullptr;
	ID3D12DescriptorHeap *rtv_heap = nullptr;
	ID3D12Fence *fence = nullptr;
	HANDLE fence_event = nullptr;
	UINT64 fence_value = 0;
	UINT64 slot_value[RING] = {};
	int slot = 0;
	DXGI_FORMAT in_format = DXGI_FORMAT_UNKNOWN;
	DXGI_FORMAT out_format = DXGI_FORMAT_UNKNOWN;
	std::string error;

	void release_d3d() {
		if (fence && fence_value > 0 && fence->GetCompletedValue() < fence_value) {
			fence->SetEventOnCompletion(fence_value, fence_event);
			WaitForSingleObject(fence_event, 2000);
		}
		if (list) { list->Release(); list = nullptr; }
		for (int i = 0; i < RING; i++) {
			if (alloc[i]) { alloc[i]->Release(); alloc[i] = nullptr; }
		}
		if (rtv_heap) { rtv_heap->Release(); rtv_heap = nullptr; }
		if (fence) { fence->Release(); fence = nullptr; }
		if (fence_event) { CloseHandle(fence_event); fence_event = nullptr; }
		device = nullptr;
	}
};

LeiaSR::LeiaSR() {
	impl = new Impl();
}

LeiaSR::~LeiaSR() {
	close();
	delete impl;
}

bool LeiaSR::runtime_installed() {
	for (const wchar_t *dll : SR_DLLS) {
		HMODULE m = LoadLibraryW(dll);
		if (m == nullptr) {
			return false;
		}
	}
	return true;
}

bool LeiaSR::open(double timeout_s) {
	if (impl->context != nullptr) {
		return impl->display != nullptr;
	}
	if (!runtime_installed()) {
		impl->error = "SR runtime not installed";
		return false;
	}
	const ULONGLONG start = GetTickCount64();
	while (impl->context == nullptr) {
		try {
			impl->context = SR::SRContext::create();
		} catch (...) {
			// The SR service may still be starting.
		}
		if (impl->context == nullptr) {
			if ((GetTickCount64() - start) / 1000.0 > timeout_s) {
				impl->error = "SR service not available";
				return false;
			}
			Sleep(100);
		}
	}
	SR::IDisplayManager *dm = SR::GetDisplayManagerInstance(*impl->context);
	while (dm != nullptr) {
		SR::IDisplay *d = dm->getPrimaryActiveSRDisplay();
		if (d != nullptr && d->isValid()) {
			SR_recti loc = d->getLocation();
			if (loc.right - loc.left != 0 && loc.bottom - loc.top != 0) {
				impl->display = d;
				break;
			}
		}
		if ((GetTickCount64() - start) / 1000.0 > timeout_s) {
			break;
		}
		Sleep(100);
	}
	if (impl->display == nullptr) {
		impl->error = "no active SR display";
		return false;
	}
	return true;
}

bool LeiaSR::create_weaver(int64_t hwnd, int64_t d3d12_device) {
	if (impl->display == nullptr) {
		impl->error = "open() first";
		return false;
	}
	if (impl->weaver != nullptr) {
		return true;
	}
	ID3D12Device *dev = reinterpret_cast<ID3D12Device *>(d3d12_device);
	WeaverErrorCode r = SR::CreateDX12Weaver(impl->context, dev, reinterpret_cast<HWND>(hwnd), &impl->weaver);
	if (r != WeaverErrorCode::WeaverSuccess || impl->weaver == nullptr) {
		impl->error = "CreateDX12Weaver failed: " + std::to_string((int)r);
		impl->weaver = nullptr;
		return false;
	}
	impl->context->initialize();
	impl->device = dev;
	HRESULT hr = S_OK;
	for (int i = 0; i < RING && SUCCEEDED(hr); i++) {
		hr = dev->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(&impl->alloc[i]));
	}
	if (SUCCEEDED(hr)) {
		hr = dev->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, impl->alloc[0], nullptr, IID_PPV_ARGS(&impl->list));
	}
	if (SUCCEEDED(hr)) {
		impl->list->Close();
		D3D12_DESCRIPTOR_HEAP_DESC hd = {};
		hd.NumDescriptors = 1;
		hd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
		hr = dev->CreateDescriptorHeap(&hd, IID_PPV_ARGS(&impl->rtv_heap));
	}
	if (SUCCEEDED(hr)) {
		hr = dev->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&impl->fence));
	}
	if (FAILED(hr)) {
		impl->error = "D3D12 setup failed";
		impl->release_d3d();
		return false;
	}
	impl->fence_event = CreateEventW(nullptr, FALSE, FALSE, nullptr);
	return true;
}

PackedFloat64Array LeiaSR::display_info() {
	PackedFloat64Array a;
	SR::IDisplay *d = impl->display;
	if (d == nullptr) {
		return a;
	}
	SR_recti loc = d->getLocation();
	float x = 0, y = 0, z = 0;
	d->getDefaultViewingPosition(x, y, z);
	double v[] = { (double)loc.left, (double)loc.top, (double)(loc.right - loc.left), (double)(loc.bottom - loc.top),
		d->getPhysicalSizeWidth(), d->getPhysicalSizeHeight(),
		(double)d->getRecommendedViewsTextureWidth(), (double)d->getRecommendedViewsTextureHeight(), x, y, z };
	for (double f : v) {
		a.push_back(f);
	}
	return a;
}

PackedFloat64Array LeiaSR::eyes() {
	PackedFloat64Array a;
	if (impl->weaver == nullptr) {
		return a;
	}
	float l[3] = {}, r[3] = {};
	impl->weaver->getPredictedEyePositions(l, r);
	for (int i = 0; i < 3; i++) {
		a.push_back(l[i]);
	}
	for (int i = 0; i < 3; i++) {
		a.push_back(r[i]);
	}
	return a;
}

bool LeiaSR::weave(int64_t queue, int64_t input, int in_w, int in_h, int in_format,
		int64_t output, int out_w, int out_h, int out_format) {
	Impl &m = *impl;
	if (m.weaver == nullptr || m.list == nullptr) {
		return false;
	}
	ID3D12CommandQueue *q = reinterpret_cast<ID3D12CommandQueue *>(queue);
	ID3D12Resource *in = reinterpret_cast<ID3D12Resource *>(input);
	ID3D12Resource *out = reinterpret_cast<ID3D12Resource *>(output);
	// Reuse this slot's allocator once the GPU is done with it.
	if (m.fence->GetCompletedValue() < m.slot_value[m.slot]) {
		m.fence->SetEventOnCompletion(m.slot_value[m.slot], m.fence_event);
		WaitForSingleObject(m.fence_event, 1000);
	}
	ID3D12CommandAllocator *al = m.alloc[m.slot];
	al->Reset();
	m.list->Reset(al, nullptr);
	try {
		if ((DXGI_FORMAT)in_format != m.in_format || (DXGI_FORMAT)out_format != m.out_format) {
			m.in_format = (DXGI_FORMAT)in_format;
			m.out_format = (DXGI_FORMAT)out_format;
			m.weaver->setOutputFormat(m.out_format);
		}
		m.weaver->setInputViewTexture(in, in_w, in_h, m.in_format);
		D3D12_CPU_DESCRIPTOR_HANDLE rtv = m.rtv_heap->GetCPUDescriptorHandleForHeapStart();
		D3D12_RENDER_TARGET_VIEW_DESC rd = {};
		rd.Format = m.out_format;
		rd.ViewDimension = D3D12_RTV_DIMENSION_TEXTURE2D;
		m.device->CreateRenderTargetView(out, &rd, rtv);
		// Godot leaves the side-by-side input as a render target and samples
		// the output; both go back to those states afterwards.
		barrier(m.list, in, D3D12_RESOURCE_STATE_RENDER_TARGET, D3D12_RESOURCE_STATE_ALL_SHADER_RESOURCE);
		barrier(m.list, out, D3D12_RESOURCE_STATE_ALL_SHADER_RESOURCE, D3D12_RESOURCE_STATE_RENDER_TARGET);
		m.list->OMSetRenderTargets(1, &rtv, FALSE, nullptr);
		D3D12_VIEWPORT vp = { 0.0f, 0.0f, (float)out_w, (float)out_h, 0.0f, 1.0f };
		D3D12_RECT sc = { 0, 0, out_w, out_h };
		m.list->RSSetViewports(1, &vp);
		m.list->RSSetScissorRects(1, &sc);
		m.weaver->setCommandList(m.list);
		m.weaver->setViewport(vp);
		m.weaver->setScissorRect(sc);
		m.weaver->weave();
		barrier(m.list, out, D3D12_RESOURCE_STATE_RENDER_TARGET, D3D12_RESOURCE_STATE_ALL_SHADER_RESOURCE);
		barrier(m.list, in, D3D12_RESOURCE_STATE_ALL_SHADER_RESOURCE, D3D12_RESOURCE_STATE_RENDER_TARGET);
	} catch (...) {
		m.error = "weave threw";
		m.list->Close();
		return false;
	}
	m.list->Close();
	ID3D12CommandList *lists[] = { m.list };
	q->ExecuteCommandLists(1, lists);
	m.fence_value++;
	q->Signal(m.fence, m.fence_value);
	m.slot_value[m.slot] = m.fence_value;
	m.slot = (m.slot + 1) % RING;
	return true;
}

void LeiaSR::configure(bool srgb, int latency_frames) {
	if (impl->weaver == nullptr) {
		return;
	}
	impl->weaver->setShaderSRGBConversion(srgb, srgb);
	if (latency_frames > 0) {
		impl->weaver->setLatencyInFrames((uint64_t)latency_frames);
	}
}

void LeiaSR::close() {
	impl->release_d3d();
	if (impl->weaver != nullptr) {
		impl->weaver->destroy();
		impl->weaver = nullptr;
	}
	if (impl->context != nullptr) {
		SR::SRContext::deleteSRContext(impl->context);
		impl->context = nullptr;
	}
	impl->display = nullptr;
}

String LeiaSR::last_error() const {
	return String(impl->error.c_str());
}

void LeiaSR::_bind_methods() {
	ClassDB::bind_static_method("LeiaSR", D_METHOD("runtime_installed"), &LeiaSR::runtime_installed);
	ClassDB::bind_method(D_METHOD("open", "timeout_s"), &LeiaSR::open);
	ClassDB::bind_method(D_METHOD("create_weaver", "hwnd", "d3d12_device"), &LeiaSR::create_weaver);
	ClassDB::bind_method(D_METHOD("display_info"), &LeiaSR::display_info);
	ClassDB::bind_method(D_METHOD("eyes"), &LeiaSR::eyes);
	ClassDB::bind_method(D_METHOD("weave", "queue", "input", "in_w", "in_h", "in_format", "output", "out_w", "out_h", "out_format"), &LeiaSR::weave);
	ClassDB::bind_method(D_METHOD("configure", "srgb", "latency_frames"), &LeiaSR::configure);
	ClassDB::bind_method(D_METHOD("close"), &LeiaSR::close);
	ClassDB::bind_method(D_METHOD("last_error"), &LeiaSR::last_error);
}
