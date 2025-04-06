module TerminalSystemMonitorGUIExt

# This extension module allows us to load GUI-related packages only when needed
# No need to force QML and Observables on all users

using QML
using Observables
# import TerminalSystemMonitor: monitorGUI
using TerminalSystemMonitor
using Dates: Dates, DateTime, Second

function monitorGUI()
    cpu_data = Observable(Float64[])
    cpu_count = Observable(0)
    memory_total = Observable(0.0)
    memory_used = Observable(0.0)
    memory_unit = Observable("GiB")
    load_average = Observable([0.0, 0.0, 0.0])
    uptime_str = Observable("")

    memory_total[], memory_unit[] =
        Sys.total_memory() |> Base.format_bytes |> TerminalSystemMonitor.extract_number_and_unit

    seconds = floor(Int, Sys.uptime())
    days = floor(Int, seconds / 86400)
    hours = floor(Int, (seconds % 86400) / 3600)
    minutes = floor(Int, (seconds % 3600) / 60)
    sec = seconds % 60
    uptime_str[] = string(days, " days, ", lpad(hours, 2, '0'), ":", lpad(minutes, 2, '0'), ":", lpad(sec, 2, '0'))

    get_mean_cpu_percent() = sum(TerminalSystemMonitor.get_cpu_percent(0.5)) / Sys.CPU_THREADS

    function get_memory_used()
        memoryfree, _ =
            Sys.free_memory() |> Base.format_bytes |> TerminalSystemMonitor.extract_number_and_unit
        return Float64(memory_total[] - memoryfree)
    end

    @qmlfunction get_memory_used get_mean_cpu_percent

    loadqml(joinpath(@__DIR__, "qml", "main.qml"),
        system_data=JuliaPropertyMap(
            # CPU
            "cpuUtilization" => cpu_data,
            "cpuCount" => cpu_count,
            # momery
            "memoryTotal" => memory_total,
            "memoryUsed" => memory_used,
            "memoryUnit" => memory_unit,
            # sysinfo
            "loadAverage" => load_average,
            "uptime" => uptime_str
        )
    )

    exec()
end

export monitorGUI

end # module TerminalSystemMonitorGUIExt
