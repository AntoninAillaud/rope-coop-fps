# GameManager.gd
extends Node

var players = []
var current_index = 0

func register_player(player):
	players.append(player)

func switch_player():
	if players.size() < 2:
		return
	
	print("switching player")
	# Deactivate current player
	players[current_index].is_active = false
	players[current_index].get_node("CameraHolder/Camera").current = false
	
	# Switch to next player
	current_index = (current_index + 1) % players.size()
	
	# Activate new player
	players[current_index].is_active = true
	players[current_index].get_node("CameraHolder/Camera").current = true

func _input(event):
	if event.is_action_pressed("switch_player"):
		switch_player()
