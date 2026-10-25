module TerminalSystemMonitorMacOSIOReportExt

using MLDataDevices: MetalDevice
using UnicodePlots: barplot
import TerminalSystemMonitor
using MacOSIOReport: Sampler, get_metrics, MTLDevice
import MacOSIOReport
include("sampler_lifecycle.jl")

TerminalSystemMonitor.gpu_available(::Type{MetalDevice}) =
    Sys.isapple() && Sys.ARCH == :aarch64

function _plot_cpu_utilization_rates(id, usage)
    x = string(id)
    y = usage
    return barplot([x], [y], maximum = 100, width = 15)
end

function TerminalSystemMonitor.plot_cpu_utilization_rates(::Type{MetalDevice})
    return sample_with_sampler(cpu_plots)
end

function cpu_plots(m)
    cpu_ids = ["E-CPU: ", "P-CPU: "]
    usages = [
        round(100 * m.ecpu_usage[2], digits = 1),
        round(100 * m.pcpu_usage[2], digits = 1),
    ]
    return Any[barplot(cpu_ids, usages, maximum = 100, width = 15)]
end

function TerminalSystemMonitor.plot_gpu_utilization_rates(::Type{MetalDevice})
    return sample_with_sampler(gpu_plots)
end

function gpu_plots(m)
    plts = []
    chip_name = String(MTLDevice(1).name)
    push!(
        plts, barplot(["GPU: "], [round(100 * m.gpu_usage[2], digits = 1)], xlabel=chip_name, maximum=100, width=15)
    )
    return plts
end

function sample_with_sampler(plot)
    return TerminalSystemMonitor.with_resource(Sampler, close_sampler) do sampler
        plot(get_metrics(sampler, UInt(500)))
    end
end

function TerminalSystemMonitor.backend_plots(::Type{MetalDevice})
    return sample_with_sampler() do metrics
        TerminalSystemMonitor.shared_metric_plots(() -> metrics, cpu_plots, gpu_plots)
    end
end

end # module TerminalSystemMonitorMacOSIOReportExt
