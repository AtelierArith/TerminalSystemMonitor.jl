module TerminalSystemMonitor

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

# Extensions opt in when their backend is available, regardless of which module
# imported the optional package.
gpu_available(::Type) = false

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
    isfinite(period) && period >= 0 ||
        throw(ArgumentError("sampling period must be finite and nonnegative"))

    info = Sys.cpu_info()
    busies = busy_time.(info)
    idles = idle_time.(info)

    sleep(period)

    info = Sys.cpu_info()
    cpu_percentages(busies, idles, busy_time.(info), idle_time.(info))
end

function cpu_percentages(busies, idles, nextbusies, nextidles)
    # CPU hotplug can change the number of counters between snapshots.
    length(busies) == length(nextbusies) || return zeros(length(nextbusies))
    return cpu_percent.(nextbusies .- busies, nextidles .- idles)
end

function cpu_percent(busy::Real, idle::Real)
    # Counters may not advance in a short interval, or may reset. Neither case
    # should send NaN/Inf or a negative percentage into the plotting library.
    busy = max(busy, zero(busy))
    idle = max(idle, zero(idle))
    total = busy + idle
    return iszero(total) ? 0.0 : 100 * (busy / total)
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

_relu(x) = max(x, zero(x))

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
    # Sometimes `ys`` can be negative, so we need to use relu function so that
    # it ensures elements in `ys`` are positive.
    ys = round.(_relu.(ys), digits = 1)

    plts = []

    chunks = collect.(collect(Iterators.partition((1:ncpus), 4)))
    for c in chunks
        push!(plts, barplot(xs[c], ys[c], maximum = 100, width = 15, height = length(c)))
    end
    return plts
end

function plot_cpu_memory_utilization(::Type{CPUDevice})
    # Keep calculations in one unit; formatting free and total independently
    # can produce MiB and GiB values that cannot be subtracted directly.
    total_bytes = Sys.total_memory()
    memorytotal = total_bytes / 2.0^30
    memorytotal_unit = "GiB"
    memoryusage = _relu(Int128(total_bytes) - Int128(Sys.free_memory())) / 2.0^30

    seconds = floor(Int, Sys.uptime())
    uptime = format_uptime(seconds)

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
                    "      Uptime: $(uptime)",
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

function format_uptime(seconds::Integer)
    days, remaining = divrem(seconds, 86400)
    hours, remaining = divrem(remaining, 3600)
    minutes, secs = divrem(remaining, 60)
    return "$(days) days, $(lpad(hours, 2, '0')):$(lpad(minutes, 2, '0')):$(lpad(secs, 2, '0'))"
end

function cpu_frame(cols, statfn)
    plts = plot_cpu_utilization_rates(CPUDevice, statfn)
    n = max(1, cols ÷ 25)
    chunks = Iterators.partition(plts, n)
    f = foldl(/, (prod(UnicodePlots.panel.(c)) for c in chunks))
    return f / prod(UnicodePlots.panel.(plot_cpu_memory_utilization(CPUDevice)))
end

function interruptible(f)
    try
        return f()
    catch e
        e isa InterruptException && return nothing
        rethrow()
    end
end

function sample_plots(functions...)
    tasks = Task[]
    @sync begin
        for f in functions
            push!(tasks, @async interruptible(f))
        end
    end
    return Tuple(fetch.(tasks))
end

function render_frame(cols, statfn)
    cpu = () -> cpu_frame(cols, statfn)
    if gpu_available(CUDADevice)
        frame, usages, memories = sample_plots(
            cpu,
            () -> plot_gpu_utilization_rates(CUDADevice),
            () -> plot_gpu_memory_utilization(CUDADevice),
        )
        any(isnothing, (frame, usages, memories)) && return nothing
        plots = Any[]
        for i in eachindex(usages, memories)
            push!(plots, usages[i], memories[i])
        end
    elseif gpu_available(MetalDevice)
        frame, clusters, gpu = sample_plots(
            cpu,
            () -> plot_cpu_utilization_rates(MetalDevice),
            () -> plot_gpu_utilization_rates(MetalDevice),
        )
        any(isnothing, (frame, clusters, gpu)) && return nothing
        plots = vcat(clusters, gpu)
    else
        return only(sample_plots(cpu))
    end
    if !isempty(plots)
        chunks = Iterators.partition(plots, max(1, cols ÷ 50))
        frame /= foldl(/, (prod(UnicodePlots.panel.(c)) for c in chunks))
    end
    return frame
end

function next_cpu_statfn(statfn, height, rows)
    height > rows && return mean
    # A compact frame fitting the terminal does not prove the full frame will fit.
    # Retry the full layout only when the terminal grows or changes shape.
    return statfn
end

function main(dummyargs...)
    try
        Consoles.hide_cursor()
        statfn = identity
        previous_size = displaysize(stdout)
        while true
            rows, cols = displaysize(stdout)
            resized = (rows, cols) != previous_size
            if resized
                statfn = identity
            end
            previous_size = (rows, cols)
            frame = render_frame(cols, statfn)
            isnothing(frame) && break
            height = length(split(string(frame), '\n'))
            statfn = next_cpu_statfn(statfn, height, rows)
            Consoles.move_to_line(stdout, 1)
            Consoles.cleartoend(stdout)
            display(frame)
        end
    catch e
        e isa InterruptException && return nothing
        rethrow()
    finally
        Consoles.show_cursor()
    end
end

function monitor(args...)
    main(args...)
end

end # module TerminalSystemMonitor
