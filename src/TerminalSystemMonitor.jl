module TerminalSystemMonitor

using UnicodePlots
import Term # this is required by UnicodePlots.panel
using Term: Consoles
using Statistics: mean
using Unicode: graphemes
using MLDataDevices: MLDataDevices, CUDADevice, CPUDevice, MetalDevice

export monitor # entrypoint from REPL

# These function will be defined in Package extensions
function plot_cpu_utilization_rates end
function plot_gpu_utilization_rates end
function plot_gpu_memory_utilization end
function backend_plots end

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
    return cpu_plots(get_cpu_percent(), statfn)
end

function cpu_plots(rates, statfn=identity)
    isempty(rates) && return Any[]
    ys = statfn(rates)
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

panel_width(panel) = maximum(textwidth ∘ Term.remove_ansi, split(string(panel), '\n'); init=0)
as_panel(plot::UnicodePlots.Plot) = UnicodePlots.panel(plot)
as_panel(panel) = panel

function layout_panels(panels, cols)
    rows = Any[]
    row = nothing
    rowwidth = 0
    for panel in panels
        width = panel_width(panel)
        if !isnothing(row) && rowwidth + width > max(cols - 1, 0)
            push!(rows, row)
            row = nothing
            rowwidth = 0
        end
        row = isnothing(row) ? panel : row * panel
        rowwidth += width
    end
    isnothing(row) || push!(rows, row)
    return isempty(rows) ? nothing : foldl(/, rows)
end

function cpu_frame(cols, statfn)
    plots = plot_cpu_utilization_rates(CPUDevice, statfn)
    append!(plots, plot_cpu_memory_utilization(CPUDevice))
    return layout_panels(as_panel.(plots), cols)
end

function paired_device_plots(devices, utilization, memory)
    plots = Any[]
    for (index, device) in enumerate(devices)
        push!(plots, utilization(index - 1, device), memory(device))
    end
    return plots
end

function shared_metric_plots(sample, cpuplot, gpuplot)
    metrics = sample()
    return vcat(cpuplot(metrics), gpuplot(metrics))
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
    device = gpu_available(CUDADevice) ? CUDADevice :
             gpu_available(MetalDevice) ? MetalDevice : nothing
    isnothing(device) && return only(sample_plots(cpu))
    frame, plots = sample_plots(cpu, () -> backend_plots(device))
    any(isnothing, (frame, plots)) && return nothing
    gpu = layout_panels(as_panel.(plots), cols)
    return isnothing(gpu) ? frame : frame / gpu
end

function fit_frame(renderer, rows, cols, statfn)
    frame = renderer(cols, statfn)
    isnothing(frame) && return nothing, statfn
    if statfn === identity && length(split(string(frame), '\n')) > rows
        statfn = mean
        frame = renderer(cols, statfn)
    end
    return frame, statfn
end

function crop_line(line, columns)
    out = IOBuffer()
    width = 0
    # Preserve SGR colors while measuring printable graphemes, not ANSI bytes.
    for token in eachmatch(r"\e\[[0-?]*[ -/]*[@-~]|[^\e]+", line)
        text = token.match
        if startswith(text, "\e[")
            print(out, text)
        else
            for grapheme in graphemes(text)
                nextwidth = textwidth(grapheme)
                width + nextwidth > columns && return String(take!(out)) * "\e[0m"
                print(out, grapheme)
                width += nextwidth
            end
        end
    end
    return String(take!(out)) * "\e[0m"
end

function viewport(frame, rows, cols)
    (rows <= 0 || cols <= 1) && return ""
    lines = split(string(frame), '\n')
    if length(lines) > rows
        omitted = length(lines) - rows + 1
        lines = vcat(lines[1:rows-1], ["... $(omitted) more lines; enlarge terminal"])
    end
    # Leave the last column unused to avoid automatic wrap at the bottom edge.
    return join((crop_line(line, cols - 1) for line in lines), '\n')
end

function main(dummyargs...; io::IO=stdout, frames::Integer=typemax(Int), renderer=render_frame)
    frames >= 0 || throw(ArgumentError("frames must be nonnegative"))
    frames == 0 && return nothing
    try
        # Keep the shell's contents in the normal screen buffer.
        print(io, "\e[?1049h")
        Consoles.hide_cursor(io)
        statfn = identity
        previous_size = displaysize(io)
        for _ in 1:frames
            rows, cols = displaysize(io)
            if (rows, cols) != previous_size
                statfn = identity
            end
            previous_size = (rows, cols)
            frame, statfn = fit_frame(renderer, rows, cols, statfn)
            isnothing(frame) && break
            # Sampling may take a second; honor a resize that occurred meanwhile.
            rows, cols = displaysize(io)
            print(io, "\e[H\e[J", viewport(frame, rows, cols))
            flush(io)
        end
    catch e
        e isa InterruptException && return nothing
        rethrow()
    finally
        Consoles.show_cursor(io)
        print(io, "\e[?1049l")
        flush(io)
    end
    return nothing
end

function monitor(args...; kwargs...)
    main(args...; kwargs...)
end

end # module TerminalSystemMonitor
