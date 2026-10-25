@testitem "CPU data can be unavailable" begin
    using Test
    using Statistics: mean
    using TerminalSystemMonitor: cpu_plots

    @test isempty(cpu_plots(Float64[]))
    @test isempty(cpu_plots(Float64[], mean))
end

@testitem "Layout measures panels instead of assuming widths" begin
    using Test
    using Term: RenderableText
    using TerminalSystemMonitor: layout_panels, panel_width

    panels = [RenderableText("a"^20), RenderableText("b"^20)]
    stacked = layout_panels(panels, 30)
    @test panel_width(stacked) == 20
    @test length(split(string(stacked), '\n')) == 2
    @test panel_width(layout_panels(panels, 50)) == 40
    @test layout_panels([], 80) === nothing
end

@testitem "Fit before emitting the first frame" begin
    using Test
    using Statistics: mean
    using TerminalSystemMonitor: fit_frame

    calls = Any[]
    renderer = (cols, statfn) -> begin
        push!(calls, statfn)
        statfn === identity ? "1\n2\n3\n4" : "compact"
    end
    frame, statfn = fit_frame(renderer, 2, 80, identity)
    @test frame == "compact"
    @test statfn === mean
    @test calls == [identity, mean]
    emptyframe, _ = fit_frame((cols, fn) -> nothing, 2, 80, identity)
    @test emptyframe === nothing
end

@testitem "Viewport bounds include ANSI and Unicode" begin
    using Test
    using Term: remove_ansi
    using TerminalSystemMonitor: viewport

    text = "\e[31m赤色abc\e[0m\nsecond\nthird\nfourth"
    for rows in (1, 2, 3, 10), cols in (2, 5, 8, 80)
        rendered = viewport(text, rows, cols)
        lines = split(remove_ansi(rendered), '\n')
        @test length(lines) <= rows
        @test all(line -> textwidth(line) < cols, lines)
        @test !endswith(rendered, '\n')
    end
    @test occursin("more lines", remove_ansi(viewport(text, 2, 80)))
    @test viewport(text, 0, 80) == ""
    @test viewport(text, 10, 1) == ""
    @test remove_ansi(viewport("e\u0301x", 1, 2)) == "e\u0301"
end

@testitem "Terminal output bypasses global display backends" begin
    using Test
    using TerminalSystemMonitor: main

    struct UnexpectedDisplay <: AbstractDisplay end
    Base.display(::UnexpectedDisplay, x) = error("must write to the requested IO")
    display = UnexpectedDisplay()
    pushdisplay(display)
    try
        io = IOBuffer()
        @test main(; io, frames=2, renderer=(cols, fn) -> "frame") === nothing
        output = String(take!(io))
        @test length(findall("frame", output)) == 2
        @test startswith(output, "\e[?1049h\e[?25l")
        @test endswith(output, "\e[?25h\e[?1049l")
        @test_throws ArgumentError main(; frames=-1)
    finally
        popdisplay(display)
    end
end

@testitem "Backend panels share one device and metrics snapshot" begin
    using Test
    using TerminalSystemMonitor: paired_device_plots, shared_metric_plots

    # A consumable iterator exposes accidental enumeration for each metric.
    devices = Iterators.Stateful([:first, :second])
    plots = paired_device_plots(devices, (i, dev) -> (i, dev), dev -> dev)
    @test plots == Any[(0, :first), :first, (1, :second), :second]
    @test isempty(devices)
    @test isempty(paired_device_plots([], identity, identity))

    samples = Ref(0)
    sample = () -> (samples[] += 1; Ref(samples[]))
    plots = shared_metric_plots(sample, x -> Any[x], x -> Any[x])
    @test samples[] == 1
    @test plots[1] === plots[2]
end
