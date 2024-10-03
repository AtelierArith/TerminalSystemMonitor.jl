using TerminalSystemMonitor: main as jlmain

Base.@ccallable function main()::Cint
    jlmain()
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    Base.exit_on_sigint(false)
    main()
end
