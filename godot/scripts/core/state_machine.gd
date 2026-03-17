## Stack-based game state machine with push/pop/switch operations.
## Mirrors Python core/state_machine.py.
##
## States are Node instances added/removed from the scene tree.
## The active state is the top of the stack and receives _process/_input.
class_name GameStateMachine
extends Node


enum GameStateType {
	MENU,
	NAVIGATION,
	COMBAT,
	TRADE,
	DIALOGUE,
	CUTSCENE,
	PAUSE,
	END,
	FACTION_SCREEN,
	SHIP_SCREEN,
	SETTINGS,
	PURCHASE,
	MISSION_LOG,
}


var _stack: Array[Node] = []


## The currently active state (top of stack), or null.
var current_state: Node:
	get:
		if _stack.is_empty():
			return null
		return _stack.back()


var is_empty: bool:
	get:
		return _stack.is_empty()


## Push a new state on top (e.g., pause overlay).
func push(state: Node) -> void:
	if not _stack.is_empty():
		var prev := _stack.back() as Node
		if prev.has_method("state_exit"):
			prev.state_exit()
		prev.process_mode = Node.PROCESS_MODE_DISABLED
	_stack.push_back(state)
	add_child(state)
	if state.has_method("state_enter"):
		state.state_enter()


## Remove the top state and resume the one below.
func pop() -> void:
	if not _stack.is_empty():
		var top := _stack.pop_back() as Node
		if top.has_method("state_exit"):
			top.state_exit()
		remove_child(top)
		top.queue_free()
	if not _stack.is_empty():
		var resumed := _stack.back() as Node
		resumed.process_mode = Node.PROCESS_MODE_INHERIT
		if resumed.has_method("state_enter"):
			resumed.state_enter()


## Replace the top state (e.g., menu → navigation).
func switch(state: Node) -> void:
	if not _stack.is_empty():
		var top := _stack.pop_back() as Node
		if top.has_method("state_exit"):
			top.state_exit()
		remove_child(top)
		top.queue_free()
	_stack.push_back(state)
	add_child(state)
	if state.has_method("state_enter"):
		state.state_enter()


## Remove all states from the stack.
## Only the top state receives state_exit(); intermediate states are discarded.
func clear() -> void:
	if not _stack.is_empty():
		var top := _stack.back() as Node
		if top.has_method("state_exit"):
			top.state_exit()
	for s in _stack:
		remove_child(s)
		s.queue_free()
	_stack.clear()
