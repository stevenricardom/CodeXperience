@tool
extends SceneTree

func _init():
	for action in [['ui_up', KEY_W], ['ui_down', KEY_S], ['ui_left', KEY_A], ['ui_right', KEY_D]]:
		var ev = InputEventKey.new()
		ev.physical_keycode = action[1]
		
		var has_key = false
		if ProjectSettings.has_setting('input/' + action[0]):
			var events = ProjectSettings.get_setting('input/' + action[0]).get('events', [])
			for e in events:
				if e is InputEventKey and e.physical_keycode == action[1]:
					has_key = true
		
		if not has_key:
			var current = ProjectSettings.get_setting('input/' + action[0])
			if current == null:
				current = {'deadzone': 0.5, 'events': []}
			var events = current.get('events', [])
			events.append(ev)
			current['events'] = events
			ProjectSettings.set_setting('input/' + action[0], current)
			print('Added ' + str(action[1]) + ' to ' + action[0])

	ProjectSettings.save()
	quit()
