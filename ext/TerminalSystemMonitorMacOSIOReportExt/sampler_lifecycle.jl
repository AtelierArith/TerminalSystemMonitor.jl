function close_sampler(sampler; release=MacOSIOReport.cfrelease)
    if applicable(close, sampler)
        return close(sampler)
    end
    # Registered MacOSIOReport 0.1.0 has no close/finalizer API. A fresh sampler
    # is used for each call, so prev is either its initial null sample or the
    # final sample committed after successful sampling.
    report = sampler.ior
    previous = report.prev
    report.prev = nothing
    if !isnothing(previous) && previous[1] != C_NULL
        release(previous[1])
    end
    for field in (:chan, :subs)
        pointer = getproperty(report, field)
        setproperty!(report, field, C_NULL)
        pointer == C_NULL || release(pointer)
    end
    return nothing
end
