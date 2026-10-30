extends Node2D

const COPY_FIELDS = ["creatureLevel", "creatureName", "creatureGold", "creatureInitialHealth",
	"goldValue", "boxNumber", "orientation", "effectRange"]
var studio
var refs: Dictionary
var mode = ""
var first = Vector2(-1, -1)
var clipboard = {}
var pending = {}
var turns = 0
var mirrored = false
var destination_owner = -1
var overwrite = false
var source_path = ""
var source_format = -1
var placing = false
var dialog: ConfirmationDialog
var template_picker: OptionButton
var size_picker: SpinBox
var owner_picker: OptionButton
var confirm: ConfirmationDialog
var pending_clipboard = {}
var pending_options = {}
var transform_dialog: ConfirmationDialog
var turn_picker: OptionButton
var mirror_check: CheckBox
var replace_check: CheckBox
var target_owner: OptionButton
var selected_rect = Rect2()
var selected_path = ""
var preview_error = ""
var preview_elapsed = 0.0
var ghost_icons = {}
var preview_font: DynamicFont


func _ready():
	refs = studio.refs
	z_index = 90
	preview_font = DynamicFont.new()
	preview_font.font_data = load("res://Theme/Hack_Regular.ttf")
	preview_font.size = 14


func cancel():
	mode = ""
	pending.clear()
	first = Vector2(-1, -1)
	update()


func _process(_delta):
	visible = refs.oEditor.currentView == refs.oEditor.VIEW_2D and not studio.advanced.pressed
	if mode != "" and (source_path != refs.oCurrentMap.path or source_format != refs.oCurrentFormat.selected):
		cancel()
	if mode != "":
		preview_elapsed += _delta
		if preview_elapsed >= 0.15:
			preview_elapsed = 0
			preview_error = placement_error(refs.oSelector.cursorTile) if mode in ["stamp", "paste"] else ""
		update()


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") and mode != "":
		cancel()
		studio.status.text = "Operacao de construcao cancelada."
		get_tree().set_input_as_handled()


func _draw():
	if selected_rect.size != Vector2.ZERO and selected_path == refs.oCurrentMap.path:
		draw_rect(Rect2(selected_rect.position * 96, selected_rect.size * 96), Color(0.35, 0.85, 1, 0.9), false, 5)
	if mode.empty() or not refs.oSelector.visible:
		return
	var cursor = refs.oSelector.cursorTile
	var rect = Rect2(cursor, Vector2.ONE)
	if mode == "select" and first.x >= 0:
		rect = Rect2(Vector2(min(first.x, cursor.x), min(first.y, cursor.y)), (first - cursor).abs() + Vector2.ONE)
	elif mode in ["stamp", "paste"] and not clipboard.empty():
		rect.size = transformed_size()
	var color = Color("#74e5ab") if preview_error.empty() else Color("#ff807a")
	if mode == "select":
		color = Color("#78ceff")
		var bounds = Rect2(Vector2.ZERO, Vector2(M.xSize, M.ySize) * 96)
		var world = Rect2(rect.position * 96, rect.size * 96)
		for outside in [Rect2(0, 0, bounds.size.x, world.position.y),
				Rect2(0, world.end.y, bounds.size.x, max(0, bounds.size.y - world.end.y)),
				Rect2(0, world.position.y, world.position.x, world.size.y),
				Rect2(world.end.x, world.position.y, max(0, bounds.size.x - world.end.x), world.size.y)]:
			draw_rect(outside, Color(0, 0, 0, 0.35))
	else:
		for cell in clipboard.cells:
			var pos = cursor + transform_point(cell[0], clipboard.size, true)
			var tile_color = _slab_color(cell[1])
			tile_color.a = 0.65
			draw_rect(Rect2(pos * 96 + Vector2.ONE * 2, Vector2.ONE * 92), tile_color)
			if destination_conflict(pos):
				draw_rect(Rect2(pos * 96, Vector2.ONE * 96), Color(1, 0.15, 0.15, 0.5))
				draw_line(pos * 96, (pos + Vector2.ONE) * 96, Color("#ffcccc"), 4)
		for thing in clipboard.things:
			var point = cursor * 96 + transform_point(thing.pos, clipboard.size * 3, false) * 32
			var key = str([thing.type, thing.subtype])
			if not ghost_icons.has(key):
				ghost_icons[key] = Things.fetch_icon_sprite(thing.type, thing.subtype, Vector2(48, 48), 2.0)
			if ghost_icons[key] != null:
				draw_texture_rect(ghost_icons[key], Rect2(point - Vector2.ONE * 32, Vector2.ONE * 64), false, Color(1, 1, 1, 0.7))
			else:
				draw_circle(point, 15, color)
	draw_rect(Rect2(rect.position * 96, rect.size * 96), Color(color.r, color.g, color.b, 0.1))
	draw_rect(Rect2(rect.position * 96, rect.size * 96), color, false, 5)
	var summary = "%s x %s blocos" % [rect.size.x, rect.size.y]
	if mode in ["stamp", "paste"]:
		summary += " | %s elementos | %s graus%s" % [clipboard.things.size(), turns * 90, " | espelho" if mirrored else ""]
		summary += "\n" + ("Permitido | R: girar | F: espelhar" if preview_error.empty() else preview_error)
	else:
		var counts = selection_counts(rect)
		summary += " | %s criaturas | %s itens" % [counts.creatures, counts.items]
	var zoom = refs.oCamera2D.zoom.x
	var label_pos = rect.position * 96 + Vector2(0, -42 * zoom)
	draw_set_transform(label_pos, 0, Vector2.ONE * zoom)
	draw_rect(Rect2(-6, -16, 580, 40), Color(0.08, 0.09, 0.12, 0.94))
	var line_y = 0
	for line in summary.split("\n"):
		draw_string(preview_font, Vector2(0, line_y), line, color, 570)
		line_y += 18
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _slab_color(slab: int) -> Color:
	return {0: Color("#595c67"), 1: Color("#d8ad35"), 2: Color("#906033"),
		10: Color("#b09c73"), 11: Color("#ad4947"), 12: Color("#f35420"),
		13: Color("#448ed0"), 14: Color("#9b72dc"), 26: Color("#e74c64"),
		38: Color("#95ad6e"), 36: Color("#d9ac72"), 16: Color("#e8bf57")}.get(slab, Color("#8fa2b8"))


func selection_counts(rect: Rect2) -> Dictionary:
	var counts = {"creatures": 0, "items": 0}
	for node in get_tree().get_nodes_in_group("Instance"):
		if rect.has_point(Vector2(node.locationX, node.locationY) / 3):
			if node.is_in_group("Creature"):
				counts.creatures += 1
			elif node.is_in_group("Object") or node.is_in_group("Trap") or node.is_in_group("Door"):
				counts.items += 1
	return counts


func destination_conflict(pos: Vector2) -> bool:
	if not Rect2(Vector2.ONE, Vector2(M.xSize - 2, M.ySize - 2)).has_point(pos):
		return true
	var slab = refs.oDataSlab.get_cellv(pos)
	if slab == Slabs.DUNGEON_HEART or (not overwrite and not slab in [Slabs.EARTH, Slabs.ROCK, Slabs.PATH]):
		return true
	for node in get_tree().get_nodes_in_group("slab_location_group_%s_%s" % [int(pos.x), int(pos.y)]):
		if node.is_in_group("ActionPoint") or (node.is_in_group("Object") and (node.subtype == 5 or node.subtype in Things.LIST_OF_HEROGATES)):
			return true
		if not overwrite and (node.is_in_group("Creature") or node.is_in_group("Trap") or (node.is_in_group("Object") and node.parentTile == 65535)):
			return true
	return false


func field_input() -> bool:
	if mode.empty() and not placing:
		return false
	if placing:
		return true
	if refs.oSelector.visible and Input.is_action_just_pressed("mouse_left"):
		var cursor = refs.oSelector.cursorTile
		if mode == "select":
			if first.x < 0:
				first = cursor
				studio.status.text = "Escolha o canto oposto da area. Esc cancela."
			else:
				var placement_issue = placement_error(cursor)
				if not placement_issue.empty():
					studio.map_tools._error(placement_issue)
					return true
				var rect = Rect2(Vector2(min(first.x, cursor.x), min(first.y, cursor.y)), (first - cursor).abs() + Vector2.ONE)
				var error = capture(rect)
				cancel()
				if not error.empty():
					studio.map_tools._error(error)
				else:
					open_transform()
		else:
			pending = {"origin": cursor, "path": refs.oCurrentMap.path, "format": refs.oCurrentFormat.selected}
			pending_clipboard = clipboard.duplicate(true)
			pending_options = {"turns": turns, "mirrored": mirrored, "owner": destination_owner, "overwrite": overwrite}
			if not is_instance_valid(confirm):
				confirm = studio.map_tools._dialog("Confirmar construcao")
				confirm.connect("confirmed", self, "_confirmed")
			confirm.dialog_text = "Aplicar %s x %s blocos em (%s, %s)?\n%s\nA copia de seguranca fica no Historico; nada e enviado ao jogo ate Salvar." % [transformed_size().x, transformed_size().y, cursor.x, cursor.y, "Substituicao de terreno autorizada. Coracoes e areas existentes continuam protegidos." if overwrite else "Destino protegido: somente terra, rocha ou caminho neutro sem elementos."]
			studio.map_tools._show(confirm)
	return true


func open_templates():
	if not studio._has_map():
		return
	if is_instance_valid(dialog):
		dialog.free()
	dialog = studio.map_tools._dialog("Bases e salas prontas")
	var box = studio.map_tools._body(dialog)
	studio._label(box, "Escolha e clique no mapa para posicionar pelo canto superior esquerdo.\nA base conecta coracao, portal e salas e coloca quatro imps.\nRegras iniciais de ouro, salas e IA sao adicionadas apenas se ausentes.")
	template_picker = studio.map_tools._labelled_picker(box, "Modelo")
	for text in ["Base completa", "Tesouro", "Dormitorio", "Galinheiro", "Treinamento", "Biblioteca", "Oficina"]:
		template_picker.add_item(text)
	studio._label(box, "Tamanho das salas (coracao e portal sempre 3 x 3)")
	size_picker = studio._spin(box, 3, 7, 3)
	size_picker.step = 2
	owner_picker = studio.map_tools._labelled_picker(box, "Dono")
	studio.map_tools._players(owner_picker)
	owner_picker.select(max(0, owner_picker.get_item_index(refs.oSelection.paintOwnership)))
	dialog.connect("confirmed", self, "_prepare_template")
	studio.map_tools._show(dialog)


func template_data(kind: int, size: int, owner: int) -> Dictionary:
	var cells = []
	var things = []
	var width = size
	var height = size
	if kind == 0:
		width = size * 3 + 4
		height = size * 2 + 3
		var rooms = [Slabs.DUNGEON_HEART, Slabs.TREASURE_ROOM, Slabs.LAIR, Slabs.PORTAL, Slabs.HATCHERY, Slabs.TRAINING_ROOM]
		for y in height:
			for x in width:
				cells.append([Vector2(x, y), Slabs.CLAIMED_GROUND, owner])
		for index in rooms.size():
			var start = Vector2(1 + (index % 3) * (size + 1), 1 + int(index / 3) * (size + 1))
			var room_size = 3 if index in [0, 3] else size
			for y in room_size:
				for x in room_size:
					cells.append([start + Vector2(x, y), rooms[index], owner])
		for offset in [Vector2(0, 0), Vector2(2, 0), Vector2(0, 2), Vector2(2, 2)]:
			things.append({"type": Things.TYPE.CREATURE, "subtype": 23, "owner": owner, "pos": Vector2(4.5, 4.5) + offset, "fields": {"creatureLevel": 1}})
	else:
		var slab = [0, Slabs.TREASURE_ROOM, Slabs.LAIR, Slabs.HATCHERY, Slabs.TRAINING_ROOM, Slabs.LIBRARY, Slabs.WORKSHOP][kind]
		for y in size:
			for x in size:
				cells.append([Vector2(x, y), slab, owner])
	return {"size": Vector2(width, height), "cells": cells, "things": things, "base_owner": owner if kind == 0 else -1, "heart_owners": [owner] if kind == 0 else [], "format": refs.oCurrentFormat.selected}


func _prepare_template():
	clipboard = template_data(template_picker.selected, int(size_picker.value), owner_picker.get_selected_id())
	turns = 0
	mirrored = false
	destination_owner = -1
	overwrite = false
	_arm("stamp")
	dialog.hide()


func _arm(next_mode: String):
	source_path = refs.oCurrentMap.path
	source_format = refs.oCurrentFormat.selected
	mode = next_mode
	preview_error = placement_error(refs.oSelector.cursorTile) if mode in ["stamp", "paste"] else ""
	studio.inspect_toggle.set_pressed_no_signal(false)
	studio.inspecting = false
	refs.oSelector.holdClickOnInstance = null
	refs.oRectangleSelection.clear()
	studio.status.text = "Clique no mapa para %s. Esc cancela." % ("selecionar dois cantos" if mode == "select" else "posicionar; depois confirme")


func begin_copy():
	if not studio._has_map() or placing:
		return
	first = Vector2(-1, -1)
	selected_rect = Rect2()
	_arm("select")


func capture(rect: Rect2) -> String:
	if rect.size.x < 1 or rect.size.y < 1 or not Rect2(Vector2.ONE, Vector2(M.xSize - 2, M.ySize - 2)).encloses(rect):
		return "Selecione uma area dentro das bordas do mapa."
	var things = []
	var cells = []
	var heart_owners = {}
	var rooms_checked = {}
	var lights = []
	var doors = []
	for y in int(rect.size.y):
		for x in int(rect.size.x):
			var pos = rect.position + Vector2(x, y)
			var slab = refs.oDataSlab.get_cellv(pos)
			if refs.oDataFakeSlab.get_cellv(pos) > 0 or slab >= 1000 or not Slabs.data.has(slab):
				return "Esta area usa geometria personalizada. A copia por blocos suporta terrenos padrao; use as ferramentas avancadas para geometria personalizada."
			var room_owner = refs.oDataOwnership.get_cellv_ownership(pos)
			if slab in [Slabs.DUNGEON_HEART, Slabs.PORTAL] and not rooms_checked.has(pos):
				var region = _room_region(pos, slab, room_owner)
				if region.size() < 9:
					return "A selecao contem coracao ou portal incompleto (menor que 3 x 3). Corrija a estrutura antes de copiar."
				for room_pos in region:
					if not rect.has_point(room_pos):
						return "Selecione o coracao ou portal inteiro. Uma copia parcial deixaria a estrutura incompleta."
					rooms_checked[room_pos] = true
				if slab == Slabs.DUNGEON_HEART:
					if heart_owners.has(room_owner) or room_owner in [4, 5]:
						return "A selecao possui coracoes com dono ou quantidade invalidos. Copie uma base por vez."
					heart_owners[room_owner] = true
			cells.append([Vector2(x, y), slab, room_owner, refs.oDataLiquid.get_cellv(pos)])
	for id in get_tree().get_nodes_in_group("Instance"):
		var pos = Vector2(id.locationX, id.locationY)
		if not rect.has_point(pos / 3):
			continue
		if id.is_in_group("ActionPoint"):
			return "A selecao contem areas de evento. Copie uma area sem esses elementos para nao duplicar numeros e referencias de scripts."
		if id.is_in_group("Light"):
			if id.parentTile == 65535:
				lights.append({"pos": pos - rect.position * 3, "height": id.locationZ, "range": id.lightRange, "intensity": id.lightIntensity})
			continue
		if id.thingType == Things.TYPE.DOOR:
			doors.append({"pos": pos - rect.position * 3, "locked": id.doorLocked, "owner": id.ownership})
			continue
		if id.thingType == Things.TYPE.OBJECT and id.subtype == 5:
			continue
		if id.thingType in [Things.TYPE.OBJECT, Things.TYPE.EFFECTGEN] and id.parentTile != 65535:
			continue
		if id.thingType == Things.TYPE.OBJECT and id.subtype in Things.LIST_OF_HEROGATES:
			return "A selecao contem portais de herois com referencias de script. Copie uma area sem esses portais para nao duplicar seus numeros."
		if id.thingType == Things.TYPE.OBJECT and Things.is_custom_special_box(id.subtype):
			return "A selecao contem uma caixa especial personalizada com numero de evento. Use as ferramentas avancadas para ajustar suas referencias."
		if not id.thingType in [Things.TYPE.CREATURE, Things.TYPE.OBJECT, Things.TYPE.TRAP, Things.TYPE.EFFECTGEN]:
			return "A selecao contem um tipo de elemento que exige as ferramentas avancadas: " + str(id.thingType)
		var fields = {}
		for field in COPY_FIELDS:
			if id.get(field) != null:
				fields[field] = id.get(field)
		things.append({"type": id.thingType, "subtype": id.subtype, "owner": id.ownership, "pos": pos - rect.position * 3, "fields": fields})
	clipboard = {"size": rect.size, "cells": cells, "things": things, "lights": lights, "doors": doors, "base_owner": -1, "heart_owners": heart_owners.keys(), "format": refs.oCurrentFormat.selected}
	selected_rect = rect
	selected_path = refs.oCurrentMap.path
	return ""


func _room_region(start: Vector2, slab: int, room_owner: int) -> Array:
	var region = [start]
	var visited = {start: true}
	var head = 0
	while head < region.size():
		var pos = region[head]
		head += 1
		for offset in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var next = pos + offset
			if not visited.has(next) and refs.oDataSlab.get_cellv(next) == slab and refs.oDataOwnership.get_cellv_ownership(next) == room_owner:
				visited[next] = true
				region.append(next)
	return region


func _heart_owners() -> Array:
	return clipboard.get("heart_owners", [clipboard.base_owner] if clipboard.get("base_owner", -1) >= 0 else [])


func open_transform():
	if clipboard.empty():
		studio.map_tools._error("Selecione primeiro uma area em Copiar area.")
		return
	if is_instance_valid(transform_dialog):
		transform_dialog.free()
	transform_dialog = studio.map_tools._dialog("Colar, girar e espelhar area")
	var box = studio.map_tools._body(transform_dialog)
	studio._label(box, "%s x %s blocos; %s criaturas/itens.\nCopia terreno padrao, donos, criaturas, itens, luzes e portas; nao copia eventos.\nBases completas podem ser copiadas para um dono sem coracao.\nAreas de evento e portais de herois exigem as ferramentas avancadas." % [clipboard.size.x, clipboard.size.y, clipboard.things.size()])
	turn_picker = studio.map_tools._labelled_picker(box, "Girar")
	for text in ["0 graus", "90 graus", "180 graus", "270 graus"]:
		turn_picker.add_item(text)
	mirror_check = CheckBox.new()
	mirror_check.text = "Espelhar horizontalmente antes de girar"
	box.add_child(mirror_check)
	target_owner = studio.map_tools._labelled_picker(box, "Dono")
	target_owner.add_item("Preservar donos", 999)
	studio.map_tools._players(target_owner)
	replace_check = CheckBox.new()
	replace_check.text = "Permitir substituir terreno e elementos no destino"
	box.add_child(replace_check)
	transform_dialog.connect("confirmed", self, "_prepare_paste")
	studio.map_tools._show(transform_dialog)


func _prepare_paste():
	turns = turn_picker.selected
	mirrored = mirror_check.pressed
	destination_owner = target_owner.get_selected_id()
	if destination_owner == 999:
		destination_owner = -1
	overwrite = replace_check.pressed
	_arm("paste")
	transform_dialog.hide()


func transformed_size() -> Vector2:
	return Vector2(clipboard.size.y, clipboard.size.x) if turns % 2 == 1 else clipboard.size


func transform_point(pos: Vector2, extent: Vector2, cell: bool) -> Vector2:
	var edge = Vector2.ONE if cell else Vector2.ZERO
	if mirrored:
		pos.x = extent.x - edge.x - pos.x
	for _turn in turns:
		pos = Vector2(extent.y - edge.y - pos.y, pos.x)
		extent = Vector2(extent.y, extent.x)
	return pos


func placement_error(origin: Vector2) -> String:
	if placing or refs.oSlabPlacement.activeGenerations > 0:
		return "Aguarde a geracao do terreno."
	if clipboard.empty() or clipboard.format != refs.oCurrentFormat.selected:
		return "A copia precisa pertencer ao mesmo formato do mapa atual."
	var rect = Rect2(origin, transformed_size())
	if not Rect2(Vector2.ONE, Vector2(M.xSize - 2, M.ySize - 2)).encloses(rect):
		return "O carimbo ultrapassa as bordas do mapa."
	var owners = {}
	for original_owner in _heart_owners():
		var target = destination_owner if destination_owner >= 0 else original_owner
		if owners.has(target) or refs.oInstances.check_for_dungeon_heart(target):
			return "Este dono ja possui um coracao ou receberia dois. Escolha um jogador sem base na janela Colar / transformar."
		owners[target] = true
	if refs.oCurrentFormat.selected == Constants.OldFormat:
		var count = get_tree().get_nodes_in_group("Creature").size()
		for thing in clipboard.things:
			count += int(thing.type == Things.TYPE.CREATURE)
		if count > 255:
			return "A colocacao excederia o limite de 255 criaturas do Gold."
	for y in int(rect.size.y):
		for x in int(rect.size.x):
			var slab = refs.oDataSlab.get_cellv(origin + Vector2(x, y))
			if slab == Slabs.DUNGEON_HEART or (not overwrite and not slab in [Slabs.EARTH, Slabs.ROCK, Slabs.PATH]):
				return "O destino contem terreno protegido. Escolha outra area ou autorize a substituicao na janela de colagem."
	for id in get_tree().get_nodes_in_group("Instance"):
		if not rect.has_point(Vector2(id.locationX, id.locationY) / 3):
			continue
		if id.is_in_group("ActionPoint") or (id.thingType == Things.TYPE.OBJECT and (id.subtype == 5 or id.subtype in Things.LIST_OF_HEROGATES)):
			return "O destino contem coracao, portal de herois ou area de evento. Esses elementos nunca sao substituidos por colagem."
		if not overwrite and (id.thingType == Things.TYPE.CREATURE or id.thingType == Things.TYPE.TRAP or (id.thingType == Things.TYPE.OBJECT and id.parentTile == 65535)):
			return "O destino contem criaturas ou itens. Escolha outra area."
	return ""


func _confirmed():
	if pending.empty() or pending.path != refs.oCurrentMap.path or pending.format != refs.oCurrentFormat.selected:
		studio.map_tools._error("O mapa mudou. Posicione novamente o carimbo.")
		return
	clipboard = pending_clipboard.duplicate(true)
	turns = pending_options.turns
	mirrored = pending_options.mirrored
	destination_owner = pending_options.owner
	overwrite = pending_options.overwrite
	var result = apply_at(pending.origin)
	if result is GDScriptFunctionState:
		yield(result, "completed")


func apply_at(origin: Vector2):
	if not _heart_owners().empty() and not studio.map_tools._script_error().empty():
		studio.map_tools._error("Corrija o script antes de colocar uma base: " + studio.map_tools._script_error())
		return false
	var error = placement_error(origin)
	if not error.empty():
		studio.map_tools._error(error)
		return false
	if studio.recovery.capture("antes-construcao").empty():
		return false
	refs.oUndoStates.save_current_state()
	placing = true
	var rect = Rect2(origin, transformed_size())
	for id in get_tree().get_nodes_in_group("Instance"):
		if rect.has_point(Vector2(id.locationX, id.locationY) / 3):
			refs.oInstances.kill_instance(id)
	var positions = []
	for cell in clipboard.cells:
		var pos = origin + transform_point(cell[0], clipboard.size, true)
		var slab = cell[1]
		if turns % 2 == 1 and slab in range(42, 50):
			slab = slab + 1 if slab % 2 == 0 else slab - 1
		var owner = destination_owner if destination_owner >= 0 and cell[2] != 5 else cell[2]
		refs.oDataSlab.set_cellv(pos, slab)
		refs.oDataFakeSlab.set_cellv(pos, 0)
		refs.oDataOwnership.set_cellv_ownership(pos, owner)
		if cell.size() > 3:
			refs.oDataLiquid.set_cellv(pos, cell[3])
		if not pos in positions:
			positions.append(pos)
	var generated = refs.oSlabPlacement.generate_slabs_based_on_id(positions, true, {"remove_things": false})
	if generated is GDScriptFunctionState:
		yield(generated, "completed")
	for door in clipboard.get("doors", []):
		var pos = origin * 3 + transform_point(door.pos, clipboard.size * 3, false)
		var id = refs.oInstances.get_node_on_subtile(int(pos.x), int(pos.y), "Door")
		if not is_instance_valid(id):
			var height = refs.oDataClm.height[refs.oDataClmPos.get_cell_clmpos(int(pos.x), int(pos.y))]
			id = refs.oInstances.place_new_thing(Things.TYPE.DOOR, 1, Vector3(pos.x, pos.y, height), destination_owner if destination_owner >= 0 else door.owner)
		id.doorLocked = door.locked
	for light in clipboard.get("lights", []):
		var pos = origin * 3 + transform_point(light.pos, clipboard.size * 3, false)
		var id = refs.oInstances.place_new_light(Things.TYPE.EXTRA, 2, Vector3(pos.x, pos.y, light.height), 5)
		id.lightRange = light.range
		id.lightIntensity = light.intensity
	for thing in clipboard.things:
		var pos = origin * 3 + transform_point(thing.pos, clipboard.size * 3, false)
		var owner = destination_owner if destination_owner >= 0 and thing.owner != 5 else thing.owner
		var height = refs.oDataClm.height[refs.oDataClmPos.get_cell_clmpos(int(pos.x), int(pos.y))]
		var id = refs.oInstances.place_new_thing(thing.type, thing.subtype, Vector3(pos.x, pos.y, height), owner)
		for field in thing.fields:
			var value = thing.fields[field]
			if field == "orientation":
				value = posmod((-int(value) if mirrored else int(value)) + turns * 512, 2048)
			id.set(field, value)
	for original_owner in _heart_owners():
		_add_base_rules(destination_owner if destination_owner >= 0 else original_owner)
	refs.oThingDetails.update_details()
	refs.oEditor.mapHasBeenEdited = true
	placing = false
	refs.oUndoStates.save_current_state()
	if is_instance_valid(confirm):
		confirm.hide()
	cancel()
	studio.status.text = "Construcao concluida. Ctrl+Z desfaz; Historico contem a copia anterior. Salve para atualizar o jogo."
	return true


func _add_base_rules(owner: int):
	var patcher = BasicScriptPatcher.new()
	var text = refs.oDataScript.data
	var token = studio.map_tools._player_token(owner)
	for pair in [["START_MONEY", ["18000"]], ["MAX_CREATURES", ["25"]]]:
		if patcher.find(patcher.parse(text), pair[0], [token]).empty() and patcher.find(patcher.parse(text), pair[0], ["ALL_PLAYERS"]).empty():
			text = patcher.set_call(text, pair[0], [token] + pair[1]).text
	if owner != 0 and patcher.find(patcher.parse(text), "COMPUTER_PLAYER", [token]).empty():
		text = patcher.set_call(text, "COMPUTER_PLAYER", [token, "0"]).text
	for room in ["TREASURE", "LAIR", "GARDEN", "TRAINING"]:
		if patcher.find(patcher.parse(text), "ROOM_AVAILABLE", [token, room]).empty() and patcher.find(patcher.parse(text), "ROOM_AVAILABLE", ["ALL_PLAYERS", room]).empty():
			text = patcher.set_call(text, "ROOM_AVAILABLE", [token, room, "1", "1"]).text
	refs.oScriptEditor.load_generated_text(text)
