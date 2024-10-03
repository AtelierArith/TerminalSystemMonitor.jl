julia +nightly --version

echo Compile Julia package TerminalSystemMonitor.jl using juliac.jl

julia +nightly --project juliac.jl --output-exe main buildmodule.jl

echo Compilation done!

./main