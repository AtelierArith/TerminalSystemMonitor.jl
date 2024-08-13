module TerminalSystemMonitor

#=
                              CPU Usage
          ┌                                               ┐
    id: 0 ┤■■■■■■■■■■ 23
    id: 1 ┤ 0
    id: 2 ┤■■■■■ 11.1111
    id: 3 ┤ 0
    id: 4 ┤■■ 5.05051
    id: 5 ┤ 0
    id: 6 ┤■ 3
    id: 7 ┤ 0
    id: 8 ┤ 1
    id: 9 ┤ 0
   id: 10 ┤ 0
   id: 11 ┤ 0
   id: 12 ┤ 0
   id: 13 ┤ 0
   id: 14 ┤ 0
   id: 15 ┤ 0
          └                                               ┘
=#

using UnicodePlots
using Term

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
function cpu_percent(period::Real=1.0)

    info = Sys.cpu_info()
    busies = busy_time.(info)
    idles = idle_time.(info)

    sleep(period)

    info = Sys.cpu_info()
    busies = busy_time.(info) .- busies
    idles = idle_time.(info) .- idles

    100 * busies ./ (idles .+ busies)
end

function clearline(; move_up::Bool=false)
    buf = IOBuffer()
    print(buf, "\x1b[2K") # clear line
    print(buf, "\x1b[999D") # rollback the cursor
    move_up && print(buf, "\x1b[1A") # move up
    print(buf |> take! |> String)
end

function clearlines(H::Integer)
    for i = 1:H
        clearline(move_up=true)
    end
end

function hidecursor()
    print("\x1b[?25l") # hidecursor
end

function unhidecursor()
    print("\u001B[?25h") # unhide cursor
end

function layout(x, y)
    ncpus = length(y)
    y = round.(y, digits=1)
    _, cols = displaysize(stdout)

    plts = []

    chunks = collect.(collect(Iterators.partition((1:ncpus), 4)))
    for c in chunks
        push!(
            plts,
            barplot(
                x[c], y[c],
                # title="CPU Usage",
                maximum=100, width=max(5, 15), height=length(c),
            )
        )
    end

    n = max(1, cols ÷ 25)
    chunks = collect(Iterators.partition(plts, n))

    foldl(/, map(c->prod(UnicodePlots.panel.(c)), chunks))

    chunks = collect(Iterators.partition(plts, n))

    canvas = foldl(/, map(c->prod(UnicodePlots.panel.(c)), chunks))

    memoryusage = round((Sys.total_memory() - Sys.free_memory()) / 2 ^ 20 / 1000, digits=1)

    canvas / UnicodePlots.panel(barplot(
        ["Mem: "], 
        [memoryusage],
        title="Memmory $(memoryusage)/$(floor(Sys.total_memory()/2^20 / 1000)) GB",
        maximum=Sys.total_memory()/2^20 / 1000, width=max(10, 40)
    ))
end


function main()
    hidecursor()
    while true
        try
            y = cpu_percent()
            x = ["id: $(i-1)" for (i, _) in enumerate(y)]
            (_, cols) = displaysize(stdout)

            # f = barplot(x, y, title="CPU Usage", maximum=100, width=max(10, cols - 15), height=length(y))
            f = layout(x, y)
            str = string(f)
            clearlines(2 + length(collect(eachmatch(r"\n", str))))
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
