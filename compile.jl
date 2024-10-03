module CompileSandbox

# begin dirty hack
import ColorTypes

function ColorTypes.register_hints()
	nothing
end

import UnicodePlots

UnicodePlots.colormode() = 8
UnicodePlots.colors256!() = nothing
UnicodePlots.truecolors!() = nothing
UnicodePlots.faintcolors!() = nothing

function Base.argmax(arr::AbstractVector{T}) where {T <: Real}
	return 1 # TODO FIX
	m = typemin(T)
	am::Int = 1
	for i in eachindex(arr)
		if arr[i] > m
			am = i
			m = arr[i]
		end
	end
	return am
end


using UnicodePlots.Crayons: Crayons

UnicodePlots.COLORMODE[] = Crayons.COLORS_24BIT
UnicodePlots.COLOR_CYCLE[] = UnicodePlots.COLOR_CYCLE_FAINT
# end dirty hack

using TerminalSystemMonitor

Base.@ccallable function main()::Cint
	println(Core.stdout, rand(ColorTypes.RGB))
	# return 0
	TerminalSystemMonitor.main()
	return 0
end

end # Module
