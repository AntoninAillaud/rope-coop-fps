extends Node3D

@onready var player1: PlayerCharacter = $PlayerCharacter
@onready var player2: PlayerCharacter = $PlayerCharacter2
@onready var rope_system: Node3D = $"../Ropes"


func _ready() -> void:
	GameManager.register_player(player1)
	GameManager.register_player(player2)
	
	# Configure the rope system
	rope_system.player1_path = $PlayerCharacter.get_path()
	rope_system.player2_path = $PlayerCharacter2.get_path()
