extends Node

var studio
var refs: Dictionary
var dialog: ConfirmationDialog
var entrance: OptionButton
var spawn: OptionButton
var enemy: OptionButton
var creature: OptionButton
var count: SpinBox
var level: SpinBox
var reward: OptionButton
var preview: TextEdit
var source = ""
var path = ""
var format = -1


func _ready():
	refs = studio.refs


func open_wizard():
	if not studio._has_map():
		return
	var error = studio.map_tools._script_error()
	if not error.empty():
		studio.map_tools._error(error)
		return
	if is_instance_valid(dialog):
		dialog.free()
	source = refs.oDataScript.data
	path = refs.oCurrentMap.path
	format = refs.oCurrentFormat.selected
	dialog = studio.map_tools._dialog("Assistente de missao encadeada")
	var box = studio.map_tools._body(dialog)
	studio._label(box, "Vermelho: explorar area > eliminar herois > receber recompensa > destruir inimigo.\nApenas uma cadeia por mapa. Aplicar novamente atualiza a mesma cadeia.\nO combate espera PLAYER_GOOD ficar sem criaturas. Por isso, nao pode coexistir com outros herois/eventos de surgimento.\nA cadeia substitui somente objetivos do Studio ou a vitoria padrao.")
	entrance = studio.map_tools._labelled_picker(box, "1. Area a explorar")
	spawn = studio.map_tools._labelled_picker(box, "2. Area de surgimento dos herois e da recompensa")
	for ap in get_tree().get_nodes_in_group("ActionPoint"):
		entrance.add_item("#%s" % ap.pointNumber, ap.pointNumber)
		spawn.add_item("#%s" % ap.pointNumber, ap.pointNumber)
	creature = studio.map_tools._labelled_picker(box, "Herois")
	for entry in refs.oScriptGenerator.get_creature_list():
		studio.map_tools._creature_option(creature, entry[0])
	creature.select(max(0, creature.get_item_index(6)))
	studio._label(box, "Quantidade / nivel")
	var row = HBoxContainer.new()
	box.add_child(row)
	count = studio._spin(row, 1, 20, 3)
	level = studio._spin(row, 1, 10, 3)
	reward = studio.map_tools._labelled_picker(box, "3. Recompensa (compativel com Gold e KeeperFX)")
	reward.add_item("Liberar poder de curar criaturas")
	reward.add_item("Receber dois feiticeiros de nivel 4")
	enemy = studio.map_tools._labelled_picker(box, "4. Coracao inimigo que encerra a missao")
	studio.map_tools._players(enemy)
	if enemy.get_item_count() > 1:
		enemy.select(1)
	preview = studio.map_tools._text_preview(box)
	for picker in [entrance, spawn, creature, reward, enemy]:
		picker.connect("item_selected", self, "_preview")
	for spin in [count, level]:
		spin.connect("value_changed", self, "_preview")
	dialog.connect("confirmed", self, "_apply")
	_preview()
	studio.map_tools._show(dialog)


func result(text: String, entry_number: int, spawn_number: int, subtype: int, quantity: int, creature_level: int, reward_kind: int, enemy_owner: int) -> Dictionary:
	var tools = studio.map_tools
	var stripped = tools.managed_block(text, "MISSION", [])
	if not stripped.error.empty():
		return stripped
	var base = stripped.text
	if enemy_owner == 0 or not refs.oInstances.check_for_dungeon_heart(enemy_owner) or not refs.oInstances.check_for_dungeon_heart(0):
		return {"text": text, "error": "Escolha um adversario com coracao no mapa. O Vermelho tambem precisa de um coracao."}
	for number in [entry_number, spawn_number]:
		var ap = refs.oInstances.return_action_point(number)
		if number <= 0 or ap == null:
			return {"text": text, "error": "Crie e selecione duas areas de evento validas."}
		var slab = refs.oDataSlab.get_cell(int(ap.locationX / 3), int(ap.locationY / 3))
		if not Slabs.data.has(slab) or Slabs.data[slab][Slabs.IS_SOLID] or slab in [Slabs.LAVA, Slabs.WATER]:
			return {"text": text, "error": "As areas precisam estar em terreno aberto e seco."}
	for id in get_tree().get_nodes_in_group("Creature"):
		if id.ownership == 4:
			return {"text": text, "error": "Ja existem herois no terreno. A cadeia simples precisa controlar o unico grupo de PLAYER_GOOD. Use Regras avancadas para combinar grupos."}
	for call in tools.patcher.parse(base).all_calls:
		if call.command in ["ADD_CREATURE_TO_LEVEL", "ADD_PARTY_TO_LEVEL", "ADD_TUNNELLER_TO_LEVEL", "ADD_TUNNELLER_PARTY_TO_LEVEL"] and call.args.size() > 0 and call.args[0] in ["PLAYER_GOOD", "ALL_PLAYERS"]:
			return {"text": text, "error": "Outro evento gera herois. Remova-o antes de criar a cadeia para que o combate nao espere por grupos de outra missao."}
	base = tools.patcher.set_block(base, ["IF(PLAYER0,ALL_DUNGEONS_DESTROYED == 1)", "\tWIN_GAME", "ENDIF"], false).text
	var no_goal = tools.managed_block(base, "GOAL", [])
	if not no_goal.error.empty():
		return no_goal
	base = no_goal.text
	for line in studio.checker.active_lines(base):
		if line.begins_with("WIN_GAME"):
			return {"text": text, "error": "Existe outra vitoria manual. Ajuste-a em Regras antes de usar este assistente."}
	var flag = -1
	var flag_regex = RegEx.new()
	for index in 8:
		flag_regex.compile("(?i)\\bFLAG%s\\b" % index)
		if flag_regex.search(base) == null:
			flag = index
			break
	if flag == -1:
		return {"text": text, "error": "Os oito flags classicos ja estao em uso. Nenhuma regra foi alterada."}
	if refs.oCurrentFormat.selected == Constants.OldFormat and get_tree().get_nodes_in_group("Creature").size() + quantity + (2 if reward_kind == 1 else 0) > 255:
		return {"text": text, "error": "A missao excederia o limite de criaturas do Gold."}
	var flag_name = "FLAG%s" % flag
	var species = Things.fetch_id_string(Things.TYPE.CREATURE, subtype)
	var prize = "MAGIC_AVAILABLE(PLAYER0,POWER_HEAL_CREATURE,1,1)" if reward_kind == 0 else "ADD_CREATURE_TO_LEVEL(PLAYER0,%s,%s,2,4,0)" % [Things.fetch_id_string(Things.TYPE.CREATURE, 21), spawn_number]
	var block = ["REM Explore a area, enfrente todos os herois, receba a recompensa e destrua o inimigo.",
		"IF(PLAYER0,%s == 0)" % flag_name,
		"\tIF_ACTION_POINT(%s,PLAYER0)" % entry_number,
		"\t\tADD_CREATURE_TO_LEVEL(PLAYER_GOOD,%s,%s,%s,%s,0)" % [species, spawn_number, quantity, creature_level],
		"\t\tSET_FLAG(PLAYER0,%s,1)" % flag_name, "\tENDIF", "ENDIF",
		"IF(PLAYER0,%s == 1)" % flag_name,
		"\tIF(PLAYER_GOOD,TOTAL_CREATURES == 0)",
		"\t\t" + prize, "\t\tSET_FLAG(PLAYER0,%s,2)" % flag_name, "\tENDIF", "ENDIF",
		"IF(PLAYER0,%s == 2)" % flag_name,
		"\tIF(%s,DUNGEON_DESTROYED == 1)" % tools._player_token(enemy_owner), "\t\tWIN_GAME", "\tENDIF", "ENDIF"]
	return tools.managed_block(base, "MISSION", block)


func current_result() -> Dictionary:
	return result(source, entrance.get_selected_id(), spawn.get_selected_id(), creature.get_selected_id(),
		int(count.value), int(level.value), reward.selected, enemy.get_selected_id())


func _preview(_value = 0):
	var output = current_result()
	preview.text = output.error if not output.error.empty() else output.text
	preview.cursor_set_line(preview.get_line_count() - 1)
	preview.center_viewport_to_cursor()


func _apply():
	if studio.map_tools._changed_script(source, path, format):
		return
	var output = current_result()
	if not output.error.empty():
		studio.map_tools._error(output.error)
		return
	if studio.recovery.capture("antes-missao").empty():
		return
	refs.oScriptEditor.load_generated_text(output.text)
	dialog.hide()
	studio.status.text = "Missao encadeada criada. Confira a previa em Regras, salve e reinicie a fase."
