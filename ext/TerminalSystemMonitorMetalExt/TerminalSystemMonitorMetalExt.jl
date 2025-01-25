module TerminalSystemMonitorMetalExt

using Metal
using MLDataDevices: MetalDevice
using UnicodePlots: barplot
import TerminalSystemMonitor
using MacOSIOReport: Sampler, get_metrics
using TerminalSystemMonitor: extract_number_and_unit

function _plot_cpu_utilization_rates(id, usage)
    x = string(id)
    y = usage
    return barplot([x], [y], maximum = 100, width = 15)
end

function TerminalSystemMonitor.plot_cpu_utilization_rates(::Type{MetalDevice})
    sampler = Sampler()
    msec = UInt(1000)
    m = get_metrics(sampler, msec)
    cpu_ids = ["E-CPU: ", "P-CPU: "]
    usages = [
        round(100 * m.ecpu_usage[2], digits = 1),
        round(100 * m.pcpu_usage[2], digits = 1),
    ]
    return Any[barplot(cpu_ids, usages, maximum = 100, width = 15)]
end

function TerminalSystemMonitor.plot_gpu_utilization_rates(::Type{MetalDevice})
    sampler = Sampler()
    msec = UInt(1000)
    m = get_metrics(sampler, msec)
    gpu_usages = [
        ("GPU: ", round(100 * m.gpu_usage[2], digits = 1)),
    ]
    plts = []
    for (id, usage) in gpu_usages
        push!(plts, _plot_cpu_utilization_rates(id, usage))
    end
    return plts
end

end # module TerminalSystemMonitorCUDAExt