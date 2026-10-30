extends Node

var studio
var refs: Dictionary
var timer = 0.0
var capturing = false
var last_local = ""
var last_game = ""
var dialog: ConfirmationDialog
var entries: ItemList
var details: Label
var records = []
var enabled = true


func _ready():
	refs = studio.refs
	enabled = Settings.config.get_value("studio", "autosave", true)
	last_local = Settings.config.get_value("studio", "last_local_save", "")
	last_game = Settings.config.get_value("studio", "last_game_save", "")
	if not "--studio-test" in OS.get_cmdline_args():
		get_tree().create_timer(3).connect("timeout", self, "_offer_recovery")


func _offer_recovery():
	for record in list_records():
		if record.reason == "salvo":
			continue
		var source = str(record.source)
		var created = int(record.path.get_file().split("-")[0])
		if (source.empty() or studio._sync_key(source) == studio._sync_key(studio.last_saved_map)) and created > int(File.new().get_modified_time(source + ".slb")):
			refs.oMessage.big("Existe uma versao de recuperacao", "Ha trabalho preservado depois do ultimo salvamento de '%s'.\nAbra a aba Mapa > Historico para recuperar uma copia.\nA fase do jogo e o arquivo original nao serao substituidos." % record.name)
			return


func root() -> String:
	return studio.workspace.plus_file("Historico")


func _process(delta):
	timer += delta
	if timer < 120 or not enabled or "--studio-test" in OS.get_cmdline_args():
		return
	timer = 0
	if not refs.oEditor.mapHasBeenEdited or refs.oLoadingBar.visible or refs.oSlabPlacement.activeGenerations > 0 or Input.is_mouse_button_pressed(BUTTON_LEFT) or studio.busy:
		return
	if refs.oDataSlab.get_cell(0, 0) != TileMap.INVALID_CELL:
		capture("automatico")


func _fail(text: String) -> String:
	studio.map_tools._error("Recuperacao: " + text + "\nO mapa em edicao e os arquivos do jogo nao foram alterados.")
	return ""


func capture(reason: String) -> String:
	if capturing or refs.oLoadingBar.visible or refs.oSlabPlacement.activeGenerations > 0:
		return _fail("aguarde o carregamento ou a geracao do terreno.")
	capturing = true
	var result = _capture(reason)
	capturing = false
	return result


func _capture(reason: String) -> String:
	var token = "%s-%s" % [OS.get_unix_time(), OS.get_ticks_msec()]
	var folder = root().plus_file(".pending-" + token)
	var final_folder = root().plus_file(token)
	var dir = Directory.new()
	if dir.make_dir_recursive(folder) != OK:
		return _fail("nao foi possivel criar a pasta local.")
	var basename = folder.plus_file("map00300")
	var hashes = {}
	var buffers = {}
	for ext in refs.oBuffers.FILE_TYPES:
		if not refs.oBuffers.should_process_file_type(ext):
			continue
		var buffer = refs.oBuffers.get_buffer_for_extension(ext, basename)
		if buffer == null:
			return _fail("nao foi possivel serializar " + ext + ".")
		buffers[ext] = buffer
	for ext in buffers:
		var path = basename + "." + str(ext).to_lower()
		if refs.oBuffers.write_buffer_to_file(path, buffers[ext]) != OK:
			return _fail("falha ao gravar " + ext + ".")
		var verified = File.new()
		if verified.open(path, File.READ) != OK:
			return _fail("falha ao verificar " + ext + ".")
		var identical = verified.get_buffer(verified.get_len()) == buffers[ext].data_array
		verified.close()
		if not identical:
			return _fail("verificacao de conteudo falhou para " + ext + ".")
		hashes[path.get_file()] = File.new().get_sha256(path)
	# Materialize the active configuration stack locally instead of changing its paths.
	for scope in [refs.oConfigFileManager.LOAD_CFG_CAMPAIGN, refs.oConfigFileManager.LOAD_CFG_CURRENT_MAP]:
		for path in refs.oConfigFileManager.paths_loaded.get(scope, []):
			if refs.oTMapLoader.parse_tmap_path_details(path) != null:
				continue
			var suffix = path.get_file()
			var prefix = refs.oCurrentMap.path.get_file() + "."
			if suffix.to_lower().begins_with(prefix.to_lower()):
				suffix = suffix.substr(prefix.length())
			var target = basename + "." + suffix
			if dir.copy(path, target) != OK or File.new().get_sha256(path) != File.new().get_sha256(target):
				return _fail("falha ao copiar a configuracao " + suffix + ".")
	var rules = refs.oSaveMap.export_rules_cfg(basename + ".rules.cfg")
	if rules == null:
		return _fail("falha ao guardar regras personalizadas.")
	var slabs = Slabset.get_all_modified_slabs()
	if not slabs.empty() and not Slabset.export_toml_slabset(basename + ".slabset.toml", slabs):
		return _fail("falha ao guardar terrenos personalizados.")
	var columns = Columnset.find_all_different_columns()
	if not columns.empty() and not Columnset.export_toml_columnset(basename + ".columnset.toml", columns):
		return _fail("falha ao guardar colunas personalizadas.")
	if not Cube.get_all_export_cube_ids().empty() and not Cube.export_cfg_cubes(basename + ".cubes.cfg"):
		return _fail("falha ao guardar cubos personalizados.")
	# Modified tilesets also need their external texture files.
	if not refs.oTabTileset.snapshot_tilesets("map00300", folder):
		return _fail("falha ao guardar texturas personalizadas.")
	hashes.clear()
	dir.open(folder)
	dir.list_dir_begin(true, true)
	var name = dir.get_next()
	while name != "":
		if not dir.current_is_dir():
			hashes[name] = File.new().get_sha256(folder.plus_file(name))
		name = dir.get_next()
	dir.list_dir_end()
	var meta = ConfigFile.new()
	meta.set_value("snapshot", "source", refs.oCurrentMap.path)
	meta.set_value("snapshot", "name", refs.oDataMapName.data)
	meta.set_value("snapshot", "time", OS.get_datetime())
	meta.set_value("snapshot", "reason", reason)
	meta.set_value("snapshot", "format", refs.oCurrentFormat.selected)
	meta.set_value("snapshot", "hashes", hashes)
	if meta.save(folder.plus_file("snapshot.cfg")) != OK or dir.rename(folder, final_folder) != OK:
		return _fail("nao foi possivel finalizar a copia de recuperacao.")
	_prune(refs.oCurrentMap.path)
	studio.status.text = "Recuperacao local criada (" + reason + "). Nao enviada ao jogo."
	return final_folder.plus_file("map00300.slb")


func _prune(source: String):
	var count = 0
	for record in list_records():
		if record.source != source or record.reason == "manual":
			continue
		count += 1
		if count <= 30:
			continue
		var identity = record.path.get_file().split("-")
		if identity.size() != 2 or not identity[0].is_valid_integer() or not identity[1].is_valid_integer():
			continue
		var dir = Directory.new()
		if studio._sync_key(record.path.get_base_dir()) != studio._sync_key(root()) or dir.open(record.path) != OK:
			continue
		var expected = record.hashes.duplicate()
		expected["snapshot.cfg"] = ""
		var safe = true
		var names = []
		dir.list_dir_begin(false, false)
		var name = dir.get_next()
		while name != "":
			if not name in [".", ".."]:
				if dir.current_is_dir() or not expected.has(name):
					safe = false
				else:
					names.append(name)
			name = dir.get_next()
		dir.list_dir_end()
		for filename in record.hashes:
			if filename.get_file() != filename or File.new().get_sha256(record.path.plus_file(filename)) != record.hashes[filename]:
				safe = false
		if not safe:
			continue
		for filename in names:
			if dir.remove(record.path.plus_file(filename)) != OK:
				_fail("nao foi possivel limpar uma versao antiga do historico: " + record.path)
				return
		if dir.remove(record.path) != OK:
			_fail("nao foi possivel remover a pasta de uma versao antiga: " + record.path)
			return


func list_records() -> Array:
	var result = []
	var dir = Directory.new()
	if not dir.dir_exists(root()):
		return result
	if dir.open(root()) != OK:
		_fail("nao foi possivel ler o historico.")
		return result
	dir.list_dir_begin(true, true)
	var name = dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			var path = root().plus_file(name)
			var meta = ConfigFile.new()
			if meta.load(path.plus_file("snapshot.cfg")) == OK:
				var record = {"path": path, "source": meta.get_value("snapshot", "source", ""),
					"name": meta.get_value("snapshot", "name", ""), "reason": meta.get_value("snapshot", "reason", ""),
					"time": meta.get_value("snapshot", "time", {}), "hashes": meta.get_value("snapshot", "hashes", {})}
				if not record.hashes is Dictionary or not record.time is Dictionary or not record.source is String or not record.name is String or not record.reason is String:
					_fail("manifesto invalido: " + path + ". A versao foi preservada, mas nao pode ser recuperada automaticamente.")
				else:
					result.append(record)
		name = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(self, "_newest")
	return result


func _newest(a, b) -> bool:
	var first = a.path.get_file().split("-")
	var second = b.path.get_file().split("-")
	if first.size() < 2 or second.size() < 2:
		return a.path.get_file() > b.path.get_file()
	if int(first[0]) != int(second[0]):
		return int(first[0]) > int(second[0])
	return int(first[1]) > int(second[1])


func stamp() -> String:
	var date = OS.get_datetime()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [date.year, date.month, date.day, date.hour, date.minute, date.second]


func saved(game: bool):
	if game:
		last_game = stamp()
		Settings.config.set_value("studio", "last_game_save", last_game)
	else:
		last_local = stamp()
		Settings.config.set_value("studio", "last_local_save", last_local)
	if not studio._save_profiles():
		return
	if studio.visual_tools != null:
		studio.visual_tools.record_save(game)


func open_history():
	records = list_records()
	if is_instance_valid(dialog):
		dialog.free()
	dialog = studio.map_tools._dialog("Historico e recuperacao - nunca substitui o jogo")
	dialog.get_ok().text = "Recuperar copia"
	var box = studio.map_tools._body(dialog)
	var toggle = CheckButton.new()
	toggle.text = "Recuperacao automatica a cada 2 minutos de alteracoes"
	toggle.pressed = enabled
	toggle.connect("toggled", self, "_toggle")
	box.add_child(toggle)
	studio._label(box, "Ultimo salvamento local: " + (last_local if last_local != "" else "sem registro") + "\nUltimo envio ao jogo: " + (last_game if last_game != "" else "sem registro") + "\nRecuperar cria outra copia em Mapas, sem vinculo de sincronizacao.\nMantem as ultimas 30 versoes automaticas/salvas por mapa. Versoes manuais nao expiram.\nO historico e local e nao e enviado ao GitHub.")
	entries = ItemList.new()
	entries.rect_min_size = Vector2(580, 200)
	box.add_child(entries)
	for record in records:
		var date = record.time
		var label = "%s | %s | %s | %s" % [record.path.get_file(), record.reason, record.name, record.source.get_file()]
		if date.has_all(["year", "month", "day", "hour", "minute", "second"]):
			label = "%04d-%02d-%02d %02d:%02d:%02d | %s | %s" % [date.year, date.month, date.day, date.hour, date.minute, date.second, record.reason, record.name]
		entries.add_item(label)
		entries.set_item_tooltip(entries.get_item_count() - 1, record.source + "\n" + record.path)
	details = studio._label(box, "Escolha uma versao. A recuperacao verifica os hashes de todos os arquivos.")
	dialog.connect("confirmed", self, "_restore_selected")
	studio.map_tools._show(dialog)
	dialog.get_ok().text = "Recuperar copia"


func _toggle(value: bool):
	enabled = value
	Settings.config.set_value("studio", "autosave", value)
	studio._save_profiles()


func recover(record: Dictionary) -> String:
	if studio._sync_key(record.path.get_base_dir()) != studio._sync_key(root()) or record.hashes.empty() or not record.hashes.has("map00300.slb"):
		return _fail("copia incompleta ou sem manifesto.")
	for name in record.hashes:
		if name.get_file() != name or File.new().get_sha256(record.path.plus_file(name)) != record.hashes[name]:
			return _fail("arquivo ausente ou alterado: " + name)
	if refs.oEditor.mapHasBeenEdited and capture("antes-recuperar").empty():
		return ""
	var folder = studio.workspace.plus_file("Mapas/Recuperados-%s-%s" % [OS.get_unix_time(), OS.get_ticks_msec()])
	if Directory.new().make_dir_recursive(folder) != OK:
		return _fail("nao foi possivel criar a copia editavel.")
	for name in record.hashes:
		var target = folder.plus_file(name)
		if Directory.new().copy(record.path.plus_file(name), target) != OK or File.new().get_sha256(target) != record.hashes[name]:
			return _fail("falha ao verificar a copia editavel.")
	return folder.plus_file("map00300.slb")


func _restore_selected():
	if entries.get_selected_items().empty():
		studio.map_tools._error("Escolha uma versao no historico.")
		return
	var path = recover(records[entries.get_selected_items()[0]])
	if path.empty():
		return
	dialog.hide()
	# The current unsaved work was preserved by recover(), even if opening is cancelled.
	if refs.oOpenMap.open_map(path):
		studio.status.text = "Copia recuperada. Confira antes de vincular ao jogo; o original nao foi substituido."
