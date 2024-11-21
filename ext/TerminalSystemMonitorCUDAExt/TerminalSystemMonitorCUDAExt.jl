module TerminalSystemMonitorCUDAExt

using CUDA
using MLDataDevices: CUDADevice
using UnicodePlots: barplot
import TerminalSystemMonitor
using TerminalSystemMonitor: extract_number_and_unit

function _plot_gpu_utilization_rates(gpu_id, dev::CUDA.CuDevice)
    mig = uuid(dev) != parent_uuid(dev)
    nvml_dev = CUDA.NVML.Device(uuid(dev); mig)
    x = string(gpu_id)
    y = 100 * CUDA.NVML.utilization_rates(nvml_dev).compute
    return barplot([x], [y], maximum = 100, width = max(5, 15))
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

    memorytotal, memorytotal_unit = extract_number_and_unit(Base.format_bytes(total))
    memoryusage, memoryusage_unit = extract_number_and_unit(Base.format_bytes(used))

    if memorytotal_unit == "GiB"
        # convert to MB
        memorytotal = memorytotal * 1024
        memorytotal_unit = "MiB"
    end

    if memoryusage_unit == "GiB"
        # convert to MB
        memoryusage = memoryusage * 1024
        memoryusage_unit = "MiB"
    end

    return barplot(
        ["GPU Mem: "],
        [memoryusage],
        xlabel = device_name,
        # Adds a space for better styling
        name = " $(memorytotal) $(memorytotal_unit)",
        maximum = memorytotal,
        width = max(5, 15),
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
