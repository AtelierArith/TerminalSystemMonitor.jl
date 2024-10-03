FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
	build-essential \
	curl \
	git \
	wget \
	nano

ENV JULIA_PROJECT="@."

RUN curl -fsSL https://install.julialang.org | sh -s -- --yes --default-channel nightly

COPY Project.toml /TerminalSystemMonitor.jl/
RUN wget https://raw.githubusercontent.com/JuliaLang/julia/refs/heads/master/contrib/juliac.jl
RUN mv juliac.jl /TerminalSystemMonitor.jl/
RUN wget https://raw.githubusercontent.com/JuliaLang/julia/refs/heads/master/contrib/juliac-buildscript.jl
RUN mv juliac-buildscript.jl /TerminalSystemMonitor.jl/

COPY src/ /TerminalSystemMonitor.jl/src/
RUN cd /TerminalSystemMonitor.jl && rm -f Manifest.toml && ~/.juliaup/bin/julia --project -e 'using Pkg; Pkg.build()'
COPY compile.jl ./TerminalSystemMonitor.jl/

# docker build -t kyu . && docker run --rm -it -w /TerminalSystemMonitor.jl kyu bash -c "echo 'compiling...' && ~/.juliaup/bin/julia +nightly --project -e 'using Pkg; Pkg.instantiate()' && ~/.juliaup/bin/julia +nightly --project juliac.jl --output-exe main compile.jl && ./main"