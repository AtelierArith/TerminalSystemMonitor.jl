module Hello

Base.@ccallable function main()::Cint
	println(Core.stdout, argmax(rand(10)))
	return 0
end

end # of module Hello
