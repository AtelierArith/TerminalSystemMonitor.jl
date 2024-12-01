using TerminalSystemMonitor
using Documenter

DocMeta.setdocmeta!(TerminalSystemMonitor, :DocTestSetup, :(using TerminalSystemMonitor); recursive=true)

makedocs(;
    modules=[TerminalSystemMonitor],
    authors="Satoshi Terasaki <terasakisatoshi.math@gmail.com> and contributors",
    sitename="TerminalSystemMonitor.jl",
    format=Documenter.HTML(;
        canonical="https://atelierarith.github.io/TerminalSystemMonitor.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/AtelierArith/TerminalSystemMonitor.jl",
    devbranch="main",
)
