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
    @test_throws ErrorException Ext.optional_metric(() -> error("unexpected"), "GPU")
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
