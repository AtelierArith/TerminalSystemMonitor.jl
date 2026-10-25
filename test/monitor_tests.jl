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

@testitem "CPU counter edge cases" begin
    using Test
    using TerminalSystemMonitor: cpu_percent, cpu_percentages, get_cpu_percent

    @test cpu_percent(0, 0) === 0.0
    @test cpu_percent(1, 3) == 25.0
    @test cpu_percent(-1, 10) == 0.0
    @test cpu_percent(10, -1) == 100.0
    @test cpu_percent(-1, -1) == 0.0
    @test cpu_percentages([1], [3], [2], [6]) == [25.0]
    @test cpu_percentages([1], [3], [2, 3], [6, 7]) == [0.0, 0.0]
    @test cpu_percentages([1, 2], [3, 4], [2], [6]) == [0.0]
    @test all(isfinite, get_cpu_percent(0))
    for period in (-1, Inf, NaN)
        @test_throws ArgumentError get_cpu_percent(period)
    end
end

@testitem "Frame sampling joins tasks on failure" begin
    using Test
    using TerminalSystemMonitor: sample_plots

    finished = Ref(false)
    slow = () -> (sleep(0.05); finished[] = true; :ready)
    failing = () -> error("sampling failed")
    @test_throws CompositeException sample_plots(failing, slow)
    @test finished[]
    @test sample_plots(() -> 1, () -> 2) == (1, 2)
    @test sample_plots(() -> throw(InterruptException())) == (nothing,)
end

@testitem "Compact layout remains stable" begin
    using Test
    using Statistics: mean
    using TerminalSystemMonitor: fit_frame

    # A frame only one line too tall must collapse. A subsequent short frame
    # must not immediately restore the overflowing full layout.
    renderer = (cols, fn) -> fn === identity ? join(1:25, '\n') : join(1:8, '\n')
    _, fn = fit_frame(renderer, 24, 80, identity)
    @test fn === mean
    _, fn = fit_frame(renderer, 24, 80, fn)
    @test fn === mean
    _, fn = fit_frame((cols, fn) -> join(1:24, '\n'), 24, 80, identity)
    @test fn === identity
end

@testitem "Terminal restored after rendering failure and interrupt" begin
    using Test
    using TerminalSystemMonitor: main

    for exception in (ErrorException("render failed"), InterruptException())
        io = IOBuffer()
        renderer = (cols, statfn) -> throw(exception)
        if exception isa InterruptException
            @test main(; io, renderer) === nothing
        else
            @test_throws ErrorException main(; io, renderer)
        end
        output = String(take!(io))
        @test startswith(output, "\e[?1049h\e[?25l")
        @test endswith(output, "\e[?25h\e[?1049l")
    end
end

@testitem "Optional backends default to unavailable" begin
    using Test
    using TerminalSystemMonitor: gpu_available, CUDADevice, MetalDevice

    @test !gpu_available(CUDADevice)
    @test !gpu_available(MetalDevice)
end

@testitem "Uptime across month boundaries" begin
    using Test
    using TerminalSystemMonitor: format_uptime

    @test format_uptime(0) == "0 days, 00:00:00"
    @test format_uptime(31 * 86400 + 3661) == "31 days, 01:01:01"
    @test format_uptime(365 * 86400) == "365 days, 00:00:00"
end
