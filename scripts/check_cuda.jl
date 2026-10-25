# Run in an environment containing CUDA and this package.
using Test
using CUDA
using TerminalSystemMonitor

const TSM = TerminalSystemMonitor
const Ext = Base.get_extension(TSM, :TerminalSystemMonitorCUDAExt)

@testset "NVML capability failures" begin
    @test !Ext.monitoring_available(() -> false, () -> error("unexpected"), () -> error("unexpected"))
    @test !Ext.monitoring_available(() -> true, () -> false, () -> error("unexpected"))
    @test !Ext.monitoring_available(() -> true, () -> true, () -> [])
    unavailable = Ext.optional_metric("GPU utilization") do
        throw(CUDA.NVML.NVMLError(CUDA.NVML.ERROR_NOT_SUPPORTED))
    end
    @test occursin("N/A", string(unavailable))
    for (code, reason) in (
        (CUDA.NVML.ERROR_NO_PERMISSION, "permission denied"),
        (CUDA.NVML.ERROR_GPU_IS_LOST, "device unavailable"),
        (CUDA.NVML.ERROR_NOT_FOUND, "device unavailable"),
    )
        panel = Ext.optional_metric("GPU") do
            throw(CUDA.NVML.NVMLError(code))
        end
        @test occursin(reason, string(panel))
    end
    @test_throws ErrorException Ext.optional_metric(() -> error("unexpected"), "GPU")
    @test_throws CUDA.NVML.NVMLError Ext.optional_metric(
        () -> throw(CUDA.NVML.NVMLError(CUDA.NVML.ERROR_UNKNOWN)), "GPU",
    )
    panels = TSM.paired_device_plots(
        [:lost, :healthy],
        (i, dev) -> Ext.optional_metric(() -> dev === :lost ?
            throw(CUDA.NVML.NVMLError(CUDA.NVML.ERROR_GPU_IS_LOST)) : dev, "GPU"),
        identity,
    )
    @test occursin("device unavailable", string(panels[1]))
    @test panels[3:4] == [:healthy, :healthy]
end

@testset "Invalid GPU memory counters" begin
    for (total, used) in ((0, 0), (-1, 0), (100, -1), (100, 101), (NaN, 1), (100, Inf))
        @test occursin("N/A", string(Ext.gpu_memory_plot(total, used, "test GPU")))
    end
    @test occursin("GPU Mem:", string(Ext.gpu_memory_plot(1024, 512, "test GPU")))
end

@testset "CUDA frame" begin
    if TSM.gpu_available(TSM.CUDADevice)
        devices = collect(CUDA.devices())
        @test length(TSM.backend_plots(TSM.CUDADevice)) == 2length(devices)
        frame = TSM.render_frame(100, TSM.mean)
        @test !isnothing(frame)
        @test occursin("GPU", string(frame))
    else
        @test isempty(TSM.backend_plots(TSM.CUDADevice))
        @test !occursin("GPU Mem:", string(TSM.render_frame(100, TSM.mean)))
    end
end
