module TerminalSystemMonitorCUDAExt

using CUDA
using UnicodePlots: barplot
import TerminalSystemMonitor
using TerminalSystemMonitor: extract_number_and_unit

"""
 Device 0 [NVIDIA GeForce GTX 1080 Ti] PCIe GEN 1@16x RX: 0.000 KiB/s TX: 0.000 KiB/s
 GPU 139MHz  MEM 405MHz  TEMP  39°C FAN   0% POW  11 / 280 W
 GPU[                                  0%] MEM[                     0.096Gi/11.000Gi]

 Device 1 [NVIDIA GeForce GTX 1080 Ti] PCIe GEN 1@16x RX: 0.000 KiB/s TX: 0.000 KiB/s
 GPU 139MHz  MEM 405MHz  TEMP  36°C FAN   0% POW   9 / 280 W
 GPU[                                  0%] MEM[                     0.107Gi/11.000Gi]
   ┌──────────────────────────────────────────────────────────────────────────────────┐
100│GPU0 %                                                                            │
   │GPU0 mem%                                                                         │
   │                                                                                  │
 75│                                                                                  │
   │                                                                                  │
   │                                                                                  │
 50│                                                                                  │
   │                                                                                  │
   │                                                                                  │
 25│                                                                                  │
   │                                                                                  │
   │                                                                                  │
  0│──────────────────────────────────────────────────────────────────────────────────│
   └41s────────────────30s──────────────────20s─────────────────10s─────────────────0s┘
   ┌──────────────────────────────────────────────────────────────────────────────────┐
100│GPU1 %                                                                            │
   │GPU1 mem%                                                                         │
   │                                                                                  │
 75│                                                                                  │
   │                                                                                  │
   │                                                                                  │
 50│                                                                                  │
   │                                                                                  │
   │                                                                                  │
 25│                                                                                  │
   │                                                                                  │
   │                                                                                  │
  0│──────────────────────────────────────────────────────────────────────────────────│
   └41s────────────────30s──────────────────20s─────────────────10s─────────────────0s┘
"""

function TerminalSystemMonitor.plot_gpu_utilization_rates(dev::CUDA.CuDevice)
    mig = uuid(dev) != parent_uuid(dev)
    nvml_dev = CUDA.NVML.Device(uuid(dev); mig)
    x = CUDA.NVML.name(nvml_dev)
    y = CUDA.NVML.utilization_rates(nvml_dev).compute # percent
    return barplot([x], [y], maximum = 100, width = max(5, 15))
end

function TerminalSystemMonitor.plot_gpu_utilization_rates(::Type{MLDataDevices.CUDADevice})
    plts = []
    for dev in CUDA.devices()
        push!(plts, _plot_gpu_utilization_rates(dev))
    end
    return plts
end

function TerminalSystemMonitor.plot_gpu_memory_utilization(dev::CUDA.CuDevice)
    device_name = CUDA.name(dev)
    mig = uuid(dev) != parent_uuid(dev)
    nvml_gpu = CUDA.NVML.Device(parent_uuid(dev))
    nvml_dev = CUDA.NVML.Device(uuid(dev); mig)
    x = CUDA.NVML.name(nvml_dev)
    device_capability = CUDA.NVML.compute_capability(nvml_dev)
    #@show CUDA.NVML.power_usage(nvml_dev) # watt
    y = CUDA.NVML.utilization_rates(nvml_dev).compute # percent
    #@show CUDA.NVML.temperature(nvml_dev)
    (; total, free, used) = CUDA.NVML.memory_info(nvml_dev)

    memorytot, memorytotal_unit = eextract_number_and_unit(Base.format_bytes(total))
    memoryusage, memoryusage_unit = eextract_number_and_unit(Base.format_bytes(used))

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
        name = " $(memorytot) $(memoryunit)",
        maximum = memorytot,
        width = max(5, 15),
    )
end

function TerminalSystemMonitor.plot_gpu_memory_utilization(::Type{MLDataDevices.CUDADevice})
    plts = []
    for dev in CUDA.devices()
        push!(plts, _plot_gpu_memory_utilization(dev))
    end
    plts
end

end # module TerminalSystemMonitorCUDAExt
