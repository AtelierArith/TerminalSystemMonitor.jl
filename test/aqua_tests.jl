@testitem "Aqua" begin
    using Aqua
    using Test
    using TerminalSystemMonitor
    @testset "Aqua" begin
        Aqua.test_all(TerminalSystemMonitor)
    end
end
