extends Node

var studio
var refs: Dictionary
var toolbar: GridContainer
var tool_label: Label
var save_label: Label
var layer_menu: MenuButton
var layers = [true, true, true, true, true]
var hidden_nodes = {}
var tick = 0.0
var saved_versions = {}


func _ready():
	refs = studio.refs
	var box = studio.profile_label.get_parent()
	save_label = studio._label(box, "")
	save_label.name = "SaveIndicator"
	box.move_child(save_label, 2)
	toolbar = GridContainer.new()
	toolbar.columns = 4
	box.add_child(toolbar)
	box.move_child(toolbar, 5)
	for action in [["Pintar", "paint"], ["Selecionar", "select"], ["Colar", "paste"], ["Inspecao", "inspect"],
			["Base", "base"], ["Girar", "rotate"], ["Espelhar", "mirror"], ["Cancelar", "cancel"]]:
		var button = Button.new()
		button.text = action[0]
		button.toggle_mode = action[1] in ["paint", "select", "paste", "inspect", "base"]
		button.hint_tooltip = {"rotate": "Girar previa 90 graus (R)", "mirror": "Espelhar previa (F)",
			"select": "Copiar uma area pelos dois cantos", "paint": "Voltar a pintar com a paleta"}.get(action[1], action[0])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.connect("pressed", self, "activate", [action[1]])
		toolbar.add_child(button)
	tool_label = studio._label(box, "")
	box.move_child(tool_label, 6)
	layer_menu = MenuButton.new()
	layer_menu.text = "Camadas visuais"
	box.add_child(layer_menu)
	box.move_child(layer_menu, 7)
	for text in ["Criaturas", "Itens, armadilhas e portas", "Donos do terreno", "Areas de evento", "Avisos da validacao"]:
		layer_menu.get_popup().add_check_item(text)
		layer_menu.get_popup().set_item_checked(layer_menu.get_popup().get_item_count() - 1, true)
	layer_menu.get_popup().hide_on_checkable_item_selection = false
	layer_menu.get_popup().connect("id_pressed", self, "toggle_layer")


func activate(action: String):
	if studio.construction.placing:
		return
	match action:
		"paint":
			studio.construction.cancel()
			studio.studio_tabs.current_tab = 1
			studio.inspect_toggle.set_pressed_no_signal(false)
			studio._inspect_toggled(false)
		"select": studio._copy_area()
		"paste": studio._paste_area()
		"inspect":
			studio.studio_tabs.current_tab = 2
			studio.inspect_toggle.set_pressed_no_signal(true)
			studio._inspect_toggled(true)
		"base": studio._templates()
		"rotate", "mirror":
			if not studio.construction.mode in ["stamp", "paste"]:
				studio.status.text = "Prepare uma base ou uma colagem antes de girar/espelhar."
				return
			if action == "rotate":
				studio.construction.turns = (studio.construction.turns + 1) % 4
			else:
				studio.construction.mirrored = not studio.construction.mirrored
			studio.construction.update()
		"cancel": studio._cancel_construction()
	refresh()


func _unhandled_key_input(event):
	if not event is InputEventKey or not event.pressed or event.echo or event.control or event.alt or event.meta:
		return
	if not studio.panel.visible or not refs.oSelector.visible or not studio.construction.mode in ["stamp", "paste"]:
		return
	var focus = studio.panel.get_focus_owner()
	if focus is LineEdit or focus is TextEdit or dialog_open():
		return
	if event.scancode in [KEY_R, KEY_F]:
		activate("rotate" if event.scancode == KEY_R else "mirror")
		get_tree().set_input_as_handled()


func toggle_layer(index: int):
	layers[index] = not layers[index]
	layer_menu.get_popup().set_item_checked(index, layers[index])
	apply_layers()


func dialog_open() -> bool:
	for parent in [refs.oUi.get_node("UiSystem"), refs.oUiMessages]:
		for node in parent.get_children():
			if node is WindowDialog and node.is_visible_in_tree():
				return true
	return false


func _layer_for(node: Node) -> int:
	if node.is_in_group("Creature"):
		return 0
	if node.is_in_group("ActionPoint"):
		return 3
	if node.is_in_group("Object") or node.is_in_group("Trap") or node.is_in_group("Door"):
		return 1
	return -1


func apply_layers():
	for node in hidden_nodes.keys():
		if is_instance_valid(node):
			node.modulate = hidden_nodes[node]
	hidden_nodes.clear()
	if studio.advanced.pressed or refs.oEditor.currentView != refs.oEditor.VIEW_2D:
		return
	var candidates = get_tree().get_nodes_in_group("Instance")
	candidates.append(refs.oOverheadOwnership)
	candidates.append(studio.spatial_checks)
	for node in candidates:
		var index = 2 if node == refs.oOverheadOwnership else (4 if node == studio.spatial_checks else _layer_for(node))
		if index >= 0 and not layers[index]:
			hidden_nodes[node] = node.modulate
			var color = node.modulate
			color.a = 0
			node.modulate = color


func record_save(game: bool):
	var key = studio._sync_key(refs.oCurrentMap.path)
	var record = saved_versions.get(key, {"local": "", "game": "", "target": ""})
	if game:
		record.game = studio.recovery.last_game
		record.target = studio.installed_path
	else:
		record.local = studio.recovery.last_local
		# A fresh local save is not proof of a successful game synchronization.
		record.game = ""
	saved_versions[key] = record
	refresh()


func save_state() -> Dictionary:
	if refs.oDataSlab.get_cell(0, 0) == TileMap.INVALID_CELL:
		return {"text": "Nenhum mapa aberto", "color": Color("#bdc4d2")}
	var key = studio._sync_key(refs.oCurrentMap.path)
	var record = saved_versions.get(key, {"local": "", "game": "", "target": ""})
	if refs.oEditor.mapHasBeenEdited:
		return {"text": "ALTERACOES PENDENTES", "color": Color("#ffd079")}
	if not record.game.empty():
		return {"text": "ENVIADO AO JOGO " + record.game.get_slice(" ", 1) + "\nFase: " + record.target.get_file(), "color": Color("#8ee0af")}
	if not record.local.empty():
		return {"text": "SALVO LOCALMENTE " + record.local.get_slice(" ", 1) + "\nEnvio ao jogo nao confirmado.", "color": Color("#97cafa")}
	return {"text": "Mapa aberto | envio ao jogo nao confirmado", "color": Color("#bdc4d2")}


func refresh():
	var state = save_state()
	save_label.text = state.text
	save_label.add_color_override("font_color", state.color)
	var mode = studio.construction.mode
	var tool = "Inspecao" if studio.inspecting else ["Lapis", "Pincel", "Retangulo", "Preencher"][studio.tool_picker.selected]
	if mode == "select":
		tool = "Selecionar dois cantos"
	elif mode in ["stamp", "paste"]:
		tool = "Base" if mode == "stamp" else "Colagem"
		tool += " | %s graus%s" % [studio.construction.turns * 90, " | espelhado" if studio.construction.mirrored else ""]
	tool_label.text = "Ferramenta: " + tool
	for index in toolbar.get_child_count():
		var button = toolbar.get_child(index)
		button.disabled = studio.construction.placing or (index in [5, 6] and not mode in ["stamp", "paste"])
		if index < 5:
			button.set_pressed_no_signal([mode.empty() and not studio.inspecting, mode == "select", mode == "paste", studio.inspecting, mode == "stamp"][index])


func _process(delta):
	tick += delta
	if tick < 0.15:
		return
	tick = 0
	refs.oMessage.get_node("VBoxContainer").visible = not dialog_open()
	apply_layers()
	refresh()
