extends Node

func log(message: Variant) -> void:
	var text := str(message)
	print(text)
	DCKit.run("echo \"%s\"" % text.replace("\"", "\\\""))
