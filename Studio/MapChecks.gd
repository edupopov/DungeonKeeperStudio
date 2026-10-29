extends Reference


func inspect(snapshot: Dictionary) -> Array:
	var issues = []
	var classic = snapshot.classic
	var hearts = snapshot.hearts
	if classic and snapshot.size != Vector2(85, 85):
		issues.append("ERRO: Gold original exige um mapa de 85 x 85.")
	if not hearts.has(0):
		issues.append("AVISO: falta um coracao vermelho para o jogador humano.")
	for owner in hearts:
		if hearts[owner] > 1:
			issues.append("AVISO: jogador %s possui mais de um coracao." % owner)
	if classic and snapshot.creatures > 255:
		issues.append("ERRO: Gold original permite no maximo 255 criaturas simultaneas.")
	if classic and snapshot.extended:
		issues.append("ERRO: existem terrenos, criaturas ou donos exclusivos do KeeperFX.")
	var commands = active_lines(snapshot.script)
	if commands.empty():
		issues.append("AVISO: mapa sem regras. Abra Regras para adicionar a configuracao inicial.")
	if not has_command(commands, "WIN_GAME"):
		issues.append("AVISO: nao foi encontrada uma condicao de vitoria em DKScript; confira se a missao pode terminar.")
	var parsed = BasicScriptPatcher.new().parse(snapshot.script)
	if parsed.error_line > 0:
		issues.append("ERRO: bloco IF/ENDIF incorreto na linha %s do DKScript." % parsed.error_line)
	for owner in hearts:
		if owner > 0 and owner < 4 and not has_player_command(commands, "COMPUTER_PLAYER", owner):
			issues.append("AVISO: jogador %s sem IA configurada; pode ser uma vaga humana multiplayer." % owner)
	if snapshot.blocked_creatures > 0:
		issues.append("AVISO: %s criatura(s) sobre terreno solido. Revise suas posicoes." % snapshot.blocked_creatures)
	if snapshot.lua and classic:
		issues.append("ERRO: scripts Lua exigem KeeperFX.")
	return issues


func active_lines(text: String) -> Array:
	var result = []
	var in_comment = false
	for line in text.split("\n"):
		line = line.strip_edges().to_upper()
		if in_comment or line.begins_with("/*"):
			in_comment = not "*/" in line
			continue
		if line.empty() or line.begins_with("REM") or line.begins_with(";"):
			continue
		result.append(line.replace(" ", "").replace("\t", ""))
	return result


func has_command(lines: Array, command: String) -> bool:
	for line in lines:
		if line == command or line.begins_with(command + "("):
			return true
	return false


func has_player_command(lines: Array, command: String, player: int) -> bool:
	for line in lines:
		if line.begins_with(command + "(PLAYER" + str(player) + ","):
			return true
	return false


func has_errors(issues: Array) -> bool:
	for issue in issues:
		if issue.begins_with("ERRO:"):
			return true
	return false
