extends Node

func _on_value_changed (value):
	self.text = str(value)
	
func _on_value_changed_float (value):
	self.text = "%.2f" % value
