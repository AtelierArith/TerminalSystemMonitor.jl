#=@testitem "JET" begin
    using Test
    using JET
    using TerminalSystemMonitor

    @testset "JET" begin
        if VERSION ≥ v"1.10"
            JET.test_package(TerminalSystemMonitor; target_defined_modules=true)
        end
    end
end
=#