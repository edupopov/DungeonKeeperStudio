extends Node

var failures = []


func _ready():
	call_deferred("_run")


func check(condition: bool, message: String):
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)


func _run():
	get_tree().create_timer(180).connect("timeout", self, "_timeout")
	var main = get_parent()
	yield(get_tree().create_timer(3), "timeout")
	var studio = main.get_node_or_null("Studio")
	check(studio != null, "Studio inicializado")
	if studio == null:
		get_tree().quit(1)
		return
	studio.wizard.hide()
	var refs = Nodelist.list
	check(File.new().file_exists(studio.gold_exe), "Dados do Gold detectados")
	var checks = load("res://Studio/MapChecks.gd").new()
	var test_root = studio.workspace.plus_file("Studio/TestOutput-%s-%s" % [OS.get_unix_time(), OS.get_ticks_msec()])
	var original_workspace = studio.workspace
	var previous_exports = [studio.installed_path, studio.installed_source, studio.installed_fingerprint]
	var previous_saved = studio.last_saved_map
	var had_saved = Settings.config.has_section_key("studio", "last_saved_map")
	var previous_recent = refs.oMenu.recentlyOpened.duplicate()
	var previous_sync = [studio.sync_enabled, studio.sync_targets.duplicate(true), studio.fx_exe]
	var had_targets = Settings.config.has_section_key("studio", "sync_targets")
	studio.sync_enabled = false
	Directory.new().make_dir_recursive(test_root)
	var model = {"classic": true, "size": Vector2(85, 85), "hearts": {0: 1, 1: 1},
		"creatures": 2, "extended": false, "blocked_creatures": 0, "lua": false,
		"script": "REM WIN_GAME\nCOMPUTER_PLAYER(PLAYER1,0)\nIF(PLAYER0,ALL_DUNGEONS_DESTROYED == 1)\nWIN_GAME\nENDIF"}
	check(checks.inspect(model).empty(), "Validador aceita mapa classico basico")
	model.creatures = 256
	check(checks.has_errors(checks.inspect(model)), "Validador rejeita limite classico excedido")
	model.classic = false
	check(not checks.has_errors(checks.inspect(model)), "Limite classico nao restringe KeeperFX")
	model.script = "REM WIN_GAME\nENDIF"
	check(checks.has_errors(checks.inspect(model)), "Validador identifica ENDIF incorreto")
	for format in [Constants.OldFormat, Constants.KfxFormat]:
		refs.oEditor.mapHasBeenEdited = false
		var source_map = Utils.case_insensitive_file(refs.oGame.DK_LEVELS_DIRECTORY, "MAP00001", "SLB")
		if not source_map.empty():
			var before = File.new().get_sha256(source_map)
			var imported = studio.prepare_open_path(source_map)
			check(not imported.empty() and imported != source_map, "Mapa original importado para uma copia separada")
			check(File.new().get_sha256(imported) == before, "Copia de importacao identica ao original")
			check(not studio.allow_save(source_map.get_basename()), "Salvamento direto sobre o original bloqueado")
			check(File.new().get_sha256(source_map) == before, "Mapa original permanece intacto")
		yield(get_tree().create_timer(0.25), "timeout")
		studio.new_profile.select(studio.new_profile.get_item_index(format))
		studio.new_players.value = 2
		studio.new_name.text = "Studio Smoke Test"
		var creation = studio._create_map()
		if creation is GDScriptFunctionState:
			yield(creation, "completed")
		yield(get_tree().create_timer(2), "timeout")
		check(not studio.busy, "Criacao concluida - perfil %s" % format)
		check(refs.oCurrentFormat.selected == format, "Formato aplicado - perfil %s" % format)
		check(M.xSize == 85 and M.ySize == 85, "Dimensoes 85 x 85")
		var snap = studio.snapshot()
		check(snap.hearts.has(0) and snap.hearts.has(1), "Bases dos dois jogadores geradas")
		var portals = 0
		var gold = 0
		for y in range(M.ySize):
			for x in range(M.xSize):
				var slab = refs.oDataSlab.get_cell(x, y)
				portals += int(slab == Slabs.PORTAL)
				gold += int(slab == Slabs.GOLD)
		check(portals >= 18, "Portais funcionais de 3 x 3 para os dois jogadores")
		check(gold >= 24, "Reserva inicial de ouro para os jogadores")
		check("COMPUTER_PLAYER(PLAYER1" in refs.oDataScript.data, "IA adversaria configurada")
		check("WIN_GAME" in refs.oDataScript.data, "Condicao de vitoria configurada")
		studio.category.select(2)
		studio._refresh_palette()
		check(studio.palette.get_item_count() > 0, "Paleta de criaturas disponivel")
		studio._palette_selected(0)
		check(refs.oSelection.paintThingType == Things.TYPE.CREATURE, "Paleta seleciona ferramenta de criatura")
		studio._level_changed(4)
		refs.oSlabPlacement.place_shape_of_slab_id([Vector2(42, 42)], Slabs.PATH, 5)
		yield(refs.oSlabPlacement.generate_slabs_based_on_id([Vector2(42, 42)], true), "completed")
		var creatures_before = get_tree().get_nodes_in_group("Creature").size()
		studio.owner_picker.select(1)
		studio._owner_selected(1)
		check(refs.oSelection.paintOwnership == 1, "Dono selecionado na interface")
		refs.oSelection.place_subtile(Vector2(127, 127))
		var creature = get_tree().get_nodes_in_group("Creature")[-1]
		check(creature.creatureLevel == 4, "Nivel da criatura aplicado")
		check(creature.ownership == 1, "Dono aplicado a criatura")
		check(creature.subtype == refs.oSelection.paintSubtype, "Criatura escolhida pela paleta foi colocada")
		check(get_tree().get_nodes_in_group("Creature").size() == creatures_before + 1, "Criatura adicionada ao mapa")
		var ux = _check_ux(studio, creature)
		if ux is GDScriptFunctionState:
			yield(ux, "completed")
		refs.oEditor.mapHasBeenEdited = true
		var path = test_root.plus_file("map32%03d" % (700 + format))
		check(refs.oSaveMap.save_map(path), "Exportacao de arquivos - perfil %s" % format)
		check(studio._fingerprints_match(studio._bundle_fingerprint(path), studio._bundle_fingerprint(path)), "Assinatura de arquivos estavel")
		var file = File.new()
		check(file.file_exists(path + ".slb"), "Terreno SLB exportado")
		check(file.file_exists(path + ".txt"), "Regras TXT exportadas")
		if format == Constants.OldFormat:
			check(file.file_exists(path + ".tng"), "Criaturas TNG classicas exportadas")
			file.open(path + ".slb", File.READ)
			check(file.get_len() == 85 * 85 * 2, "SLB possui tamanho binario correto")
			file.close()
		else:
			check(file.file_exists(path + ".tngfx"), "Criaturas TNGFX exportadas")
		refs.oEditor.mapHasBeenEdited = false
		check(refs.oOpenMap.open_map(path + ".slb"), "Reabertura dos arquivos exportados")
		yield(get_tree().create_timer(1), "timeout")
		check(get_tree().get_nodes_in_group("Creature").size() == creatures_before + 1, "Criaturas preservadas apos reabrir")
		check(refs.oCurrentFormat.selected == format, "Compatibilidade preservada apos reabrir")
		check(get_tree().get_nodes_in_group("Creature")[-1].creatureLevel == 4, "Nivel preservado no round-trip")
		var specials = 0
		var books = 0
		for object in get_tree().get_nodes_in_group("Object"):
			specials += int(object.subtype == 91)
			books += int(object.subtype == 18)
		check(specials == 1 and books == 1, "Especial e livro preservados no round-trip")
		check(get_tree().get_nodes_in_group("ActionPoint").size() == 2, "Areas preservadas no round-trip")
		check("REM STUDIO-BEGIN EVENT_" in refs.oDataScript.data and "POWER_HEAL_CREATURE,1,1" in refs.oDataScript.data, "Eventos e poderes preservados no round-trip")
		studio.category.select(0)
		studio._refresh_palette()
		studio._palette_selected(0)
		check(refs.oSelection.paintSlab == Slabs.EARTH, "Paleta seleciona terreno")
		studio._tool_selected(2)
		check(refs.oEditingTools.TOOL_SELECTED == refs.oEditingTools.RECTANGLE, "Ferramenta de retangulo conectada")
		refs.oRectangleSelection.beginTile = Vector2(40, 40)
		refs.oRectangleSelection.endTile = Vector2(42, 42)
		refs.oSelection.paintSlab = Slabs.CLAIMED_GROUND
		refs.oSelection.construct_shape_for_placement(refs.oSelection.CONSTRUCT_RECTANGLE)
		yield(get_tree().create_timer(1), "timeout")
		check(refs.oDataSlab.get_cell(41, 41) == Slabs.CLAIMED_GROUND, "Retangulo realmente altera o terreno")
		check(refs.oDataOwnership.get_cell_ownership(41, 41) == 1, "Dono aplicado ao terreno")
		var test_target = test_root.plus_file("test-game-" + str(format))
		Directory.new().make_dir_recursive(test_target)
		var target = test_target.plus_file(path.get_file())
		check(studio._publish_bundle(path, target), "Publicacao do conjunto de mapas em destino isolado")
		var source_hash = File.new().get_sha256(path + ".slb")
		check(File.new().get_sha256(target + ".slb") == source_hash, "Terreno publicado identico a origem")
		check(not studio._publish_bundle(path, target), "Publicacao recusa sobrescrever mapa existente")
		check(File.new().get_sha256(target + ".slb") == source_hash, "Recusa preserva mapa existente")
		studio.workspace = test_root
		Directory.new().make_dir_recursive(test_root.plus_file("Mapas"))
		studio.pending_export_path = test_target.plus_file("map00600")
		studio._export()
		yield(get_tree().create_timer(1), "timeout")
		check(File.new().file_exists(studio.pending_export_path + ".slb"), "Fluxo completo de exportacao publica o mapa")
		check(refs.oCurrentMap.path == studio.installed_source, "Exportacao restaura a copia local para continuar editando")
		check(refs.oCurrentMap.currentFilePaths.SLB[0].to_lower().begins_with(studio.installed_source.to_lower()), "Arquivos rastreados pertencem a copia local")
		check(studio._fingerprints_match(studio._bundle_fingerprint(studio.installed_source), studio.installed_fingerprint), "Teste vinculado a versao exportada correta")
		var saved_path = refs.oCurrentMap.path
		var installed_hash = File.new().get_sha256(studio.pending_export_path + ".slb")
		var new_tiles = [Vector2(41, 41)]
		refs.oSlabPlacement.place_shape_of_slab_id(new_tiles, Slabs.HATCHERY, 0)
		yield(refs.oSlabPlacement.generate_slabs_based_on_id(new_tiles, true), "completed")
		refs.oEditor.mapHasBeenEdited = true
		check(studio.save_working_map(), "Salvar atualiza a copia de trabalho")
		check(refs.oCurrentMap.path == saved_path, "Salvar nao cria outra copia numerada")
		check(studio.last_saved_map == saved_path, "Ultimo mapa salvo registrado")
		check(Settings.config.get_value("studio", "last_saved_map") == saved_path, "Destino salvo persiste nas preferencias")
		check(File.new().get_sha256(studio.pending_export_path + ".slb") == installed_hash, "Salvar local nao altera a versao instalada")
		check(not studio._fingerprints_match(studio._bundle_fingerprint(saved_path), studio.installed_fingerprint), "Edicoes salvas exigem nova exportacao")
		studio._resume_saved()
		yield(get_tree().create_timer(1), "timeout")
		check(refs.oDataSlab.get_cell(41, 41) == Slabs.HATCHERY, "Retomar ultimo salvo preserva o terreno editado")
		check(refs.oCurrentMap.path == saved_path, "Retomar abre a copia e nao o original")
		for message in refs.oUiMessages.get_children():
			if message is WindowDialog:
				message.hide()
		studio._browse()
		yield(get_tree().create_timer(0.3), "timeout")
		var expected_dir = test_root.plus_file("Mapas")
		# Godot 3 keeps the Windows drive in its separate drive selector.
		if OS.get_name() == "Windows":
			expected_dir = expected_dir.substr(expected_dir.find(":") + 1)
		check(studio.map_dialog.current_dir.trim_suffix("/") == expected_dir, "Abrir meus mapas comeca nas copias salvas")
		check(studio.map_dialog.rect_size.x >= 640 and studio.map_dialog.rect_size.y >= 440, "Seletor tem tamanho suficiente para navegar")
		check(studio._file_picker_tree(studio.map_dialog).rect_size.y >= 260, "Lista de pastas e arquivos permanece visivel")
		check(studio.map_dialog.resizable, "Janela de selecao permite redimensionar")
		var listed = studio._file_picker_tree(studio.map_dialog).get_root()
		var map_found = false
		if listed != null:
			listed = listed.get_children()
		while listed != null:
			if listed.get_text(0).to_lower() == saved_path.get_file().to_lower() + ".slb":
				map_found = true
			listed = listed.get_next()
		check(map_found, "Mapa salvo aparece na lista sem digitar o nome")
		studio.map_dialog.current_dir = test_target
		studio._browse()
		yield(get_tree().create_timer(0.2), "timeout")
		check(studio.map_dialog.current_dir.trim_suffix("/") == expected_dir, "Reabrir seletor retorna a pasta de mapas correta")
		VisualServer.force_draw()
		if format == Constants.OldFormat:
			var picker_image = get_tree().root.get_texture().get_data()
			picker_image.flip_y()
			picker_image.save_png(OS.get_environment("TEMP").plus_file("studio-map-picker.png"))
		listed = studio._file_picker_tree(studio.map_dialog).get_root().get_children()
		while listed != null:
			if listed.get_text(0).to_lower() == saved_path.get_file().to_lower() + ".slb":
				var old_selection = studio._file_picker_tree(studio.map_dialog).get_selected()
				if old_selection != null:
					old_selection.deselect(0)
				listed.select(0)
				studio._file_picker_tree(studio.map_dialog).emit_signal("cell_selected")
				yield(get_tree(), "idle_frame")
				studio._file_picker_tree(studio.map_dialog).emit_signal("item_activated")
				break
			listed = listed.get_next()
		yield(get_tree().create_timer(1), "timeout")
		check(not studio.map_dialog.visible and refs.oCurrentMap.path == saved_path, "Duplo clique no arquivo abre o mapa sem digitar caminho")
		studio.map_dialog.hide()
		var fake_exe = test_target.plus_file("keeperfx.exe")
		var executable = File.new()
		check(executable.open(fake_exe, File.WRITE) == OK, "Destino de teste KeeperFX isolado")
		executable.close()
		studio.fx_exe = fake_exe
		studio.sync_enabled = true
		studio.sync_targets = {studio._sync_key(saved_path): studio.pending_export_path}
		var old_target_hash = File.new().get_sha256(studio.pending_export_path + ".slb")
		check(studio.save_working_map(), "Salvar tambem atualiza o mapa no jogo")
		check(File.new().get_sha256(studio.pending_export_path + ".slb") == File.new().get_sha256(saved_path + ".slb"), "Destino sincronizado corresponde a copia editavel")
		check(studio._fingerprints_match(studio._bundle_fingerprint(saved_path), studio.installed_fingerprint), "Testar aponta para a versao sincronizada")
		var backups = Directory.new()
		var backup_found = false
		if backups.open(test_root.plus_file("Backups-Jogo")) == OK:
			backups.list_dir_begin(true, true)
			var entry = backups.get_next()
			while not entry.empty():
				var old_map = test_root.plus_file("Backups-Jogo").plus_file(entry).plus_file(studio.pending_export_path.get_file() + ".slb")
				if File.new().file_exists(old_map) and File.new().get_sha256(old_map) == old_target_hash:
					backup_found = true
				entry = backups.get_next()
			backups.list_dir_end()
		check(backup_found, "Backup preserva o mapa anterior do jogo")
		var lock = test_target.plus_file(".studio-lock-" + studio.pending_export_path.get_file())
		check(Directory.new().make_dir(lock) == OK, "Preparar destino ocupado")
		check(not studio.save_working_map(), "Destino ocupado nao retorna sucesso falso")
		check(not refs.oSaveMap.queueExit, "Falha de sincronizacao impede sair como se tivesse salvo")
		check(File.new().get_sha256(studio.pending_export_path + ".slb") == File.new().get_sha256(saved_path + ".slb"), "Falha preserva destino e copia")
		check(Directory.new().remove(lock) == OK, "Liberar trava de teste")
		check(studio.save_working_map(), "Salvar novamente recupera sincronizacao")
		var before_failure = studio._bundle_fingerprint(studio.pending_export_path)
		var conflict_ext = ".studiofixture"
		var conflict_file = File.new()
		check(conflict_file.open(saved_path + conflict_ext, File.WRITE) == OK, "Preparar arquivo de teste de reversao")
		conflict_file.store_string("fixture")
		conflict_file.close()
		check(Directory.new().make_dir(studio.pending_export_path + conflict_ext) == OK, "Preparar colisao durante instalacao")
		var reverted = studio.game_sync.sync(saved_path, studio.pending_export_path, test_root.plus_file("Backups-Jogo"))
		check(reverted.has("error"), "Falha durante instalacao e reportada")
		check(studio._fingerprints_match(studio._bundle_fingerprint(studio.pending_export_path), before_failure), "Reversao restaura conjunto anterior apos falha parcial")
		check(Directory.new().remove(saved_path + conflict_ext) == OK, "Limpar arquivo de reversao")
		check(Directory.new().remove(studio.pending_export_path + conflict_ext) == OK, "Limpar colisao de reversao")
		studio.sync_targets.clear()
		check(studio.save_working_map(), "Novo mapa recebe destino proprio no pacote KeeperFX")
		check(studio.installed_path.begins_with(test_target.plus_file("levels/studio/")), "Novos mapas nao substituem fases da campanha")
		check(File.new().file_exists(studio.installed_path + ".slb"), "Novo destino instalado")
		check(studio._saved_map_file() == saved_path + ".slb", "Copia local continua disponivel apos sincronizar")
		studio._sync_toggled(false)
		var persisted = ConfigFile.new()
		check(persisted.load(Settings.settings_file_path) == OK and not persisted.get_value("studio", "sync_enabled", true), "Alternar sincronizacao persiste estado desligado")
		studio.pending_sync_source = saved_path
		studio.pending_sync_target = studio.pending_export_path
		studio._confirm_sync_target()
		check(studio.sync_enabled and studio.sync_targets[studio._sync_key(saved_path)] == studio.pending_export_path, "Vincular fase ativa sincronizacao para a copia escolhida")
		persisted.load(Settings.settings_file_path)
		check(persisted.get_value("studio", "sync_enabled", false), "Sincronizacao ligada persiste apos confirmacao")
		check(persisted.get_value("studio", "sync_targets", {}).get(studio._sync_key(saved_path), "") == studio.pending_export_path, "Vinculo da fase persiste em disco")
		var linked_target = studio.pending_export_path
		studio.pending_export_path = test_target.plus_file("map00601")
		studio._export()
		yield(get_tree().create_timer(1), "timeout")
		check(refs.oCurrentMap.path == saved_path, "Exportar nao troca o caminho da copia de trabalho")
		check(studio.sync_targets.get(studio._sync_key(saved_path), "") == linked_target, "Exportar preserva vinculo com a fase da campanha")
		check(studio.save_working_map() and studio.installed_path == linked_target, "Salvar apos exportar volta a atualizar a fase vinculada")
		studio.sync_enabled = false
		var expansion = load("res://Studio/ExpansionTest.gd").new()
		add_child(expansion)
		expansion.smoke = self
		var expanded = expansion.run(studio, test_root)
		if expanded is GDScriptFunctionState:
			yield(expanded, "completed")
		expansion.queue_free()
		studio.sync_enabled = false
		studio.fx_exe = previous_sync[2]
		studio.workspace = original_workspace
	studio.sync_enabled = previous_sync[0]
	studio.sync_targets = previous_sync[1]
	studio.fx_exe = previous_sync[2]
	if had_targets:
		Settings.config.set_value("studio", "sync_targets", studio.sync_targets)
	else:
		Settings.config.erase_section_key("studio", "sync_targets")
	studio.last_saved_map = previous_saved
	if had_saved:
		Settings.config.set_value("studio", "last_saved_map", previous_saved)
	else:
		Settings.config.erase_section_key("studio", "last_saved_map")
	refs.oMenu.recentlyOpened = previous_recent
	refs.oMenu.populate_recently_opened()
	Settings.config.set_value("settings", "recently_opened", previous_recent)
	studio.installed_path = previous_exports[0]
	studio.installed_source = previous_exports[1]
	studio.installed_fingerprint = previous_exports[2]
	Settings.config.set_value("studio", "installed_path", studio.installed_path)
	Settings.config.set_value("studio", "installed_source", studio.installed_source)
	Settings.config.set_value("studio", "installed_fingerprint", studio.installed_fingerprint)
	studio._save_profiles()
	refs.oEditor.mapHasBeenEdited = false
	for dialog in refs.oUi.get_node("UiSystem").get_children():
		if dialog is WindowDialog:
			dialog.hide()
	for message in refs.oUiMessages.get_children():
		if message is WindowDialog:
			message.hide()
	print("STUDIO_TEST_RESULT: %s falha(s)" % failures.size())
	yield(get_tree(), "idle_frame")
	VisualServer.force_draw()
	var screenshot = get_tree().root.get_texture().get_data()
	screenshot.flip_y()
	screenshot.save_png(OS.get_environment("TEMP").plus_file("dungeon-keeper-studio-preview.png"))
	get_tree().quit(0 if failures.empty() else 1)


func _timeout():
	printerr("STUDIO_TEST_TIMEOUT")
	get_tree().quit(2)


func _select_entry(studio, source_category: int, id: int) -> bool:
	studio.palette_filter.select(0)
	studio.search.text = ""
	studio.category.select(source_category)
	studio._refresh_palette()
	for index in studio.palette.get_item_count():
		if studio.palette.get_item_metadata(index) == id:
			studio._palette_selected(index)
			return true
	check(false, "Entrada disponivel: %s:%s" % [source_category, id])
	return false


func _check_ux(studio, creature):
	var refs = Nodelist.list
	var tools = studio.map_tools
	var favorites = studio.favorites.duplicate()
	var recent = studio.recent_items.duplicate()
	check(_select_entry(studio, 5, 91), "Especial aumentar nivel disponivel")
	check(refs.oSelection.paintThingType == Things.TYPE.OBJECT and refs.oSelection.paintSubtype == 91, "Especial seleciona o objeto real do jogo")
	yield(get_tree().create_timer(0.2), "timeout")
	_capture_view("studio-specials.png")
	check(studio.catalog.search_key("Transferência") == "transferencia", "Busca ignora acentos")
	studio.search.text = "transferir"
	studio._refresh_palette()
	check(studio.palette.get_item_count() == 1 and studio.palette.get_item_metadata(0) == 88, "Busca encontra transferencia sem confundir roubar heroi")
	_select_entry(studio, 5, 91)
	studio.favorites.erase("5:91")
	studio._favorite()
	studio.palette_filter.select(1)
	studio._refresh_palette()
	var favorite_found = false
	for index in studio.palette.get_item_count():
		favorite_found = favorite_found or (studio.palette_entries[index] == 5 and studio.palette.get_item_metadata(index) == 91)
	check(favorite_found, "Favorito encontrado entre categorias")
	check(Settings.config.get_value("studio", "favorites", []).has("5:91"), "Favorito persiste nas preferencias")
	var positions = [Vector2(43, 42), Vector2(44, 42), Vector2(45, 42), Vector2(46, 42)]
	refs.oSlabPlacement.place_shape_of_slab_id(positions, Slabs.PATH, 5)
	yield(refs.oSlabPlacement.generate_slabs_based_on_id(positions, true), "completed")
	_select_entry(studio, 5, 91)
	refs.oSelection.place_subtile(Vector2(130, 127))
	_select_entry(studio, 6, 18)
	check(studio.preview.texture != null, "Livro possui previa antes da colocacao")
	refs.oSelection.place_subtile(Vector2(133, 127))
	_select_entry(studio, 7, 1)
	studio._area_radius_changed(4)
	refs.oSelection.place_subtile(Vector2(136, 127))
	refs.oSelection.place_subtile(Vector2(139, 127))
	var areas = get_tree().get_nodes_in_group("ActionPoint")
	check(areas.size() == 2 and areas[0].pointNumber != areas[1].pointNumber and areas[0].pointRange == 4, "Areas com numero unico e raio escolhido")
	refs.oInspector.set_inspector_instance(creature)
	studio.studio_tabs.current_tab = 2
	check(studio.inspecting and studio.inspect_toggle.pressed, "Aba Inspecionar ativa selecao sem pintura")
	tools.open_inspector()
	tools.element_owner.select(tools.element_owner.get_item_index(0))
	tools.element_level.value = 6
	tools._apply_element()
	check(creature.ownership == 0 and creature.creatureLevel == 6, "Inspetor altera dono e nivel")
	tools.duplicate_element()
	check(not studio.inspecting and refs.oSelection.paintThingType == Things.TYPE.CREATURE and refs.oPlacingSettings.creatureLevel == 6, "Duplicar prepara copia com propriedades originais")
	var count = get_tree().get_nodes_in_group("Creature").size()
	refs.oSelection.place_subtile(Vector2(128, 127))
	var copy = get_tree().get_nodes_in_group("Creature")[-1]
	check(get_tree().get_nodes_in_group("Creature").size() == count + 1 and copy.creatureLevel == 6, "Copia colocada no local escolhido")
	refs.oInspector.set_inspector_instance(copy)
	tools.delete_element()
	check(get_tree().get_nodes_in_group("Creature").size() == count, "Excluir remove somente a copia selecionada")
	creature.ownership = 1
	creature.creatureLevel = 4
	tools.open_powers()
	yield(get_tree(), "idle_frame")
	_capture_view("studio-powers.png")
	check(tools.powers_result() == refs.oDataScript.data, "Abrir poderes nao altera o script")
	for row in tools.power_rows:
		if row.power == "POWER_HEAL_CREATURE":
			row.control.select(2)
	tools._apply_powers()
	check("MAGIC_AVAILABLE(PLAYER0,POWER_HEAL_CREATURE,1,1)" in refs.oDataScript.data, "Formulario libera cura inicial apenas para Vermelho")
	check(tools.managed_block("REM STUDIO-BEGIN GOAL\n", "GOAL", []).error != "", "Marcadores incompletos nao sao sobrescritos")
	tools.open_events()
	check(tools.event_result().error.empty(), "Objetivo aceita adversario com coracao")
	tools._apply_event()
	check("IF(PLAYER1,DUNGEON_DESTROYED == 1)" in refs.oDataScript.data and not "IF(PLAYER0,ALL_DUNGEONS_DESTROYED" in refs.oDataScript.data, "Objetivo especifico substitui somente vitoria padrao")
	tools.open_events()
	tools.event_kind.select(1)
	tools.destination.select(1)
	tools._update_event_preview()
	yield(get_tree(), "idle_frame")
	_capture_view("studio-events.png")
	tools._apply_event()
	check("IF_ACTION_POINT(%s,PLAYER0)" % areas[0].pointNumber in refs.oDataScript.data and "ADD_CREATURE_TO_LEVEL(PLAYER_GOOD," in refs.oDataScript.data, "Formulario cria evento com areas existentes")
	check("MAGIC_AVAILABLE(PLAYER0,POWER_HEAL_CREATURE,1,1)" in refs.oDataScript.data, "Evento preserva disponibilidade de poderes")
	var once = refs.oDataScript.data
	tools.open_events()
	tools.event_kind.select(1)
	tools.destination.select(1)
	tools._apply_event()
	check(refs.oDataScript.data == once, "Reaplicar evento nao duplica comandos")
	refs.oInspector.set_inspector_instance(areas[1])
	tools.delete_element()
	check(areas[1].is_in_group("ActionPoint"), "Area de surgimento usada pelo evento nao pode ser excluida pelo painel")
	tools.open_powers()
	refs.oDataScript.data += "\nREM edicao externa"
	tools._apply_powers()
	check(refs.oDataScript.data.ends_with("REM edicao externa"), "Formulario recusa sobrescrever edicao concorrente")
	refs.oDataScript.data = once
	tools.powers.hide()
	check(tools.patcher.parse(refs.oDataScript.data).error_line == 0, "Script gerado mantem IF/ENDIF equilibrados")
	for _i in range(3, 256):
		refs.oInstances.place_new_action_point(Things.TYPE.EXTRA, 1, Vector3(136.5, 127.5, 0), 5)
	check(refs.oInstances.get_free_action_point_number() == 256, "Numeros de area 1 a 255 preenchidos sem colisao")
	refs.oInstances.place_new_action_point(Things.TYPE.EXTRA, 1, Vector3(136.5, 127.5, 0), 5)
	check(get_tree().get_nodes_in_group("ActionPoint").size() == (255 if refs.oCurrentFormat.selected == Constants.OldFormat else 256), "Gold bloqueia area 256; KeeperFX preserva formato estendido")
	for area in get_tree().get_nodes_in_group("ActionPoint"):
		if not area in areas:
			refs.oInstances.kill_instance(area)
	studio.favorites = favorites
	studio.recent_items = recent
	studio._save_palette_preferences()
	studio.inspect_toggle.set_pressed_no_signal(false)
	studio._inspect_toggled(false)
	studio.owner_picker.select(1)
	studio._owner_selected(1)
	studio._level_changed(4)
	for message in refs.oUiMessages.get_children():
		if message is WindowDialog:
			message.hide()


func _capture_view(name: String):
	for message in Nodelist.list.oUiMessages.get_children():
		if message is WindowDialog:
			message.hide()
	VisualServer.force_draw()
	var image = get_tree().root.get_texture().get_data()
	image.flip_y()
	image.save_png(OS.get_environment("TEMP").plus_file(name))
