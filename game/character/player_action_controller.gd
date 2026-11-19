extends Node
class_name PlayerActionController

const PAID_ACTION_IDS: Array[StringName] = [&"combo", &"shot_price", &"shot"]

var _player: Player
var _hud: Control
var _buttons_by_action: Dictionary = {}
var _paid_abilities: Dictionary = {}
var _paid_charge_ap: Dictionary = {}
var _charge_fallback_capacities: Dictionary = {}
var _block_keyboard_held: bool = false
var _block_pointer_held: bool = false

func setup(player: Player, hud: Control) -> void:
	_player = player
	_hud = hud
	_connect_action_buttons()
	_setup_paid_ability_charges()
	_player.ap_delta_applied.connect(_on_player_ap_delta_applied)
	_update_paid_ability_charges()

func _process(_delta: float) -> void:
	for action_id in _buttons_by_action:
		var button := _buttons_by_action[action_id] as Control
		var input_action := StringName(button.get("input_action"))
		if input_action == &"":
			continue
		if action_id == &"block":
			_block_keyboard_held = Input.is_action_pressed(input_action)
			continue
		if not Input.is_action_just_pressed(input_action):
			continue
		if button is ChargeButton:
			button.try_activate()
		elif button is ButtonFeedback:
			button.activate()

	_sync_block_input()

func _connect_action_buttons() -> void:
	for button in get_tree().get_nodes_in_group(&"player_action_buttons"):
		if not _hud.is_ancestor_of(button):
			continue
		var action_id := StringName(button.get("action_id"))
		if action_id == &"":
			continue
		if _buttons_by_action.has(action_id):
			push_error("PlayerActionController: duplicate action_id '%s'." % action_id)
			continue
		_buttons_by_action[action_id] = button
		var input_action := StringName(button.get("input_action"))
		if input_action != &"" and not InputMap.has_action(input_action):
			push_error(
				"PlayerActionController: InputMap action '%s' is missing for '%s'."
				% [input_action, button.name]
			)
		button.connect(&"pressed", _on_action_pressed.bind(action_id))
		if action_id == &"block":
			button.connect(&"button_down", _on_block_button_down)
			button.connect(&"button_up", _on_block_button_up)

func _setup_paid_ability_charges() -> void:
	var paid_action_ids: Array[StringName] = []
	for action_id in PAID_ACTION_IDS:
		if not (_buttons_by_action.get(action_id) is ChargeButton):
			continue
		paid_action_ids.append(action_id)
		_paid_abilities[action_id] = null
		_paid_charge_ap[action_id] = _player.current_ap
		_charge_fallback_capacities[action_id] = _player.max_ap if action_id == &"combo" else 0.0

	if _player.weapon == null:
		return

	var ability_index := 0
	for ability in _player.weapon.abilities:
		if ability == null or _is_free_ability(ability):
			continue
		if ability_index >= paid_action_ids.size():
			break
		var action_id := paid_action_ids[ability_index]
		_paid_abilities[action_id] = ability
		_paid_charge_ap[action_id] = _player.current_ap
		ability_index += 1

func _on_player_ap_delta_applied(delta: float) -> void:
	if is_zero_approx(delta):
		return
	for action_id in _paid_charge_ap:
		var capacity := _get_paid_ability_charge_capacity(action_id)
		_paid_charge_ap[action_id] = clampf(
			_paid_charge_ap[action_id] + delta, 0.0, capacity
		)
	_update_paid_ability_charges()

func _update_paid_ability_charges() -> void:
	for action_id in _paid_charge_ap:
		var capacity := _get_paid_ability_charge_capacity(action_id)
		var charge := 0.0
		if capacity > 0.0:
			charge = clampf(_paid_charge_ap[action_id] / capacity, 0.0, 1.0)
		var button := _buttons_by_action[action_id] as ChargeButton
		button.smooth_to(charge)

func _get_paid_ability_charge_capacity(action_id: StringName) -> float:
	var ability := _paid_abilities[action_id] as Ability
	if ability == null:
		return _charge_fallback_capacities[action_id]
	return ability.ap_need

func _is_free_ability(ability: Ability) -> bool:
	return is_zero_approx(ability.ap_need) and ability.ap_delta >= 0.0

func _on_action_pressed(action_id: StringName) -> void:
	match action_id:
		&"attack":
			_player.try_attack()
		&"dodge":
			_player.try_dodge()
		&"inventory":
			_player.request_inventory()
		_:
			if _paid_charge_ap.has(action_id):
				_paid_charge_ap[action_id] = 0.0
				var button := _buttons_by_action[action_id] as ChargeButton
				button.smooth_to(0.0)

func _on_block_button_down() -> void:
	_block_pointer_held = true
	_sync_block_input()

func _on_block_button_up() -> void:
	_block_pointer_held = false
	_sync_block_input()

func _sync_block_input() -> void:
	_player.set_block_held(_block_keyboard_held or _block_pointer_held)
