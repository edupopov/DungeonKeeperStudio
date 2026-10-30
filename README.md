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

## Paleta, inspecao e regras visuais

O painel possui abas **Mapa**, **Construir** e **Inspecionar**. Os atalhos
Novo, Abrir, Salvar e Testar permanecem visiveis acima delas. A aba Mapa
reune sincronizacao, exportacao, poderes e eventos; Construir concentra
a paleta; Inspecionar permite selecionar sem pintar por acidente.

- **Itens especiais**: revelar mapa, ressuscitar, transferir criatura,
  roubar heroi, multiplicar criaturas, aumentar nivel, tornar seguro e
  encontrar mundo secreto. Transferencia e mundo secreto dependem da
  campanha; nao criam automaticamente uma ligacao entre mapas isolados.
- **Livros de magia**: coloque livros coletaveis no terreno. O painel
  **Poderes por jogador** e separado: define Inicio, Pesquisar ou
  Indisponivel para cada poder do jogador escolhido. Somente as escolhas
  alteradas sao gravadas; regras condicionais existentes sao preservadas.
  A pesquisa depende de biblioteca, pesquisadores e configuracao do jogo.
- Use a busca por nome/descricao, inclusive sem acentos. Adicione a selecao
  aos **Favoritos** ou filtre pelos **Recentes**, entre todas as categorias.
  Essas preferencias sao locais. A previa semitransparente acompanha
  o cursor antes de colocar criaturas, itens e armadilhas.
- Ative **Inspecionar (sem pintar)** e clique em um elemento para
  seleciona-lo sem colocar outro por acidente. **Editar selecionado**
  muda dono e nivel de criaturas ou raio de areas. **Duplicar** prepara
  a ferramenta com as propriedades do original; clique em um local livre
  para colocar a copia. **Excluir** remove o selecionado, com o desfazer
  nativo para elementos do mapa. Portas, coracoes e elementos vinculados
  ao terreno continuam sendo editados como terreno ou nas ferramentas
  avancadas. Livros/especiais seguem o dono da biblioteca; fora dela sao
  neutros, conforme a mecanica do jogo.
- **Areas de evento** cria pontos circulares numerados automaticamente.
  O raio e medido em subblocos (tres subblocos formam um bloco de terreno).
  No formato Gold, a colocacao respeita os numeros de area de 1 a 255.
  Em **Objetivos e eventos**, escolha a area de entrada do Vermelho,
  a area de surgimento, criatura, quantidade e nivel dos herois.
  Cada evento dispara uma vez. Reaplicar na mesma area atualiza o evento,
  sem duplicar o bloco; o formulario tambem permite remove-lo.
- O objetivo visual **destruir um coracao inimigo** destina-se a partidas
  individuais com o humano Vermelho. Substitui apenas a vitoria padrao
  "todos os inimigos"; nao apaga vitorias manuais desconhecidas. Remover
  esse objetivo nao restaura automaticamente outra condicao de vitoria.
  Confira **Verificar** antes de exportar.

Os formularios mostram o script resultante antes de aplicar. Abrir/cancelar
nao altera as regras. Eles recusam scripts com IF/ENDIF desequilibrados,
mapas com Lua e alteracoes concorrentes no mapa/script. Regras avancadas
continuam disponiveis no Unearth. Itens adicionais dependentes da
configuracao do KeeperFX nao sao oferecidos no perfil Gold.

Depois de aplicar, use **Salvar mapa** e reinicie a fase para carregar
as alteracoes. Os formularios nao mudam partidas ja salvas.

## Construcao, recuperacao e missoes

As seis ferramentas abaixo ficam no painel simples, sem precisar abrir os
controles avancados:

| Ferramenta | Onde usar | Comportamento |
| --- | --- | --- |
| Bases e salas prontas | Construir > Bases / salas prontas | Escolha modelo, dono e salas de 3, 5 ou 7 blocos. Clique pelo canto superior esquerdo e confirme a previa. A base inclui coracao, portal, tesouro, dormitorio, galinheiro, treinamento e quatro imps. |
| Copiar e transformar | Construir > Copiar area | Clique nos dois cantos. Em Colar / transformar, escolha giro de 90/180/270 graus, espelhamento, dono e substituicao. Clique no destino e confirme. |
| Historico | Mapa > Historico | Versoes por horario e origem, recuperacao automatica a cada dois minutos de trabalho nao salvo e copias antes de carimbos/missoes. Criar versao de recuperacao guarda uma versao manual. |
| Validacao visual | Mapa > Verificar | Lista problemas e marca suas posicoes. Clique na lista para centralizar o mapa; reveja a analise depois de editar. |
| Missao encadeada | Mapa > Assistente de missao encadeada | Explorar uma area, enfrentar herois, receber cura ou aliados e destruir o coracao inimigo, com previa do DKScript e um flag livre. |
| Biblioteca e campanhas | Mapa > Biblioteca / campanhas | Miniaturas do terreno salvo, busca, nome/descricao locais, Abrir, Jogar e sequencia de campanha KeeperFX. |

**Construcao e copia:** o destino e protegido por padrao. A substituicao de
terreno precisa ser autorizada na janela de colagem e sempre exige confirmacao
no mapa. Coracoes, areas de evento e portais de herois existentes nunca sao
apagados pela colagem. Uma base inteira pode ser copiada para um jogador sem
coracao; coracoes e portais devem estar inteiramente na selecao. Criaturas
mantem nivel, nome, ouro, saude e orientacao; as copias recebem novos indices.
Itens, portas e luzes manuais acompanham a area, e a decoracao e regenerada
pelo terreno. Pontos de evento, portais de herois e caixas especiais
personalizadas nao sao copiados, para nao duplicar numeros usados no script.
Geometria personalizada exige as ferramentas
avancadas: o carimbo trabalha com tipos de terreno padrao, nao com edicoes
individuais de colunas. **Esc** ou **Cancelar ferramenta** cancela a operacao.
Um Ctrl+Z desfaz o carimbo inteiro, incluindo as regras iniciais adicionadas
para o novo dono, sem deixar uma base pela metade.

**Recuperacao:** os conjuntos em `Historico` incluem terreno, elementos,
scripts e configuracoes/texturas locais, com manifesto e verificacao de
conteudo. Nao chamam o salvamento normal, nao limpam a marca de trabalho
pendente e nunca sincronizam com o jogo. Recuperar cria outra pasta em `Mapas`,
sem herdar um destino de substituicao. A versao atual nao salva tambem recebe
uma copia antes da recuperacao. O Studio conserva as ultimas 30 versoes
automaticas/salvas por mapa; versoes manuais nao expiram. Versoes alteradas
externamente nao sao apagadas pela limpeza automatica. A janela mostra os
horarios do ultimo salvamento local e do ultimo envio ao KeeperFX.

**Validacao:** inclui criaturas em terreno solido, portais pequenos ou sem
saida, bases sem caminho pronto ate um portal, numeros de area duplicados,
referencias a areas removidas e objetivos de destruir jogadores sem coracao.
Conectividade considera o terreno atual, sem escavacao, voo ou travessia de
agua/lava: isolamento e um aviso para revisao, nao uma prova de missao impossivel.
Scripts podem criar novas estruturas durante a partida; a analise nao executa
nem demonstra que todo objetivo manual e alcancavel.

**Missoes:** uma cadeia gerenciada por mapa, para o humano Vermelho. A segunda
etapa espera `PLAYER_GOOD` ficar sem criaturas; por isso, o assistente recusa
outros herois no terreno ou surgimentos de herois em outros eventos. Reaplicar
atualiza o bloco, sem duplicar regras. O assistente preserva flags e regras
manuais, recusa Lua e nao remove uma vitoria manual desconhecida.

**Biblioteca:** indexa ate 1.000 mapas locais, em ate cinco niveis de subpastas.
Nome e descricao organizam somente o catalogo; nao alteram arquivos comerciais
ou o texto da missao. Miniaturas sao geradas de SLB descomprimido. **Jogar**
instala uma nova copia da versao salva no disco, sem trocar o mapa aberto,
o vinculo de sincronizacao ou uma fase original.

**Campanhas:** adicione mapas KeeperFX pela biblioteca e abra Organizar /
exportar campanha. Subir/Descer muda a ordem; Proxima fase define tambem o
destino normal da caixa Transferir criatura. A caixa ainda precisa ser colocada
no mapa e ativada pelo jogador; o editor nao transfere criaturas sozinho.
Sao aceitas de 1 a 32 fases, sem ciclos ou fases inacessiveis na sequencia.
A exportacao em `Campanhas` usa novas copias e `SET_NEXT_LEVEL`, sem mudar os
scripts fonte. A instalacao opcional registra uma NOVA campanha no KeeperFX.
Inicie-a pela selecao de campanhas do jogo, nao por uma partida salva antiga.
Usa os recursos de tela/creditos da campanha original ja instalados em
`campgns\keeporig_lnd`, sem copia-los para o pacote. Mapas Gold precisam ser
convertidos e salvos como outra copia KeeperFX para compor uma campanha;
continuam jogaveis individualmente no Gold. Lua e progressao manual por
`SET_NEXT_LEVEL` exigem as ferramentas avancadas.

`Historico`, `Biblioteca` e `Campanhas` sao privados, ignorados pelo Git e
excluidos do executavel. Uma campanha contendo mapas importados continua
sujeita aos direitos desses mapas: a exportacao local nao autoriza publica-los.

## Interface visual e ferramentas rapidas

A barra fixa oferece Pintar, Selecionar, Colar, Inspecao, Base, Girar,
Espelhar e Cancelar. O texto abaixo identifica a ferramenta ativa. Durante
uma previa de base/colagem, **R** gira 90 graus e **F** espelha; os atalhos
nao atuam durante digitacao nem com um formulario aberto.

O carimbo fantasma mostra terreno e elementos sem alterar o mapa. A borda
verde indica colocacao permitida; vermelho indica impedimento, e os blocos
de destino protegidos recebem uma cruz vermelha. Um impedimento global
(por exemplo, dono que ja tem coracao) aparece no texto da previa.
Geometria final e decoracao continuam sendo geradas ao confirmar.
A selecao destaca o contorno, escurece o exterior e mostra dimensoes,
quantidade de criaturas e itens. O texto da previa mantem tamanho legivel
ao aproximar ou afastar o mapa.

**Camadas visuais** permite ocultar criaturas, itens/armadilhas/portas,
donos do terreno, areas de evento e marcadores de validacao. Isso e somente
visual: nao remove nem muda elementos salvos, e nao desliga sua selecao
nas ferramentas nativas. Reative a camada antes de editar elementos ocultos.
As escolhas valem para a sessao; o modo avancado restaura a visualizacao
nativa. Novos elementos respeitam as camadas ocultas.

O indicador fixo distingue **Alteracoes pendentes**, **Salvo localmente**
e **Enviado ao jogo**, com horario e numero da fase quando confirmado.
Uma nova gravacao local invalida o estado de envio anterior ate a
sincronizacao terminar. Ao abrir outro mapa ou reiniciar o editor, um
envio antigo nao e tratado como confirmacao atual. O Historico continua
exibindo os ultimos horarios registrados.

A biblioteca usa cartoes com miniatura, perfil Gold/KeeperFX e botoes
Abrir/Jogar, em paginas de ate 12 mapas. Clique no nome para editar os
metadados. Busca sem resultados limpa a selecao anterior. Criaturas do
catalogo classico aparecem em portugues; o nome tecnico continua na dica.
Icones usam os recursos locais ja carregados, sem distribuir os assets do jogo.
Formularios usam fonte uniforme, rolagem para conteudo extenso e espaco
reservado ao menu superior. Notificacoes rapidas nao se empilham no modo
simples nem cobrem formularios; erros continuam em janelas explicitas.

Os testes integrados `--studio-test` cobrem Gold e KeeperFX, incluindo
transformacoes, salvamento/sincronizacao, recuperacao, missoes/campanhas,
camadas, atalhos, estados do indicador, paginacao e janelas 1280 x 720 e
1024 x 768. Execute somente em uma copia isolada do projeto, pois geram
mapas de teste e usam configuracoes locais.

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
