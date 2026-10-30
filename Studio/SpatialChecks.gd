extends Node2D

var studio
var refs: Dictionary
var issues = []
var dialog: ConfirmationDialog
var listing: ItemList
var checked_path = ""
var checked_signature = ""
var selected = -1


func _ready():
	refs = studio.refs
	z_index = 95


func signature() -> String:
	var key = refs.oDataScript.data
	for y in M.ySize:
		for x in M.xSize:
			key += str(refs.oDataSlab.get_cell(x, y)) + ","
	for id in get_tree().get_nodes_in_group("Instance"):
		key += str([id.get_instance_id(), id.locationX, id.locationY, id.get("ownership"), id.get("pointNumber")])
	return key.sha256_text()


func _process(_delta):
	visible = refs.oEditor.currentView == refs.oEditor.VIEW_2D
	if not issues.empty() and refs.oCurrentMap.path != checked_path:
		clear()


func clear():
	issues.clear()
	selected = -1
	update()


func _draw():
	for index in issues.size():
		var issue = issues[index]
		if issue.position.x < 0:
			continue
		var color = Color(1, 0.3, 0.2, 0.85) if issue.severity == "ERRO" else Color(1, 0.8, 0.1, 0.85)
		draw_rect(Rect2(issue.position * 96 + Vector2(5, 5), Vector2(86, 86)), color, false, 8 if selected == index else 4)


func _add(code: String, text: String, pos = Vector2(-1, -1), severity = "AVISO"):
	issues.append({"code": code, "text": text, "position": pos, "severity": severity})


func open_report():
	if not studio._has_map():
		return
	analyze()
	if is_instance_valid(dialog):
		dialog.free()
	dialog = studio.map_tools._dialog("Validacao visual - clique para localizar")
	var box = studio.map_tools._body(dialog)
	studio._label(box, "Analise estatica, nao substitui jogar a missao.\nConectividade considera caminhos existentes, sem escavar, nadar ou voar.\nMarcadores amarelos: avisos. Vermelhos: erros comprovados.\nReverifique depois de editar: os marcadores representam esta analise.")
	listing = ItemList.new()
	listing.rect_min_size = Vector2(580, 280)
	box.add_child(listing)
	for issue in issues:
		var location = "(%s,%s) " % [issue.position.x, issue.position.y] if issue.position.x >= 0 else ""
		listing.add_item("%s: %s%s" % [issue.severity, location, issue.text])
		listing.set_item_tooltip(listing.get_item_count() - 1, issue.text)
	if issues.empty():
		listing.add_item("Nenhum problema encontrado nas verificacoes disponiveis.")
	listing.connect("item_selected", self, "_focus")
	dialog.connect("confirmed", dialog, "hide")
	var clear_button = dialog.add_button("Limpar marcadores", false, "clear")
	clear_button.connect("pressed", self, "clear")
	studio.map_tools._show(dialog)
	dialog.get_ok().text = "Fechar"


func _focus(index: int):
	if index >= issues.size():
		return
	if checked_signature != signature():
		studio.map_tools._error("O mapa foi alterado depois da analise. Clique em Verificar novamente para atualizar os problemas.")
		return
	selected = index
	var pos = issues[index].position
	if pos.x >= 0:
		refs.oCamera2D.position = (pos + Vector2(0.5, 0.5)) * 96
		refs.oEditor.input_requests_screen_update()
		dialog.hide()
	update()


func _open_cell(pos: Vector2) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.x >= M.xSize or pos.y >= M.ySize:
		return false
	var slab = refs.oDataSlab.get_cellv(pos)
	return Slabs.data.has(slab) and (not Slabs.data[slab][Slabs.IS_SOLID] or slab in range(42, 50)) and not slab in [Slabs.LAVA, Slabs.WATER]


func _reachable(start: Vector2) -> Dictionary:
	var visited = {start: true}
	var queue = [start]
	var head = 0
	while head < queue.size():
		var pos = queue[head]
		head += 1
		for step in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var next = pos + step
			if not visited.has(next) and _open_cell(next):
				visited[next] = true
				queue.append(next)
	return visited


func analyze() -> Array:
	clear()
	checked_path = refs.oCurrentMap.path
	for text in studio.checker.inspect(studio.snapshot()):
		_add("basic", text.substr(text.find(":") + 1).strip_edges(), Vector2(-1, -1), "ERRO" if text.begins_with("ERRO:") else "AVISO")
	for id in get_tree().get_nodes_in_group("Creature"):
		var pos = Vector2(floor(id.locationX / 3), floor(id.locationY / 3))
		var slab = refs.oDataSlab.get_cellv(pos)
		if not Slabs.data.has(slab) or Slabs.data[slab][Slabs.IS_SOLID]:
			_add("blocked_creature", "Criatura dentro de terreno solido: " + Things.fetch_name(id.thingType, id.subtype), pos)
	var hearts = {}
	var portals = {}
	for y in M.ySize:
		for x in M.xSize:
			var pos = Vector2(x, y)
			var slab = refs.oDataSlab.get_cellv(pos)
			var owner = refs.oDataOwnership.get_cellv_ownership(pos)
			if slab == Slabs.DUNGEON_HEART:
				if not hearts.has(owner):
					hearts[owner] = pos
			elif slab == Slabs.PORTAL:
				if not portals.has(owner):
					portals[owner] = []
				portals[owner].append(pos)
	for owner in hearts:
		var visited = _reachable(hearts[owner])
		var reachable_portal = false
		for portal_owner in [owner, 5]:
			for pos in portals.get(portal_owner, []):
				if visited.has(pos):
					reachable_portal = true
					break
		if not reachable_portal:
			_add("base_access", "Base de %s sem caminho pronto ate um portal proprio ou neutro. Pode exigir escavacao." % studio.OWNER_NAMES[owner], hearts[owner])
	for owner in portals:
		var remaining = portals[owner].duplicate()
		while not remaining.empty():
			var first = remaining.pop_back()
			var region = [first]
			var outside = false
			var head = 0
			while head < region.size():
				var pos = region[head]
				head += 1
				for step in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
					var next = pos + step
					if next in remaining:
						remaining.erase(next)
						region.append(next)
					elif not next in region and _open_cell(next):
						outside = true
			if not outside:
				_add("blocked_portal", "Portal sem saida para terreno aberto; confira os acessos.", first)
			if region.size() < 9:
				_add("small_portal", "Portal menor que 3 x 3; pode nao gerar criaturas.", first)
	var parsed = studio.map_tools.patcher.parse(refs.oDataScript.data)
	var numbers = {}
	for ap in get_tree().get_nodes_in_group("ActionPoint"):
		var pos = Vector2(floor(ap.locationX / 3), floor(ap.locationY / 3))
		if numbers.has(ap.pointNumber):
			_add("duplicate_area", "Numero de area duplicado: #%s." % ap.pointNumber, pos, "ERRO")
		numbers[ap.pointNumber] = pos
		if not _open_cell(pos):
			_add("blocked_area", "Area de evento #%s em terreno sem acesso terrestre." % ap.pointNumber, pos)
	var arguments = {"IF_ACTION_POINT": 0, "RESET_ACTION_POINT": 0, "REVEAL_MAP_LOCATION": 1,
		"ADD_CREATURE_TO_LEVEL": 2, "ADD_PARTY_TO_LEVEL": 2}
	for call in parsed.all_calls:
		if arguments.has(call.command):
			var index = arguments[call.command]
			if call.args.size() <= index:
				continue
			var token = call.args[index].strip_edges()
			if token.is_valid_integer() and int(token) > 0 and not numbers.has(int(token)):
				_add("missing_area", "Linha %s: %s aponta para a area removida #%s." % [call.line.number, call.command, token], Vector2(-1, -1), "ERRO")
		if call.command == "IF" and call.args.size() > 1 and "DUNGEON_DESTROYED" in call.args[1]:
			for owner in [0, 1, 2, 3, 6, 7, 8]:
				if call.args[0] == studio.map_tools._player_token(owner) and not hearts.has(owner):
					_add("missing_enemy", "Objetivo exige destruir %s, mas nao existe coracao desse jogador. Confira se ele sera criado por script." % studio.OWNER_NAMES[owner])
	checked_signature = signature()
	update()
	return issues
