module TerminalSystemMonitor

using Dates: Dates, Day, DateTime, Second
using UnicodePlots
import Term # this is required by UnicodePlots.panel

idle_time(info::Sys.CPUinfo) = Int64(info.cpu_times!idle)

busy_time(info::Sys.CPUinfo) = Int64(
    info.cpu_times!user + info.cpu_times!nice + info.cpu_times!sys + info.cpu_times!irq,
)

"""
    cpu_percent(period)

CPU usage between 0.0 and 100 [percent]
The idea is borrowed from https://discourse.julialang.org/t/get-cpu-usage/24468/7
Thank you @fonsp.
"""
function cpu_percent(period::Real = 1.0)

    info = Sys.cpu_info()
    busies = busy_time.(info)
    idles = idle_time.(info)

    sleep(period)

    info = Sys.cpu_info()
    busies = busy_time.(info) .- busies
    idles = idle_time.(info) .- idles

    100 * busies ./ (idles .+ busies)
end

function clearline(; move_up::Bool = false)
    buf = IOBuffer()
    print(buf, "\x1b[2K") # clear line
    print(buf, "\x1b[999D") # rollback the cursor
    move_up && print(buf, "\x1b[1A") # move up
    print(buf |> take! |> String)
end

function clearlines(H::Integer)
    for i = 1:H
        clearline(move_up = true)
    end
end

function clearlinesall()
    CSI = "\x1b["
    print("$(CSI)H$(CSI)2J")
end

function hidecursor()
    print("\x1b[?25l") # hidecursor
end

function unhidecursor()
    print("\u001B[?25h") # unhide cursor
end

function layout(x, y)
    ncpus = length(y)
    y = round.(y, digits = 1)
    _, cols = displaysize(stdout)

    plts = []

    chunks = collect.(collect(Iterators.partition((1:ncpus), 4)))
    for c in chunks
        push!(
            plts,
            barplot(x[c], y[c], maximum = 100, width = max(5, 15), height = length(c)),
        )
    end
    memoryusageGB = round((Sys.total_memory() - Sys.free_memory()) / 2^30, digits = 1)
    memorytotGB = Sys.total_memory() / 2 ^ 30
    (memorytot, memoryusage, memoryunit) = if memorytotGB ≤ 1.0
        1024memorytotGB, 1024memoryusageGB, "MB"
    else
        memorytotGB, memoryusageGB, "GB"
    end

    seconds = floor(Int, Sys.uptime())
    datetime = DateTime(1970) + Second(seconds)
    push!(
        plts,
        barplot(
            ["Mem: "],
            [memoryusage],
            title= join(
                [
                    "Load average: " * join(string.(round.(Sys.loadavg(), digits=2)),' '),
                    "     Uptime: $(max(Day(0), Day(datetime)-Day(1))), $(Dates.format(datetime, "HH:MM:SS"))",
                ],
                '\n',
            ),
            name="$(memorytot) $(memoryunit)",
            maximum = Sys.total_memory() / 2^30,
            width = max(5, 15),
        ),
    )

    n = max(1, cols ÷ 25)
    chunks = collect(Iterators.partition(plts, n))


    return foldl(/, map(c -> prod(UnicodePlots.panel.(c)), chunks))
end

function main(dummyargs...)
    hidecursor()

    while true
        try
            y = cpu_percent()
            x = ["id: $(i-1)" for (i, _) in enumerate(y)]
            (newrows, newcols) = displaysize(stdout)

            # f = barplot(x, y, title="CPU Usage", maximum=100, width=max(10, cols - 15), height=length(y))
            f = layout(x, y)
            str = string(f)
            newheight = 2 + length(collect(eachmatch(r"\n", str)))

            clearlinesall()

            display(f)
        catch e
            unhidecursor() # unhide cursor
            if e isa InterruptException
                @info "Intrrupted"
                break
            else
                @warn "Got Exception"
                rethrow(e) # so we don't swallow true exceptions
            end
        end
    end
    @info "Unhide cursor"
    unhidecursor() # unhide cursor
end

end # module TerminalSystemMonitor
