@testitem "CPU monitoring smoke test" begin
    using Test
    using TerminalSystemMonitor
    using TerminalSystemMonitor: CPUDevice, get_cpu_percent,
        plot_cpu_utilization_rates, plot_cpu_memory_utilization
    using Statistics: mean

    rates = get_cpu_percent(0.1)
    @test length(rates) == length(Sys.cpu_info())
    @test all(isfinite, rates)
    @test all(x -> 0 <= x <= 100, rates)

    # Exercise both layouts used by the monitor without entering its infinite loop.
    for statfn in (identity, mean)
        plots = plot_cpu_utilization_rates(CPUDevice, statfn)
        @test length(plots) == (statfn === mean ? 1 : cld(length(rates), 4))
        @test all(p -> !isempty(string(p)), plots)
    end
    plots = plot_cpu_memory_utilization(CPUDevice)
    @test length(plots) == 1
    @test occursin("Mem:", string(only(plots)))
end

@testitem "Uptime across month boundaries" begin
    using Test
    using TerminalSystemMonitor: format_uptime

    @test format_uptime(0) == "0 days, 00:00:00"
    @test format_uptime(31 * 86400 + 3661) == "31 days, 01:01:01"
    @test format_uptime(365 * 86400) == "365 days, 00:00:00"
end
