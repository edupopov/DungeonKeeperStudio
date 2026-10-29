# Dungeon Keeper Studio

Editor simplificado para Dungeon Keeper Gold e KeeperFX, baseado no Unearth
de rainlizard (licenca MIT, preservada em `LICENSE`).

## Repositorio publico e backup

Este repositorio contem o projeto-fonte do editor moderno, scripts de
compilacao e os mapas **TesteProdutivo** criados do zero para Gold e KeeperFX.
Nao inclui o jogo comercial, uma instalacao do KeeperFX, dados extraidos,
configuracoes pessoais, mapas importados da campanha ou backups desses mapas.
Esses arquivos permanecem apenas na instalacao local e sao ignorados pelo Git.
Consulte `Mapas\README.md` para instalar os mapas de exemplo.

A licenca MIT cobre o codigo deste projeto e as modificacoes do Studio,
preservando os avisos do Unearth. As licencas de dependencias e direitos
de recursos de terceiros continuam aplicaveis. Dungeon Keeper e suas
marcas pertencem aos respectivos titulares; este e um projeto independente.

Para obter o projeto:

```powershell
git clone https://github.com/edupopov/DungeonKeeperStudio.git
```

Baixe o Godot 3.6.3, abra `project.godot` e aguarde a importacao.
Configure sua propria copia legal do jogo em **Configurar jogos**.
Para gerar o executavel, execute `Build-Studio.ps1 -GodotPath` com o caminho
do runtime oficial compativel. O runtime e os binarios gerados nao ficam no Git.

## Salvamento sincronizado com o KeeperFX

Nesta instalacao, **Salvar mapa/Ctrl+S** tambem pode atualizar o mapa no
KeeperFX configurado. A opcao `studio.sync_enabled` em `settings.cfg`
ativa esse comportamento; `studio.sync_targets` vincula cada caminho local
ao destino no jogo. Tambem e possivel ativar **Salvar tambem no KeeperFX**
no painel e usar **Vincular fase do KeeperFX** para escolher e confirmar a
fase existente que sera substituida. Configure primeiro o executavel correto
em **Configurar jogos**. O painel mostra esse destino e avisa quando a
sincronizacao esta desligada. As escolhas sao persistidas ao salvar configuracoes.

A copia editavel permanece em `Mapas`. Antes de atualizar o jogo, o Studio
guarda e confere um backup do conjunto anterior em `Backups-Jogo`.
Falhas de backup ou copia sao exibidas como erro, nunca como sucesso.
Se a publicacao falhar, a copia local permanece salva para tentar novamente.

Mapas importados da instalacao configurada ficam vinculados ao mesmo destino.
Mapas novos ou novas copias recebem um numero livre em `levels/studio`, com
um pacote separado. Os vinculos sao locais e nao acompanham o clone. Escolha explicitamente a
fase desejada usando **Vincular fase do KeeperFX** antes de substitui-la.

Feche a fase antes de salvar e inicie-a novamente depois. Carregar uma
partida salva nao recarrega o mapa do disco. **Testar** usa o KeeperFX para
mapas sincronizados, inclusive quando o formato dos dados e Gold classico.
**Exportar ao jogo** continua disponivel como publicacao separada em novo
numero; nao substitui o destino sincronizado nem muda o caminho da copia
local ja salva em Mapas, preservando sua vinculacao para o proximo Ctrl+S.

## Abrir e criar mapas

Abra `DungeonKeeperStudio.exe` ou `Abrir Editor.cmd`.
O programa utiliza os dados da sua copia do jogo; ele nao inclui nem substitui
os executaveis comerciais do Dungeon Keeper.

1. Use **Novo mapa** e escolha **Gold original** ou **KeeperFX**.
2. Escolha um nome e de um a quatro jogadores. Vermelho e o jogador humano;
   os demais recebem IA. O mapa inicial tem 85 x 85, coracoes, quatro imps
   por base, portais conectados, reservas de ouro e regras iniciais.
3. Escolha o **dono**, a categoria e um item da paleta. Clique no mapa para
   pintar ou colocar criaturas. O nivel vale para as proximas criaturas.
4. Use **Regras** para editar dinheiro, limite de criaturas, portais,
   disponibilidade e IA. O texto avancado do script continua acessivel.
5. Use **Salvar mapa** (ou Ctrl+S) para atualizar a copia de trabalho.
   No primeiro salvamento de um mapa novo, ela e criada em `Mapas`.
6. Use **Verificar**, depois **Exportar ao jogo** e confirme o destino.
7. Use **Testar** para iniciar o ultimo mapa exportado. Alteracoes posteriores
   precisam ser exportadas novamente se a sincronizacao estiver desativada.

**Continuar uma edicao:** use **Abrir meus mapas** ou **Retomar ultimo salvo**.
O seletor de mapas abre com uma lista visivel de pastas e arquivos e pode
ser redimensionado. Navegue pelas pastas com dois cliques; selecione o
arquivo `.slb` e clique em **Abrir mapa**, ou abra-o com dois cliques.
Os atalhos **Meus mapas**, **Campanha KeeperFX** e **Gold original** levam
diretamente as pastas correspondentes, sem digitar caminhos ou nomes.
O editor reabre o ultimo mapa salvo ao iniciar. O caminho da copia aparece
no painel, junto ao aviso de alteracoes ainda nao salvas.
**Importar original** cria outra copia do mapa do jogo, sem suas edicoes
anteriores. **Salvar nova copia** e a opcao explicita para duplicar o trabalho.

Sem sincronizacao, salvar nao substitui fases da campanha original. Cada exportacao usa um
numero livre: para jogar a versao atual, use **Testar** depois de exportar.
Atalhos antigos continuam apontando para a versao anterior, nao para a nova.

**Controles:** clique esquerdo coloca; direito copia o elemento sob o cursor;
roda ajusta o zoom; botao central move; Delete remove objetos; Ctrl+Z desfaz.
O retangulo e arrastado sobre o mapa. Coracoes e portais selecionam
automaticamente um carimbo quadrado 3 x 3.

O modo simples possui busca, categorias de terreno/salas/criaturas/armadilhas/
portas, dono explicito, pincel, retangulo e preenchimento. Ative
**Ferramentas avancadas do Unearth** para acessar os recursos especializados.
O botao **Modo simples**, no menu superior, permite voltar.
Os menus avancados e alguns nomes tecnicos ainda usam o idioma do Unearth.

## Compatibilidade e protecao dos originais

- **Gold original:** tamanho 85 x 85, arquivos TNG/APT/LGT classicos e
  restricoes do jogo original. Sao usados numeros livres de 300 a 799
  na pasta `levels`.
- **KeeperFX:** arquivos TNGFX/APTFX/LGTFX e metadados LOF, com exportacao
  para `levels\studio`. Um `levels\studio.cfg` separado identifica o pacote.
  Numeros livres comecam em 5000. Nao e feita conversao automatica entre formatos.
- **Configurar jogos** armazena um executavel separado para cada perfil.
  Sem KeeperFX instalado, ainda e possivel editar e salvar mapas KFX usando
  os recursos classicos. Criaturas/texturas exclusivas exigem seus dados.
- Abrir um mapa fora da pasta do Studio cria antes uma copia de trabalho.
  A eventual descompressao ocorre na copia, nao no original.
- O salvamento direto fora do Studio e bloqueado. A exportacao prepara o
  conjunto localmente, verifica colisao, copia por arquivos temporarios e
  desfaz arquivos novos se ocorrer falha. Nenhum slot existente e substituido.
- `Mapas`, `Exportados` e `backups` guardam trabalho, pacotes e recuperacao.
  Mantenha uma copia externa dessas pastas.

O diagnostico verifica limites basicos, donos, recursos estendidos, criaturas
sobre terreno solido e blocos IF/ENDIF. Avisos sobre vitoria e IA sao
heuristicas: mapas especiais podem ter regras intencionais diferentes.
Ele nao substitui jogar a missao nem valida toda a linguagem de scripts.

**Importante:** exportar para Gold nao altera `levels.txt`, `dd1lev.txt`
nem substitui niveis de campanha. O botao Testar abre pelo numero do mapa.
Adicionar uma missao ao menu de campanha do Gold e uma configuracao separada.
O teste no jogo depende de uma instalacao executavel no seu Windows; o editor
nao emula DOS/Windows 95 e nao instala o KeeperFX.

Mapas avancados importados podem depender de configuracoes, mods e recursos
compartilhados da campanha de origem. Copiar seus arquivos de mapa nao torna
esses recursos automaticamente independentes.

## Desenvolvimento

Use **Godot 3.6.3**; nao abra este projeto no Godot 4.
O codigo da interface simplificada esta em `Studio\Studio.gd` e as
verificacoes em `Studio\MapChecks.gd`. O restante preserva o motor de
leitura, escrita, geometria e edicao do Unearth.

O executavel local utiliza o runtime oficial do Godot 3.6.3 e o pacote
`DungeonKeeperStudio.pck`; ambos precisam ficar juntos. O projeto-fonte
tambem esta nesta pasta.

Para reconstruir, execute `Build-Studio.ps1`. Se necessario, informe
`-GodotPath` com o caminho do Godot 3.6.3. Na primeira compilacao de uma
copia limpa, abra o projeto no editor Godot e aguarde a importacao.

Execute as verificacoes em uma copia isolada do projeto, configurada para
usar os dados de sua instalacao legal do jogo. Elas criam mapas temporarios
e gravam configuracoes; nao use uma instancia do editor com trabalho aberto.
Para executar as verificacoes integradas sem iniciar o jogo:

```powershell
.\Runtime\Godot.exe --path . --no-window --studio-test
```

O teste cria mapas em um diretorio isolado `Studio\TestOutput-*`, percorre
os dois perfis, coloca criaturas pela ferramenta de edicao, confere dono
e nivel, pinta terreno, salva/reabre os arquivos e verifica publicacao sem
sobrescrita. Nao publica mapas na instalacao real do jogo.

Licencas do runtime: `GODOT-LICENSE.txt` e `GODOT-COPYRIGHT.txt`.
Recursos comerciais do Dungeon Keeper continuam sujeitos aos direitos
dos respectivos titulares; nao redistribua os dados do jogo.

---

## Documentacao original do Unearth

A map editor made for Dungeon Keeper 1 and KeeperFX, prioritizing ease of use and extending map editing capabilities. When running the editor, the game will be detected, maps will be browsable and playable using the 'Play' button. To see all editor controls check the Help menu.

You can set up file association on Windows with any of the map file types (.slb, .clm, .tng, etc) and the editor will open the map when you open the file in Windows. You can also drag a file into the editor window to open the map.

Report all bugs and feature requests to the [issues page](https://github.com/rainlizard/Unearth/issues).

# Installation
Download the .zip from the [releases page](https://github.com/rainlizard/Unearth/releases), then extract the archive into the game directory.

If you extract somewhere other than the game directory, then Unearth will prompt you to locate the game executable.

For Linux: make the binary executable with `chmod +x Unearth.x86_64` after extracting.

# Development

To edit this project:
1. Clone this repository:
   - Command line: `git clone https://github.com/rainlizard/Unearth.git`
   - Or use [Github Desktop](https://desktop.github.com/)
2. Download [Godot 3.6.3](https://godotengine.org/download/archive/3.6.3-stable/) (4.0+ is unsupported)
3. Open the project in Godot, be aware that it may take a moment for the main scene to appear

If you submit a pull request, an automatic build will be generated for it in [Actions](https://github.com/rainlizard/Unearth/actions).
