@testitem "JET" begin
    using Test
    using JET
    using CUDA
    using TerminalSystemMonitor

    @testset "JET" begin
        JET.test_package(TerminalSystemMonitor; target_defined_modules = true)
    end
end
