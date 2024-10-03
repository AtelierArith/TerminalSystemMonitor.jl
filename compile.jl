module CompileSandbox

# begin dirty hack
import ColorTypes

function ColorTypes.register_hints()
    nothing
end

#=
function Base.argmax(arr::Array{Float64,1})
    m = -10000.0
    am = 1
    for i in eachindex(arr)
        if arr[i] > m
            m = arr[i]
            am = i
        end
    end
    return am
end
=#

using UnicodePlots:
    UserColorType,
    KEYWORDS,
    split_plot_kw,
    DEFAULT_WIDTH,
    default_formatter,
    Plot,
    BarplotGraphics,
    transform_name,
    label!,
    scale_callback,
    ansi_color,
    GraphicsArea,
    RefValue,
    ColorType,
    nrows,
    ncols,
    MVP,
    PLOT_KEYWORDS,
    is_enabled,
    ColorMap,
    colormap_callback,
    BLANK,
    blank,
    xlabel,
    ylabel,
    zlabel,
    preprocess!,
    BORDERMAP,
    BORDER_COLOR,
    no_ansi_escape,
    title,
    Crayon,
    print_title,
    print_labels,
    print_border,
    print_row,
    ImageGraphics

import UnicodePlots

UnicodePlots.colormode() = 8
UnicodePlots.colors256!() = nothing
UnicodePlots.truecolors!() = nothing
UnicodePlots.faintcolors!() = nothing

function _f(x)
    unicode_exponent = false
    thousands_separator = ' '
    UnicodePlots.nice_repr(x, unicode_exponent, thousands_separator)
end

function UnicodePlots.default_formatter(kw)
    return _f
end

Base._nt_names(::Type{NamedTuple{(:maximum,),Tuple{Int64}}}) = (:maximum,)
Base._nt_names(::Type{NamedTuple{(:height,),Tuple{Int64}}}) = (:height,)

using UnicodePlots.Crayons: Crayons

UnicodePlots.COLORMODE[] = Crayons.COLORS_24BIT
UnicodePlots.COLOR_CYCLE[] = UnicodePlots.COLOR_CYCLE_FAINT

struct MyBarplotGraphics{R<:Number,F<:Function,XS<:Function} <: UnicodePlots.GraphicsArea
    bars::Vector{R}
    colors::Vector{ColorType}
    char_width::Int
    visible::Bool
    maximum::Float64
    max_val::RefValue{Float64}
    max_len::RefValue{Int}
    symbols::Vector{Char}
    formatter::F
    xscale::XS

    function MyBarplotGraphics(bars::AbstractVector{R}, char_width::Int) where {R<:Number}

        symbols::Union{AbstractVector,Tuple} = KEYWORDS.symbols
        color::Union{UserColorType,AbstractVector} = :green
        maximum::Union{Number,Nothing} = nothing
        # formatter::Function = default_formatter((;))
        formatter::Function = _f
        visible::Bool = KEYWORDS.visible
        xscale = KEYWORDS.xscale

        for s ∈ symbols
            length(s) == 1 ||
                throw(ArgumentError("symbol has to be a single character, got \"$s\""))
        end
        xscale = scale_callback(xscale)
        #char_width = max(10, char_width, length(string(bars[argmax(xscale.(bars))])) + 7)
        char_width = 10
        colors = if color isa AbstractVector
            ansi_color.(color)
        else
            fill(ansi_color(color), length(bars))
        end
        new{R,typeof(formatter),typeof(xscale)}(
            bars,
            colors,
            char_width,
            visible,
            Float64(something(maximum, -Inf)),
            Ref(-Inf),
            Ref(0),
            collect(map(s -> first(s), symbols)),
            formatter,
            xscale,
        )
    end
end

@inline UnicodePlots.nrows(c::MyBarplotGraphics) = length(c.bars)
@inline UnicodePlots.ncols(c::MyBarplotGraphics) = c.char_width

function UnicodePlots.addrow!(
    c::MyBarplotGraphics{R},
    bars::AbstractVector{R},
    color::Union{UserColorType,AbstractVector} = nothing,
) where {R<:Number}
    append!(c.bars, bars)
    colors = if color isa AbstractVector
        ansi_color.(color)
    else
        fill(suitable_color(c, color), length(bars))
    end
    append!(c.colors, colors)
    c
end

function UnicodePlots.addrow!(
    c::MyBarplotGraphics{R},
    bar::Number,
    color::UserColorType = nothing,
) where {R<:Number}
    push!(c.bars, R(bar))
    push!(c.colors, suitable_color(c, color))
    c
end

function _tmp(c::MyBarplotGraphics)
    c.max_val[] = -Inf
    c.max_len[] = 0
    nothing
end

function UnicodePlots.preprocess!(
    ::Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}},
    c::CompileSandbox.MyBarplotGraphics{
        Float64,
        typeof(CompileSandbox._f),
        typeof(Base.identity),
    },
)
    max_val, i = findmax(c.xscale.(c.bars))
    c.max_val[] = max(max_val, c.maximum)
    c.max_len[] = length(c.formatter(c.bars[i]))
    _tmp
end

function UnicodePlots.print_row(
    io::Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}},
    print_nocol::typeof(Base.print),
    print_color::typeof(UnicodePlots.print_color),
    c::CompileSandbox.MyBarplotGraphics{
        Float64,
        typeof(CompileSandbox._f),
        typeof(Base.identity),
    },
    row::Int,
)
    1 ≤ row ≤ nrows(c) || throw(ArgumentError("`row` out of bounds: $row"))
    val = (bar = c.bars[row]) |> c.xscale
    nsyms = length(c.symbols)
    frac = c.max_val[] > 0 ? max(val, zero(val)) / c.max_val[] : 0.0
    max_bar_width = max(c.char_width - 2 - c.max_len[], 1)
    bar_head = round(Int, frac * max_bar_width, nsyms > 1 ? RoundDown : RoundNearestTiesUp)
    print_color(io, c.colors[row], c.symbols[nsyms]^bar_head)
    if nsyms > 1
        rem = (frac * max_bar_width - bar_head) * (nsyms - 2)
        print_color(io, c.colors[row], rem > 0 ? c.symbols[1+round(Int, rem)] : ' ')
        bar_head += 1  # padding, we printed one more char
    end
    len = if bar ≥ 0
        bar_lbl = c.formatter(bar)
        print_color(io, nothing, ' ', bar_lbl)
        length(bar_lbl)
    else
        -1
    end
    pad_len = max(max_bar_width + 1 + c.max_len[] - bar_head - len, 0)
    print_nocol(io, ' '^round(Int, pad_len))
    nothing
end

function UnicodePlots._show(
    end_io::Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}},
    print_nocol::typeof(Base.print),
    print_color::typeof(UnicodePlots.print_color),
    p::Plot
)
    buf = PipeBuffer()  # buffering, for performance
    io_color = get(end_io, :color, false)
    io = IOContext(buf, :color => io_color, :displaysize => displaysize(end_io))

    g = p.graphics
    🗷 = Char(BLANK)  # blank outside graphics
    🗹 = blank(g)  # blank inside graphics
    ############################################################
    # 🗷 = 'x'  # debug
    # 🗹 = Char(typeof(g) <: BrailleCanvas ? '⠿' : 'o')  # debug
    ############################################################
    xlab, ylab, zlab = axes_labels = xlabel(p), ylabel(p), zlabel(p)
    postprocess! = preprocess!(io, g)
    nr, nc = nrows(g), ncols(g)

    p_width = nc + 2  # left corner + border length (number of graphics cols) + right corner
    if p.compact[]
        isempty(xlab) || label!(p, :b, xlab)
        isempty(ylab) || label!(p, :l, round(Int, nr / 2), ylab)
    end

    bmap = BORDERMAP[p.border[] ≡ :none && g isa BrailleCanvas ? :bnone : p.border[]]
    bc = BORDER_COLOR[]

    # get length of largest strings to the left and right
    max_len_l = if p.labels[] && !isempty(p.labels_left)
        maximum(length ∘ no_ansi_escape, values(p.labels_left))
    else
        0
    end
    max_len_r = if p.labels[] && !isempty(p.labels_right)
        maximum(length ∘ no_ansi_escape, values(p.labels_right))
    else
        0
    end
    max_len_a = p.labels[] ? maximum(length ∘ no_ansi_escape, axes_labels) : 0
    if !p.compact[] && p.labels[] && !isempty(ylab)
        max_len_l += length(ylab) + 1
    end

    has_labels =
        max_len_l > 0 || max_len_r > 0 || max_len_a > 0 || length(p.decorations) > 0
    has_labels &= p.labels[]

    plot_offset = max_len_l + p.margin[] + p.padding[]  # offset where the plot (including border) begins
    border_left_pad = 🗷^plot_offset  # padding-string between labels and border
    plot_padding = 🗷^p.padding[]  # base padding-string (e.g. left to border)

    cbar_pad = if p.cmap.bar
        min_z_str, max_z_str =
            map(x -> nice_repr(roundable(x) ? x : float_round_log10(x), p), p.cmap.lim)
        len_z_lab = length(no_ansi_escape(zlabel(p)))
        cbar_max_len = max(
            length(min_z_str),
            length(max_z_str),
            WIDTH_CB + (len_z_lab > 0 ? p.padding[] + len_z_lab : 0),
        )
        🗷^cbar_max_len
    else
        ""
    end

    # trailing
    border_right_pad = if p.cmap.bar
        🗷^max_len_r  # colorbar labels can overlap padding
    else
        plot_padding * 🗷^max_len_r
    end
    border_right_cbar_pad = plot_padding * 🗷^max_len_r * cbar_pad

    # plot the title and the top border
    h_ttl, w_ttl = print_title(
        io,
        print_nocol,
        print_color,
        border_left_pad,
        title(p),
        border_right_cbar_pad * '\n',
        🗹;
        p_width = p_width,
        color = io_color ? Crayon(foreground = :white, bold = true) : nothing,
    )
    h_lbl = print_labels(
        io,
        print_nocol,
        print_color,
        p,
        :t,
        nc - 2,
        border_left_pad * 🗹,
        🗹 * border_right_cbar_pad * '\n',
        🗹,
    )
    g.visible && print_border(
        io,
        print_nocol,
        print_color,
        :t,
        nc,
        border_left_pad,
        border_right_pad * (p.cmap.bar ? "" : "\n"),
        bmap,
    )
    p.cmap.bar && print_colorbar_lim(
        io,
        print_nocol,
        print_color,
        p,
        max_z_str,
        bc,
        cbar_max_len,
        🗷,
        '\n',
    )

    # compute position of ylabel
    y_lab_row = round(nr / 2, RoundNearestTiesUp)

    # plot all rows
    for row ∈ 1:nr
        # print left annotations
        print_nocol(io, 🗷^p.margin[])
        if has_labels
            # Current labels to left and right of the row and their length
            left_str   = get(p.labels_left, row, "")
            left_col   = get(p.colors_left, row, bc)
            right_str  = get(p.labels_right, row, "")
            right_col  = get(p.colors_right, row, bc)
            left_str_  = no_ansi_escape(left_str)
            right_str_ = no_ansi_escape(right_str)
            left_len   = length(left_str_)
            right_len  = length(right_str_)
            if !io_color
                left_str  = left_str_
                right_str = right_str_
            end
            if !p.compact[] && row == y_lab_row
                # print ylabel
                print_color(io, :normal, ylab)
                print_nocol(io, 🗷^(max_len_l - length(ylab) - left_len))
            else
                # print padding to fill ylabel length
                print_nocol(io, 🗷^(max_len_l - left_len))
            end
            # print the left annotation
            print_color(io, left_col, left_str)
        end
        if g.visible
            # print left border
            print_nocol(io, plot_padding)
            print_color(io, bc, bmap[:l])
            # print canvas row
            print_row(io, print_nocol, print_color, g, row)
            if g isa ImageGraphics && g.sixel[]
                offset = plot_offset + nc + 1  # COV_EXCL_LINE
                # 1F: move cursor to the beginning of the previous line, 1 line up
                # $(offset)C: move cursor to the right by an amount of $offset columns
                print_nocol(io, "\e[1F\e[$(offset)C")  # COV_EXCL_LINE
            end
            # print right border (symmetry with left border and padding)
            print_color(io, bc, bmap[:r])
            print_nocol(io, plot_padding)
        end
        if has_labels
            print_color(io, right_col, right_str)
            print_nocol(io, 🗷^(max_len_r - right_len))
        end
        # print a colorbar element
        p.cmap.bar && print_colorbar_row(
            io,
            print_nocol,
            print_color,
            p,
            row,
            nr,
            zlab,
            bc,
            cbar_max_len,
            🗷,
        )
        row < nr && print_nocol(io, '\n')
    end
    postprocess!(g)

    (g.visible || p.cmap.bar || has_labels) && print_nocol(io, '\n')

    # draw bottom border
    g.visible && print_border(
        io,
        print_nocol,
        print_color,
        :b,
        nc,
        border_left_pad,
        border_right_pad,
        bmap,
    )
    p.cmap.bar && print_colorbar_lim(
        io,
        print_nocol,
        print_color,
        p,
        min_z_str,
        bc,
        cbar_max_len,
        🗷,
        "",
    )

    # print bottom labels
    w_lbl = 0
    if has_labels
        h_lbl += print_labels(
            io,
            print_nocol,
            print_color,
            p,
            :b,
            nc - 2,
            '\n' * border_left_pad * 🗹,
            🗹 * border_right_cbar_pad,
            🗹,
        )
        if !p.compact[]
            h_w = print_title(
                io,
                print_nocol,
                print_color,
                '\n' * border_left_pad,
                xlab,
                border_right_cbar_pad,
                🗹;
                p_width,
            )
            h_lbl += h_w[1]
            w_lbl += h_w[2]
        end
    end

    # delayed print (buffering)
    print_nocol(end_io, read(buf, String))

    # return the approximate image size
    (
        h_ttl + 1 + nr + 1 + h_lbl,  # +1 for borders
        max(
            w_ttl,
            w_lbl,
            length(border_left_pad) + p_width + length(border_right_cbar_pad),
        ),
    )
end


function UnicodePlots.barplot(
    text::AbstractVector{<:AbstractString},
    heights::AbstractVector{<:Number};
    color::Union{UserColorType,AbstractVector} = :green,
    width::Union{Nothing,Integer} = nothing,
    xscale = KEYWORDS.xscale,
    name::AbstractString = KEYWORDS.name,
    kw...,
)
    pkw, okw = split_plot_kw(kw)
    length(text) == length(heights) ||
        throw(DimensionMismatch("the given vectors must be of the same length"))
    minimum(heights) ≥ 0 || throw(ArgumentError("all values have to be ≥ 0"))

    if any(map(t -> occursin('\n', t), text))
        _text = eltype(text)[]
        _heights = eltype(heights)[]
        for (t, h) ∈ zip(text, heights)
            lines = split(t, '\n')
            if (n = length(lines)) > 1
                append!(_text, lines)
                for i ∈ eachindex(lines)
                    push!(_heights, i == n ? h : -1)
                end
            else
                push!(_text, t)
                push!(_heights, h)
            end
        end
        text, heights = _text, _heights
    end

    area = MyBarplotGraphics(heights, something(width, DEFAULT_WIDTH[]))
    #formatter = default_formatter(pkw),
    #symbols = KEYWORDS.symbols,
    #maximum = nothing,
    #xscale = xscale,
    #color = color,
    #okw...,
    #)
    # plot = Plot(area; border = :barplot, xlabel = transform_name(xscale), pkw...)
    plot = _Plot(area, :barplot)

    isempty(name) || label!(plot, :r, string(name), suitable_color(plot.graphics, color))
    for i ∈ eachindex(text)
        label!(plot, :l, i, text[i])
    end

    plot
end

function _Plot(graphics::MyBarplotGraphics, border::Symbol)

    title::AbstractString = PLOT_KEYWORDS.title
    xlabel::AbstractString = PLOT_KEYWORDS.xlabel
    ylabel::AbstractString = PLOT_KEYWORDS.ylabel
    zlabel::AbstractString = PLOT_KEYWORDS.zlabel
    unicode_exponent::Bool = PLOT_KEYWORDS.unicode_exponent
    thousands_separator::Char = PLOT_KEYWORDS.thousands_separator
    # border::Symbol = PLOT_KEYWORDS.border
    compact::Bool = PLOT_KEYWORDS.compact
    margin::Integer = PLOT_KEYWORDS.margin
    padding::Integer = PLOT_KEYWORDS.padding
    labels::Bool = PLOT_KEYWORDS.labels
    colorbar::Bool = PLOT_KEYWORDS.colorbar
    colorbar_border::Symbol = PLOT_KEYWORDS.colorbar_border
    colorbar_lim = PLOT_KEYWORDS.colorbar_lim
    colormap::Any = PLOT_KEYWORDS.colormap
    projection::Union{Nothing,MVP} = nothing

    margin < 0 && throw(ArgumentError("`margin` must be ≥ 0"))
    projection = something(projection, MVP())
    E = Val{is_enabled(projection)}
    F = typeof(projection.dist)
    UnicodePlots.Plot{MyBarplotGraphics,E,F}(
        graphics,
        projection,
        Ref(0),
        Ref(0),
        Ref(string(title)),
        Ref(string(xlabel)),
        Ref(string(ylabel)),
        Ref(string(zlabel)),
        Ref(Int(margin)),
        Ref(Int(padding)),
        Ref(unicode_exponent),
        Ref(thousands_separator),
        Ref(border),
        Ref(compact),
        Ref(labels && graphics.visible),
        Dict{Int,String}(),
        Dict{Int,String}(),
        Dict{Int,ColorType}(),
        Dict{Int,ColorType}(),
        Dict{Symbol,String}(),
        Dict{Symbol,ColorType}(),
        ColorMap(colorbar_border, colorbar, colorbar_lim, colormap_callback(colormap)),
    )
end

import Term
using Term: Padding, AbstractRenderable, default_width, console_width, Measure, Panel
using Term.Panels: content_as_renderable, render
using Term.Layout: RenderablesUnion
using Term.Segments: get_string_types, Segment
using Term.Renderables: Renderable

Term.default_width(io::Core.CoreSTDOUT) = displaysize()[end]
Term.console_width(io::Core.CoreSTDOUT) = displaysize()[end]

function Term.remove_markup(input_text; remove_orphan_tags = true)::String
    input_text
end

#=
function Term.Panel(
    content::Union{AbstractString,AbstractRenderable};
    fit::Bool = false,
    padding::Union{Nothing,Padding,NTuple} = nothing,
    width::Int = default_width(),
    style::String = "default",
)
    padding = if isnothing(padding)
        if style == "hidden"
            Padding(0, 0, 0, 0)
        else
            Padding(2, 2, 0, 0)
        end
    else
        Padding(padding)
    end

    # estimate content and panel size 
    content_width = content isa AbstractString ? Measure(content).w : content.measure.w
    panel_width = if fit
        content_width + padding.left + padding.right + 2
    else
        width
    end

    # if too large, set fit=false
    fit = if fit
        (!isa(content, AbstractString) ? panel_width <= console_width() : true)
    else
        false
    end
    width = fit ? min(panel_width, console_width()) : width

    # @debug "Ready to make panel" content content_width panel_width width console_width() fit
    return Panel(content, Val(fit), width, padding)
end

function Term.Panel(
    content::Union{AbstractString,AbstractRenderable},
    ::Val{true},
    width::Int,
    padding::Padding
)
    height::Union{Nothing,Int} = nothing
    background::Union{Nothing,String} = nothing
    justify::Symbol = :left

    Δw = padding.left + padding.right + 2
    Δh = padding.top + padding.bottom

    # create content
    # @info "panel fit" width height Δw Δh background
    content = content_as_renderable(content, width, Δw, justify, background)

    # estimate panel size
    panel_measure = Measure(
        max(something(height, 0), content.measure.h + padding.top + padding.bottom + 2),
        max(width, content.measure.w + padding.left + padding.right + 2),
    )

    # @debug "Creating fitted panel" content.measure panel_measure content
    return render(
        content;
        panel_measure = panel_measure,
        content_measure = content.measure,
        Δw = Δw,
        Δh = Δh,
        padding = padding,
        background = background,
        justify = justify,
    )
end
=#

function Term.do_by_line(fn::Function, text::AbstractString)::String
    arrstr = String[fn(sl) for sl in Term.split_lines(text)]
    join(arrstr, "\n")
end

function Term.Segments.get_string_types(a, b)
    return String
end

function Term.Layout.hstack(r1::Term.Panels.Panel, r2::Term.Panels.Panel; pad::Int = 0)
    # get dimensions of final renderable
    h1 = r1.measure.h
    h2 = r2.measure.h
    Δh = abs(h2 - h1)

    # make sure both renderables have the same number of segments
    if h1 > h2
        s1_ = r1.segments
        s2_ = vcat(r2.segments, fill(Segment(' '^(r2.measure.w)), Δh))
    elseif h1 < h2
        s1_ = vcat(r1.segments, fill(Segment(' '^(r1.measure.w)), Δh))
        s2_ = r2.segments
    else
        s1_, s2_, = r1.segments, r2.segments
    end

    s1 = s1_::Vector{Segment}
    s2 = s2_::Vector{Segment}

    # combine segments
    stype = String
    m = min(length(s1), length(s2))

    segments::Vector{Segment} = map(1:m) do i
        Segment(
            stype(s1[i].text * ' '^pad * s2[i].text),
            Measure(1, s1[i].measure.w + pad + s2[i].measure.w),
        )
    end
    return Term.Panels.Panel(segments, Measure(segments))
end

function Base.string(r::Term.Panel)
    isnothing(r.segments) && return ""
    seg_texts = map(r.segments) do s
        s.text
    end
    # seg_texts = getfield.(r.segments, :text)
    stype = String
    return join(seg_texts, "\n") |> stype
end

# end dirty hack

using TerminalSystemMonitor

Base.@ccallable function main()::Cint
    TerminalSystemMonitor.main()
    return 0
end

end # Module
