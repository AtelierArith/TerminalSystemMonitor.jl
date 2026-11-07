@testitem "Buffered row updates preserve the visible screen" begin
    using Test
    using TerminalSystemMonitor: frame_update, viewport, main

    # A small terminal model: catch stale suffixes/rows and premature erasure.
    function apply_update!(screen, update)
        row, col = 1, 1
        for token in eachmatch(r"\e\[([0-9;]*)([HKJm])|[^\e]+", update)
            if isnothing(token[2])
                for c in token.match
                    screen[row, col] = c
                    col += 1
                end
            elseif token[2] == "H"
                args = isempty(token[1]) ? [1, 1] : parse.(Int, split(token[1], ';'))
                row, col = args
            elseif token[2] == "K"
                screen[row, col:end] .= ' '
            elseif token[2] == "J"
                screen[row, col:end] .= ' '
                screen[row+1:end, :] .= ' '
            end
        end
        return screen
    end

    screen = fill(' ', 4, 20)
    for text in ("long first\nsecond\nthird", "x\ny", "", "back")
        rendered = viewport(text, 4, 20)
        update = frame_update(rendered)
        apply_update!(screen, update)
        expected = fill(' ', 4, 20)
        for (row, line) in enumerate(split(text, '\n')), (col, c) in enumerate(line)
            expected[row, col] = c
        end
        @test screen == expected
        @test !occursin("\e[2J", update)
        if !isempty(text)
            @test findfirst(first(split(text, '\n')), update).start < findfirst("\e[J", update).start
        end
    end
    styled = viewport("\e[31m赤色\e[0m", 4, 20)
    @test occursin(styled, frame_update(styled))

    struct FrameRecordingIO <: IO
        writes::Vector{String}
    end
    Base.displaysize(::FrameRecordingIO) = (4, 20)
    Base.write(io::FrameRecordingIO, text::String) = (push!(io.writes, text); sizeof(text))
    Base.flush(::FrameRecordingIO) = nothing
    io = FrameRecordingIO(String[])
    main(; io, frames=2, renderer=(cols, fn) -> "visible")
    updates = filter(text -> occursin("visible", text), io.writes)
    @test length(updates) == 2
    @test all(text -> occursin("\e[1;1H\e[0mvisible", text), updates)
    @test all(text -> !occursin("\e[H\e[J", text), updates)
end
