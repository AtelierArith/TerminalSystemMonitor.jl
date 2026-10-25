module TerminalSystemMonitorCUDAExt

using CUDA
using MLDataDevices: CUDADevice
using UnicodePlots: barplot
import TerminalSystemMonitor

function _plot_gpu_utilization_rates(gpu_id, dev::CUDA.CuDevice)
    mig = uuid(dev) != parent_uuid(dev)
    nvml_dev = CUDA.NVML.Device(uuid(dev); mig)
    x = string(gpu_id)
    y = 100 * CUDA.NVML.utilization_rates(nvml_dev).compute
    return barplot([x], [y], maximum = 100, width = 15)
end

function TerminalSystemMonitor.plot_gpu_utilization_rates(::Type{CUDADevice})
    plts = []
    devices = collect(CUDA.devices())
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
    nvml_gpu = CUDA.NVML.Device(parent_uuid(dev))
    nvml_dev = CUDA.NVML.Device(uuid(dev); mig)
    x = CUDA.NVML.name(nvml_dev)
    (; total, free, used) = CUDA.NVML.memory_info(nvml_dev)

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
    for dev in CUDA.devices()
        push!(plts, _plot_gpu_memory_utilization(dev))
    end
    plts
end

end # module TerminalSystemMonitorCUDAExt
