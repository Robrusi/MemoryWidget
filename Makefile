.PHONY: memorywidget
memorywidget:
	swiftc -framework Cocoa MemoryWidget/*.swift -o memwidget && ./memwidget
