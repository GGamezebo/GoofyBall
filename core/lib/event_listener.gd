class_name EventListener
extends RefCounted

var _events: Dictionary = {}

func deinit() -> void:
	self.clear()
	
func clear() -> void:
	for event in self._events:
		var callbacks = self._events[event]
		for callback in callbacks:
			event.disconnect(callback)
	self._events.clear()

func add(event: Signal, callback: Callable) -> void:
	var callbacks = self._events.get_or_add(event, [])
	if callback not in callbacks:
		event.connect(callback)
		callbacks.append(callback)
		
func remove(event: Signal, callback: Callable) -> void:
	var callbacks = self._events.get(event, [])
	if callback in callbacks:
		event.disconnect(callback)
		callbacks.erase(callback)
