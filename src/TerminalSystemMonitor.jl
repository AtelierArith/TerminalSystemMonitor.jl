module TerminalSystemMonitor

using UnicodePlots
using Term # this is required by UnicodePlots.panel

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
    print(Core.stdout, buf |> take! |> String)
end

function clearlines(H::Integer)
    for i = 1:H
        clearline(move_up = true)
    end
end

function hidecursor()
    print(Core.stdout, "\x1b[?25l") # hidecursor
end

function unhidecursor()
    print(Core.stdout, "\u001B[?25h") # unhide cursor
end

function layout(x, y)
    ncpus = length(y)
    y = round.(y, digits = 1)
    (_, cols) = displaysize()

    chunks = collect.(collect(Iterators.partition((1:ncpus), 4)))

    plts = map(chunks) do c
        barplot(x[c], y[c], maximum = 100, width = max(5, 15), height = length(c))
    end

    memoryusage = round((Sys.total_memory() - Sys.free_memory()) / 2^20 / 1000, digits = 1)

    push!(
        plts,
        barplot(
            ["Mem: "],
            [memoryusage],
            maximum = Sys.total_memory() / 2^20 / 1000,
            width = max(5, 15),
        ),
    )

    n = max(1, cols ÷ 25)
    chunks = collect(Iterators.partition(plts, n))

    #=
    #panels = map(chunks) do chunk
        #p = Panel(fit=false)
        #for c in chunk
        #    p = p * UnicodePlots.panel(c)
        #end
        #
        #prod(UnicodePlots.panel(c) for c in chunk)
        #p
    #end
    =#
    #return UnicodePlots.panel(plts[1])
    return plts
    #return "GOMAGOMA"
    # return foldl(/, panels)
end


function main()
    hidecursor()
    while true
        try
            y = cpu_percent()
            x = ["id: $(i-1)" for (i, _) in enumerate(y)]
            plts = layout(x, y)
            str = join([Base.string(p; color = true) for p in plts], '\n')
            clearlines(2 + length(collect(eachmatch(r"\n", str))))
            println(Core.stdout, str)
        catch e
            unhidecursor() # unhide cursor
            if e isa InterruptException
                # @info "Intrrupted"
                break
            else
                # @warn "Got Exception"
                rethrow(e) # so we don't swallow true exceptions
            end
        end
    end
    # @info "Unhide cursor"
    unhidecursor() # unhide cursor
end

end # module TerminalSystemMonitor
