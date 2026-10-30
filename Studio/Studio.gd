extends Node

const Checks = preload("res://Studio/MapChecks.gd")
const Catalog = preload("res://Studio/ContentCatalog.gd")
const OWNER_NAMES = ["Vermelho (voce)", "Azul", "Verde", "Amarelo", "Herois", "Neutro", "Roxo", "Preto", "Laranja"]
const TERRAIN = [
	["Terra", 2], ["Rocha", 0], ["Ouro", 1], ["Gemas", 52],
	["Caminho", 10], ["Terreno conquistado", 11], ["Agua", 13], ["Lava", 12],
	["Parede automatica", 999], ["Ponte", 51]]
const ROOMS = [
	["Coracao da dungeon", 26], ["Portal", 14], ["Tesouro", 16], ["Dormitorio", 38],
	["Galinheiro", 36], ["Treinamento", 24], ["Biblioteca", 18], ["Oficina", 28],
	["Prisao", 20], ["Tortura", 22], ["Templo", 32], ["Cemiterio", 34],
	["Quartel", 40], ["Saqueadores", 30], ["Posto de guarda", 53]]
const DOORS = [["Madeira", 42], ["Reforcada", 44], ["Ferro", 46], ["Magica", 48]]

var refs: Dictionary
var checker = Checks.new()
var panel: PanelContainer
var palette: ItemList
var search: LineEdit
var category: OptionButton
var owner_picker: OptionButton
var profile_label: Label
var status: Label
var selection_label: Label
var wizard: ConfirmationDialog
var new_profile: OptionButton
var new_name: LineEdit
var new_players: SpinBox
var advanced: CheckButton
var report: AcceptDialog
var report_text: TextEdit
var export_confirm: ConfirmationDialog
var exe_dialog: FileDialog
var pending_exe_profile = 0
var pending_export_path = ""
var installed_path = ""
var installed_source = ""
var installed_fingerprint = {}
var last_format = -1
var elapsed = 0.0
var workspace = ""
var gold_exe = ""
var fx_exe = ""
var selected_label = "Escolha um terreno ou uma criatura"
var busy = false
var tool_picker: OptionButton
var working_label: Label
var map_dialog: FileDialog
var last_saved_map = ""
var sync_enabled = false
var sync_targets = {}
var suppress_sync = false
var game_sync = preload("res://Studio/GameSync.gd").new()
var sync_toggle: CheckButton
var target_dialog: FileDialog
var target_confirm: ConfirmationDialog
var pending_sync_source = ""
var pending_sync_target = ""
var catalog = Catalog.new()
var map_tools
var palette_filter: OptionButton
var favorite_button: Button
var favorites = []
var recent_items = []
var selected_entry = ""
var selected_description = ""
var preview: Sprite
var inspect_toggle: CheckButton
var inspecting = false
var inspect_label: Label
var palette_entries = []
var preview_key = ""
var studio_tabs: TabContainer


func _ready():
	refs = Nodelist.list
	workspace = Settings.unearth_path
	_setup_paths()
	_build_ui()
	map_tools = load("res://Studio/MapTools.gd").new()
	map_tools.studio = self
	add_child(map_tools)
	_translate_interface()
	get_tree().connect("files_dropped", self, "_files_dropped")
	call_deferred("_start")


func _setup_paths():
	gold_exe = Settings.config.get_value("studio", "gold_exe", "")
	fx_exe = Settings.config.get_value("studio", "fx_exe", "")
	installed_path = Settings.config.get_value("studio", "installed_path", "")
	installed_source = Settings.config.get_value("studio", "installed_source", "")
	installed_fingerprint = Settings.config.get_value("studio", "installed_fingerprint", {})
	last_saved_map = Settings.config.get_value("studio", "last_saved_map", "")
	sync_enabled = Settings.config.get_value("studio", "sync_enabled", false)
	sync_targets = Settings.config.get_value("studio", "sync_targets", {})
	favorites = Settings.config.get_value("studio", "favorites", [])
	recent_items = Settings.config.get_value("studio", "recent_items", [])
	var detected = refs.oGame.EXECUTABLE_PATH
	if File.new().file_exists(detected):
		if detected.get_file().to_lower().begins_with("keeperfx"):
			fx_exe = detected if fx_exe.empty() else fx_exe
		else:
			gold_exe = detected if gold_exe.empty() else gold_exe
	var base = workspace
	for _i in range(5):
		if gold_exe.empty():
			var candidate = base.plus_file("Keeper/keeper95.exe")
			if File.new().file_exists(candidate):
				gold_exe = candidate
		if fx_exe.empty():
			var candidate = base.plus_file("Keeper/KeeperFX/keeperfx.exe")
			if File.new().file_exists(candidate):
				fx_exe = candidate
		base = base.get_base_dir()
	for folder in ["Mapas", "Exportados", "Exportados/Gold", "Exportados/KeeperFX"]:
		var error = Directory.new().make_dir_recursive(workspace.plus_file(folder))
		if error != OK and error != ERR_ALREADY_EXISTS:
			refs.oMessage.big("Pasta indisponivel", "Nao foi possivel criar " + folder + ". Erro: " + str(error))
	if detected.empty() and not gold_exe.empty():
		Settings.set_setting("executable_path", gold_exe)
	_save_profiles()


func _save_profiles() -> bool:
	Settings.config.set_value("studio", "gold_exe", gold_exe)
	Settings.config.set_value("studio", "fx_exe", fx_exe)
	Settings.config.set_value("studio", "sync_enabled", sync_enabled)
	Settings.config.set_value("studio", "sync_targets", sync_targets)
	var error = Settings.config.save(Settings.settings_file_path)
	if error != OK:
		refs.oMessage.big("Configuracao", "Nao foi possivel salvar os caminhos. Erro: " + str(error))
	return error == OK


func _build_ui():
	panel = PanelContainer.new()
	panel.name = "StudioPanel"
	panel.rect_position = Vector2(12, 72)
	panel.rect_min_size.x = 310
	var studio_theme = Theme.new()
	var font = DynamicFont.new()
	font.font_data = load("res://Theme/Hack_Regular.ttf")
	font.size = 14
	studio_theme.default_font = font
	panel.theme = studio_theme
	refs.oUiTools.add_child(panel)
	var box = VBoxContainer.new()
	box.add_constant_override("separation", 7)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(box)
	var title = Label.new()
	title.text = "DUNGEON KEEPER STUDIO"
	title.add_color_override("font_color", Color("#e8bf77"))
	box.add_child(title)
	profile_label = _label(box, "Crie ou abra um mapa para comecar.")
	_row(box, [["Novo mapa", "_show_wizard"], ["Abrir meus mapas", "_browse"]])
	_row(box, [["Salvar mapa", "save_working_map"], ["Testar", "_test"]])
	var root_box = box
	studio_tabs = TabContainer.new()
	studio_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	studio_tabs.rect_min_size.y = 250
	root_box.add_child(studio_tabs)
	box = _studio_tab("Mapa")
	_row(box, [["Exportar ao jogo", "_confirm_export"], ["Verificar", "_verify"]])
	_row(box, [["Importar original", "_import_original"], ["Salvar nova copia", "_save_copy"]])
	_row(box, [["Retomar ultimo salvo", "_resume_saved"]])
	sync_toggle = CheckButton.new()
	sync_toggle.text = "Salvar tambem no KeeperFX"
	sync_toggle.pressed = sync_enabled
	box.add_child(sync_toggle)
	sync_toggle.connect("toggled", self, "_sync_toggled")
	_row(box, [["Vincular fase do KeeperFX", "_choose_sync_target"]])
	working_label = _label(box, "Nenhum mapa aberto.")
	working_label.hint_tooltip = "O painel mostra a copia editavel e o destino sincronizado. Feche e reinicie a fase para carregar mudancas."
	_row(box, [["Regras avancadas", "_rules"]])
	_row(box, [["Poderes por jogador", "_powers"], ["Objetivos e eventos", "_events"]])
	_row(box, [["Configurar jogos", "_configure"], ["Pasta de mapas", "_open_folder"]])
	box = _studio_tab("Construir")
	owner_picker = OptionButton.new()
	box.add_child(_heading("Dono dos terrenos e criaturas"))
	box.add_child(owner_picker)
	owner_picker.connect("item_selected", self, "_owner_selected")
	category = OptionButton.new()
	for text in ["Terreno", "Salas e coracao", "Criaturas", "Armadilhas", "Portas", "Itens especiais", "Livros de magia", "Areas de evento"]:
		category.add_item(text)
	box.add_child(category)
	category.connect("item_selected", self, "_category_changed")
	search = LineEdit.new()
	search.placeholder_text = "Buscar pelo nome..."
	box.add_child(search)
	search.connect("text_changed", self, "_search_changed")
	palette_filter = OptionButton.new()
	for text in ["Todos da categoria", "Favoritos (todas as categorias)", "Recentes (todas as categorias)"]:
		palette_filter.add_item(text)
	box.add_child(palette_filter)
	palette_filter.connect("item_selected", self, "_category_changed")
	palette = ItemList.new()
	palette.rect_min_size = Vector2(300, 160)
	palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette.max_columns = 2
	palette.same_column_width = true
	palette.fixed_column_width = 146
	palette.fixed_icon_size = Vector2(34, 34)
	palette.icon_mode = ItemList.ICON_MODE_TOP
	palette.max_text_lines = 2
	box.add_child(palette)
	palette.connect("item_selected", self, "_palette_selected")
	selection_label = _label(box, selected_label)
	favorite_button = Button.new()
	favorite_button.text = "Adicionar aos favoritos"
	favorite_button.disabled = true
	favorite_button.connect("pressed", self, "_favorite")
	box.add_child(favorite_button)
	var tools = OptionButton.new()
	tool_picker = tools
	for text in ["Lapis", "Pincel", "Retangulo", "Preencher"]:
		tools.add_item(text)
	box.add_child(tools)
	tools.connect("item_selected", self, "_tool_selected")
	var brush_row = HBoxContainer.new()
	box.add_child(brush_row)
	_label(brush_row, "Tamanho")
	var brush = _spin(brush_row, 1, 15, 1)
	brush.connect("value_changed", self, "_brush_changed")
	_label(brush_row, "Nivel")
	var level = _spin(brush_row, 1, 10, 1)
	level.connect("value_changed", self, "_level_changed")
	var area_row = HBoxContainer.new()
	box.add_child(area_row)
	_label(area_row, "Raio da area (subblocos)")
	var radius = _spin(area_row, 1, 30, 3)
	refs.oPlacingSettings.pointRange = 3
	radius.connect("value_changed", self, "_area_radius_changed")
	_label(box, "Clique: colocar | Direito: copiar\nRoda: zoom | Central: mover | Ctrl+Z: desfazer")
	box = _studio_tab("Inspecionar")
	inspect_toggle = CheckButton.new()
	inspect_toggle.text = "Inspecionar (sem pintar)"
	box.add_child(inspect_toggle)
	inspect_toggle.connect("toggled", self, "_inspect_toggled")
	inspect_label = _label(box, "Ative Inspecionar e clique em um elemento.")
	_row(box, [["Editar selecionado", "_edit_element"], ["Duplicar", "_duplicate_element"], ["Excluir", "_delete_element"]])
	_label(box, "Clique em criaturas, itens ou areas no mapa.\nEditar abre as propriedades. Duplicar prepara uma copia para colocar em outro local.\nPortas e coracoes sao editados como terreno.")
	advanced = CheckButton.new()
	advanced.text = "Ferramentas avancadas do Unearth"
	box.add_child(advanced)
	advanced.connect("toggled", self, "_advanced_changed")
	status = _label(root_box, "Os mapas originais sao protegidos.")
	status.add_color_override("font_color", Color("#a8c9a1"))
	get_viewport().connect("size_changed", self, "_layout")
	_build_dialogs()
	preview = Sprite.new()
	preview.modulate = Color(1, 1, 1, 0.55)
	preview.z_index = 100
	refs.oSelector.add_child(preview)
	studio_tabs.current_tab = 1
	studio_tabs.connect("tab_changed", self, "_studio_tab_changed")
	_layout()


func _studio_tab(title: String) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.name = title
	scroll.scroll_horizontal_enabled = false
	studio_tabs.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_constant_override("separation", 7)
	scroll.add_child(box)
	return box


func _studio_tab_changed(index: int):
	var enabled = index == 2
	inspect_toggle.set_pressed_no_signal(enabled)
	_inspect_toggled(enabled)


func _label(parent: Node, text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap = parent is VBoxContainer
	label.rect_min_size.x = 280 if parent is VBoxContainer else 0
	parent.add_child(label)
	return label


func _heading(text: String) -> Label:
	var label = Label.new()
	label.text = text
	return label


func _row(parent: Node, actions: Array):
	var row = HBoxContainer.new()
	parent.add_child(row)
	for action in actions:
		var button = Button.new()
		button.text = action[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.connect("pressed", self, action[1])
		row.add_child(button)


func _spin(parent: Node, minimum: int, maximum: int, value: int) -> SpinBox:
	var spin = SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = value
	spin.rect_min_size.x = 65
	parent.add_child(spin)
	return spin


func _layout():
	var height = get_viewport().size.y / Settings.UI_SCALE.y
	panel.rect_size = Vector2(330, max(300, height - 90))


func _build_dialogs():
	var ui = refs.oUi.get_node("UiSystem")
	wizard = ConfirmationDialog.new()
	wizard.window_title = "Criar mapa jogavel"
	wizard.get_ok().text = "Criar mapa"
	wizard.get_cancel().text = "Cancelar"
	ui.add_child(wizard)
	var box = VBoxContainer.new()
	wizard.add_child(box)
	_label(box, "Compatibilidade (nao converte mapas abertos)")
	new_profile = OptionButton.new()
	new_profile.add_item("Dungeon Keeper Gold - original", Constants.OldFormat)
	new_profile.add_item("KeeperFX - formato estendido", Constants.KfxFormat)
	box.add_child(new_profile)
	_label(box, "Nome do mapa")
	new_name = LineEdit.new()
	new_name.text = "Minha dungeon"
	box.add_child(new_name)
	_label(box, "Jogadores: vermelho humano; demais com IA")
	new_players = _spin(box, 1, 4, 2)
	_label(box, "Mapa 85 x 85 com bases, portais e regras iniciais.\nOuro e limite de criaturas podem ser alterados em Regras.\nKeeperFX pode ser editado antes de configurar seu executavel.")
	wizard.connect("confirmed", self, "_create_map")
	report = AcceptDialog.new()
	report.window_title = "Diagnostico do mapa"
	report.rect_min_size = Vector2(700, 420)
	ui.add_child(report)
	report_text = TextEdit.new()
	report_text.readonly = true
	report_text.wrap_enabled = true
	report_text.anchor_right = 1
	report_text.anchor_bottom = 1
	report_text.margin_bottom = -45
	report.add_child(report_text)
	export_confirm = ConfirmationDialog.new()
	export_confirm.window_title = "Exportar sem substituir mapas existentes"
	export_confirm.get_ok().text = "Exportar"
	ui.add_child(export_confirm)
	export_confirm.connect("confirmed", self, "_export")
	exe_dialog = FileDialog.new()
	exe_dialog.access = FileDialog.ACCESS_FILESYSTEM
	exe_dialog.mode = FileDialog.MODE_OPEN_FILE
	exe_dialog.add_filter("*.exe ; Executavel do jogo")
	ui.add_child(exe_dialog)
	exe_dialog.connect("file_selected", self, "_exe_selected")
	map_dialog = FileDialog.new()
	map_dialog.access = FileDialog.ACCESS_FILESYSTEM
	map_dialog.mode = FileDialog.MODE_OPEN_FILE
	map_dialog.add_filter("*.slb ; Mapa Dungeon Keeper")
	ui.add_child(map_dialog)
	map_dialog.connect("file_selected", self, "_map_selected")
	_prepare_file_picker(map_dialog)
	var shortcuts = HBoxContainer.new()
	map_dialog.get_vbox().add_child(shortcuts)
	map_dialog.get_vbox().move_child(shortcuts, 0)
	for location in [["Meus mapas", "local"], ["Campanha KeeperFX", "keeperfx"], ["Gold original", "gold"]]:
		var button = Button.new()
		button.text = location[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.connect("pressed", self, "_map_location", [location[1]])
		shortcuts.add_child(button)
	target_dialog = FileDialog.new()
	target_dialog.window_title = "Escolha a fase do KeeperFX que esta copia vai substituir"
	target_dialog.access = FileDialog.ACCESS_FILESYSTEM
	target_dialog.mode = FileDialog.MODE_OPEN_FILE
	target_dialog.add_filter("*.slb ; Fase existente (sera substituida com backup)")
	ui.add_child(target_dialog)
	target_dialog.connect("file_selected", self, "_sync_target_selected")
	_prepare_file_picker(target_dialog)
	target_confirm = ConfirmationDialog.new()
	target_confirm.window_title = "Confirmar substituicao ao salvar"
	target_confirm.get_ok().text = "Vincular"
	ui.add_child(target_confirm)
	target_confirm.connect("confirmed", self, "_confirm_sync_target")


func _start():
	refs.oCurrentMap.clear_map()
	refs.oChangelogWindow.hide()
	refs.oMapBrowser.hide()
	for arg in OS.get_cmdline_args():
		if arg.get_extension().to_lower() in ["slb", "tng", "tngfx"]:
			refs.oOpenMap.open_map(arg)
			return
	_refresh_palette()
	if not "--studio-test" in OS.get_cmdline_args():
		if _saved_map_file().empty():
			_show_wizard()
		else:
			_resume_saved()


func _translate_interface():
	var menus = {
		"oMenuButtonFile": "Arquivo", "oMenuButtonEdit": "Editar",
		"oMenuButtonMap": "Mapa", "oMenuButtonScript": "Regras",
		"oMenuButtonView": "Visualizar", "oMenuButtonHelp": "Ajuda"}
	for key in menus:
		refs[key].text = menus[key]
	var translations = {
		"New map": "Novo mapa (avancado)", "Open map": "Abrir mapa",
		"Browse maps": "Explorar mapas", "Open recent": "Recentes",
		"Save map": "Salvar mapa", "Save map as": "Salvar como",
		"Reload map": "Reabrir mapa", "Backups": "Copias de seguranca",
		"Preferences": "Preferencias", "Exit": "Sair", "Undo": "Desfazer",
		"Resize map": "Redimensionar mapa", "Map properties": "Propriedades do mapa",
		"Controls": "Controles", "Gold": "Ouro inicial", "Creature limit": "Limite de criaturas",
		"Portal attraction rate": "Intervalo do portal", "Add default setup": "Adicionar regras iniciais",
		"Edit": "Editar texto", "Delete": "Excluir", "AI": "Inteligencia artificial"}
	for key in menus:
		var popup = refs[key].get_popup()
		for i in popup.get_item_count():
			var text = popup.get_item_text(i)
			if translations.has(text):
				popup.set_item_text(i, translations[text])
	_translate_labels(refs.oScriptGeneratorWindow, translations)
	refs.oScriptGeneratorWindow.window_title = "Regras - disponibilidade, criaturas e IA"


func _translate_labels(node: Node, translations: Dictionary):
	if node is Label or node is Button:
		if translations.has(node.text):
			node.text = translations[node.text]
	for child in node.get_children():
		_translate_labels(child, translations)


func _process(delta):
	_update_preview()
	elapsed += delta
	if elapsed < 0.15:
		return
	elapsed = 0
	panel.visible = refs.oEditor.currentView == refs.oEditor.VIEW_2D and not advanced.pressed
	if not advanced.pressed:
		for key in ["oPickSlabWindow", "oPickThingWindow", "oPropertiesWindow", "oEditingMode"]:
			refs[key].hide()
	if last_format != refs.oCurrentFormat.selected:
		last_format = refs.oCurrentFormat.selected
		_refresh_owners()
		_refresh_palette()
	var classic = refs.oCurrentFormat.selected == Constants.OldFormat
	profile_label.text = ("GOLD ORIGINAL | 85 x 85" if classic else "KEEPERFX | formato estendido")
	if sync_enabled:
		profile_label.text += "\nJogo sincronizado: KeeperFX"
	var runtime = gold_exe if classic else fx_exe
	if not File.new().file_exists(runtime):
		profile_label.text += "\nExecutavel nao configurado: exportacao ao jogo indisponivel."
	var path = refs.oCurrentMap.path
	working_label.text = "Edicao: " + (path if not path.empty() else "mapa novo, ainda nao salvo")
	if refs.oEditor.mapHasBeenEdited:
		working_label.text += "\nALTERACOES AINDA NAO SALVAS"
	if sync_enabled:
		working_label.text += "\nSalvar: copia local + KeeperFX (com backup)."
		working_label.text += "\nDestino: " + str(sync_targets.get(_sync_key(path), "novo mapa em levels/studio"))
	elif path != installed_source or installed_path.empty():
		working_label.text += "\nEsta copia nao foi exportada. Salvar nao altera a campanha original."
	else:
		working_label.text += "\nUltimo destino no jogo: " + installed_path.get_file()
		working_label.text += "\nApos editar, exporte novamente e use Testar (nao um atalho antigo)."
	if not sync_enabled:
		working_label.text += "\nSINCRONIZACAO DESLIGADA: Salvar NAO atualiza o KeeperFX."
	selection_label.text = selected_label + "\n" + selected_description + "\nDono: " + OWNER_NAMES[int(refs.oSelection.paintOwnership)]
	if is_instance_valid(map_tools):
		inspect_label.text = map_tools.selection_summary()
	palette.mouse_filter = Control.MOUSE_FILTER_STOP


func _refresh_owners():
	owner_picker.clear()
	for i in OWNER_NAMES.size():
		if refs.oCurrentFormat.selected == Constants.OldFormat and i > 5:
			continue
		owner_picker.add_item(OWNER_NAMES[i], i)
	if refs.oCurrentFormat.selected == Constants.OldFormat and refs.oSelection.paintOwnership > 5:
		refs.oSelection.paintOwnership = 0
	owner_picker.select(owner_picker.get_item_index(refs.oSelection.paintOwnership))


func _owner_selected(index):
	refs.oUseSlabOwnerCheckBox.pressed = false
	refs.oSelection.paintOwnership = owner_picker.get_item_id(index)


func _category_changed(_index):
	_refresh_palette()


func _search_changed(_text):
	_refresh_palette()


func _refresh_palette():
	palette.set_block_signals(true)
	palette.clear()
	palette_entries.clear()
	var categories = [category.selected]
	if palette_filter.selected > 0:
		categories = range(8)
	for source_category in categories:
		_append_palette_category(source_category)
	if palette_filter.selected == 2:
		var destination_index = 0
		for key in recent_items:
			for index in range(destination_index, palette.get_item_count()):
				if "%s:%s" % [palette_entries[index], palette.get_item_metadata(index)] == key:
					palette.move_item(index, destination_index)
					var source_category = palette_entries[index]
					palette_entries.remove(index)
					palette_entries.insert(destination_index, source_category)
					destination_index += 1
					break
	palette.set_block_signals(false)


func _append_palette_category(source_category: int):
	var entries = []
	match source_category:
		0: entries = TERRAIN
		1: entries = ROOMS
		2:
			for id in Things.DATA_CREATURE:
				if id == 0 or id == 31:
					continue
				if refs.oCurrentFormat.selected == Constants.OldFormat and id > 30:
					continue
				entries.append([Things.fetch_name(Things.TYPE.CREATURE, id), id])
		3:
			for id in Things.DATA_TRAP:
				if id == 0 or (refs.oCurrentFormat.selected == Constants.OldFormat and id > 6):
					continue
				entries.append([Things.fetch_name(Things.TYPE.TRAP, id), id])
		4: entries = DOORS
		_: entries = catalog.entries(source_category, refs.oCurrentFormat.selected == Constants.OldFormat, refs.oScriptGenerator)
	for entry in entries:
		var key = "%s:%s" % [source_category, entry[1]]
		if palette_filter.selected == 1 and not key in favorites:
			continue
		if palette_filter.selected == 2 and not key in recent_items:
			continue
		var description = _entry_description(source_category, entry[1])
		if not search.text.empty() and not catalog.search_key(search.text) in catalog.search_key(entry[0] + " " + description):
			continue
		var icon
		if source_category in [0, 1, 4]:
			var icon_id = entry[1] + 1 if source_category == 4 else entry[1]
			icon = Slabs.icons.get(Slabs.fetch_idname(icon_id), null)
			if icon == null:
				icon = _terrain_icon(entry[1])
		else:
			var type = _category_type(source_category)
			icon = Things.fetch_icon_sprite(type, entry[1], Vector2(34, 34), 2.0)
		palette.add_item(_palette_title(entry[0]), icon)
		palette.set_item_metadata(palette.get_item_count() - 1, entry[1])
		palette_entries.append(source_category)
		palette.set_item_tooltip(palette.get_item_count() - 1, entry[0] + "\n" + description + "\nSelecione e clique no mapa para colocar.")


func _category_type(value: int) -> int:
	return {2: Things.TYPE.CREATURE, 3: Things.TYPE.TRAP, 5: Things.TYPE.OBJECT, 6: Things.TYPE.OBJECT, 7: Things.TYPE.EXTRA}.get(value, Things.TYPE.NONE)


func _palette_title(text: String) -> String:
	return {"Ressuscitar criatura": "Ressuscitar", "Transferir criatura": "Transferir",
		"Multiplicar criaturas": "Multiplicar", "Encontrar mundo secreto": "Mundo secreto",
		"Transformar em galinha": "Virar galinha", "Convocar audiencia": "Audiencia",
		"Coracao da dungeon": "Coracao"}.get(text, text)


func _entry_description(value: int, id: int) -> String:
	if value in [5, 6]:
		var text = catalog.object_description(id)
		text += "\nLivro coletavel; liberar o poder inicial e uma opcao separada." if value == 6 else ""
		text += "\nNa biblioteca, o dono segue o terreno; fora dela, fica neutro."
		return text + ("\nGold / KeeperFX" if Catalog.OBJECTS.has(id) else "\nKeeperFX (configuracao instalada)")
	if value == 7:
		return "Area circular usada em Objetivos e eventos. Ajuste o raio antes de colocar; o numero e automatico."
	return "Selecione para pintar ou colocar. Use Inspecionar para editar elementos existentes."


func _terrain_icon(id: int) -> ImageTexture:
	var colors = {
		0: Color("#595c67"), 1: Color("#d8ad35"), 2: Color("#906033"),
		10: Color("#b09c73"), 11: Color("#ad4947"), 12: Color("#f35420"),
		13: Color("#448ed0"), 14: Color("#6a4d9b"), 51: Color("#a68565"),
		52: Color("#5bcca8"), 999: Color("#a5a7b5")}
	var image = Image.new()
	image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(colors.get(id, Color("#ab8855")))
	var texture = ImageTexture.new()
	texture.create_from_image(image, 0)
	return texture


func _palette_selected(index):
	var id = palette.get_item_metadata(index)
	var source_category = palette_entries[index]
	selected_entry = "%s:%s" % [source_category, id]
	selected_description = _entry_description(source_category, id)
	selected_label = palette.get_item_tooltip(index).split("\n")[0]
	inspect_toggle.set_pressed_no_signal(false)
	_inspect_toggled(false)
	studio_tabs.current_tab = 1
	if source_category in [0, 1, 4]:
		preview.texture = null
		refs.oSelection.paintSlab = id
		refs.oPickSlabWindow.set_selection(id)
		refs.oPlacingSettings.set_placing_tab_and_update_it()
		if id == Slabs.DUNGEON_HEART or id == Slabs.PORTAL:
			tool_picker.select(0)
			_tool_selected(0)
			refs.oEditingTools.BRUSH_SIZE = 3
			refs.oBrushPreview.update_img()
			status.text = "Coracoes e portais: carimbo 3 x 3. Clique uma vez no mapa."
	else:
		var type = _category_type(source_category)
		refs.oSelection.paintThingType = type
		refs.oSelection.paintSubtype = id
		refs.oPickThingWindow.set_selection(type, id)
		refs.oUseSlabOwnerCheckBox.pressed = false
		refs.oPlacingSettings.set_placing_tab_and_update_it()
		preview.texture = Things.fetch_sprite(type, id)
	recent_items.erase(selected_entry)
	recent_items.push_front(selected_entry)
	recent_items.resize(int(min(20, recent_items.size())))
	_save_palette_preferences()
	_update_favorite_button()


func _save_palette_preferences():
	Settings.config.set_value("studio", "favorites", favorites)
	Settings.config.set_value("studio", "recent_items", recent_items)
	if Settings.config.save(Settings.settings_file_path) != OK:
		refs.oMessage.big("Preferencias", "Nao foi possivel salvar favoritos e recentes.")


func _update_favorite_button():
	favorite_button.disabled = selected_entry.empty()
	favorite_button.text = "Remover dos favoritos" if selected_entry in favorites else "Adicionar aos favoritos"


func _favorite():
	if selected_entry.empty():
		return
	if selected_entry in favorites:
		favorites.erase(selected_entry)
	else:
		favorites.append(selected_entry)
	_save_palette_preferences()
	_update_favorite_button()
	_refresh_palette()


func _area_radius_changed(value):
	refs.oPlacingSettings.pointRange = int(value)


func _inspect_toggled(enabled):
	inspecting = enabled
	refs.oSelector.holdClickOnInstance = null
	refs.oSelector.draggingInstance = false
	refs.oRectangleSelection.clear()
	if enabled:
		refs.oSelector.change_mode(refs.oSelector.MODE_SUBTILE)
		status.text = "Inspecao: clique para selecionar. Nao coloca nem arrasta elementos."
	else:
		status.text = "Edicao: escolha um elemento na paleta para colocar."


func _update_preview():
	if not is_instance_valid(preview):
		return
	var selection = refs.oSelection
	var key = "%s:%s" % [selection.paintThingType, selection.paintSubtype]
	if key != preview_key and selection.paintThingType != null and selection.paintSubtype != null:
		preview_key = key
		preview.texture = Things.fetch_sprite(selection.paintThingType, selection.paintSubtype)
	preview.visible = panel.visible and not inspecting and refs.oSelector.visible and refs.oSelector.mode == refs.oSelector.MODE_SUBTILE and preview.texture != null and not refs.oLoadingBar.visible
	preview.global_position = (refs.oSelector.cursorSubtile + Vector2(0.5, 0.5)) * Constants.SUBTILE_SIZE


func _powers():
	if _has_map():
		map_tools.open_powers()


func _events():
	if _has_map():
		map_tools.open_events()


func _edit_element():
	map_tools.open_inspector()


func _duplicate_element():
	map_tools.duplicate_element()


func _delete_element():
	map_tools.delete_element()


func _tool_selected(index):
	var buttons = ["oToolPencil", "oToolBrush", "oToolRectangle", "oToolPaintBucket"]
	refs[buttons[index]].pressed = true


func _brush_changed(value):
	refs.oEditingTools.BRUSH_SIZE = int(value)
	refs.oBrushPreview.update_img()


func _level_changed(value):
	refs.oPlacingSettings.creatureLevel = int(value)


func _advanced_changed(enabled):
	if enabled:
		refs.oUi.show_tools()
		panel.hide()
		var back = refs.oMenu.get_child(0).get_node_or_null("StudioBack")
		if back == null:
			back = Button.new()
			back.name = "StudioBack"
			back.text = "Modo simples"
			refs.oMenu.get_child(0).add_child(back)
			back.connect("pressed", self, "_simple_mode")
	else:
		refs.oMessage.quick("Modo simples: selecione o que deseja colocar na paleta.")


func _simple_mode():
	advanced.pressed = false


func _show_wizard():
	if refs.oEditor.mapHasBeenEdited:
		refs.oMessage.big("Salve primeiro", "Salve uma copia do mapa atual antes de criar outro. Nenhuma alteracao sera descartada.")
		return
	Utils.popup_centered(wizard)


func _create_map():
	if busy:
		return
	var format = new_profile.get_selected_id()
	var exe = gold_exe if format == Constants.OldFormat else fx_exe
	if not File.new().file_exists(exe):
		exe = gold_exe
	if not File.new().file_exists(exe):
		refs.oMessage.big("Dados do jogo", "Configure um executavel valido antes de criar o mapa.")
		return
	if refs.oEditor.mapHasBeenEdited:
		refs.oMessage.big("Salve primeiro", "O mapa atual tem alteracoes. Salve uma copia antes de criar outro.")
		return
	busy = true
	if refs.oGame.EXECUTABLE_PATH != exe:
		Settings.set_setting("executable_path", exe)
	var native = refs.oNewMapWindow
	native.visible = true
	refs.oSetNewFormat.selected = format
	native._on_NewMapFormat_item_selected(format)
	refs.oXSizeLine.text = "85"
	refs.oYSizeLine.text = "85"
	refs.oCheckBoxNewMapBorder.pressed = true
	native._on_CheckBoxNewMapBorder_pressed()
	refs.oPlacePlayersCheckBox.pressed = true
	refs.oPlayerCount.value = new_players.value
	refs.oCheckBoxNewMapAutoOpensMapSettings.pressed = false
	native.update_border_image_with_noise()
	var result = native.create_new_map()
	if result is GDScriptFunctionState:
		yield(result, "completed")
	native.hide()
	if Slabset.dat.empty():
		busy = false
		refs.oMessage.big("Falha na criacao", "Os dados do jogo nao foram carregados. Confira o executavel em Configurar jogos.")
		return
	var features = _add_starter_features()
	if features is GDScriptFunctionState:
		yield(features, "completed")
	busy = false
	refs.oDataMapName.set_map_name(new_name.text.strip_edges())
	refs.oDataLof.KIND = "FREE"
	refs.oScriptGenerator.add_default_setup()
	refs.oEditor.mapHasBeenEdited = true
	refs.oSelection.paintOwnership = 0
	_refresh_owners()
	_refresh_palette()
	status.text = "Mapa criado. Desenhe o terreno e adicione criaturas."


func _add_starter_features():
	var positions = []
	for heart in get_tree().get_nodes_in_group("Object"):
		if heart.subtype != 5:
			continue
		var center = Vector2(int(heart.locationX / 3), int(heart.locationY / 3))
		var dx = 1 if center.x < M.xSize / 2 else -1
		var dy = 1 if center.y < M.ySize / 2 else -1
		var portal = center + Vector2(dx * 8, 0)
		var tiles = []
		for y in range(-1, 2):
			for x in range(-1, 2):
				tiles.append(portal + Vector2(x, y))
		refs.oSlabPlacement.place_shape_of_slab_id(tiles, Slabs.PORTAL, heart.ownership)
		positions.append_array(tiles)
		tiles = []
		for step in range(3, 7):
			tiles.append(center + Vector2(dx * step, 0))
		refs.oSlabPlacement.place_shape_of_slab_id(tiles, Slabs.CLAIMED_GROUND, heart.ownership)
		positions.append_array(tiles)
		tiles = []
		for y in range(5, 8):
			for x in range(-2, 2):
				tiles.append(center + Vector2(x, dy * y))
		refs.oSlabPlacement.place_shape_of_slab_id(tiles, Slabs.GOLD, 5)
		positions.append_array(tiles)
	if not positions.empty():
		yield(refs.oSlabPlacement.generate_slabs_based_on_id(positions, true), "completed")


func _browse():
	map_dialog.window_title = "Abrir meus mapas - copias de trabalho salvas"
	_show_file_picker(map_dialog, workspace.plus_file("Mapas"))


func _import_original():
	map_dialog.window_title = "Importar original - cria OUTRA copia; nao reabre suas edicoes"
	var folder = refs.oGame.DK_LEVELS_DIRECTORY
	if sync_enabled and File.new().file_exists(fx_exe):
		folder = fx_exe.get_base_dir().plus_file("campgns/keeporig")
	_show_file_picker(map_dialog, folder)


func _prepare_file_picker(dialog: FileDialog):
	dialog.resizable = true
	dialog.rect_min_size = Vector2(640, 440)
	_file_picker_tree(dialog).rect_min_size.y = 260
	dialog.get_ok().text = "Abrir mapa"
	dialog.get_cancel().text = "Cancelar"
	dialog.get_line_edit().placeholder_text = "Selecione um mapa na lista acima"


func _file_picker_tree(node: Node) -> Tree:
	if node is Tree:
		return node as Tree
	for child in node.get_children():
		var tree = _file_picker_tree(child)
		if tree != null:
			return tree
	return null


func _show_file_picker(dialog: FileDialog, folder: String):
	if not Directory.new().dir_exists(folder):
		refs.oMessage.big("Pasta nao encontrada", "Nao foi possivel abrir:\n" + folder + "\nConfira o caminho em Configurar jogos.")
		return
	dialog.current_file = ""
	dialog.current_dir = folder
	dialog.invalidate()
	var available = get_viewport().size / dialog.get_global_transform().get_scale()
	dialog.rect_size = Vector2(min(1000, available.x * 0.9), min(680, available.y * 0.85))
	Utils.popup_centered(dialog)
	dialog.get_ok().text = "Abrir mapa"
	_file_picker_tree(dialog).grab_focus()


func _map_location(location: String):
	var folder = workspace.plus_file("Mapas")
	if location == "keeperfx":
		if not File.new().file_exists(fx_exe):
			refs.oMessage.big("Configure o KeeperFX", "Selecione keeperfx.exe em Configurar jogos para navegar nas campanhas.")
			return
		folder = fx_exe.get_base_dir().plus_file("campgns/keeporig")
	elif location == "gold":
		if not File.new().file_exists(gold_exe):
			refs.oMessage.big("Configure o Gold", "Selecione o executavel original em Configurar jogos.")
			return
		folder = gold_exe.get_base_dir().plus_file("levels")
	map_dialog.window_title = "Abrir mapa - arquivos do jogo serao abertos como copias"
	_show_file_picker(map_dialog, folder)


func _map_selected(path: String):
	wizard.hide()
	refs.oOpenMap.open_map(path)


func _saved_map_file() -> String:
	var root = workspace.replace("\\", "/").trim_suffix("/").to_lower() + "/Mapas/"
	if not last_saved_map.replace("\\", "/").to_lower().begins_with(root.to_lower()):
		return ""
	return Utils.case_insensitive_file(last_saved_map.get_base_dir(), last_saved_map.get_file(), ".slb")


func _resume_saved():
	var path = _saved_map_file()
	if path.empty():
		refs.oMessage.big("Retomar mapa", "Nenhuma copia salva foi encontrada. Use Abrir meus mapas para escolher suas edicoes.")
		return
	_map_selected(path)


func _rules():
	refs.oScriptGenerator.open()


func _configure():
	var dialog = AcceptDialog.new()
	dialog.window_title = "Configurar os dois jogos"
	var box = VBoxContainer.new()
	dialog.add_child(box)
	_label(box, "Gold original:\n" + (gold_exe if not gold_exe.empty() else "Nao configurado"))
	var gold = Button.new()
	gold.text = "Selecionar keeper95.exe / keeper.exe"
	gold.connect("pressed", self, "_pick_exe", [Constants.OldFormat])
	box.add_child(gold)
	_label(box, "KeeperFX:\n" + (fx_exe if not fx_exe.empty() else "Nao instalado ou nao configurado"))
	var fx = Button.new()
	fx.text = "Selecionar keeperfx.exe"
	fx.connect("pressed", self, "_pick_exe", [Constants.KfxFormat])
	box.add_child(fx)
	_label(box, "A selecao vale para novos mapas e para testar/exportar.\nNao instala o jogo e nao converte o mapa aberto.")
	refs.oUi.get_node("UiSystem").add_child(dialog)
	dialog.connect("popup_hide", dialog, "queue_free")
	Utils.popup_centered(dialog)


func _pick_exe(profile):
	pending_exe_profile = profile
	exe_dialog.window_title = "Selecionar executavel do jogo"
	exe_dialog.current_dir = refs.oGame.GAME_DIRECTORY
	Utils.popup_centered(exe_dialog)


func _exe_selected(path):
	var name = path.get_file().to_lower()
	var valid_name = name in ["keeper.exe", "keeper95.exe", "deeper.exe", "deeper95.exe"]
	if pending_exe_profile == Constants.KfxFormat:
		valid_name = name in ["keeperfx.exe", "keeperfx_hvlog.exe"]
	if not valid_name or not Directory.new().dir_exists(path.get_base_dir().plus_file("data")):
		refs.oMessage.big("Jogo invalido", "Selecione o executavel correto em uma instalacao que contenha a pasta data.")
		return
	if pending_exe_profile == Constants.OldFormat:
		gold_exe = path
	else:
		fx_exe = path
	_save_profiles()
	refs.oMessage.big("Caminho salvo", "Executavel configurado:\n" + path + "\nSera usado nos proximos mapas e testes desse perfil.")


func snapshot() -> Dictionary:
	var hearts = {}
	var extended = false
	var blocked = 0
	for object in get_tree().get_nodes_in_group("Object"):
		if object.subtype == 5:
			hearts[object.ownership] = hearts.get(object.ownership, 0) + 1
	for thing in get_tree().get_nodes_in_group("Instance"):
		if "ownership" in thing and thing.ownership > 5:
			extended = true
	var creatures = get_tree().get_nodes_in_group("Creature")
	for creature in creatures:
		if creature.subtype > 30:
			extended = true
		var slab = refs.oDataSlab.get_cell(int(creature.locationX / 3), int(creature.locationY / 3))
		if Slabs.data.has(slab) and Slabs.data[slab][Slabs.IS_SOLID]:
			blocked += 1
	for y in range(M.ySize):
		for x in range(M.xSize):
			var slab = refs.oDataSlab.get_cell(x, y)
			if slab > 53 or refs.oDataOwnership.get_cell_ownership(x, y) > 5:
				extended = true
	return {
		"classic": refs.oCurrentFormat.selected == Constants.OldFormat,
		"size": Vector2(M.xSize, M.ySize), "hearts": hearts,
		"creatures": creatures.size(), "extended": extended,
		"blocked_creatures": blocked, "script": refs.oDataScript.data,
		"lua": refs.oCurrentMap.LuaScript_enabled
	}


func _has_map() -> bool:
	if refs.oDataSlab.get_cell(0, 0) == TileMap.INVALID_CELL or Slabset.dat.empty():
		refs.oMessage.big("Nenhum mapa", "Crie um mapa ou abra uma copia antes de continuar.")
		return false
	return true


func _verify():
	if not _has_map():
		return
	var issues = checker.inspect(snapshot())
	report_text.text = "Verificacao estatica; nao substitui jogar a missao.\n\n"
	report_text.text += "\n\n".join(issues) if not issues.empty() else "Nenhum problema detectado nas verificacoes basicas."
	Utils.popup_centered(report)


func _next_path(folder: String, first: int, last: int) -> String:
	var dir = Directory.new()
	var error = dir.open(folder)
	if error != OK:
		refs.oMessage.big("Pasta indisponivel", "Nao foi possivel abrir:\n" + folder + "\nErro: " + str(error))
		return ""
	var used = {}
	dir.list_dir_begin(true, true)
	var file = dir.get_next()
	while not file.empty():
		used[file.to_lower().split(".")[0]] = true
		file = dir.get_next()
	dir.list_dir_end()
	for number in range(first, last + 1):
		var name = "map%05d" % number
		if not used.has(name):
			return folder.plus_file(name)
	refs.oMessage.big("Sem numeros livres", "Nao existe um numero livre para exportar nesta pasta.")
	return ""


func allow_save(path: String) -> bool:
	var normalized = path.replace("\\", "/").to_lower()
	normalized = normalized.simplify_path()
	var root = workspace.replace("\\", "/").trim_suffix("/").to_lower() + "/"
	if not normalized.begins_with(root):
		refs.oMessage.big("Mapa original protegido", "Salve primeiro uma copia com o botao Salvar mapa.\nPara adicionar ao jogo, use Exportar ao jogo; ele escolhe um numero livre.")
		return false
	if refs.oCurrentFormat.selected == Constants.OldFormat:
		var issues = checker.inspect(snapshot())
		if checker.has_errors(issues):
			refs.oMessage.big("Incompatibilidade com Gold", "\n".join(issues))
			return false
	return true


func prepare_open_path(path: String) -> String:
	var normalized = path.replace("\\", "/").simplify_path()
	var root = workspace.replace("\\", "/").trim_suffix("/") + "/"
	if normalized.to_lower().begins_with(root.to_lower()):
		return path
	if not File.new().file_exists(normalized):
		refs.oMessage.big("Abrir mapa", "Arquivo nao encontrado:\n" + path)
		return ""
	var source_dir = normalized.get_base_dir()
	var basename = normalized.get_file().get_basename().to_lower()
	var destination = workspace.plus_file("Mapas/Importados-%s-%s" % [OS.get_unix_time(), OS.get_ticks_msec()])
	var dir = Directory.new()
	var error = dir.make_dir_recursive(destination)
	if error != OK:
		refs.oMessage.big("Abrir copia", "Nao foi possivel criar uma copia de trabalho. Erro: " + str(error))
		return ""
	if dir.open(source_dir) != OK:
		refs.oMessage.big("Abrir copia", "Nao foi possivel ler a pasta original.")
		return ""
	dir.list_dir_begin(true, true)
	var file = dir.get_next()
	while not file.empty():
		if not dir.current_is_dir() and file.to_lower().begins_with(basename + "."):
			error = dir.copy(source_dir.plus_file(file), destination.plus_file(file))
			if error != OK:
				dir.list_dir_end()
				refs.oMessage.big("Abrir copia", "Copia interrompida ao ler " + file + ". Erro: " + str(error))
				return ""
		file = dir.get_next()
	dir.list_dir_end()
	if sync_enabled and normalized.to_lower().begins_with(fx_exe.get_base_dir().to_lower() + "/"):
		var local = destination.plus_file(normalized.get_file()).get_basename()
		sync_targets[_sync_key(local)] = normalized.get_basename()
		Settings.config.set_value("studio", "sync_targets", sync_targets)
		if not _save_profiles():
			return ""
	status.text = "OUTRA copia importada do original. Para continuar suas edicoes, use Abrir meus mapas ou Retomar ultimo salvo."
	return destination.plus_file(normalized.get_file())


func _save_copy():
	if not _has_map():
		refs.oSaveMap.queueExit = false
		return
	var path = _next_path(workspace.plus_file("Mapas"), 300, 32767)
	if not path.empty():
		refs.oSaveMap.save_map(path)


func save_working_map() -> bool:
	if not _has_map():
		refs.oSaveMap.queueExit = false
		return false
	var path = refs.oCurrentMap.path.replace("\\", "/").simplify_path()
	var root = workspace.replace("\\", "/").trim_suffix("/").to_lower() + "/"
	if path.to_lower().begins_with(root) and not refs.oCurrentMap.loaded_from_backup:
		return refs.oSaveMap.save_map(path)
	var destination = _next_path(workspace.plus_file("Mapas"), 300, 32767)
	return not destination.empty() and refs.oSaveMap.save_map(destination)


func record_working_save(path: String) -> bool:
	var normalized = path.replace("\\", "/").simplify_path()
	var root = workspace.replace("\\", "/").trim_suffix("/") + "/Mapas/"
	if not normalized.to_lower().begins_with(root.to_lower()):
		return true
	last_saved_map = normalized
	Settings.config.set_value("studio", "last_saved_map", last_saved_map)
	if not _save_profiles():
		return false
	refs.oMenu.add_recent(path)
	if sync_enabled and not suppress_sync:
		return _sync_working_map(normalized)
	status.text = "Edicoes salvas em:\n" + path + "\nPara jogar esta versao: Exportar ao jogo, depois Testar. A campanha original nao foi alterada."
	return true


func _sync_key(path: String) -> String:
	return path.replace("\\", "/").simplify_path().to_lower()


func _sync_toggled(enabled: bool):
	if enabled and not File.new().file_exists(fx_exe):
		sync_toggle.set_pressed_no_signal(false)
		refs.oMessage.big("Configure o KeeperFX", "Selecione keeperfx.exe em Configurar jogos antes de ativar a sincronizacao.")
		return
	var previous = sync_enabled
	sync_enabled = enabled
	if not _save_profiles():
		sync_enabled = previous
		sync_toggle.set_pressed_no_signal(previous)
		return
	status.text = "Sincronizacao ativada. Confira o destino antes de salvar." if enabled else "Sincronizacao desativada. Salvar atualiza apenas a copia local."


func _choose_sync_target():
	if not _has_map():
		return
	if not File.new().file_exists(fx_exe):
		refs.oMessage.big("Configure o KeeperFX", "Selecione keeperfx.exe em Configurar jogos.")
		return
	var source = refs.oCurrentMap.path
	if not _sync_key(source).begins_with(_sync_key(workspace.plus_file("Mapas")) + "/"):
		refs.oMessage.big("Salve primeiro", "Salve uma copia em Mapas antes de vincular uma fase.")
		return
	pending_sync_source = source
	_show_file_picker(target_dialog, fx_exe.get_base_dir().plus_file("campgns"))


func _sync_target_selected(path: String):
	if not _sync_key(path).begins_with(_sync_key(fx_exe.get_base_dir()) + "/") or path.get_extension().to_lower() != "slb":
		refs.oMessage.big("Destino invalido", "Escolha uma fase .slb dentro da instalacao configurada do KeeperFX.")
		return
	pending_sync_target = path.get_basename()
	target_confirm.dialog_text = "Copia local:\n" + pending_sync_source + "\n\nFase que sera substituida ao salvar:\n" + pending_sync_target + "\n\nSera criado um backup antes de cada atualizacao. A vinculacao nao altera os arquivos agora."
	Utils.popup_centered(target_confirm)


func _confirm_sync_target():
	if _sync_key(refs.oCurrentMap.path) != _sync_key(pending_sync_source):
		refs.oMessage.big("Mapa alterado", "Escolha o destino novamente para o mapa atualmente aberto.")
		return
	var key = _sync_key(pending_sync_source)
	var previous = sync_targets.duplicate(true)
	var was_enabled = sync_enabled
	sync_targets[key] = pending_sync_target
	sync_enabled = true
	if not _save_profiles():
		sync_targets = previous
		sync_enabled = was_enabled
		return
	sync_toggle.set_pressed_no_signal(true)
	status.text = "Fase vinculada:\n" + pending_sync_target + "\nUse Salvar mapa para atualizar o jogo com backup."


func _sync_working_map(source: String) -> bool:
	if not File.new().file_exists(fx_exe):
		refs.oMessage.big("Copia local salva; jogo NAO atualizado", "Configure um KeeperFX valido antes de sincronizar.")
		return false
	var key = _sync_key(source)
	var target = str(sync_targets.get(key, ""))
	var game_root = fx_exe.get_base_dir().replace("\\", "/").simplify_path()
	if target.empty():
		var folder = game_root.plus_file("levels/studio")
		if Directory.new().make_dir_recursive(folder) != OK or not _ensure_fx_pack(folder):
			refs.oMessage.big("Copia local salva; jogo NAO atualizado", "Nao foi possivel preparar o pacote: " + folder)
			return false
		target = _next_path(folder, 5000, 32767)
		if target.empty():
			return false
	if not _sync_key(target).begins_with(_sync_key(game_root) + "/"):
		refs.oMessage.big("Destino invalido", "O destino sincronizado precisa estar dentro da instalacao configurada do KeeperFX:\n" + target)
		return false
	var result = game_sync.sync(source, target, workspace.plus_file("Backups-Jogo"))
	if result.has("error"):
		status.text = "Copia local salva; jogo NAO atualizado.\n" + str(result.error)
		refs.oMessage.big("Falha na sincronizacao", status.text)
		return false
	sync_targets[key] = target
	installed_source = source
	installed_path = target
	installed_fingerprint = _bundle_fingerprint(source)
	Settings.config.set_value("studio", "sync_targets", sync_targets)
	Settings.config.set_value("studio", "installed_source", installed_source)
	Settings.config.set_value("studio", "installed_path", installed_path)
	Settings.config.set_value("studio", "installed_fingerprint", installed_fingerprint)
	if not _save_profiles():
		return false
	status.text = "SALVO NA COPIA E NO KEEPERFX\n" + source + "\nJogo: " + target + "\nBackup: " + str(result.backup) + "\nReinicie a fase; partidas salvas mantem o cenario anterior."
	return true


func _confirm_export():
	if not _has_map():
		return
	var issues = checker.inspect(snapshot())
	if checker.has_errors(issues):
		_verify()
		return
	var classic = refs.oCurrentFormat.selected == Constants.OldFormat
	var exe = gold_exe if classic else fx_exe
	if not File.new().file_exists(exe):
		refs.oMessage.big("Configure o jogo", "O executavel deste perfil nao esta disponivel.\nVoce ainda pode salvar uma copia local do mapa.")
		return
	var folder = exe.get_base_dir().plus_file("levels")
	if not classic:
		folder = folder.plus_file("studio")
		var error = Directory.new().make_dir_recursive(folder)
		if error != OK and error != ERR_ALREADY_EXISTS:
			refs.oMessage.big("Exportacao", "Nao foi possivel criar a pasta de mapas. Erro: " + str(error))
			return
	pending_export_path = _next_path(folder, 300 if classic else 5000, 799 if classic else 32767)
	if pending_export_path.empty():
		return
	export_confirm.dialog_text = "Perfil: " + ("Gold original" if classic else "KeeperFX")
	export_confirm.dialog_text += "\nNovo mapa: " + pending_export_path + "\n\nNenhum mapa existente sera substituido."
	if not issues.empty():
		export_confirm.dialog_text += "\n\n" + "\n".join(issues)
	export_confirm.dialog_text += "\n\nUse Testar para abrir o mapa pelo numero.\nA inclusao nos menus de campanha do jogo e uma etapa separada."
	Utils.popup_centered(export_confirm)


func _export():
	suppress_sync = true
	_export_map()
	suppress_sync = false


func _export_map():
	if not _has_map():
		return
	if checker.has_errors(checker.inspect(snapshot())):
		_verify()
		return
	# Recheck after confirmation, because another editor may have occupied this slot.
	var folder = pending_export_path.get_base_dir()
	var name = pending_export_path.get_file().to_lower()
	var dir = Directory.new()
	if dir.open(folder) != OK:
		refs.oMessage.big("Exportacao", "A pasta de destino nao esta disponivel.")
		return
	dir.list_dir_begin(true, true)
	var file = dir.get_next()
	while not file.empty():
		if file.to_lower().begins_with(name + "."):
			dir.list_dir_end()
			refs.oMessage.big("Numero ocupado", "O destino passou a existir. Clique em Exportar ao jogo novamente.")
			return
		file = dir.get_next()
	dir.list_dir_end()
	var local = refs.oCurrentMap.path
	if not _sync_key(local).begins_with(_sync_key(workspace.plus_file("Mapas")) + "/") or refs.oCurrentMap.loaded_from_backup:
		local = _next_path(workspace.plus_file("Mapas"), 300, 32767)
	if local.empty() or not refs.oSaveMap.save_map(local):
		return
	var stage_folder = workspace.plus_file("Exportados/%s/%s-%s" % [
		"Gold" if refs.oCurrentFormat.selected == Constants.OldFormat else "KeeperFX",
		name, OS.get_ticks_msec()])
	var error = dir.make_dir_recursive(stage_folder)
	if error != OK:
		refs.oMessage.big("Exportacao", "Nao foi possivel preparar o pacote. Erro: " + str(error))
		return
	var stage = stage_folder.plus_file(name)
	if not refs.oSaveMap.save_map(stage):
		return
	if refs.oCurrentFormat.selected == Constants.KfxFormat:
		if not _ensure_fx_pack(folder):
			return
	if not _publish_bundle(stage, pending_export_path):
		return
	installed_path = pending_export_path
	installed_source = local
	installed_fingerprint = _bundle_fingerprint(local)
	Settings.config.set_value("studio", "installed_path", installed_path)
	Settings.config.set_value("studio", "installed_source", installed_source)
	Settings.config.set_value("studio", "installed_fingerprint", installed_fingerprint)
	_save_profiles()
	if not refs.oOpenMap.open_map(local + ".slb", {"show_opened_message": false, "reset_camera": false}):
		refs.oMessage.big("Copia de trabalho", "O mapa foi exportado, mas a copia local nao pode ser reaberta:\n" + local)
		return
	status.text = "Exportado: " + installed_path.get_file() + ". Use Testar."
	refs.oMessage.big("Mapa exportado", installed_path + "\n\nSua copia de trabalho continua separada do jogo.\nUse Testar para iniciar esta missao diretamente.")


func _publish_bundle(stage: String, target: String) -> bool:
	var folder = target.get_base_dir()
	var name = stage.get_file()
	var dir = Directory.new()
	if dir.open(stage.get_base_dir()) != OK:
		refs.oMessage.big("Exportacao", "Pacote de exportacao indisponivel.")
		return false
	var files = []
	dir.list_dir_begin(true, true)
	var file = dir.get_next()
	while not file.empty():
		if not dir.current_is_dir() and file.to_lower().begins_with(name.to_lower() + "."):
			files.append(file)
		file = dir.get_next()
	dir.list_dir_end()
	if files.empty():
		refs.oMessage.big("Exportacao", "O pacote nao contem arquivos de mapa.")
		return false
	var lock = folder.plus_file(".studio-lock-" + target.get_file())
	var error = dir.make_dir(lock)
	if error != OK:
		refs.oMessage.big("Destino ocupado", "Outra exportacao pode estar usando este numero. Escolha um novo numero exportando novamente.")
		return false
	var temporary = []
	var published = []
	var token = ".studio-tmp-" + str(OS.get_ticks_msec())
	for source in files:
		var destination = folder.plus_file(source)
		if File.new().file_exists(destination):
			error = ERR_ALREADY_EXISTS
			break
		var temp = destination + token
		error = dir.copy(stage.get_base_dir().plus_file(source), temp)
		if error != OK:
			break
		temporary.append(temp)
	if error == OK:
		for i in files.size():
			var destination = folder.plus_file(files[i])
			if File.new().file_exists(destination):
				error = ERR_ALREADY_EXISTS
				break
			error = dir.rename(temporary[i], destination)
			if error != OK:
				break
			published.append(destination)
	if error != OK:
		for path in published:
			var cleanup_error = dir.remove(path)
			if cleanup_error != OK:
				refs.oMessage.big("Limpeza incompleta", "Remova o arquivo incompleto: " + path)
	for path in temporary:
		if File.new().file_exists(path):
			var cleanup_error = dir.remove(path)
			if cleanup_error != OK:
				refs.oMessage.big("Limpeza incompleta", "Remova o arquivo temporario: " + path)
	var unlock_error = dir.remove(lock)
	if unlock_error != OK:
		refs.oMessage.big("Limpeza incompleta", "Nao foi possivel remover a trava: " + lock)
	if error != OK:
		refs.oMessage.big("Exportacao interrompida", "O pacote local foi preservado. Erro: " + str(error))
		return false
	return true


func _ensure_fx_pack(folder: String) -> bool:
	var path = folder.get_base_dir().plus_file("studio.cfg")
	var file = File.new()
	if file.file_exists(path):
		var error = file.open(path, File.READ)
		if error != OK:
			refs.oMessage.big("Pacote KeeperFX", "Nao foi possivel ler " + path)
			return false
		var text = file.get_as_text()
		file.close()
		if not "LEVELS_LOCATION = levels/studio" in text:
			refs.oMessage.big("Pacote KeeperFX", "studio.cfg ja existe com outra configuracao. Ele nao foi alterado.")
			return false
		return true
	var error = file.open(path, File.WRITE)
	if error != OK:
		refs.oMessage.big("Pacote KeeperFX", "Nao foi possivel criar " + path + ". Erro: " + str(error))
		return false
	file.store_string("; Dungeon Keeper Studio mappack\n[common]\nNAME = Dungeon Keeper Studio\nLEVELS_LOCATION = levels/studio\nHUMAN_PLAYER = RED\n\n[strings]\nENG = fxdata/gtext_eng.dat\nPOR = fxdata/gtext_por.dat\n")
	var write_error = file.get_error()
	file.close()
	if write_error != OK:
		refs.oMessage.big("Pacote KeeperFX", "Falha ao escrever " + path + ". Erro: " + str(write_error))
		return false
	return true


func _test():
	if not _has_map():
		return
	var classic = refs.oCurrentFormat.selected == Constants.OldFormat
	var synced = sync_enabled and sync_targets.get(_sync_key(refs.oCurrentMap.path), "") == installed_path
	var exe = fx_exe if synced or not classic else gold_exe
	if not File.new().file_exists(exe):
		refs.oMessage.big("Jogo indisponivel", "Configure o executavel deste perfil em Configurar jogos.")
		return
	if installed_path.empty() or refs.oCurrentMap.path != installed_source:
		refs.oMessage.big("Exporte primeiro", "Use Exportar ao jogo antes de Testar. Copias de trabalho nao sao instaladas automaticamente.")
		return
	if refs.oEditor.mapHasBeenEdited or not _fingerprints_match(_bundle_fingerprint(installed_source), installed_fingerprint):
		refs.oMessage.big("Alteracoes pendentes", "Use Salvar mapa para atualizar o KeeperFX." if synced else "Exporte novamente para testar suas alteracoes. A versao instalada nao sera sobrescrita.")
		return
	Settings.set_setting("executable_path", exe)
	var command = refs.oGame.cmdline(installed_path, false)
	if not classic or synced:
		command = command.replace(" -campaign studio", " -campaign levels/studio")
	refs.oGame.launch_game(command, "Iniciando mapa exportado...")


func _fingerprints_match(first: Dictionary, second: Dictionary) -> bool:
	if first.empty() or first.size() != second.size():
		return false
	for key in first:
		if not second.has(key) or first[key] != second[key]:
			return false
	return true


func _bundle_fingerprint(path: String) -> Dictionary:
	var result = {}
	var dir = Directory.new()
	if dir.open(path.get_base_dir()) != OK:
		return result
	var prefix = path.get_file().to_lower() + "."
	dir.list_dir_begin(true, true)
	var file = dir.get_next()
	while not file.empty():
		if not dir.current_is_dir() and file.to_lower().begins_with(prefix):
			result[file.substr(prefix.length())] = File.new().get_sha256(path.get_base_dir().plus_file(file))
		file = dir.get_next()
	dir.list_dir_end()
	return result


func _open_folder():
	var error = OS.shell_open(workspace.plus_file("Mapas"))
	if error != OK:
		refs.oMessage.big("Abrir pasta", "Nao foi possivel abrir a pasta. Erro: " + str(error))


func _files_dropped(files, _screen):
	if not files.empty():
		refs.oOpenMap.open_map(files[0])
