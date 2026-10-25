@testitem "Tabs and terminal commands in frame content" begin
    using Test
    using TerminalSystemMonitor: viewport, sanitize_terminal, display_width
    using Term: remove_ansi

    @test remove_ansi(viewport("a\tb", 1, 11)) == "a       b"
    @test remove_ansi(viewport("a\tb", 1, 5)) == "a   "
    @test display_width("a\tb") == 9
    @test !occursin('\t', viewport("a\tb", 1, 5))
    @test sanitize_terminal("before\e[2Jafter\e[?1049l") == "beforeafter"
    @test sanitize_terminal("a\e]52;c;secret\ab") == "ab"
    @test sanitize_terminal("a\e]0;title\e\\b") == "ab"
    @test sanitize_terminal("a\ePpayload\e\\b") == "ab"
    @test sanitize_terminal("abc\rZ\a\u009b2J") == "abcZ2J"
    @test sanitize_terminal("\e[31mred\e[0m") == "\e[31mred\e[0m"
    @test sanitize_terminal("text\e[31") == "text"
    @test sanitize_terminal("\e\0[2Jtext") == "text"
end

@testitem "Emoji occupy terminal cells as grapheme clusters" begin
    using Test
    using TerminalSystemMonitor: grapheme_width, display_width, viewport
    using Term: remove_ansi

    for emoji in ("❤️", "👩‍💻", "👍🏽", "1️⃣", "🇯🇵")
        @test grapheme_width(emoji) == 2
        @test display_width(emoji * emoji) == 4
        @test remove_ansi(viewport(emoji * emoji, 1, 3)) == emoji
    end
    @test grapheme_width("e\u0301") == 1
    @test grapheme_width("赤") == 2
end

@testitem "Multiline styles survive cropping" begin
    using Test
    using TerminalSystemMonitor: viewport

    @test viewport("\e[31mred\nred", 2, 20) == "\e[31mred\e[0m\n\e[31mred\e[0m"
    text = "\e[31mabcdef\e[0m\e[32mhidden\nnext"
    rendered = viewport(text, 2, 4)
    @test rendered == "\e[31mabc\e[0m\n\e[32mnex\e[0m"
    @test viewport("\e[31ma\e[0m\nb", 2, 20) == "\e[31ma\e[0m\e[0m\nb\e[0m"
end

@testitem "Cleanup preserves the primary error and attempts every action" begin
    using Test
    using TerminalSystemMonitor: with_cleanup, main

    original = ErrorException("render failed")
    cleanup = ErrorException("cleanup failed")
    failure = try
        with_cleanup(() -> throw(original), () -> throw(cleanup))
    catch e
        e
    end
    @test failure isa CompositeException
    @test failure.exceptions == [original, cleanup]

    struct FailingRestoreIO <: IO
        data::IOBuffer
    end
    Base.displaysize(::FailingRestoreIO) = (24, 80)
    Base.flush(io::FailingRestoreIO) = flush(io.data)
    Base.write(io::FailingRestoreIO, data::String) =
        data == "\e[?25h" ? error("show cursor failed") : write(io.data, data)
    io = FailingRestoreIO(IOBuffer())
    failure = try
        main(; io, renderer=(cols, fn) -> throw(original))
    catch e
        e
    end
    @test failure isa CompositeException
    @test failure.exceptions[1] === original
    @test occursin("\e[?1049l", String(take!(io.data)))
end

@testitem "Compact mode retries after CPU topology changes" begin
    using Test
    using Statistics: mean
    using TerminalSystemMonitor: main, layout_statfn

    @test layout_statfn(mean, (24, 80, 32), (24, 80, 32)) === mean
    @test layout_statfn(mean, (24, 80, 32), (24, 80, 2)) === identity
    count = Ref(32)
    calls = Any[]
    renderer = (cols, fn) -> begin
        push!(calls, fn)
        if fn === mean
            count[] = 2
            "compact"
        else
            count[] == 32 ? join(1:25, '\n') : "CPU 0\nCPU 1"
        end
    end
    io = IOBuffer()
    @test main(; io, frames=2, renderer, cpu_count=() -> count[]) === nothing
    @test calls == [identity, mean, identity]
    @test occursin("CPU 1", String(take!(io)))
end

@testitem "Sampler resources close on every exit path" begin
    using Test
    using TerminalSystemMonitor: with_resource
    using TerminalSystemMonitor

    closed = Ref(0)
    resource = Ref(:sampler)
    release = x -> (closed[] += 1)
    @test with_resource(identity, () -> resource, release) === resource
    @test closed[] == 1
    @test_throws ErrorException with_resource(x -> error("sampling failed"), () -> resource, release)
    @test closed[] == 2
    @test_throws InterruptException with_resource(x -> throw(InterruptException()), () -> resource, release)
    @test closed[] == 3

    # Exercise the registered 0.1.0 ownership layout without calling native APIs.
    include(joinpath(pkgdir(TerminalSystemMonitor), "ext", "TerminalSystemMonitorMacOSIOReportExt", "sampler_lifecycle.jl"))
    mutable struct LegacyReport
        prev::Union{Nothing,Tuple{Ptr{Cvoid},Nothing}}
        chan::Ptr{Cvoid}
        subs::Ptr{Cvoid}
    end
    report = LegacyReport((Ptr{Cvoid}(1), nothing), Ptr{Cvoid}(2), Ptr{Cvoid}(3))
    released = Ptr{Cvoid}[]
    close_sampler((ior=report,); release=p -> push!(released, p))
    @test released == Ptr{Cvoid}.([1, 2, 3])
    @test report.prev === nothing
    @test report.chan == report.subs == C_NULL
    close_sampler((ior=report,); release=p -> push!(released, p))
    @test length(released) == 3
    empty!(released)
    interrupted = LegacyReport((C_NULL, nothing), Ptr{Cvoid}(4), Ptr{Cvoid}(5))
    close_sampler((ior=interrupted,); release=p -> push!(released, p))
    @test released == Ptr{Cvoid}.([4, 5])

    struct ModernSampler
        closed::Base.RefValue{Bool}
    end
    Base.close(sampler::ModernSampler) = (sampler.closed[] = true)
    modern = ModernSampler(Ref(false))
    close_sampler(modern; release=p -> error("must use the native close API"))
    @test modern.closed[]
end
