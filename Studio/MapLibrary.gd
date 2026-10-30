extends Node

var studio
var refs: Dictionary
var catalog = []
var filtered = []
var metadata = ConfigFile.new()
var dialog: ConfirmationDialog
var listing: ItemList
var search: LineEdit
var title: LineEdit
var description: TextEdit
var location: Label
var selected_path = ""
var campaign_dialog: ConfirmationDialog
var campaign_list: ItemList
var campaign_title: LineEdit
var next_picker: OptionButton
var install_check: CheckBox
var campaign = []
var routes = []
var play_confirm: ConfirmationDialog
var pending_play = {}
var thumbnails = {}
var cards: GridContainer
var page_label: Label
var page = 0
const PAGE_SIZE = 12


func _ready():
	refs = studio.refs
	var file = metadata_path()
	if File.new().file_exists(file) and metadata.load(file) != OK:
		studio.map_tools._error("Nao foi possivel ler os metadados da biblioteca. O arquivo original foi mantido.")
	campaign = metadata.get_value("campaign", "maps", []).duplicate(true)
	routes = metadata.get_value("campaign", "routes", []).duplicate()


func metadata_path() -> String:
	return studio.workspace.plus_file("Biblioteca/catalogo.cfg")


func _error(text: String):
	studio.map_tools._error("Biblioteca: " + text)


func _save_metadata() -> bool:
	var dir = Directory.new()
	var path = metadata_path()
	if dir.make_dir_recursive(path.get_base_dir()) != OK or metadata.save(path + ".tmp") != OK:
		_error("nao foi possivel gravar os metadados locais.")
		return false
	if dir.file_exists(path + ".anterior") and dir.remove(path + ".anterior") != OK:
		_error("nao foi possivel atualizar o backup dos metadados.")
		return false
	var existed = dir.file_exists(path)
	if existed and dir.rename(path, path + ".anterior") != OK:
		_error("nao foi possivel preservar os metadados anteriores.")
		return false
	if dir.rename(path + ".tmp", path) != OK:
		if existed and dir.rename(path + ".anterior", path) != OK:
			_error("falha ao recuperar catalogo.cfg; a copia anterior permanece em catalogo.cfg.anterior.")
		else:
			_error("falha ao finalizar os metadados; a versao anterior foi mantida.")
		return false
	return true


func _read(path: String) -> String:
	var file = File.new()
	if file.open(path, File.READ) != OK:
		return ""
	var text = file.get_as_text()
	file.close()
	return text


func scan() -> Array:
	catalog.clear()
	_scan_folder(studio.workspace.plus_file("Mapas"), 0)
	catalog.sort_custom(self, "_sort")
	return catalog


func _sort(a, b) -> bool:
	return (a.name + a.path).to_lower() < (b.name + b.path).to_lower()


func _scan_folder(folder: String, depth: int):
	if depth > 5 or catalog.size() >= 1000:
		return
	var dir = Directory.new()
	if dir.open(folder) != OK:
		_error("nao foi possivel listar " + folder)
		return
	var subfolders = []
	var files = []
	dir.list_dir_begin(true, true)
	var name = dir.get_next()
	while name != "":
		if dir.current_is_dir():
			subfolders.append(folder.plus_file(name))
		elif name.get_extension().to_lower() == "slb":
			files.append(folder.plus_file(name).get_basename())
		name = dir.get_next()
	dir.list_dir_end()
	for path in files:
		if catalog.size() >= 1000:
			break
		var details = {"path": path, "name": path.get_file(), "description": "", "size": Vector2(85, 85),
			"format": Constants.KfxFormat if File.new().file_exists(path + ".tngfx") else Constants.OldFormat}
		var overview = _read(path + ".lof")
		for line in overview.split("\n"):
			var equal = line.find("=")
			if equal < 0:
				continue
			var key = line.substr(0, equal).strip_edges().to_upper()
			var value = line.substr(equal + 1).strip_edges()
			if key == "NAME_TEXT" and not value.empty():
				details.name = value
			elif key == "DESCRIPTION":
				details.description = value
			elif key == "MAPSIZE":
				var dimensions = value.split(" ", false)
				if dimensions.size() == 2:
					details.size = Vector2(int(dimensions[0]), int(dimensions[1]))
		if overview.empty():
			var lif = _read(path + ".lif")
			if "," in lif:
				details.name = lif.substr(lif.find(",") + 1).strip_edges()
		var section = studio._sync_key(path)
		details.name = metadata.get_value(section, "name", details.name)
		details.description = metadata.get_value(section, "description", details.description)
		catalog.append(details)
	for subfolder in subfolders:
		_scan_folder(subfolder, depth + 1)


func thumbnail(details: Dictionary) -> Texture:
	var key = details.path + str(File.new().get_modified_time(details.path + ".slb")) + str(details.size)
	if thumbnails.has(key):
		return thumbnails[key]
	var width = int(details.size.x)
	var height = int(details.size.y)
	if width < 1 or height < 1 or width > 1024 or height > 1024:
		return null
	var file = File.new()
	if file.open(details.path + ".slb", File.READ) != OK:
		return null
	if file.get_len() != width * height * 2:
		file.close()
		return null
	var image = Image.new()
	image.create(width, height, false, Image.FORMAT_RGB8)
	image.lock()
	for y in height:
		for x in width:
			var slab = file.get_16()
			var color = Color("#594838")
			if slab == Slabs.ROCK:
				color = Color("#22232b")
			elif slab == Slabs.GOLD or slab == Slabs.GEMS:
				color = Color("#edbd4d")
			elif slab in [Slabs.PATH, Slabs.CLAIMED_GROUND]:
				color = Color("#8d826d")
			elif slab == Slabs.LAVA:
				color = Color("#db541e")
			elif slab == Slabs.WATER:
				color = Color("#317ba1")
			elif slab == Slabs.DUNGEON_HEART:
				color = Color("#e44a63")
			elif slab == Slabs.PORTAL:
				color = Color("#9175dd")
			elif slab >= 16 and slab <= 40:
				color = Color("#69845c")
			image.set_pixel(x, y, color)
	image.unlock()
	file.close()
	image.resize(112, 112, Image.INTERPOLATE_NEAREST)
	var texture = ImageTexture.new()
	texture.create_from_image(image, 0)
	thumbnails[key] = texture
	return texture


func open_library():
	scan()
	if is_instance_valid(dialog):
		dialog.free()
	dialog = studio.map_tools._dialog("Biblioteca de mapas locais")
	var box = studio.map_tools._body(dialog)
	studio._label(box, "Mapas da pasta Mapas (incluindo copias importadas e recuperadas).\nJogar usa a versao salva no disco e instala uma copia com numero novo.\nNome e descricao abaixo organizam a biblioteca; nao mudam o script nem os arquivos do mapa.")
	search = LineEdit.new()
	search.placeholder_text = "Buscar nome, descricao ou caminho..."
	box.add_child(search)
	search.connect("text_changed", self, "_filter")
	listing = ItemList.new()
	listing.rect_min_size = Vector2(580, 220)
	listing.fixed_icon_size = Vector2(80, 80)
	box.add_child(listing)
	listing.connect("item_selected", self, "_selected")
	listing.connect("item_activated", self, "_open_index")
	listing.hide()
	var card_scroll = ScrollContainer.new()
	card_scroll.rect_min_size = Vector2(360, 230)
	box.add_child(card_scroll)
	cards = GridContainer.new()
	cards.columns = 3
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_scroll.add_child(cards)
	dialog.connect("resized", self, "_layout_cards")
	var pages = HBoxContainer.new()
	box.add_child(pages)
	for direction in [-1, 1]:
		var button = Button.new()
		button.text = "Anterior" if direction < 0 else "Proxima"
		button.connect("pressed", self, "_page", [direction])
		pages.add_child(button)
	page_label = studio._label(pages, "")
	title = LineEdit.new()
	box.add_child(title)
	description = TextEdit.new()
	description.rect_min_size.y = 70
	box.add_child(description)
	location = studio._label(box, "Escolha um mapa.")
	var row = HBoxContainer.new()
	box.add_child(row)
	for action in [["Guardar nome e descricao", "_store_details"], ["Jogar", "_ask_play"], ["Adicionar a campanha", "_add_campaign"]]:
		var button = Button.new()
		button.text = action[0]
		button.connect("pressed", self, action[1])
		row.add_child(button)
	var campaign_button = Button.new()
	campaign_button.text = "Organizar / exportar campanha KeeperFX"
	campaign_button.connect("pressed", self, "open_campaign")
	box.add_child(campaign_button)
	dialog.connect("confirmed", self, "_open_selected")
	_filter("")
	studio.map_tools._show(dialog)
	dialog.get_ok().text = "Abrir mapa"


func _filter(text: String):
	listing.clear()
	filtered.clear()
	selected_path = ""
	title.text = ""
	description.text = ""
	location.text = "Clique no nome de um cartao para editar os metadados; Abrir/Jogar estao no proprio cartao."
	for details in catalog:
		if text.empty() or studio.catalog.search_key(text) in studio.catalog.search_key(details.name + " " + details.description + " " + details.path):
			filtered.append(details)
			listing.add_item(details.name + (" [Gold]" if details.format == Constants.OldFormat else " [KeeperFX]"), thumbnail(details))
			listing.set_item_tooltip(listing.get_item_count() - 1, details.description + "\n" + details.path)
	page = 0
	_refresh_cards()


func _page(direction: int):
	page = int(clamp(page + direction, 0, max(0, int((filtered.size() - 1) / PAGE_SIZE))))
	_refresh_cards()


func _layout_cards():
	cards.columns = 3 if dialog.rect_size.x >= 700 else 2


func _refresh_cards():
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	_layout_cards()
	for index in range(page * PAGE_SIZE, min(filtered.size(), (page + 1) * PAGE_SIZE)):
		var details = filtered[index]
		var card = VBoxContainer.new()
		card.rect_min_size.x = 170
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.add_child(card)
		var image = TextureRect.new()
		image.texture = thumbnail(details)
		image.rect_min_size = Vector2(112, 112)
		image.expand = true
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(image)
		var name_button = Button.new()
		name_button.text = details.name
		name_button.clip_text = true
		name_button.hint_tooltip = details.name + "\n" + details.description + "\n" + details.path
		name_button.connect("pressed", self, "_card_action", [index, "select"])
		card.add_child(name_button)
		var format_label = Label.new()
		format_label.text = "GOLD" if details.format == Constants.OldFormat else "KEEPERFX"
		format_label.align = Label.ALIGN_CENTER
		format_label.add_color_override("font_color", Color("#e8bf77"))
		card.add_child(format_label)
		var actions = HBoxContainer.new()
		card.add_child(actions)
		for action in [["Abrir", "open"], ["Jogar", "play"]]:
			var button = Button.new()
			button.text = action[0]
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.connect("pressed", self, "_card_action", [index, action[1]])
			actions.add_child(button)
	page_label.text = "%s mapas | %s / %s" % [filtered.size(), page + 1, max(1, int(ceil(filtered.size() / float(PAGE_SIZE))))]
	if filtered.empty():
		location.text = "Nenhum mapa encontrado. Salve um mapa em Mapas ou ajuste a busca."


func _card_action(index: int, action: String):
	listing.select(index)
	_selected(index)
	if action == "open":
		_open_selected()
	elif action == "play":
		_ask_play()


func _selected(index: int):
	var details = filtered[index]
	selected_path = details.path
	title.text = details.name
	description.text = details.description
	location.text = details.path


func selected_details() -> Dictionary:
	for details in filtered:
		if details.path == selected_path:
			return details
	_error("escolha um mapa na lista.")
	return {}


func _store_details():
	var details = selected_details()
	if details.empty():
		return
	var section = studio._sync_key(details.path)
	var old_name = metadata.get_value(section, "name", details.name)
	var old_description = metadata.get_value(section, "description", details.description)
	metadata.set_value(section, "name", title.text.strip_edges())
	metadata.set_value(section, "description", description.text)
	if not _save_metadata():
		metadata.set_value(section, "name", old_name)
		metadata.set_value(section, "description", old_description)
		return
	details.name = title.text.strip_edges()
	details.description = description.text
	if not listing.get_selected_items().empty():
		listing.set_item_text(listing.get_selected_items()[0], details.name + (" [Gold]" if details.format == Constants.OldFormat else " [KeeperFX]"))
	_refresh_cards()
	location.text = "Metadados locais guardados. O arquivo do mapa nao foi alterado."


func _open_index(index: int):
	_selected(index)
	_open_selected()


func _open_selected():
	var details = selected_details()
	if details.empty():
		return
	dialog.hide()
	refs.oOpenMap.open_map(details.path + ".slb")


func _ask_play():
	pending_play = selected_details().duplicate(true)
	if pending_play.empty():
		return
	if not is_instance_valid(play_confirm):
		play_confirm = studio.map_tools._dialog("Jogar uma copia salva")
		play_confirm.connect("confirmed", self, "_play")
	play_confirm.dialog_text = "Jogar '%s'?\nSera instalada uma nova copia, sem substituir nenhuma fase original.\nAlteracoes ainda nao salvas nao entram nessa partida.\n%s" % [pending_play.name, pending_play.path]
	studio.map_tools._show(play_confirm)
	play_confirm.get_ok().text = "Instalar copia e jogar"


func _play():
	if refs.oCurrentMap.path == pending_play.path and refs.oEditor.mapHasBeenEdited:
		_error("este mapa tem alteracoes nao salvas. Salve antes de jogar.")
		return
	var classic = pending_play.format == Constants.OldFormat
	var exe = studio.gold_exe if classic else studio.fx_exe
	if not File.new().file_exists(exe):
		_error("configure o executavel desse perfil em Configurar jogos.")
		return
	var token = "studioplay_%s_%s" % [OS.get_unix_time(), OS.get_ticks_msec()]
	var folder = exe.get_base_dir().plus_file("levels")
	if not classic:
		folder = folder.plus_file(token)
	if Directory.new().make_dir_recursive(folder) != OK:
		_error("nao foi possivel preparar a pasta de teste.")
		return
	var target = studio._next_path(folder, 300 if classic else 6000, 799 if classic else 32767)
	if target.empty():
		return
	var stage_folder = studio.workspace.plus_file("Exportados/Biblioteca/" + token)
	if Directory.new().make_dir_recursive(stage_folder) != OK:
		_error("nao foi possivel preparar a copia local.")
		return
	var stage = stage_folder.plus_file(target.get_file())
	var error = copy_bundle(pending_play.path, stage)
	if not error.empty():
		_error(error)
		return
	if not studio._publish_bundle(stage, target):
		return
	if not classic:
		var cfg = "[common]\nNAME = Studio - " + _safe_title(pending_play.name) + "\nLEVELS_LOCATION = levels/" + token + "\nMEDIA_LOCATION = ldata\nHUMAN_PLAYER = RED\n" + _text_resources()
		if not write_text(folder + ".cfg", cfg):
			_error("o mapa foi copiado, mas o pacote nao foi registrado. Nao foi iniciado.")
			return
	play_confirm.hide()
	_launch(exe, target, "levels/" + token if not classic else "")


func _launch(exe: String, target: String, pack: String):
	var command = refs.oGame.cmdline(target, false, exe)
	var pattern = RegEx.new()
	pattern.compile("\\s+-campaign\\s+\\S+")
	command = pattern.sub(command, "", true)
	if not pack.empty():
		command += " -campaign " + pack
	refs.oGame.launch_game(command, "Iniciando a copia salva do mapa...")


func _safe_title(text: String) -> String:
	return text.replace("\r", " ").replace("\n", " ").replace("[", "(").replace("]", ")").replace(";", " ").strip_edges()


func _text_resources() -> String:
	return "\n[strings]\nENG = fxdata/gtext_eng.dat\nPOR = fxdata/gtext_por.dat\n\n[speech]\nENG = campgns/keeporig_eng\n"


func write_text(path: String, text: String) -> bool:
	var file = File.new()
	if file.open(path, File.WRITE) != OK:
		return false
	file.store_string(text)
	var success = file.get_error() == OK
	file.close()
	return success and _read(path) == text


func copy_bundle(source: String, target: String) -> String:
	var fingerprint = {}
	for ext in studio._bundle_fingerprint(source):
		fingerprint[ext.to_lower()] = File.new().get_sha256(source + "." + ext)
	for ext in ["slb", "clm", "dat", "own", "inf"]:
		if not fingerprint.has(ext):
			return "Conjunto incompleto; falta " + ext + " em " + source
	if not fingerprint.has("tng") and not fingerprint.has("tngfx"):
		return "Conjunto incompleto; faltam os elementos TNG/TNGFX."
	for ext in fingerprint:
		if ext.get_file() != ext:
			return "Extensao de arquivo invalida."
		var path = target + "." + ext
		if File.new().file_exists(path) or Directory.new().copy(source + "." + ext, path) != OK or File.new().get_sha256(path) != fingerprint[ext]:
			return "Falha na copia verificada de " + ext + ". O original foi preservado."
	if fingerprint.has("lif") and not write_text(target + ".lif", str(int(target.get_file().trim_prefix("map"))) + ", " + _safe_title(source.get_file())):
		return "Falha ao atualizar o indice Gold da copia."
	return ""


func _add_campaign():
	var details = selected_details()
	if details.empty():
		return
	campaign.append(details.duplicate(true))
	routes.append(-1)
	if not _persist_campaign():
		campaign.pop_back()
		routes.pop_back()
		return
	location.text = "Adicionado a campanha na posicao %s. Abra Organizar campanha." % campaign.size()


func _persist_campaign() -> bool:
	var previous = metadata.get_value("campaign", "maps", [])
	var previous_routes = metadata.get_value("campaign", "routes", [])
	metadata.set_value("campaign", "maps", campaign)
	metadata.set_value("campaign", "routes", routes)
	if not _save_metadata():
		metadata.set_value("campaign", "maps", previous)
		metadata.set_value("campaign", "routes", previous_routes)
		return false
	return true


func open_campaign():
	campaign = metadata.get_value("campaign", "maps", []).duplicate(true)
	routes = metadata.get_value("campaign", "routes", []).duplicate()
	if is_instance_valid(campaign_dialog):
		campaign_dialog.free()
	campaign_dialog = studio.map_tools._dialog("Campanha KeeperFX - sem alterar a campanha original")
	var box = studio.map_tools._body(campaign_dialog)
	studio._label(box, "Adicione fases pela biblioteca. Organize a ordem e escolha a proxima fase.\nO destino da caixa Transferir criatura acompanha a proxima fase escolhida.\nA caixa deve ser encontrada e ativada durante o jogo; nao transfere automaticamente.\nCampanhas personalizadas exigem KeeperFX; no Gold, jogue os mapas individualmente.\nExportar gera copias locais; instalar e opcional e nunca substitui uma campanha.")
	campaign_title = LineEdit.new()
	campaign_title.text = metadata.get_value("campaign", "title", "Minha campanha Studio")
	box.add_child(campaign_title)
	campaign_list = ItemList.new()
	campaign_list.rect_min_size = Vector2(580, 180)
	box.add_child(campaign_list)
	campaign_list.connect("item_selected", self, "_campaign_selected")
	var row = HBoxContainer.new()
	box.add_child(row)
	for action in [["Subir", "_up"], ["Descer", "_down"], ["Remover", "_remove"]]:
		var button = Button.new()
		button.text = action[0]
		button.connect("pressed", self, action[1])
		row.add_child(button)
	next_picker = studio.map_tools._labelled_picker(box, "Proxima fase / destino da transferencia")
	next_picker.connect("item_selected", self, "_route")
	install_check = CheckBox.new()
	install_check.text = "Tambem instalar como NOVA campanha no KeeperFX configurado"
	box.add_child(install_check)
	campaign_dialog.connect("confirmed", self, "_export_campaign")
	_refresh_campaign()
	studio.map_tools._show(campaign_dialog)
	campaign_dialog.get_ok().text = "Guardar e exportar campanha"


func _refresh_campaign():
	campaign_list.clear()
	for index in campaign.size():
		var route = int(routes[index])
		campaign_list.add_item("%s. %s > %s" % [index + 1, campaign[index].name, str(route + 1) if route >= 0 else ("proxima da lista" if index < campaign.size() - 1 else "fim")])
	next_picker.clear()
	next_picker.add_item("Sequencia normal (fim na ultima fase)", 999)
	for index in campaign.size():
		next_picker.add_item("%s. %s" % [index + 1, campaign[index].name], index)
	next_picker.disabled = true


func _campaign_selected(index: int):
	next_picker.disabled = false
	next_picker.select(max(0, next_picker.get_item_index(routes[index] if routes[index] >= 0 else 999)))


func _route(_index: int):
	if campaign_list.get_selected_items().empty():
		return
	var index = campaign_list.get_selected_items()[0]
	var target = next_picker.get_selected_id()
	if target == 999:
		target = -1
	if target == index:
		_error("uma fase nao pode apontar para si mesma.")
		_campaign_selected(index)
		return
	var previous = routes[index]
	routes[index] = target
	if not _persist_campaign():
		routes[index] = previous
	_refresh_campaign()


func _up():
	_move(-1)


func _down():
	_move(1)


func _move(direction: int):
	if campaign_list.get_selected_items().empty():
		return
	var index = int(campaign_list.get_selected_items()[0])
	var other = index + direction
	if other < 0 or other >= campaign.size():
		return
	var old_campaign = campaign.duplicate(true)
	var old_routes = routes.duplicate()
	var item = campaign[index]
	campaign[index] = campaign[other]
	campaign[other] = item
	var old = routes[index]
	routes[index] = routes[other]
	routes[other] = old
	for i in routes.size():
		if routes[i] == index:
			routes[i] = other
		elif routes[i] == other:
			routes[i] = index
	if not _persist_campaign():
		campaign = old_campaign
		routes = old_routes
	_refresh_campaign()
	campaign_list.select(other)
	_campaign_selected(other)


func _remove():
	if campaign_list.get_selected_items().empty():
		return
	var index = int(campaign_list.get_selected_items()[0])
	var old_campaign = campaign.duplicate(true)
	var old_routes = routes.duplicate()
	campaign.remove(index)
	routes.remove(index)
	for i in routes.size():
		if routes[i] == index:
			routes[i] = -1
		elif routes[i] > index:
			routes[i] -= 1
	if not _persist_campaign():
		campaign = old_campaign
		routes = old_routes
	_refresh_campaign()


func build_campaign(maps: Array, next_routes: Array, name: String) -> Dictionary:
	if maps.empty() or maps.size() > 32 or maps.size() != next_routes.size():
		return {"error": "Escolha de 1 a 32 fases e destinos validos."}
	var visited = {}
	var current = 0
	while current >= 0 and current < maps.size():
		if visited.has(current):
			return {"error": "A sequencia forma um ciclo e nao pode terminar. Ajuste os destinos."}
		visited[current] = true
		current = int(next_routes[current]) if int(next_routes[current]) >= 0 else current + 1
		if current > maps.size():
			return {"error": "Destino fora da campanha."}
	if visited.size() != maps.size():
		return {"error": "Ha fases que nao podem ser alcancadas a partir da primeira. Ajuste a ordem ou os destinos."}
	for index in maps.size():
		if int(next_routes[index]) < -1 or int(next_routes[index]) >= maps.size():
			return {"error": "Destino fora da campanha."}
		if studio._sync_key(maps[index].path) == studio._sync_key(refs.oCurrentMap.path) and refs.oEditor.mapHasBeenEdited:
			return {"error": "Salve as alteracoes do mapa aberto antes de exportar a campanha."}
	var token = "studio_%s_%s" % [OS.get_unix_time(), OS.get_ticks_msec()]
	var folder = studio.workspace.plus_file("Campanhas/" + token)
	var levels = folder.plus_file("campgns/" + token)
	if Directory.new().make_dir_recursive(levels) != OK:
		return {"error": "Nao foi possivel criar a pasta de exportacao."}
	var common = "[common]\nNAME = " + _safe_title(name) + "\nLEVELS_LOCATION = campgns/" + token + "\nLAND_LOCATION = campgns/keeporig_lnd\n"
	common += "CREDITS = dkcredts.txt\nMEDIA_LOCATION = ldata\nHIGH_SCORES = 100 scr_" + token + ".dat\n"
	common += "LAND_VIEW_START = rgmap00 viframe00\nLAND_VIEW_END = rgmap21 viframe21\nLAND_MARKERS = ENSIGNS\nHUMAN_PLAYER = RED\nSINGLE_LEVELS ="
	var sections = ""
	var patcher = studio.map_tools.patcher
	for index in maps.size():
		var number = 6000 + index
		common += " " + str(number)
		var target = levels.plus_file("map%05d" % number)
		var error = copy_bundle(maps[index].path, target)
		if not error.empty():
			return {"error": error}
		if File.new().file_exists(target + ".lua"):
			return {"error": "Esta exportacao usa DKScript. Fases Lua exigem configurar a progressao nas ferramentas avancadas."}
		var script = _read(target + ".txt")
		if script.empty() or patcher.parse(script).error_line != 0:
			return {"error": "Fase sem DKScript valido: " + maps[index].name}
		if File.new().file_exists(target + ".tng"):
			return {"error": "Converta '" + maps[index].name + "' para KeeperFX e salve uma copia antes de adiciona-la a campanha. O Gold continua disponivel como mapa individual."}
		for call in patcher.parse(script).all_calls:
			if call.command == "SET_NEXT_LEVEL":
				return {"error": "A fase '" + maps[index].name + "' ja define SET_NEXT_LEVEL manualmente. Remova a progressao manual antes de organizar pelo Studio."}
		script = patcher.set_level_version(script).text
		var destination = int(next_routes[index]) if int(next_routes[index]) >= 0 else index + 1
		if destination < maps.size():
			script = patcher.set_call(script, "SET_NEXT_LEVEL", [str(6000 + destination)]).text
		if not write_text(target + ".txt", script):
			return {"error": "Falha ao gravar a progressao da copia."}
		var x = 200 + (index % 8) * 125
		var y = 200 + int(index / 8) * 150
		sections += "\n[map%05d]\nNAME_TEXT = %s\nENSIGN_POS = %s %s\nENSIGN_ZOOM = %s %s\nPLAYERS = 1\nLAND_VIEW = rgmap00 viframe00\nMAPSIZE = %s %s\n" % [number, _safe_title(maps[index].name), x, y, x, y, maps[index].size.x, maps[index].size.y]
	var cfg_path = folder.plus_file("campgns/" + token + ".cfg")
	common += "\nBONUS_LEVELS ="
	for _index in maps.size():
		common += " 0"
	var config = common + "\n" + _text_resources() + sections
	if not write_text(cfg_path, config):
		return {"error": "Falha ao finalizar a configuracao da campanha."}
	var manifest = ConfigFile.new()
	manifest.set_value("campaign", "name", name)
	manifest.set_value("campaign", "sources", maps)
	manifest.set_value("campaign", "routes", next_routes)
	manifest.set_value("campaign", "token", token)
	if manifest.save(folder.plus_file("campanha.cfg")) != OK:
		return {"error": "Falha ao guardar o manifesto da campanha."}
	return {"error": "", "folder": folder, "levels": levels, "config": cfg_path, "token": token}


func install_campaign(result: Dictionary, game_root: String) -> String:
	var source = result.levels
	var target = game_root.plus_file("campgns/" + result.token)
	var config = target + ".cfg"
	var dir = Directory.new()
	if not dir.dir_exists(game_root.plus_file("campgns/keeporig_lnd")) or not File.new().file_exists(game_root.plus_file("campgns/keeporig_lnd/dkcredts.txt")):
		return "Faltam os cenarios de campanha do jogo em campgns/keeporig_lnd. Nenhuma campanha foi registrada."
	if dir.dir_exists(target) or dir.file_exists(config) or dir.dir_exists(target + ".pending") or dir.file_exists(config + ".pending"):
		return "O destino ja existe. Gere uma nova exportacao; nenhuma campanha existente sera sobrescrita."
	if dir.make_dir_recursive(target + ".pending") != OK or dir.open(source) != OK:
		return "Nao foi possivel preparar a instalacao."
	dir.list_dir_begin(true, true)
	var name = dir.get_next()
	while name != "":
		if dir.current_is_dir() or dir.copy(source.plus_file(name), (target + ".pending").plus_file(name)) != OK or File.new().get_sha256(source.plus_file(name)) != File.new().get_sha256((target + ".pending").plus_file(name)):
			dir.list_dir_end()
			return "Falha na verificacao da instalacao; arquivos parciais em " + target + ".pending"
		name = dir.get_next()
	dir.list_dir_end()
	if dir.copy(result.config, config + ".pending") != OK or File.new().get_sha256(result.config) != File.new().get_sha256(config + ".pending"):
		return "Falha ao verificar a configuracao; a campanha nao foi registrada."
	if dir.rename(target + ".pending", target) != OK or dir.rename(config + ".pending", config) != OK:
		return "Falha ao finalizar a instalacao. Confira " + target + "; nenhuma campanha anterior foi alterada."
	return ""


func _export_campaign():
	if install_check.pressed and not File.new().file_exists(studio.fx_exe):
		_error("configure primeiro o KeeperFX.")
		return
	metadata.set_value("campaign", "title", campaign_title.text)
	if not _save_metadata():
		return
	var output = build_campaign(campaign, routes, campaign_title.text)
	if not output.error.empty():
		_error(output.error)
		return
	if install_check.pressed:
		var error = install_campaign(output, studio.fx_exe.get_base_dir())
		if not error.empty():
			_error("Exportacao local criada em " + output.folder + "\nInstalacao nao concluida: " + error)
			return
	campaign_dialog.hide()
	studio.refs.oMessage.big("Campanha exportada", "Copias locais em:\n" + output.folder + ("\n\nInstalada como nova campanha. Escolha '" + campaign_title.text + "' na selecao de campanhas do KeeperFX e inicie uma nova partida." if install_check.pressed else "\n\nPara instalar pelo Studio, exporte novamente com a opcao de instalacao marcada.") + "\nA campanha original e os mapas fonte nao foram alterados.")
