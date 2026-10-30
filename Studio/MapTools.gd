extends Node

var studio
var refs: Dictionary
var patcher = BasicScriptPatcher.new()
var powers: ConfirmationDialog
var power_player: OptionButton
var power_rows = []
var power_source = ""
var power_path = ""
var power_format = -1
var current_player = 0
var power_preview: TextEdit
var events: ConfirmationDialog
var event_kind: OptionButton
var enemy: OptionButton
var trigger: OptionButton
var destination: OptionButton
var event_creature: OptionButton
var event_count: SpinBox
var event_level: SpinBox
var event_source = ""
var event_path = ""
var event_format = -1
var event_preview: TextEdit
var element_dialog: ConfirmationDialog
var element = null
var element_owner: OptionButton
var element_level: SpinBox
var element_range: SpinBox


func _ready():
	refs = studio.refs


func _dialog(title: String) -> ConfirmationDialog:
	var dialog = ConfirmationDialog.new()
	dialog.window_title = title
	dialog.resizable = true
	dialog.rect_min_size = Vector2(640, 440)
	dialog.get_ok().text = "Aplicar"
	dialog.get_cancel().text = "Cancelar"
	dialog.dialog_hide_on_ok = false
	refs.oUi.get_node("UiSystem").add_child(dialog)
	return dialog


func _body(dialog: WindowDialog) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.rect_min_size = Vector2(600, 360)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box


func _show(dialog: WindowDialog):
	var available = get_viewport().size / dialog.get_global_transform().get_scale()
	dialog.rect_size = Vector2(min(900, available.x * 0.9), min(680, available.y * 0.85))
	Utils.popup_centered(dialog)
	if dialog is AcceptDialog:
		dialog.get_ok().text = "Aplicar"


func _players(picker: OptionButton):
	for owner in [0, 1, 2, 3, 6, 7, 8]:
		if refs.oCurrentFormat.selected == Constants.OldFormat and owner > 3:
			continue
		picker.add_item(studio.OWNER_NAMES[owner], owner)


func _player_token(owner: int) -> String:
	return {0: "PLAYER0", 1: "PLAYER1", 2: "PLAYER2", 3: "PLAYER3", 4: "PLAYER_GOOD", 5: "PLAYER_NEUTRAL", 6: "PLAYER4", 7: "PLAYER5", 8: "PLAYER6"}[owner]


func _script_error() -> String:
	if refs.oCurrentMap.LuaScript_enabled:
		return "Este mapa usa Lua. Edite suas regras nas ferramentas avancadas para evitar regras conflitantes."
	if patcher.parse(refs.oDataScript.data).error_line != 0:
		return "O script possui IF/ENDIF desequilibrados. Corrija em Regras antes de usar este formulario."
	return ""


func _error(text: String):
	print("Studio: " + text)
	refs.oMessage.big("Ferramentas do mapa", text)


func _text_preview(box: VBoxContainer) -> TextEdit:
	studio._label(box, "Script resultante (previa; nada muda ate Aplicar)")
	var edit = TextEdit.new()
	edit.readonly = true
	edit.rect_min_size = Vector2(560, 140)
	box.add_child(edit)
	return edit


func _labelled_picker(box: VBoxContainer, title: String) -> OptionButton:
	studio._label(box, title)
	var picker = OptionButton.new()
	box.add_child(picker)
	return picker


func _changed_script(source: String, path: String, format: int) -> bool:
	if refs.oDataScript.data != source or refs.oCurrentMap.path != path or refs.oCurrentFormat.selected != format:
		_error("O mapa ou o script mudou com o formulario aberto. Feche e abra novamente; nenhuma regra foi sobrescrita.")
		return true
	var error = _script_error()
	if not error.empty():
		_error(error)
		return true
	return false


func open_powers():
	var error = _script_error()
	if not error.empty():
		_error(error)
		return
	if is_instance_valid(powers):
		powers.free()
	powers = _dialog("Poderes por jogador - nao coloca livros")
	power_source = refs.oDataScript.data
	power_path = refs.oCurrentMap.path
	power_format = refs.oCurrentFormat.selected
	var box = _body(powers)
	studio._label(box, "Muda somente os poderes alterados neste formulario.\nInicio: liberado. Pesquisar: exige biblioteca e pesquisa.\nIndisponivel: nao pode ser pesquisado. Livros no terreno sao outra opcao.\nRegras condicionais existentes continuam valendo durante a partida.")
	power_player = _labelled_picker(box, "Jogador")
	_players(power_player)
	current_player = 0
	power_player.connect("item_selected", self, "_power_player_changed")
	var rows = VBoxContainer.new()
	rows.name = "PowerRows"
	box.add_child(rows)
	power_rows.clear()
	for magic in refs.oScriptGenerator.get_magic_list():
		var row = HBoxContainer.new()
		rows.add_child(row)
		var label = studio._label(row, studio.catalog.object_name(magic[0]))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.hint_tooltip = studio.catalog.object_description(magic[0])
		var state = OptionButton.new()
		for text in ["Indisponivel", "Pesquisar", "Inicio"]:
			state.add_item(text)
		row.add_child(state)
		power_rows.append({"control": state, "power": magic[1], "initial": 0})
		state.connect("item_selected", self, "_update_power_preview")
	power_preview = _text_preview(box)
	powers.connect("confirmed", self, "_apply_powers")
	_read_powers()
	_show(powers)


func _power_player_changed(index: int):
	for row in power_rows:
		if row.control.selected != row.initial:
			power_player.select(current_player)
			_error("Aplique as alteracoes ou feche e cancele antes de trocar de jogador.")
			return
	current_player = index
	_read_powers()


func _read_powers():
	var player = _player_token(power_player.get_item_id(current_player))
	var parsed = patcher.parse(power_source)
	for row in power_rows:
		var state = 0
		# Last applicable top-level call wins, whether shared or player-specific.
		for call in parsed.calls:
			if call.command == "MAGIC_AVAILABLE" and call.line.depth == 0 and call.args[0] in ["ALL_PLAYERS", player] and call.args[1] == row.power:
				state = 2 if int(call.args[3]) != 0 else (1 if int(call.args[2]) != 0 else 0)
		row.initial = state
		row.control.select(state)
	_update_power_preview()


func powers_result() -> String:
	var text = power_source
	var player = _player_token(power_player.get_item_id(current_player))
	for row in power_rows:
		if row.control.selected == row.initial:
			continue
		text = patcher.remove_call(text, "MAGIC_AVAILABLE", [player, row.power]).text
		var values = [["0", "0"], ["1", "0"], ["1", "1"]][row.control.selected]
		# Append after shared settings so the explicit per-player override takes effect.
		text = patcher.insert(text, text.length(), "MAGIC_AVAILABLE(" + player + "," + row.power + "," + PoolStringArray(values).join(",") + ")", true).text
	return text


func _update_power_preview(_index = 0):
	power_preview.text = powers_result()
	power_preview.cursor_set_line(power_preview.get_line_count() - 1)
	power_preview.center_viewport_to_cursor()


func _apply_powers():
	if _changed_script(power_source, power_path, power_format):
		return
	var text = powers_result()
	if text != power_source:
		refs.oScriptEditor.load_generated_text(text)
	powers.hide()
	studio.status.text = "Poderes atualizados. Salve o mapa para gravar as regras."


func selected_element():
	var id = refs.oInspector.inspectingInstance
	if is_instance_valid(id) and id.is_in_group("Instance"):
		return id
	return null


func selection_summary() -> String:
	var id = selected_element()
	if id == null:
		return "Inspecao: nenhum elemento selecionado."
	if id.is_in_group("ActionPoint"):
		return "Area #%s | raio %s subblocos" % [id.pointNumber, id.pointRange]
	return "%s | dono: %s%s" % [Things.fetch_name(id.thingType, id.subtype), studio.OWNER_NAMES[id.ownership], " | nivel %s" % id.creatureLevel if id.thingType == Things.TYPE.CREATURE else ""]


func _editable(id) -> bool:
	if id == null:
		_error("Ative Inspecionar e clique em uma criatura, item, armadilha ou area.")
		return false
	if id.is_in_group("ActionPoint"):
		return true
	if not id.thingType in [Things.TYPE.CREATURE, Things.TYPE.OBJECT, Things.TYPE.TRAP] or (id.thingType == Things.TYPE.OBJECT and id.parentTile != 65535):
		_error("Este elemento faz parte do terreno ou exige propriedades avancadas. Use as ferramentas avancadas; portas e coracoes devem ser editados como salas/terreno.")
		return false
	return true


func open_inspector():
	element = selected_element()
	if not _editable(element):
		return
	if is_instance_valid(element_dialog):
		element_dialog.free()
	element_dialog = _dialog("Editar elemento selecionado")
	var box = _body(element_dialog)
	studio._label(box, selection_summary())
	studio._label(box, "Posicao (subblocos): %s, %s. Para mover, use as ferramentas de colocacao do Unearth." % [element.locationX, element.locationY])
	element_owner = _labelled_picker(box, "Dono")
	for owner in studio.OWNER_NAMES.size():
		if refs.oCurrentFormat.selected == Constants.OldFormat and owner > 5:
			continue
		element_owner.add_item(studio.OWNER_NAMES[owner], owner)
	element_owner.select(element_owner.get_item_index(element.ownership))
	var collectible = element.thingType == Things.TYPE.OBJECT and Things.DATA_OBJECT.has(element.subtype) and Things.collectible_belonging.has(Things.DATA_OBJECT[element.subtype][Things.GENRE])
	element_owner.disabled = collectible or element.is_in_group("ActionPoint")
	if collectible:
		studio._label(box, "O dono deste item segue a sala correspondente; fora dela, fica neutro.")
	studio._label(box, "Nivel da criatura")
	element_level = studio._spin(box, 1, 10, 1)
	element_level.editable = element.thingType == Things.TYPE.CREATURE
	if element_level.editable:
		element_level.value = element.creatureLevel
	studio._label(box, "Raio da area (subblocos)")
	element_range = studio._spin(box, 1, 30, 3)
	element_range.editable = element.is_in_group("ActionPoint")
	if element_range.editable:
		element_range.step = 1.0 / 256.0
		element_range.max_value = max(30, element.pointRange)
		element_range.min_value = 0
		element_range.value = element.pointRange
	element_dialog.connect("confirmed", self, "_apply_element")
	_show(element_dialog)


func _apply_element():
	if not is_instance_valid(element) or not element.is_in_group("Instance"):
		_error("O elemento foi removido ou o mapa mudou. Selecione-o novamente.")
		return
	if not element_owner.disabled:
		element.ownership = element_owner.get_selected_id()
	if element_level.editable:
		element.creatureLevel = int(element_level.value)
	if element_range.editable:
		element.pointRange = element_range.value
	refs.oThingDetails.update_details()
	refs.oEditor.mapHasBeenEdited = true
	element_dialog.hide()


func duplicate_element():
	var id = selected_element()
	if not _editable(id):
		return
	refs.oSelection.paintThingType = id.thingType
	refs.oSelection.paintSubtype = id.subtype
	refs.oSelection.paintOwnership = id.ownership
	studio.owner_picker.select(studio.owner_picker.get_item_index(id.ownership))
	refs.oPlacingSettings.replicate_instance_settings(id)
	refs.oUseSlabOwnerCheckBox.pressed = false
	refs.oPickThingWindow.set_selection(id.thingType, id.subtype)
	refs.oPlacingSettings.set_placing_tab_and_update_it()
	studio.inspect_toggle.set_pressed_no_signal(false)
	studio._inspect_toggled(false)
	studio.studio_tabs.current_tab = 1
	studio.preview.texture = Things.fetch_sprite(id.thingType, id.subtype)
	studio.selected_label = "Copia: " + selection_summary()
	studio.selected_description = "Clique em um local livre para colocar a copia."
	var source_category = {Things.TYPE.CREATURE: 2, Things.TYPE.TRAP: 3, Things.TYPE.EXTRA: 7}.get(id.thingType, -1)
	if id.thingType == Things.TYPE.OBJECT and Things.DATA_OBJECT.has(id.subtype):
		source_category = {"SPECIALBOX": 5, "SPELLBOOK": 6}.get(Things.DATA_OBJECT[id.subtype][Things.GENRE], -1)
	studio.selected_entry = "%s:%s" % [source_category, id.subtype] if source_category >= 0 else ""
	studio._update_favorite_button()
	studio.status.text = "Copia preparada; clique em um local livre. O original nao foi movido."


func delete_element():
	var id = selected_element()
	if not _editable(id):
		return
	if id.is_in_group("ActionPoint") and _action_point_used(id.pointNumber):
		_error("Esta area e usada por um evento. Remova primeiro o evento em Objetivos e eventos.")
		return
	refs.oSelection.manually_delete_one_instance(id)
	studio.status.text = "Elemento removido. Ctrl+Z desfaz a remocao."


func _action_point_used(number: int) -> bool:
	var pattern = RegEx.new()
	pattern.compile("(?im)^\\s*(IF_ACTION_POINT|RESET_ACTION_POINT|REVEAL_MAP_LOCATION)\\s*\\(\\s*%s\\s*[,)]|^\\s*ADD_(CREATURE|PARTY)_TO_LEVEL\\s*\\(\\s*[^,]+,\\s*[^,]+,\\s*%s\\s*[,)]" % [number, number])
	return pattern.search(refs.oDataScript.data) != null


func open_events():
	var error = _script_error()
	if not error.empty():
		_error(error)
		return
	if is_instance_valid(events):
		events.free()
	events = _dialog("Objetivos e eventos - partida individual vermelha")
	event_source = refs.oDataScript.data
	event_path = refs.oCurrentMap.path
	event_format = refs.oCurrentFormat.selected
	var box = _body(events)
	studio._label(box, "Formularios para partidas individuais (voce: Vermelho).\nAs regras manuais sao preservadas. Cada area pode ter um evento deste formulario.\nUma vitoria especifica substitui apenas a vitoria padrao 'todos os inimigos'.")
	event_kind = _labelled_picker(box, "Acao")
	for text in ["Vencer ao destruir um coracao inimigo", "Ao entrar numa area, surgem herois", "Remover objetivo criado pelo Studio", "Remover evento da area"]:
		event_kind.add_item(text)
	enemy = _labelled_picker(box, "Coracao inimigo (objetivo)")
	_players(enemy)
	if enemy.get_item_count() > 1:
		enemy.select(1)
	trigger = _labelled_picker(box, "Area de entrada do Vermelho (evento)")
	destination = _labelled_picker(box, "Area de surgimento (evento)")
	for ap in get_tree().get_nodes_in_group("ActionPoint"):
		for picker in [trigger, destination]:
			picker.add_item("#%s (%s, %s)" % [ap.pointNumber, ap.locationX, ap.locationY], ap.pointNumber)
	studio._label(box, "Crie areas pela categoria Areas de evento; ajuste o raio e clique no mapa.\nO evento dispara uma vez. Herois pertencem a PLAYER_GOOD.")
	event_creature = _labelled_picker(box, "Criatura dos herois")
	for creature in refs.oScriptGenerator.get_creature_list():
		event_creature.add_item(Things.fetch_name(Things.TYPE.CREATURE, creature[0]), creature[0])
	event_creature.select(max(0, event_creature.get_item_index(6)))
	studio._label(box, "Quantidade / nivel")
	var row = HBoxContainer.new()
	box.add_child(row)
	event_count = studio._spin(row, 1, 20, 3)
	event_level = studio._spin(row, 1, 10, 3)
	event_preview = _text_preview(box)
	for picker in [event_kind, enemy, trigger, destination, event_creature]:
		picker.connect("item_selected", self, "_update_event_preview")
	for spin in [event_count, event_level]:
		spin.connect("value_changed", self, "_update_event_preview")
	events.connect("confirmed", self, "_apply_event")
	_update_event_preview()
	_show(events)


func managed_block(source: String, key: String, block: Array) -> Dictionary:
	var first = "REM STUDIO-BEGIN " + key
	var last = "REM STUDIO-END " + key
	var parsed = patcher.parse(source)
	var begins = []
	var ends = []
	for line in parsed.lines:
		if line.text.strip_edges() == first:
			begins.append(line)
		if line.text.strip_edges() == last:
			ends.append(line)
	if begins.size() != ends.size() or begins.size() > 1:
		return {"text": source, "error": "Marcadores do Studio alterados. Corrija o bloco em Regras antes de continuar."}
	if not begins.empty():
		if begins[0].number >= ends[0].number or begins[0].depth != 0 or ends[0].depth != 0:
			return {"text": source, "error": "O bloco do Studio nao esta completo no nivel principal do script."}
		source = source.substr(0, begins[0].start) + source.substr(ends[0].end)
	if not block.empty():
		source = patcher.insert(source, source.length(), first + "\n" + PoolStringArray(block).join("\n") + "\n" + last, true).text
	return {"text": source, "error": ""}


func event_result() -> Dictionary:
	var text = event_source
	var key = "GOAL"
	var block = []
	if event_kind.selected == 0:
		var owner = enemy.get_selected_id()
		if owner == 0 or not refs.oInstances.check_for_dungeon_heart(owner) or not refs.oInstances.check_for_dungeon_heart(0):
			return {"text": text, "error": "Escolha um adversario com coracao no mapa. O Vermelho tambem precisa de um coracao."}
		# Replace only the generator's known default, never an arbitrary victory script.
		text = patcher.set_block(text, ["IF(PLAYER0,ALL_DUNGEONS_DESTROYED == 1)", "\tWIN_GAME", "ENDIF"], false).text
		var without_goal = managed_block(text, key, [])
		if not without_goal.error.empty():
			return without_goal
		var win = RegEx.new()
		win.compile("(?im)^\\s*WIN_GAME\\b")
		if win.search(without_goal.text) != null:
			return {"text": text, "error": "Ha outra vitoria personalizada no script. Ajuste-a em Regras antes de definir este objetivo; ela nao sera apagada automaticamente."}
		block = ["IF(" + _player_token(owner) + ",DUNGEON_DESTROYED == 1)", "\tWIN_GAME", "ENDIF"]
	elif event_kind.selected in [1, 3]:
		if trigger.get_selected_id() < 1 or refs.oInstances.return_action_point(trigger.get_selected_id()) == null:
			return {"text": text, "error": "Crie e selecione uma area de entrada valida."}
		key = "EVENT_" + str(trigger.get_selected_id())
		if event_kind.selected == 1:
			if destination.get_selected_id() < 1 or refs.oInstances.return_action_point(destination.get_selected_id()) == null:
				return {"text": text, "error": "Selecione uma area de surgimento valida."}
			var area = refs.oInstances.return_action_point(destination.get_selected_id())
			var slab = refs.oDataSlab.get_cell(int(area.locationX / 3), int(area.locationY / 3))
			if not Slabs.data.has(slab) or Slabs.data[slab][Slabs.IS_SOLID] or slab == Slabs.LAVA:
				return {"text": text, "error": "A area de surgimento precisa estar em terreno aberto e sem lava."}
			var creature = Things.fetch_id_string(Things.TYPE.CREATURE, event_creature.get_selected_id())
			block = ["IF_ACTION_POINT(%s,PLAYER0)" % trigger.get_selected_id(),
				"\tADD_CREATURE_TO_LEVEL(PLAYER_GOOD,%s,%s,%s,%s,0)" % [creature, destination.get_selected_id(), int(event_count.value), int(event_level.value)], "ENDIF"]
	return managed_block(text, key, block)


func _update_event_preview(_value = 0):
	var result = event_result()
	event_preview.text = result.error if not result.error.empty() else result.text
	event_preview.cursor_set_line(event_preview.get_line_count() - 1)
	event_preview.center_viewport_to_cursor()
	enemy.disabled = event_kind.selected != 0
	for picker in [trigger, destination, event_creature]:
		picker.disabled = not event_kind.selected in [1, 3] or (event_kind.selected == 3 and picker != trigger)
	event_count.editable = event_kind.selected == 1
	event_level.editable = event_kind.selected == 1


func _apply_event():
	if _changed_script(event_source, event_path, event_format):
		return
	var result = event_result()
	if not result.error.empty():
		_error(result.error)
		return
	if result.text != event_source:
		refs.oScriptEditor.load_generated_text(result.text)
	events.hide()
	studio.status.text = "Regras atualizadas. Salve o mapa e reinicie a fase para usa-las."
