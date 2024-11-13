# TerminalSystemMonitor.jl

## Description

This Julia package displays CPU and RAM usage information on your computer. If necessary, one can show GPU usage.

![image](https://private-user-images.githubusercontent.com/16760547/385691047-695d64ab-62ba-417e-ac04-e168237b4957.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MzE0OTA1ODcsIm5iZiI6MTczMTQ5MDI4NywicGF0aCI6Ii8xNjc2MDU0Ny8zODU2OTEwNDctNjk1ZDY0YWItNjJiYS00MTdlLWFjMDQtZTE2ODIzN2I0OTU3LnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNDExMTMlMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjQxMTEzVDA5MzEyN1omWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTA0MjNkZjJjODllZGMxMDMxNDAzZThjOTIyZTY1ZWRjMDVhNzBkNTIyMzY2NWEyNjAyMWE1ZTRkMWJiZGYxMjUmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.4Up5YqmqTmzlQptiPnQhEpJqMys_eND9qajF_NttO7c)

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

```
sh
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
$ julia main.jl
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
julia> using TerminalSystemMonitor: main; main()
```

### Monitoring GPU Usage

Please load `CUDA.jl` package in advance:

```julia
julia> using CUDA; using TerminalSystemMonitor: main; main()
```


## Why not `htop`?

You might be familiar with the `htop` command, which provides similar functionality. You can use `htop` in Julia as follows:

```julia
julia> using Htop_jll; run(Htop_jll.htop())
```

However, `Htop_jll` only supports Unix-based systems. The TerminalSystemMonitor.jl package also supports Windows as long as Term.jl and UnicodePlots.jl are available on the platform.

## Why not `bottom`?

You can also use bottom, also known as the btm command:

```
btm -b
```

However, TerminalSystemMonitor.jl offers a cross-platform solution that integrates directly with Julia, providing similar functionality in a familiar environment.
