extends Reference

const MANAGED = ["slb", "clm", "dat", "own", "inf", "tng", "tngfx", "apt", "aptfx", "lgt", "lgtfx", "txt", "lua", "lif", "lof", "wlb", "wib", "slx", "une"]


func bundle(path: String) -> Dictionary:
	var files = {}
	var dir = Directory.new()
	if dir.open(path.get_base_dir()) != OK:
		return files
	var prefix = path.get_file().to_lower() + "."
	dir.list_dir_begin(true, true)
	var name = dir.get_next()
	while not name.empty():
		if not dir.current_is_dir() and name.to_lower().begins_with(prefix):
			files[name.substr(prefix.length()).to_lower()] = path.get_base_dir().plus_file(name)
		name = dir.get_next()
	dir.list_dir_end()
	return files


func sync(source: String, target: String, backup_root: String) -> Dictionary:
	var dir = Directory.new()
	if source.to_lower() == target.to_lower():
		return {"error": "A copia local e o destino no jogo precisam ser separados."}
	var incoming = bundle(source)
	for ext in ["slb", "clm", "dat", "own", "inf"]:
		if not incoming.has(ext):
			return {"error": "Copia local incompleta: falta ." + ext}
	if not incoming.has("tng") and not incoming.has("tngfx"):
		return {"error": "Copia local sem arquivos de criaturas."}
	if not dir.dir_exists(target.get_base_dir()):
		return {"error": "Pasta do jogo indisponivel: " + target.get_base_dir()}
	var lock = target.get_base_dir().plus_file(".studio-lock-" + target.get_file().to_lower())
	if dir.make_dir(lock) != OK:
		return {"error": "Destino ocupado ou sem permissao de escrita: " + lock}
	var result = _locked_sync(incoming, target, backup_root)
	if dir.remove(lock) != OK:
		result["error"] = result.get("error", "") + "\nNao foi possivel remover a trava: " + lock
	return result


func _locked_sync(incoming: Dictionary, target: String, backup_root: String) -> Dictionary:
	var dir = Directory.new()
	var existing = bundle(target)
	var backup = backup_root.plus_file("%s-%s-%s" % [target.get_file(), OS.get_unix_time(), OS.get_ticks_usec()])
	if dir.make_dir_recursive(backup) != OK:
		return {"error": "Nao foi possivel criar o backup: " + backup}
	var originals = {}
	for ext in existing:
		var path = existing[ext]
		var copy = backup.plus_file(path.get_file())
		var digest = File.new().get_sha256(path)
		if dir.copy(path, copy) != OK or File.new().get_sha256(copy) != digest:
			return {"error": "Backup nao confirmado; jogo nao alterado: " + path}
		originals[ext] = digest
	var staged = {}
	var failure = ""
	for ext in incoming:
		var dest = existing.get(ext, target + "." + ext)
		var temp = dest + ".studio-tmp-" + str(OS.get_ticks_usec())
		staged[ext] = temp
		if dir.copy(incoming[ext], temp) != OK or File.new().get_sha256(temp) != File.new().get_sha256(incoming[ext]):
			failure = "Falha ao preparar arquivo: " + dest
			break
	for ext in existing:
		if File.new().get_sha256(existing[ext]) != originals[ext]:
			failure = "O mapa no jogo mudou durante o backup; sincronizacao cancelada."
			break
	var changed = false
	var added = []
	if failure.empty():
		changed = true
		for ext in staged:
			var dest = existing.get(ext, target + "." + ext)
			if not existing.has(ext) and dir.file_exists(dest):
				failure = "Outro programa criou o destino durante a sincronizacao: " + dest
				break
			if dir.file_exists(dest) and dir.remove(dest) != OK:
				failure = "Nao foi possivel substituir: " + dest
				break
			if dir.rename(staged[ext], dest) != OK:
				failure = "Nao foi possivel instalar: " + dest
				break
			if not existing.has(ext):
				added.append(dest)
		if failure.empty():
			for ext in existing:
				if ext in MANAGED and not incoming.has(ext) and dir.remove(existing[ext]) != OK:
					failure = "Nao foi possivel remover arquivo antigo: " + existing[ext]
					break
	if failure.empty():
		for ext in incoming:
			var dest = existing.get(ext, target + "." + ext)
			if File.new().get_sha256(dest) != File.new().get_sha256(incoming[ext]):
				failure = "Arquivo instalado divergente: " + dest
				break
	if not failure.empty() and changed:
		for path in added:
			if dir.file_exists(path) and dir.remove(path) != OK:
				failure += "\nFalha ao remover arquivo novo: " + path
		for ext in existing:
			var path = existing[ext]
			if dir.copy(backup.plus_file(path.get_file()), path) != OK or File.new().get_sha256(path) != originals[ext]:
				failure += "\nRESTAURE MANUALMENTE: " + path + " a partir de " + backup
	for ext in staged:
		if dir.file_exists(staged[ext]) and dir.remove(staged[ext]) != OK:
			failure += "\nFalha ao limpar temporario: " + staged[ext]
	if not failure.empty():
		return {"error": failure, "backup": backup}
	return {"backup": backup}
