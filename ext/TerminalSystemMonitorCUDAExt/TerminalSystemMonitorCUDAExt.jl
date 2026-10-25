module TerminalSystemMonitorCUDAExt

using CUDA
using MLDataDevices: CUDADevice
using UnicodePlots: barplot
import TerminalSystemMonitor
using Term: Panel

TerminalSystemMonitor.gpu_available(::Type{CUDADevice}) =
    monitoring_available(CUDA.functional, CUDA.NVML.has_nvml, CUDA.devices)

monitoring_available(functional, has_nvml, devices) =
    functional() && has_nvml() && iterate(devices()) !== nothing

function _plot_gpu_utilization_rates(gpu_id, dev::CUDA.CuDevice)
    mig = uuid(dev) != parent_uuid(dev)
    nvml_dev = CUDA.NVML.Device(uuid(dev); mig)
    x = string(gpu_id)
    return optional_metric("GPU $(x) utilization") do
        y = 100 * CUDA.NVML.utilization_rates(nvml_dev).compute
        barplot([x], [y], maximum = 100, width = 15)
    end
end

function TerminalSystemMonitor.plot_gpu_utilization_rates(::Type{CUDADevice})
    plts = []
    TerminalSystemMonitor.gpu_available(CUDADevice) || return plts
    devices = collect(CUDA.devices())
    isempty(devices) && return plts
    npad = 1 + floor(Int, log10(length(devices)))
    xs = ["id: $(lpad(i-1, npad))" for i = 1:length(devices)]

    for (gpu_id, dev) in zip(xs, devices)
        push!(plts, _plot_gpu_utilization_rates(gpu_id, dev))
    end
    return plts
end

function _plot_gpu_memory_utilization(dev::CUDA.CuDevice)
    device_name = CUDA.name(dev)
    mig = uuid(dev) != parent_uuid(dev)
    nvml_dev = CUDA.NVML.Device(uuid(dev); mig)
    (; total, used) = CUDA.NVML.memory_info(nvml_dev)

    memorytotal = total / 2.0^20
    memoryusage = used / 2.0^20
    memorytotal_unit = "MiB"

    return barplot(
        ["GPU Mem: "],
        [memoryusage],
        xlabel = device_name,
        # Adds a space for better styling
        name = " $(memorytotal) $(memorytotal_unit)",
        maximum = memorytotal,
        width = 15,
    )
end

function TerminalSystemMonitor.plot_gpu_memory_utilization(::Type{CUDADevice})
    plts = []
    TerminalSystemMonitor.gpu_available(CUDADevice) || return plts
    for dev in CUDA.devices()
        push!(plts, _plot_gpu_memory_utilization(dev))
    end
    plts
end

function optional_metric(f, label)
    try
        return f()
    catch e
        if e isa CUDA.NVML.NVMLError && e.code == CUDA.NVML.ERROR_NOT_SUPPORTED
            return Panel("$(label): N/A (not supported)")
        end
        rethrow()
    end
end

function TerminalSystemMonitor.backend_plots(::Type{CUDADevice})
    TerminalSystemMonitor.gpu_available(CUDADevice) || return Any[]
    # Use one snapshot so utilization and memory always refer to the same devices.
    devices = collect(CUDA.devices())
    return TerminalSystemMonitor.paired_device_plots(
        devices,
        _plot_gpu_utilization_rates,
        dev -> optional_metric(() -> _plot_gpu_memory_utilization(dev), "GPU memory"),
    )
end

end # module TerminalSystemMonitorCUDAExt
