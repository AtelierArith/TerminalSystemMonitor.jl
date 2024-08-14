# TerminalSystemMonitor.jl

## Description

This Julia package displays CPU and RAM memory usage information on your computer.

## Installation

### Step 1. Install Julia

#### macOS or Linux

```sh
$ curl -fsSL https://install.julialang.org | sh
```

####

```powershell
PS> winget install julia -s msstore
```

You can run `julia --version` to confirm Julia is installed on your computer.


### Step 2. Download source code

```sh
$ git clone https://github.com/AtelierArith/TerminalSystemMonitor.jl.git
$ cd TerminalSystemMonitor.jl
```

### Step 3. Resolve dependencies

```
$ pwd
path/to/TerminalSystemMonitor.jl
$ ls
Project.toml  README.md     main.jl       src
$ julia -q
julia> using Pkg; Pkg.activate("."); Pkg.instantiate()
```

## Usage

```sh
$ ls
Project.toml  README.md     main.jl       src
$ julia main.jl
```

You will get the following output like this:

```
──────────────────────╮╭──────────────────────╮
│     ┌               ┐││     ┌               ┐│
│id: 0┤■■■■ 37         ││id: 4┤■■ 23.2         │
│id: 1┤ 0              ││id: 5┤ 0              │
│id: 2┤■■■ 29          ││id: 6┤■ 15.2          │
│id: 3┤ 0              ││id: 7┤ 1              │
│     └               ┘││     └               ┘│
╰──────────────────────╯╰──────────────────────╯
╭───────────────────────╮╭───────────────────────╮
│      ┌               ┐││      ┌               ┐│
│ id: 8┤■ 10.9          ││id: 12┤ 3              │
│ id: 9┤ 0              ││id: 13┤ 0              │
│id: 10┤■ 5.9           ││id: 14┤ 2              │
│id: 11┤ 0              ││id: 15┤ 0              │
│      └               ┘││      └               ┘│
╰───────────────────────╯╰───────────────────────╯
╭──────────────────────╮
│     ┌               ┐│
│Mem: ┤■■■■■■■■ 29.4   │
│     └               ┘│
╰──────────────────────╯
```

Ofcourse, you can launch the functionality in your terminal.

```julia
julia> using TerminalSystemMonitor: main; main()
```

## Why not htop?

You might think of the `htop' command. Yes, you can:

```julia
julia> using Htop_jll; run(Htop_jll.htop())
```

However, [Htop_jll](https://github.com/JuliaBinaryWrappers/Htop_jll.jl?tab=readme-ov-file#platforms) only supports Unix systems. Our Julia package runs on Windows as long as Term.jl and UnicodePlots.jl support Windows.

## Why not bottom?

It's possible. We could use [bottom](https://github.com/ClementTsang/bottom) a.k.a `btm` command.

```sh
btm -b
```
