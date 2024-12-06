module TerminalSystemMonitor

using Dates: Dates, Day, DateTime, Second
using UnicodePlots
import Term # this is required by UnicodePlots.panel
using MLDataDevices: MLDataDevices, CUDADevice

# These function will be defined in Package extensions
function plot_gpu_utilization_rates end
function plot_gpu_memory_utilization end

idle_time(info::Sys.CPUinfo) = Int64(info.cpu_times!idle)

busy_time(info::Sys.CPUinfo) = Int64(
    info.cpu_times!user + info.cpu_times!nice + info.cpu_times!sys + info.cpu_times!irq,
)

"""
    get_cpu_percent(period)

CPU usage between 0.0 and 100 [percent]

The idea is borrowed from https://discourse.julialang.org/t/get-cpu-usage/24468/7

Thank you @fonsp.
"""
function get_cpu_percent(period::Real = 1.0)

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

function extract_number_and_unit(str::AbstractString)
    m = match(r"(\d+\.\d+)\s*(\w+)", str)
    if !isnothing(m)
        return parse(Float64, m.captures[1]::SubString), m.captures[2]::SubString
    else
        return nothing, nothing
    end
end

function plot_cpu_utilization_rates()
    ys = get_cpu_percent()
    npad = 1 + floor(Int, log10(length(ys)))
    xs = ["id: $(lpad(i-1, npad))" for (i, _) in enumerate(ys)]

    ncpus = length(ys)
    ys = round.(ys, digits = 1)

    plts = []

    chunks = collect.(collect(Iterators.partition((1:ncpus), 4)))
    for c in chunks
        push!(plts, barplot(xs[c], ys[c], maximum = 100, width = 15, height = length(c)))
    end
    return plts
end

function plot_cpu_memory_utilization()
    memorytotal, memorytotal_unit =
        Sys.total_memory() |> Base.format_bytes |> extract_number_and_unit
    memoryfree, _ = Sys.free_memory() |> Base.format_bytes |> extract_number_and_unit
    if isnothing(memorytotal) || isnothing(memoryfree)
        return []
    end
    memoryusage = memorytotal - memoryfree
    memorytotal = round(memorytotal)

    seconds = floor(Int, Sys.uptime())
    datetime = DateTime(1970) + Second(seconds)

    plts = []
    push!(
        plts,
        barplot(
            ["Mem: "],
            [memoryusage],
            xlabel = join(
                [
                    "Load average: " *
                    join(string.(round.(Sys.loadavg(), digits = 2)), ' '),
                    # Adds spaces for better styling
                    "      Uptime: $(max(Day(0), Day(datetime)-Day(1))), $(Dates.format(datetime, "HH:MM:SS"))",
                ],
                '\n',
            ),
            # Adds a space for better styling
            name = " $(memorytotal) $(memorytotal_unit)",
            maximum = memorytotal,
            width = 30,
        ),
    )

end

function main(dummyargs...)
    hidecursor()

    while true
        try
            plts = []
            append!(plts, plot_cpu_utilization_rates())
            _, cols = displaysize(stdout)
            n = max(1, cols ÷ 25)
            chunks = collect(Iterators.partition(plts, n))
            f = foldl(/, map(c -> prod(UnicodePlots.panel.(c)), chunks))

            f /= prod(UnicodePlots.panel.(plot_cpu_memory_utilization()))

            if isdefined(Main, :CUDA) &&
               getproperty(getproperty(Main, :CUDA), :functional)()
                cudaplts = []
                n = max(1, cols ÷ 50)
                plts1 = plot_gpu_utilization_rates(MLDataDevices.CUDADevice)::Vector{Any}
                plts2 = plot_gpu_memory_utilization(MLDataDevices.CUDADevice)::Vector{Any}
                for i in eachindex(plts1, plts2)
                    push!(cudaplts, plts1[i])
                    push!(cudaplts, plts2[i])
                end
                gpuchunks = collect(Iterators.partition(cudaplts, n))
                f /= foldl(/, map(c -> prod(UnicodePlots.panel.(c)), gpuchunks))
            end
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
