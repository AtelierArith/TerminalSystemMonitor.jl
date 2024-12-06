# [TerminalSystemMonitor.jl](https://github.com/AtelierArith/TerminalSystemMonitor.jl)

[![Build Status](https://github.com/AtelierArith/TerminalSystemMonitor.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/AtelierArith/TerminalSystemMonitor.jl/actions/workflows/CI.yml?query=branch%3Amain) [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://AtelierArith.github.io/TerminalSystemMonitor.jl/stable/) [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://AtelierArith.github.io/TerminalSystemMonitor.jl/dev/)

## Description

This Julia package displays CPU and RAM usage information on your computer. If necessary, one can show GPU usage.

<img width="2592" alt="image" src="https://github.com/user-attachments/assets/695d64ab-62ba-417e-ac04-e168237b4957">

## Installation

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

### Monitoring GPU Usage

Please load `CUDA.jl` package in advance:

```julia
julia> using CUDA; using TerminalSystemMonitor; monitor()
```

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

Technically yes, however, you may want to chekcout [context-labs/mactop](https://github.com/context-labs/mactop) or [tlkh/asitop](https://github.com/tlkh/asitop) to start instantly. To get information regarding GPU, we need to call `powermetrics` command which requires root privilege. If you are familiar with Rust language, [vladkens/macmon](https://github.com/vladkens/macmon) is what you need. It states "sudoless performance monitoring for Apple Silicon processors".
