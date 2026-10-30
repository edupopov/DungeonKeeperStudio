extends Node

var smoke


func check(condition: bool, text: String):
	smoke.check(condition, text)


func run(studio):
	var refs = studio.refs
	var ui = studio.visual_tools
	var tools = studio.construction
	var dirty = refs.oEditor.mapHasBeenEdited
	var versions = ui.saved_versions.duplicate(true)
	var map_path = refs.oCurrentMap.path
	for node in refs.oUi.get_node("UiSystem").get_children():
		if node is WindowDialog:
			node.hide()
	var before = refs.oBuffers.get_buffer_for_extension("SLB", map_path).data_array
	var script = refs.oDataScript.data
	var creatures = get_tree().get_nodes_in_group("Creature").size()
	var targets = studio.sync_targets.duplicate(true)
	refs.oEditor.mapHasBeenEdited = false
	ui.record_save(false)
	check("SALVO LOCALMENTE" in ui.save_state().text and not "ENVIADO AO JOGO" in ui.save_state().text, "Indicador local nao afirma sincronizacao")
	ui.record_save(true)
	check("ENVIADO AO JOGO" in ui.save_state().text, "Somente envio confirmado mostra estado verde")
	ui.record_save(false)
	check(not "ENVIADO AO JOGO" in ui.save_state().text, "Novo salvamento local invalida confirmacao anterior de envio")
	refs.oEditor.mapHasBeenEdited = true
	check(ui.save_state().text == "ALTERACOES PENDENTES", "Alteracoes pendentes prevalecem sobre estados de sucesso")
	refs.oEditor.mapHasBeenEdited = false
	refs.oCurrentMap.path = map_path + "-outro"
	check(not "ENVIADO AO JOGO" in ui.save_state().text, "Troca de mapa nao herda confirmacao de outro arquivo")
	refs.oCurrentMap.path = map_path
	var creature = get_tree().get_nodes_in_group("Creature")[0]
	var original_color = creature.modulate
	ui.toggle_layer(0)
	check(creature.modulate.a == 0 and creature.is_in_group("Creature"), "Ocultar criaturas altera somente visualizacao")
	var extra = refs.oInstances.place_new_thing(Things.TYPE.CREATURE, 23, Vector3(130.5, 130.5, 1), 0)
	ui.apply_layers()
	check(extra.modulate.a == 0, "Camada oculta abrange novos elementos")
	ui.toggle_layer(0)
	check(creature.modulate == original_color and extra.modulate.a > 0, "Restaurar camada preserva cores originais")
	ui.toggle_layer(0)
	refs.oInstances.kill_instance(extra)
	yield(get_tree(), "idle_frame")
	ui.apply_layers()
	check(creature.modulate.a == 0, "Excluir elemento oculto nao quebra atualizacao das camadas")
	studio.advanced.set_pressed_no_signal(true)
	ui.apply_layers()
	check(creature.modulate == original_color, "Modo avancado restaura visualizacao nativa")
	studio.advanced.set_pressed_no_signal(false)
	ui.toggle_layer(0)
	for index in [1, 2, 3, 4]:
		ui.toggle_layer(index)
	check(refs.oOverheadOwnership.modulate.a == 0 and studio.spatial_checks.modulate.a == 0, "Donos e avisos podem ser ocultados")
	for index in [1, 2, 3, 4]:
		ui.toggle_layer(index)
	var key_event = InputEventKey.new()
	key_event.pressed = true
	key_event.scancode = KEY_R
	ui.activate("paint")
	check(not studio.inspecting and tools.mode.empty(), "Pintar sai da inspecao e da construcao")
	ui.activate("inspect")
	check(studio.inspecting and tools.mode.empty(), "Barra ativa inspecao sem pintura")
	ui.activate("select")
	check(tools.mode == "select" and not studio.inspecting, "Barra inicia selecao exclusiva")
	tools.clipboard = tools.template_data(0, 3, 3)
	tools.turns = 0
	tools.mirrored = false
	tools._arm("stamp")
	refs.oSelector.visible = true
	ui.activate("rotate")
	ui.activate("mirror")
	check(tools.turns == 1 and tools.mirrored, "Girar e espelhar alteram apenas a previa")
	studio.search.grab_focus()
	ui._unhandled_key_input(key_event)
	check(tools.turns == 1, "Atalho R nao interfere na digitacao")
	studio.search.release_focus()
	var previous_turns = tools.turns
	ui._unhandled_key_input(key_event)
	check(tools.turns == (previous_turns + 1) % 4, "Atalho R gira previa quando nao ha formulario ou digitacao")
	tools.open_templates()
	previous_turns = tools.turns
	ui._unhandled_key_input(key_event)
	check(tools.turns == previous_turns, "Atalho R nao atua por tras de um formulario")
	tools.dialog.hide()
	var counts = tools.selection_counts(Rect2(0, 0, 85, 85))
	check(counts.creatures == creatures and counts.items > 0, "Resumo da selecao conta criaturas e itens")
	check(tools.destination_conflict(Vector2.ZERO), "Previa marca borda como conflito")
	var heart = refs.oInstances.return_dungeon_heart(0)
	var heart_pos = Vector2(int(heart.locationX / 3), int(heart.locationY / 3))
	check(tools.destination_conflict(heart_pos), "Previa marca coracao protegido em vermelho")
	refs.oSelector.set_process(false)
	refs.oSelector.visible = true
	refs.oSelector.cursorTile = Vector2(30, 35)
	tools.preview_error = tools.placement_error(refs.oSelector.cursorTile)
	tools.update()
	yield(get_tree(), "idle_frame")
	smoke._capture_view("studio-ghost.png")
	tools.first = Vector2(30, 35)
	tools.mode = "select"
	refs.oSelector.cursorTile = Vector2(36, 40)
	tools.update()
	yield(get_tree(), "idle_frame")
	smoke._capture_view("studio-selection.png")
	refs.oSelector.set_process(true)
	ui.activate("cancel")
	check(tools.mode.empty(), "Cancelar encerra a previa")
	studio.studio_tabs.current_tab = 2
	tools._arm("stamp")
	ui.activate("inspect")
	check(studio.inspecting and tools.mode.empty(), "Inspecao funciona mesmo quando a aba ja estava aberta")
	tools._arm("stamp")
	studio._tool_selected(0)
	check(tools.mode.empty(), "Escolher lapis encerra carimbo anterior")
	check(before == refs.oBuffers.get_buffer_for_extension("SLB", map_path).data_array and script == refs.oDataScript.data, "Previa, camadas e barra nao alteram terreno nem script")
	check(var2str(targets) == var2str(studio.sync_targets), "Controles visuais nao alteram vinculos de sincronizacao")
	for id in [6, 7, 8, 14, 21, 23, 27, 29]:
		check(studio.catalog.creature_name(id) == studio.catalog.CREATURE_NAMES[id], "Criatura %s tem nome esperado em portugues" % id)
	for pair in [[Things.TYPE.CREATURE, 23], [Things.TYPE.OBJECT, 91], [Things.TYPE.OBJECT, 18]]:
		check(Things.fetch_icon_sprite(pair[0], pair[1], Vector2(48, 48), 2.0) != null, "Icone visual disponivel para criatura/especial/magia %s" % pair[1])
	var picker = OptionButton.new()
	add_child(picker)
	studio.map_tools._creature_option(picker, 6)
	check(picker.get_item_text(0) == "Cavaleiro" and picker.get_item_icon(0) != null, "Formularios de herois compartilham nomes e icones da paleta")
	picker.queue_free()
	var library = studio.library
	library.open_library()
	var original_catalog = library.catalog.duplicate(true)
	if not original_catalog.empty():
		library.catalog.clear()
		for i in 25:
			var details = original_catalog[0].duplicate(true)
			details.name = "Cartao %s" % i
			details.path += "-cartao-%s" % i
			library.catalog.append(details)
		library._filter("")
		check(library.cards.get_child_count() == 12, "Biblioteca limita cartoes por pagina")
		library._page(1)
		check(library.page == 1 and library.cards.get_child_count() == 12, "Biblioteca navega para segunda pagina")
		library._page(1)
		check(library.page == 2 and library.cards.get_child_count() == 1, "Ultima pagina mostra somente mapas restantes")
		library._card_action(24, "select")
		check(library.title.text == "Cartao 24" and not library.selected_path.empty(), "Cartao seleciona metadados do mapa correto")
		library._card_action(24, "play")
		check(library.pending_play.name == "Cartao 24" and library.play_confirm.visible, "Jogar do cartao solicita confirmacao para o mapa certo")
		library.play_confirm.hide()
		library._filter("inexistente-visual-test")
		check(library.cards.get_child_count() == 0 and library.selected_path.empty(), "Busca vazia limpa cartoes e selecao antiga")
	library.catalog = original_catalog
	library._filter("")
	yield(get_tree(), "idle_frame")
	smoke._capture_view("studio-cards.png")
	library.dialog.hide()
	# Override the viewport, not the user's saved window preferences.
	var old_size = OS.window_size
	for size in [Vector2(1280, 720), Vector2(1024, 768)]:
		OS.window_size = size
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
		studio._layout()
		tools.open_templates()
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
		var bounds = Rect2(Vector2.ZERO, get_viewport().size)
		check(bounds.encloses(studio.panel.get_global_transform_with_canvas().xform(Rect2(Vector2.ZERO, studio.panel.rect_size))), "Painel cabe na janela %s" % size)
		check(bounds.encloses(tools.dialog.get_global_transform_with_canvas().xform(Rect2(Vector2.ZERO, tools.dialog.rect_size))), "Formulario cabe na janela %s" % size)
		check(tools.dialog.get_ok().is_visible_in_tree(), "Aplicar permanece acessivel em %s" % size)
		check(tools.dialog.rect_position.y >= 72, "Titulo nao fica atras do menu em %s" % size)
		yield(get_tree().create_timer(0.2), "timeout")
		check(not refs.oMessage.get_node("VBoxContainer").visible, "Notificacoes rapidas nao cobrem o formulario")
		smoke._capture_view("studio-small-%s.png" % int(size.x))
		tools.dialog.hide()
		library.open_library()
		yield(get_tree(), "idle_frame")
		check(bounds.encloses(library.dialog.get_global_transform_with_canvas().xform(Rect2(Vector2.ZERO, library.dialog.rect_size))), "Biblioteca cabe na janela %s" % size)
		library.dialog.hide()
	OS.window_size = old_size
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	studio._layout()
	refs.oEditor.mapHasBeenEdited = dirty
	ui.saved_versions = versions
	ui.refresh()
