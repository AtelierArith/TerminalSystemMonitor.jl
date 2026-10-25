# [TerminalSystemMonitor.jl](https://github.com/AtelierArith/TerminalSystemMonitor.jl)

[![Build Status](https://github.com/AtelierArith/TerminalSystemMonitor.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/AtelierArith/TerminalSystemMonitor.jl/actions/workflows/CI.yml?query=branch%3Amain) [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://AtelierArith.github.io/TerminalSystemMonitor.jl/stable/) [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://AtelierArith.github.io/TerminalSystemMonitor.jl/dev/)

## Description

This Julia package displays CPU and RAM usage information on your computer. If necessary, one can show GPU usage.

<img width="2592" alt="image" src="https://github.com/user-attachments/assets/695d64ab-62ba-417e-ac04-e168237b4957">

## Installation

### Supported Julia versions

Julia 1.10 and the latest stable Julia 1.x release are tested on Linux, macOS,
and Windows in CI, including a weekly compatibility check. GPU extensions require
compatible hardware and are not covered by this CPU-only test matrix.

### Step 1. Install Julia

#### macOS or Linux

To install Julia on macOS or Linux, run the following command in your terminal:

```sh
$ curl -fsSL https://install.julialang.org | sh
```

#### Windows

For Windows, you can install Julia using the following command in PowerShell:

```powershell
PS> winget install julia -s msstore
After installation, you can confirm Julia is installed by running:
```

```sh
$ julia --version
```

### Step 2. Download the source code

Clone the repository and navigate to the directory:

```sh
$ git clone https://github.com/AtelierArith/TerminalSystemMonitor.jl.git
$ cd TerminalSystemMonitor.jl
```

### Step 3. Resolve dependencies
To resolve dependencies, ensure you are in the correct directory, then activate the Julia environment and instantiate the project:

```sh
$ pwd
path/to/TerminalSystemMonitor.jl
$ ls
Project.toml  README.md     main.jl       src
$ julia -q
julia> using Pkg; Pkg.activate("."); Pkg.instantiate()
```

## Usage

Run the program using the following commands:

```sh
$ ls
Project.toml  README.md     main.jl       src
$ julia --project main.jl
```

You will see an output similar to this:

```bash
╭───────────────────────╮╭───────────────────────╮
│      ┌               ┐││      ┌               ┐│
│id:  0┤■■■ 24          ││id:  4┤■ 10.1          │
│id:  1┤ 0              ││id:  5┤ 0              │
│id:  2┤■■ 13.9         ││id:  6┤■ 6             │
│id:  3┤ 0              ││id:  7┤ 0              │
│      └               ┘││      └               ┘│
╰───────────────────────╯╰───────────────────────╯
╭───────────────────────╮╭───────────────────────╮
│      ┌               ┐││      ┌               ┐│
│id:  8┤■ 6             ││id: 12┤ 3              │
│id:  9┤ 0              ││id: 13┤ 0              │
│id: 10┤■ 5             ││id: 14┤ 2              │
│id: 11┤ 0              ││id: 15┤ 0              │
│      └               ┘││      └               ┘│
╰───────────────────────╯╰───────────────────────╯
╭────────────────────────────────────────╮
│     ┌               ┐                  │
│Mem: ┤■■■■■■ 58.859    64.0 GiB         │
│     └               ┘                  │
│      Load average: 1.81 2.4 2.73       │
│      Uptime: 0 days, 10:35:59          │
╰────────────────────────────────────────╯
```

Alternatively, you can launch the functionality directly from Julia:

```julia
$ julia --project
julia> using TerminalSystemMonitor; monitor()
```

The monitor uses the terminal's alternate screen and restores the shell display
when it exits. It writes to `stdout` by default, independently of notebook or
other Julia display backends. Use `monitor(; frames=10)` to stop after ten frames,
or `monitor(; io=stream, frames=10)` to direct terminal output to another stream.
Frames are bounded to the current terminal size; enlarge the terminal if an
omitted-lines message appears.

### Monitoring GPU Usage

Please load `CUDA.jl` package in advance:

```julia
julia> using CUDA; using TerminalSystemMonitor; monitor()
```

CUDA monitoring requires NVML as well as a functional CUDA driver. If NVML is
unavailable, CPU monitoring remains active. Individual unsupported metrics are
shown as `N/A`. The optional `scripts/check_cuda.jl` smoke test can be run in an
environment containing CUDA and TerminalSystemMonitor.

## Why not `htop`?

You might be familiar with the [htop-dev/htop](https://github.com/htop-dev/htop), which provides similar functionality. You can use the `htop` command in Julia as follows:

```julia
julia> using Htop_jll; run(Htop_jll.htop())
```

However, `Htop_jll` only supports Unix-based systems. The TerminalSystemMonitor.jl package also supports Windows as long as Term.jl and UnicodePlots.jl are available on the platform.

## Why not `btm`?

You can also use [ClementTsang/bottom](https://github.com/ClementTsang/bottom), also known as the `btm` command:

```sh
$ btm -b
```

We could use `bottom_jll` instead:

```julia
julia> using bottom_jll; run(`$(btm()) --basic`)
```

Our Julia package [TerminalSystemMonitor.jl](https://github.com/AtelierArith/TerminalSystemMonitor.jl) offers a cross-platform solution and adopts responsive design; chaging layout nicely based on your terminal size.

## Can I visualize GPU Apple Silicon processors?

Yes!!! See this [PR](https://github.com/AtelierArith/TerminalSystemMonitor.jl/pull/6#issue-2825769951)

```julia
julia> using MacOSIOReport; using TerminalSystemMonitor; monitor()
```

