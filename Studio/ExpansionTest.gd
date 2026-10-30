extends Node

var smoke


func check(condition: bool, message: String):
	smoke.check(condition, message)


func run(studio, test_root: String):
	var refs = studio.refs
	var format = refs.oCurrentFormat.selected
	var tools = studio.construction
	var initial_path = refs.oCurrentMap.path
	var initial_targets = studio.sync_targets.duplicate(true)
	var initial_installed = studio._bundle_fingerprint(studio.installed_path)
	var positions = []
	for y in range(32, 35):
		for x in range(25, 29):
			var pos = Vector2(x, y)
			refs.oDataSlab.set_cellv(pos, Slabs.PATH)
			refs.oDataOwnership.set_cellv_ownership(pos, 5)
			positions.append(pos)
	refs.oDataSlab.set_cell(25, 32, Slabs.CLAIMED_GROUND)
	refs.oDataOwnership.set_cellv_ownership(Vector2(25, 32), 0)
	yield(refs.oSlabPlacement.generate_slabs_based_on_id(positions, true), "completed")
	var creature = refs.oInstances.place_new_thing(Things.TYPE.CREATURE, 21, Vector3(76.5, 97.5, 1), 0)
	creature.creatureLevel = 7
	creature.creatureName = "Teste de copia"
	creature.orientation = 300
	refs.oInstances.place_new_thing(Things.TYPE.OBJECT, 91, Vector3(79.5, 97.5, 1), 5)
	check(tools.capture(Rect2(25, 32, 4, 3)).empty(), "Area captura terreno, criatura e especial")
	check(tools.clipboard.things.size() == 2, "Copia nao inclui decoracao gerada automaticamente")
	var source_creature_index = creature.index
	var original = refs.oBuffers.get_buffer_for_extension("SLB", initial_path).data_array
	for mirrored in [false, true]:
		for turns in 4:
			tools.turns = turns
			tools.mirrored = mirrored
			tools.destination_owner = 1
			tools.overwrite = true
			var before_size = tools.clipboard.size
			var expected_size = Vector2(3, 4) if turns % 2 == 1 else Vector2(4, 3)
			check(tools.transformed_size() == expected_size, "Dimensoes da transformacao %s/%s" % [turns, mirrored])
			var corner = tools.transform_point(Vector2.ZERO, before_size, true)
			var expected = Vector2(25.5, 32.5) * 3 - Vector2(25, 32) * 3
			expected = Vector2(50, 30) * 3 + tools.transform_point(expected, before_size * 3, false)
			var operation = tools.apply_at(Vector2(50, 30))
			if operation is GDScriptFunctionState:
				yield(operation, "completed")
			check(refs.oDataSlab.get_cellv(Vector2(50, 30) + corner) == Slabs.CLAIMED_GROUND, "Terreno gira e espelha exatamente")
			var copy = refs.oInstances.get_node_on_subtile(int(expected.x), int(expected.y), "Creature")
			check(is_instance_valid(copy), "Criatura acompanha a transformacao")
			if is_instance_valid(copy):
				check(copy.creatureLevel == 7 and copy.ownership == 1 and copy.creatureName == "Teste de copia", "Nivel, nome e dono remapeado preservados")
				check(copy.index != source_creature_index, "Copia recebe identificador unico")
				check(copy.orientation == posmod((-300 if mirrored else 300) + turns * 512, 2048), "Orientacao acompanha giro e espelho")
			check(refs.oDataSlab.get_cell(25, 32) == Slabs.CLAIMED_GROUND and creature.index == source_creature_index, "Area original nao e movida")
			var found_special = false
			for id in get_tree().get_nodes_in_group("Object"):
				if id.subtype == 91 and Rect2(Vector2(50, 30), expected_size).has_point(Vector2(id.locationX, id.locationY) / 3):
					found_special = true
			check(found_special, "Item especial acompanha a copia")
	check(not tools.placement_error(Vector2(84, 84)).empty(), "Colagem fora do mapa recusada antes de alterar")
	var red_heart = refs.oInstances.return_dungeon_heart(0)
	check(not tools.placement_error(Vector2(int(red_heart.locationX / 3), int(red_heart.locationY / 3))).empty(), "Colagem protege coracao existente")
	var hearts_before = studio.snapshot().hearts
	tools.clipboard = tools.template_data(0, 3, 2)
	tools.turns = 0
	tools.mirrored = false
	tools.destination_owner = -1
	tools.overwrite = true
	var base_origin = _free_stamp_origin(tools, Vector2(4, 40))
	check(base_origin.x >= 0, "Fixture encontra destino livre sem substituir as bases originais")
	var placed = tools.apply_at(base_origin)
	if placed is GDScriptFunctionState:
		yield(placed, "completed")
	check(refs.oInstances.check_for_dungeon_heart(2) and not hearts_before.has(2), "Carimbo cria coracao para o novo dono")
	var room_counts = {}
	for y in range(9):
		for x in range(13):
			var slab = refs.oDataSlab.get_cellv(base_origin + Vector2(x, y))
			room_counts[slab] = room_counts.get(slab, 0) + 1
	check(room_counts.get(Slabs.DUNGEON_HEART, 0) == 9 and room_counts.get(Slabs.PORTAL, 0) == 9, "Base tem coracao e portal completos de 3 x 3")
	check(room_counts.get(Slabs.LAIR, 0) >= 9 and room_counts.get(Slabs.HATCHERY, 0) >= 9 and room_counts.get(Slabs.TREASURE_ROOM, 0) >= 9, "Base inclui dormitorio, galinheiro e tesouro")
	check("COMPUTER_PLAYER(PLAYER2" in refs.oDataScript.data and ("START_MONEY(PLAYER2" in refs.oDataScript.data or "START_MONEY(ALL_PLAYERS" in refs.oDataScript.data), "Base adversaria recebe economia e IA sem duplicar regras existentes")
	check(not tools.placement_error(Vector2(20, 40)).empty(), "Segundo coracao do mesmo dono recusado")
	var imp_count = 0
	for id in get_tree().get_nodes_in_group("Creature"):
		imp_count += int(id.subtype == 23 and id.ownership == 2)
	check(imp_count == 4, "Base coloca quatro imps do dono correto")
	refs.oEditor.mapHasBeenEdited = true
	var script = refs.oDataScript.data
	var configs = refs.oConfigFileManager.paths_loaded.duplicate(true)
	var modified = refs.oTabTileset.modified.duplicate()
	var snapshot_path = studio.recovery.capture("manual")
	check(not snapshot_path.empty(), "Snapshot completo criado sem SaveMap")
	check(refs.oCurrentMap.path == initial_path and refs.oEditor.mapHasBeenEdited and script == refs.oDataScript.data, "Recuperacao nao troca caminho, script nem estado de edicao")
	check(var2str(configs) == var2str(refs.oConfigFileManager.paths_loaded) and var2str(modified) == var2str(refs.oTabTileset.modified), "Snapshot nao muda dependencias nem flags de texturas")
	check(var2str(studio.sync_targets) == var2str(initial_targets) and studio._fingerprints_match(studio._bundle_fingerprint(studio.installed_path), initial_installed), "Recuperacao nao altera vinculos ou arquivos do jogo")
	var records = studio.recovery.list_records()
	var record = {}
	for entry in records:
		if entry.path == snapshot_path.get_base_dir():
			record = entry
	check(not record.empty(), "Historico encontra a versao com horario e origem")
	var snapshot_hash = File.new().get_sha256(snapshot_path)
	var restored = studio.recovery.recover(record)
	check(not restored.empty() and File.new().get_sha256(restored) == snapshot_hash, "Recuperar cria copia editavel verificada")
	check(not studio.sync_targets.has(studio._sync_key(restored.get_basename())), "Copia recuperada nao herda destino de substituicao")
	var before_corrupt = refs.oCurrentMap.path
	var wrong = record.duplicate(true)
	wrong.hashes["map00300.slb"] = "invalid"
	check(studio.recovery.recover(wrong).empty() and refs.oCurrentMap.path == before_corrupt, "Historico rejeita manifesto corrompido e preserva mapa aberto")
	var recovered_script = File.new()
	recovered_script.open(restored.get_basename() + ".txt", File.READ)
	check(recovered_script.get_as_text() == refs.oDataScript.data, "Snapshot inclui as regras ainda nao salvas")
	recovered_script.close()
	check(not studio.allow_save(snapshot_path.get_basename()), "Versao do historico nao pode ser sobrescrita pelo salvamento normal")
	var workspace = studio.workspace
	var blocker = test_root.plus_file("blocked-recovery")
	studio.library.write_text(blocker, "fixture")
	studio.workspace = blocker
	check(studio.recovery.capture("manual").empty(), "Falha de criacao de pasta nao retorna sucesso falso")
	studio.workspace = workspace
	check(refs.oCurrentMap.path == initial_path and refs.oEditor.mapHasBeenEdited, "Falha de recuperacao preserva a edicao em memoria")
	_check_retention(studio)
	var analyzer = studio.spatial_checks
	var blocked = refs.oInstances.place_new_thing(Things.TYPE.CREATURE, 21, Vector3(10.5, 10.5, 1), 0)
	refs.oDataSlab.set_cell(3, 3, Slabs.ROCK)
	var script_before = refs.oDataScript.data
	refs.oDataScript.data += "\nIF_ACTION_POINT(250,PLAYER0)\nENDIF\n"
	var diagnostics = analyzer.analyze()
	var codes = []
	for issue in diagnostics:
		codes.append(issue.code)
	check("blocked_creature" in codes and "missing_area" in codes, "Validacao visual encontra criatura na parede e referencia a area removida")
	refs.oInstances.kill_instance(blocked)
	refs.oDataScript.data = script_before
	analyzer.clear()
	var action_points = get_tree().get_nodes_in_group("ActionPoint")
	check(action_points.size() >= 2, "Areas disponiveis para o assistente")
	if action_points.size() >= 2:
		var entry_number = action_points[0].pointNumber
		var spawn_number = action_points[1].pointNumber
		var no_events = studio.map_tools.managed_block(refs.oDataScript.data, "EVENT_" + str(entry_number), []).text
		no_events = studio.map_tools.managed_block(no_events, "EVENT_" + str(spawn_number), []).text
		var mission = studio.missions.result(no_events, entry_number, spawn_number, 6, 3, 3, 0, 1)
		check(mission.error.empty(), "Assistente gera cadeia valida em Gold e KeeperFX")
		if mission.error.empty():
			check(studio.map_tools.patcher.parse(mission.text).error_line == 0, "Cadeia tem blocos condicionais equilibrados")
			check("TOTAL_CREATURES == 0" in mission.text and "POWER_HEAL_CREATURE,1,1" in mission.text, "Recompensa depende da derrota dos herois")
			check("FLAG0 == 2" in mission.text and "DUNGEON_DESTROYED == 1" in mission.text, "Vitoria aguarda as etapas anteriores")
			var updated = studio.missions.result(mission.text, entry_number, spawn_number, 6, 3, 3, 1, 1)
			check(updated.error.empty() and updated.text.count("REM STUDIO-BEGIN MISSION") == 1, "Atualizar missao nao duplica a cadeia")
			check(("ADD_CREATURE_TO_LEVEL(PLAYER0," + Things.fetch_id_string(Things.TYPE.CREATURE, 21)) in updated.text, "Recompensa alternativa gera aliados")
		var reserved = no_events + "\nREM FLAG0 reservado\n"
		var next_flag = studio.missions.result(reserved, entry_number, spawn_number, 6, 3, 3, 0, 1)
		check(next_flag.error.empty() and "FLAG1 == 0" in next_flag.text, "Missao escolhe flag livre e preserva flags manuais")
		var hero = refs.oInstances.place_new_thing(Things.TYPE.CREATURE, 6, Vector3(127.5, 127.5, 1), 4)
		check(not studio.missions.result(no_events, entry_number, spawn_number, 6, 3, 3, 0, 1).error.empty(), "Missao recusa combate ambiguo com outros herois")
		refs.oInstances.kill_instance(hero)
		if mission.error.empty():
			refs.oScriptEditor.load_generated_text(mission.text)
	refs.oEditor.mapHasBeenEdited = true
	var library_path = test_root.plus_file("Mapas/map%05d" % (7000 + format))
	check(refs.oSaveMap.save_map(library_path), "Salvar mapa para a biblioteca")
	var library = studio.library
	var entries = library.scan()
	var details = {}
	for entry in entries:
		if studio._sync_key(entry.path) == studio._sync_key(library_path):
			details = entry
	check(not details.empty(), "Biblioteca encontra mapa salvo recursivamente")
	check(library.thumbnail(details) != null, "Biblioteca gera miniatura a partir do SLB real")
	var source_hash = File.new().get_sha256(library_path + ".slb")
	var editor_executable = refs.oGame.EXECUTABLE_PATH
	var launch_command = refs.oGame.cmdline(library_path, false, test_root.plus_file("other-game/keeperfx.exe"))
	check("other-game" in launch_command and refs.oGame.EXECUTABLE_PATH == editor_executable, "Preparar Jogar usa o executavel escolhido sem trocar os dados do editor")
	var exported = library.build_campaign([details], [-1], "Campanha de teste")
	if format == Constants.OldFormat:
		check(not exported.error.empty(), "Campanha pede conversao explicita de Gold para KeeperFX")
	else:
		check(exported.error.empty(), "Campanha KeeperFX gera pacote independente")
		if exported.error.empty():
			var second = details.duplicate(true)
			second.name = "Segunda fase"
			exported = library.build_campaign([details, second], [-1, -1], "Teste de duas fases")
			check(exported.error.empty(), "Campanha com duas fases exportada")
			if exported.error.empty():
				print("EXPANSION_CAMPAIGN_CONFIG: " + exported.config)
				var output_script = library._read(exported.levels.plus_file("map06000.txt"))
				check("SET_NEXT_LEVEL(6001)" in output_script, "Progressao aponta para o numero instalado da fase seguinte")
				check(not "SET_NEXT_LEVEL" in library._read(library_path + ".txt"), "Progressao nao modifica script fonte")
				check("SINGLE_LEVELS = 6000 6001" in library._read(exported.config), "Configuracao registra a ordem real das fases")
				var game_root = test_root.plus_file("campaign-game")
				Directory.new().make_dir_recursive(game_root.plus_file("campgns/keeporig_lnd"))
				library.write_text(game_root.plus_file("campgns/keeporig_lnd/dkcredts.txt"), "Studio fixture")
				check(library.install_campaign(exported, game_root).empty(), "Campanha instala em jogo isolado com verificacao")
				check(not library.install_campaign(exported, game_root).empty(), "Instalacao nao sobrescreve campanha existente")
		check(not library.build_campaign([details, details], [1, 0], "Ciclo").error.empty(), "Campanha rejeita ciclo sem final")
		check(not library.build_campaign([details, details], [1, 4], "Destino invalido").error.empty(), "Campanha rejeita destino fora da lista")
	check(File.new().get_sha256(library_path + ".slb") == source_hash, "Biblioteca e campanha preservam mapa fonte")
	var limit_folder = test_root.plus_file("library-limit")
	Directory.new().make_dir_recursive(limit_folder)
	library.write_text(limit_folder.plus_file("map00001.slb"), "")
	library.write_text(limit_folder.plus_file("map00002.slb"), "")
	library.catalog.resize(999)
	library._scan_folder(limit_folder, 0)
	check(library.catalog.size() == 1000, "Limite de 1.000 mapas respeitado dentro da mesma pasta")
	check(studio.map_tools.patcher.parse("LEVEL_VERSION(1,2)\n").version == 0, "Versao com argumentos invalidos nao altera o perfil do script")
	var undo_script = refs.oDataScript.data
	check(not tools.capture(Rect2(base_origin + Vector2.ONE, Vector2.ONE)).empty(), "Copia parcial de coracao e recusada")
	var copy_error = tools.capture(Rect2(base_origin, Vector2(13, 9)))
	check(copy_error.empty(), "Copia aceita base inteira com coracao e portal" + (": " + copy_error if not copy_error.empty() else ""))
	tools.overwrite = true
	tools.turns = 0
	tools.mirrored = false
	tools.destination_owner = 3
	while refs.oSlabPlacement.activeGenerations > 0 or refs.oLoadingBar.visible:
		yield(get_tree(), "idle_frame")
	var undo_origin = _free_stamp_origin(tools, Vector2(24, 55))
	var undo_terrain = refs.oDataSlab.get_cellv(undo_origin + Vector2.ONE)
	check(undo_origin.x >= 0, "Destino da base de desfazer nao sobrepoe coracoes existentes")
	var undo_base = tools.apply_at(undo_origin)
	if undo_base is GDScriptFunctionState:
		yield(undo_base, "completed")
	check(refs.oInstances.check_for_dungeon_heart(3), "Base adicionada para testar desfazer atomico")
	yield(get_tree().create_timer(0.1), "timeout")
	refs.oUndoStates.perform_undo()
	yield(get_tree().create_timer(1), "timeout")
	check(not refs.oInstances.check_for_dungeon_heart(3) and refs.oDataSlab.get_cellv(undo_origin + Vector2.ONE) == undo_terrain and refs.oDataScript.data == undo_script, "Um unico desfazer restaura terreno, criaturas e regras da base juntos")
	tools.open_templates()
	yield(get_tree(), "idle_frame")
	smoke._capture_view("studio-prefabs.png")
	tools.dialog.hide()
	tools.open_transform()
	tools.transform_dialog.hide()
	studio.recovery.open_history()
	yield(get_tree(), "idle_frame")
	smoke._capture_view("studio-history.png")
	studio.recovery.dialog.hide()
	studio.spatial_checks.open_report()
	yield(get_tree(), "idle_frame")
	smoke._capture_view("studio-validation.png")
	studio.spatial_checks.dialog.hide()
	studio.missions.open_wizard()
	if is_instance_valid(studio.missions.dialog):
		yield(get_tree(), "idle_frame")
		smoke._capture_view("studio-missions.png")
		studio.missions.dialog.hide()
	library.open_library()
	check(library.listing.get_item_count() == library.catalog.size() and library.listing.get_item_count() > 0, "Abrir biblioteca sem busca mostra todos os mapas")
	library._filter(library_path.get_file())
	check(library.listing.get_item_count() > 0, "Busca da biblioteca encontra o arquivo salvo")
	if library.listing.get_item_count() > 0:
		library.listing.select(0)
		library._selected(0)
		library.title.text = "Mapa da biblioteca"
		library.description.text = "Descricao persistente de teste."
		library._store_details()
		check(library.metadata.get_value(studio._sync_key(library.selected_path), "name", "") == "Mapa da biblioteca", "Nome e descricao da biblioteca persistem sem mudar os arquivos")
		library._add_campaign()
	yield(get_tree(), "idle_frame")
	smoke._capture_view("studio-library.png")
	library.dialog.hide()
	library.open_campaign()
	check(library.campaign_list.get_item_count() > 0, "Adicionar na biblioteca alimenta a lista de campanha")
	if library.campaign_list.get_item_count() > 0:
		library.campaign_list.select(0)
		library._campaign_selected(0)
		check(library.next_picker.get_selected_id() == 999, "Destino padrao da campanha preserva sequencia normal")
	yield(get_tree(), "idle_frame")
	smoke._capture_view("studio-campaigns.png")
	library.campaign_dialog.hide()
	check(true, "Todos os formularios da expansao abrem sem erro")
	refs.oEditor.mapHasBeenEdited = false
	check(refs.oOpenMap.open_map(restored), "Copia recuperada pode ser reaberta")
	yield(get_tree().create_timer(1), "timeout")
	check(refs.oInstances.check_for_dungeon_heart(2), "Base nova preservada na recuperacao")
	check(refs.oCurrentFormat.selected == format, "Recuperacao preserva formato Gold/KeeperFX")
	check(refs.oDataScript.data == script, "Recuperacao restaura exatamente o script capturado")
	check(original.size() == 85 * 85 * 2, "Fixture tem dimensoes classicas esperadas")


func _free_stamp_origin(tools, start: Vector2) -> Vector2:
	for y in range(int(start.y), 71):
		for x in range(int(start.x), 71):
			var origin = Vector2(x, y)
			if tools.placement_error(origin).empty():
				return origin
	return Vector2(-1, -1)


func _check_retention(studio):
	var source = "retention-fixture"
	var root = studio.recovery.root()
	var tick = OS.get_ticks_msec()
	var manual = ""
	for index in 36:
		var path = root.plus_file("1000000000-%s" % (tick + index))
		Directory.new().make_dir_recursive(path)
		studio.library.write_text(path.plus_file("map00300.slb"), "fixture")
		var meta = ConfigFile.new()
		meta.set_value("snapshot", "source", source)
		meta.set_value("snapshot", "name", "Fixture")
		meta.set_value("snapshot", "reason", "manual" if index == 0 else "automatico")
		meta.set_value("snapshot", "hashes", {"map00300.slb": File.new().get_sha256(path.plus_file("map00300.slb"))})
		meta.save(path.plus_file("snapshot.cfg"))
		if index == 0:
			manual = path
	studio.recovery._prune(source)
	var count = 0
	for record in studio.recovery.list_records():
		if record.source == source and record.reason != "manual":
			count += 1
	check(count == 30, "Retencao conserva exatamente 30 versoes automaticas por mapa")
	check(File.new().file_exists(manual.plus_file("map00300.slb")), "Versao manual nao e removida pela retencao")
