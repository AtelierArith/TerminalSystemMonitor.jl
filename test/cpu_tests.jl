@testitem "CPU monitor smoke tests" begin
    using Test
    using TerminalSystemMonitor

    TSM = TerminalSystemMonitor
    @test TSM.extract_number_and_unit("12.5 GiB") == (12.5, "GiB")
    @test TSM.extract_number_and_unit("not a size") == (nothing, nothing)
    @test TSM._relu(-1.0) == 0.0
    @test TSM._relu(2.0) == 2.0

    # Exercise the CPU-only path without starting the interactive monitor loop.
    @test length(TSM.get_cpu_percent(0.1)) == length(Sys.cpu_info())
    @test length(TSM.plot_cpu_utilization_rates(TSM.CPUDevice, TSM.mean)) == 1
    @test !isempty(TSM.plot_cpu_memory_utilization(TSM.CPUDevice))
end
