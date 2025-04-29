module TerminalSystemMonitor

using Dates: Dates, Day, DateTime, Second
using UnicodePlots
import Term # this is required by UnicodePlots.panel
using Term: Consoles
using Statistics: mean
using MLDataDevices: MLDataDevices, CUDADevice, CPUDevice, MetalDevice

export monitor # entrypoint from REPL

# These function will be defined in Package extensions
function plot_cpu_utilization_rates end
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

function plot_cpu_utilization_rates(::Type{CPUDevice})
    ys = get_cpu_percent()
    npad = 1 + floor(Int, log10(length(ys)))
    xs = ["id: $(lpad(i-1, npad))" for (i, _) in enumerate(ys)]
function plot_cpu_utilization_rates(::Type{CPUDevice}, statfn=identity)
    ys = statfn(get_cpu_percent())
    if !(ys isa AbstractVector)
        xs = ["CPU: " * string(statfn)]
        ys = [ys]
    else
        npad = 1 + floor(Int, log10(length(ys)))
        xs = ["id: $(lpad(i-1, npad))" for (i, _) in enumerate(ys)]
    end

    ncpus = length(ys)
    ys = round.(ys, digits = 1)

    plts = []

    chunks = collect.(collect(Iterators.partition((1:ncpus), 4)))
    for c in chunks
        push!(plts, barplot(xs[c], ys[c], maximum = 100, width = 15, height = length(c)))
    end
    return plts
end

function plot_cpu_memory_utilization(::Type{CPUDevice})
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
    # Control cursor hiding and showing with Term.Consoles
    Consoles.hide_cursor()

    statfn = identity
    while true
        try
            rows, cols = displaysize(stdout)
            t1 = @async begin
                try
                    plts = []
                    append!(plts, plot_cpu_utilization_rates(CPUDevice, statfn))
                    n = max(1, cols ÷ 25)
                    chunks = collect(Iterators.partition(plts, n))
                    f = foldl(/, map(c -> prod(UnicodePlots.panel.(c)), chunks))

                    f /= prod(UnicodePlots.panel.(plot_cpu_memory_utilization(CPUDevice)))
                    return f
                catch e
                    if e isa InterruptException
                        return nothing
                    else
                        rethrow(e)
                    end
                end
            end

            if isdefined(Main, :CUDA) &&
               getproperty(getproperty(Main, :CUDA), :functional)()
                wait(t1)
                f = fetch(t1)
                if isnothing(f)
                    break
                end
                cudaplts = []
                n = max(1, cols ÷ 50)
                plts1 = plot_gpu_utilization_rates(CUDADevice)::Vector{Any}
                plts2 = plot_gpu_memory_utilization(CUDADevice)::Vector{Any}
                for i in eachindex(plts1, plts2)
                    push!(cudaplts, plts1[i])
                    push!(cudaplts, plts2[i])
                end
                gpuchunks = collect(Iterators.partition(cudaplts, n))
                f /= foldl(/, map(c -> prod(UnicodePlots.panel.(c)), gpuchunks))
            elseif isdefined(Main, :MacOSIOReport) && Sys.isapple() && Sys.ARCH == :aarch64
                metalplts = []
                n = max(1, cols ÷ 50)
                t2 = @async begin
                    try
                        return plot_cpu_utilization_rates(MetalDevice)
                    catch e
                        if e isa InterruptException
                            return nothing
                        else
                            rethrow(e)
                        end
                    end
                end
                t3 = @async begin
                    try
                        return plot_gpu_utilization_rates(MetalDevice)
                    catch e
                        if e isa InterruptException
                            return nothing
                        else
                            rethrow(e)
                        end
                    end
                end
                wait(t1)
                wait(t2)
                wait(t3)
                plts1 = fetch(t2)
                plts2 = fetch(t3)
                if isnothing(plts1) || isnothing(plts2)
                    break
                end
                for i in eachindex(plts1)
                    push!(metalplts, plts1[i])
                end
                for i in eachindex(plts2)
                    push!(metalplts, plts2[i])
                end
                metalchunks = collect(Iterators.partition(metalplts, n))
                f /= foldl(/, map(c -> prod(UnicodePlots.panel.(c)), metalchunks))
            else
                wait(t1)
                f = fetch(t1)
                if isnothing(f)
                    break
                end
            end

            Consoles.move_to_line(stdout, 1)
            Consoles.cleartoend(stdout)
            # If user's machine has lots of CPU cores, we can't fit all the plots in one screen.
            # So we need to use `mean` function to reduce the number of plots.
            if length(split(string(f), "\n")) > rows
                statfn = mean
            end

            # If terminal has enough space, we can use `identity` function again to show all the plots.
            if  rows > 2length(split(string(f), "\n"))
                statfn = identity
            end
            display(f)
        catch e
            Consoles.show_cursor()
            @warn "Got Exception"
            rethrow(e) # so we don't swallow true exceptions
        end
    end
    Consoles.show_cursor()
end

function monitor(args...)
    main(args...)
end

end # module TerminalSystemMonitor
