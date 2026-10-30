extends Reference

const CREATURE_NAMES = {
	1: "Mago", 2: "Barbaro", 3: "Arqueiro", 4: "Monge", 5: "Anao",
	6: "Cavaleiro", 7: "Avatar", 8: "Tunelador", 9: "Bruxa", 10: "Gigante",
	11: "Fada", 12: "Ladra", 13: "Samurai", 14: "Ceifador", 15: "Esqueleto",
	16: "Troll", 17: "Dragao", 18: "Filho das trevas", 19: "Mosca",
	20: "Amante sombria", 21: "Feiticeiro", 22: "Demonio de bile", 23: "Diabinho (imp)",
	24: "Besouro", 25: "Vampiro", 26: "Aranha", 27: "Cao infernal",
	28: "Fantasma", 29: "Tentaculo", 30: "Orc"
}


func creature_name(id: int) -> String:
	return CREATURE_NAMES.get(id, Things.fetch_name(Things.TYPE.CREATURE, id))

const OBJECTS = {
	86: ["Revelar mapa", "Revela o terreno oculto do mapa."],
	87: ["Ressuscitar criatura", "Permite recuperar uma criatura morta."],
	88: ["Transferir criatura", "Leva uma criatura para outra missao. Depende da progressao da campanha; nao conecta mapas isolados."],
	89: ["Roubar heroi", "Converte um heroi para o seu lado. Nao e o especial de transferencia."],
	90: ["Multiplicar criaturas", "Duplica criaturas do jogador que ativa o especial."],
	91: ["Aumentar nivel", "Aumenta o nivel das criaturas do jogador."],
	92: ["Tornar seguro", "Reforca a dungeon do jogador."],
	93: ["Encontrar mundo secreto", "Libera um nivel secreto quando a campanha oferece esse destino."],
	11: ["Mao do mal", "Poder de pegar elementos da dungeon."],
	12: ["Criar imp", "Cria um trabalhador imp."],
	13: ["Obediencia", "Ordena que as criaturas trabalhem."],
	14: ["Tapa", "Poder de dar tapas nas criaturas."],
	15: ["Visao do mal", "Revela temporariamente uma area distante."],
	16: ["Chamado as armas", "Atrai criaturas para um ponto de reuniao."],
	17: ["Desmoronamento", "Provoca uma queda de pedras."],
	18: ["Curar criatura", "Recupera a saude de uma criatura."],
	19: ["Convocar audiencia", "Reune criaturas junto ao coracao."],
	20: ["Raio", "Atinge inimigos com um raio."],
	21: ["Acelerar criatura", "Aumenta temporariamente a velocidade."],
	22: ["Proteger criatura", "Protege uma criatura contra dano."],
	23: ["Ocultar criatura", "Torna uma criatura invisivel temporariamente."],
	45: ["Doenca", "Infecta uma criatura."],
	46: ["Transformar em galinha", "Transforma temporariamente uma criatura em galinha."],
	47: ["Destruir paredes", "Destroi paredes da dungeon."],
	134: ["Armagedom", "Reune os combatentes para a batalha final."],
	135: ["Possuir criatura", "Permite controlar uma criatura diretamente."]
}


func object_name(id: int) -> String:
	return OBJECTS[id][0] if OBJECTS.has(id) else Things.fetch_name(Things.TYPE.OBJECT, id)


func object_description(id: int) -> String:
	return OBJECTS[id][1] if OBJECTS.has(id) else "Elemento definido pela configuracao do KeeperFX. Consulte as regras dessa instalacao."


func entries(category: int, classic: bool, generator) -> Array:
	var result = []
	if category == 5:
		for id in Things.DATA_OBJECT:
			if Things.DATA_OBJECT[id][Things.GENRE] != "SPECIALBOX":
				continue
			# Custom boxes require a script and box number; keep them in advanced tools.
			if not id in range(86, 94) and (classic or Things.is_custom_special_box(id)):
				continue
			result.append([object_name(id), id])
	elif category == 6:
		for magic in generator.get_magic_list():
			result.append([object_name(magic[0]), magic[0]])
	elif category == 7:
		result.append(["Area de evento", 1])
	return result


func search_key(text: String) -> String:
	var key = text.to_lower()
	for pair in [["á", "a"], ["à", "a"], ["ã", "a"], ["â", "a"], ["é", "e"], ["ê", "e"], ["í", "i"], ["ó", "o"], ["ô", "o"], ["õ", "o"], ["ú", "u"], ["ç", "c"]]:
		key = key.replace(pair[0], pair[1])
	return key
