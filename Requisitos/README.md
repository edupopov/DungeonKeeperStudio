# Requisitos e aplicativos

Este kit atende a distribuicao **Windows x64** do Dungeon Keeper Studio.
O editor nao inclui o jogo comercial nem os dados originais de Dungeon Keeper.

## O que e necessario

| Componente | Para que serve | Obrigatorio? |
| --- | --- | --- |
| Windows 10/11 de 64 bits | Ambiente recomendado para o executavel distribuido e scripts | Sim, para este kit |
| GPU e driver com OpenGL 3.3 | Renderer GLES3 padrao do Godot usado pelo projeto | Sim; atualize o driver pelo fabricante |
| Copia legal de Dungeon Keeper Gold, com os arquivos de dados instalados | Terrenos, texturas, sprites e execucao no jogo original | Os dados do jogo sao necessarios para a experiencia completa; nao basta copiar um `.exe` |
| `DungeonKeeperStudio.exe` e `DungeonKeeperStudio.pck` da mesma compilacao | Executar a versao pronta | Sim; mantenha os dois juntos |
| KeeperFX corretamente instalado | Jogar mapas KeeperFX, sincronizar e usar campanhas encadeadas | Somente para essas funcionalidades; a linha 1.4.0 foi usada na validacao |
| Godot **3.6.3 Standard**, sem .NET/Mono | Abrir o projeto-fonte, importar recursos e gerar EXE/PCK | Somente para desenvolvimento/compilacao; o EXE pronto ja contem o runtime |
| Windows PowerShell 5.1 ou PowerShell 7 | Baixar o kit, compilar e consultar a versao do jogo no Windows | Os scripts de preparacao exigem 5.1 ou superior; 5.1 normalmente acompanha o Windows |
| 7-Zip | Extrair o pacote `.7z` do KeeperFX | Utilitario opcional; outro extrator compativel tambem serve |
| Git | Clonar e atualizar o codigo do GitHub | Opcional; tambem e possivel baixar o ZIP do repositorio |

**Nao sao requisitos do editor:** Python, Node.js, Java, Visual Studio,
SDK .NET, Docker, Supabase ou navegador. Nao instale pacotes de DLLs de
sites desconhecidos. Dependencias do Launcher ou do jogo devem ser tratadas
conforme as instrucoes oficiais desses aplicativos.

Godot 4 **nao e compativel** com este projeto. Nao use a edicao Godot .NET/Mono.
O motor suporta outras plataformas, mas este kit e os scripts foram preparados
para Windows x64; nao ha garantia de validacao do Studio em Linux/macOS.

## Hardware e pastas

- Interface conferida em 1024 x 768 e 1280 x 720; 1280 x 720 ou maior e
  recomendavel. Mouse com roda e teclado facilitam pintura, zoom e atalhos.
- Como orientacao pratica, recomendamos 4 GB de RAM ou mais. Isto nao e
  um minimo medido nem uma garantia de desempenho para mapas grandes.
- Reserve algumas centenas de MB para codigo, Godot e pacotes; jogo,
  KeeperFX, importacoes e historico exigem espaco adicional. O consumo do
  historico depende do numero e tamanho dos mapas.
- Use uma pasta em que voce possa gravar, por exemplo uma pasta de projetos
  no seu perfil. Nao coloque o editor em `Program Files` nem execute como
  administrador apenas para contornar permissoes.
- Para sincronizar, o usuario tambem precisa poder gravar na pasta do
  KeeperFX. Backups verificados sao gravados em `Backups-Jogo`.

## Conteudo desta pasta

| Arquivo/pasta | Conteudo |
| --- | --- |
| `Baixar-Aplicativos.ps1` | Baixa versoes fixadas de fontes oficiais, confere SHA-256 e extrai o Godot sem instalar nada |
| `Aplicativos\Godot_v3.6.3-stable_win64.exe.zip` | Arquivo oficial completo do Godot |
| `Aplicativos\Godot-3.6.3\` | Godot portatil, acompanhado dos avisos de licenca |
| `Aplicativos\7z2605-x64.exe` | Instalador oficial do 7-Zip; execute manualmente somente se necessario |
| `Aplicativos\keeperfx-web-installer-0c014ed3.exe` | Instalador web oficial do KeeperFX; exige internet e uma copia legal dos dados originais |
| `KeeperFX-oficial.url` | Abre o site oficial para baixar e instalar KeeperFX |
| `Dungeon-Keeper-Gold-GOG.url` | Opcao legal de aquisicao do jogo; uma copia existente tambem serve |

`Aplicativos` e preenchida localmente pelo script e **nao fica no Git**.
O GitHub guarda instrucoes, atalhos e o script reproduzivel, nao instaladores
nem dados comerciais. O kit nao altera uma instalacao de KeeperFX existente.

## Preparar a partir de um clone novo

Abra PowerShell na raiz do DungeonKeeperStudio:

```powershell
.\Requisitos\Baixar-Aplicativos.ps1
```

Se a politica do computador bloquear scripts e voce tiver permissao para
executar este script revisado, use uma excecao apenas nesse processo:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Requisitos\Baixar-Aplicativos.ps1"
```

Nao mude permanentemente a politica de seguranca nem contorne regras de
uma organizacao. O download do kit e o instalador web do KeeperFX exigem
internet; o editor e o Godot portatil funcionam localmente apos a preparacao.
Para baixar apenas o Godot, acrescente `-SomenteGodot`.

O script recusa arquivos existentes com hash diferente e preserva downloads
ou extracoes incompletas para revisao. Nao executa os aplicativos baixados,
nao instala o 7-Zip/KeeperFX e nao copia arquivos sobre `Runtime` ou sobre o jogo.
Uma segunda execucao verifica e reutiliza os arquivos ja baixados.

## Instalar e configurar o jogo

1. Instale sua copia legal do Gold e confira que os dados foram instalados.
   No perfil Gold, escolha o executavel do jogo, como `keeper95.exe`.
2. Para uma instalacao nova do KeeperFX, execute manualmente o instalador
   web da pasta `Aplicativos`, em Windows 10/11 x64, e siga as
   [instrucoes oficiais](https://keeperfx.net/wiki/Home). Escolha uma pasta
   separada. Como alternativa, abra `KeeperFX-oficial.url`, baixe a versao
   completa estavel e extraia com 7-Zip. **Um alpha patch nao e uma
   instalacao completa**. Nao atualize o jogo em uso apenas para abrir o editor.
3. Configure/importe os arquivos originais pelo procedimento do KeeperFX.
   O site oficial informa que o jogo original e necessario. Teste o
   KeeperFX sozinho antes de configurar o Studio.
4. No Studio, use **Mapa > Configurar jogos** e escolha `keeperfx.exe`,
   nao o Launcher. O Launcher pode ajudar na instalacao, mas nao e um
   requisito separado do editor.
5. Mantenha as pastas do jogo junto do executavel (`data`, `levels` e,
   no KeeperFX, `fxdata`/`campgns`, conforme a instalacao). Para campanhas
   Studio, mantenha os recursos originais de `campgns\keeporig_lnd`;
   a exportacao faz referencia a essas telas/creditos.
6. Salve uma copia em `Mapas`. Ative sincronizacao somente depois de conferir
   a fase vinculada. Reinicie a fase para carregar mudancas; uma partida
   salva antiga nao recarrega o mapa do disco.

## Rodar o fonte ou compilar

No Godot portatil, importe `project.godot` pela interface, aguarde a importacao
de recursos e execute o projeto com F5.
Para abrir diretamente o editor de projeto:

```powershell
& ".\Requisitos\Aplicativos\Godot-3.6.3\Godot_v3.6.3-stable_win64.exe" --editor --path .
```

Depois de importar os recursos, feche o Studio em execucao antes de compilar
para que o Windows permita substituir o executavel:

```powershell
.\Build-Studio.ps1 -GodotPath ".\Requisitos\Aplicativos\Godot-3.6.3\Godot_v3.6.3-stable_win64.exe"
```

O build gera `DungeonKeeperStudio.exe` e `DungeonKeeperStudio.pck`. Abra
`Abrir Editor.cmd` ou o EXE. O build usa `--export-pack` e copia o runtime:
nao exige baixar o grande pacote de export templates do Godot.
O clone do GitHub e um projeto-fonte, nao um EXE pronto.

## Licencas, procedencia e integridade

- Godot: [MIT e dependencias](https://godotengine.org/license/);
  avisos incluidos em `GODOT-LICENSE.txt` e `GODOT-COPYRIGHT.txt` na raiz
  e copiados para a pasta do Godot.
- 7-Zip: [licencas LGPL, BSD e restricao unRAR](https://www.7-zip.org/license.txt).
  A licenca MIT do Studio nao substitui a licenca do instalador.
- KeeperFX: [projeto oficial](https://github.com/dkfans/keeperfx).
  Seus termos e os direitos dos dados comerciais continuam aplicaveis.
- Driver de video: obtenha somente do fabricante; nao e redistribuido aqui.

Os hashes do Godot ZIP e 7-Zip foram conferidos nos metadados das releases
oficiais do GitHub. O hash do EXE Godot foi conferido apos extrair o ZIP.
O hash do instalador web foi calculado a partir do download HTTPS indicado
pelo site oficial; nao e uma assinatura digital nem um checksum publicado
independentemente pelo KeeperFX.

| Arquivo | SHA-256 |
| --- | --- |
| Godot 3.6.3 ZIP Windows x64 | `80616a2621025b508a5ed14a5066630fb6c0c384ecab87277bf33569e965eec3` |
| Godot 3.6.3 EXE extraido | `958aac5115c00a7e2fe560c1296d5d49d51c62e80b36f660d2b4ebb46a153179` |
| 7-Zip 26.05 instalador x64 | `fd99e86f57d8f429ef5ed045bf98315af962e2309b0f1ba87a147a44c71647d0` |
| KeeperFX web installer `0c014ed3` | `4d67259f14d2d9693a6342252c5cd9a546fd019be2d3f8b4907e67a3cbacc5a9` |

Fontes: [Godot 3.6.3](https://github.com/godotengine/godot-builds/releases/tag/3.6.3-stable),
[7-Zip 26.05](https://github.com/ip7z/7zip/releases/tag/26.05),
[plataformas do Godot 3.6](https://docs.godotengine.org/en/3.6/about/list_of_features.html).

## Problemas comuns

| Sintoma | Conferir |
| --- | --- |
| EXE nao abre ou erro de OpenGL | Windows x64, driver oficial e OpenGL 3.3; GPU/ambiente remoto podem nao oferecer aceleracao adequada |
| Texturas/sprites ausentes | Caminho do jogo e dados originais; copiar somente `keeperfx.exe` nao basta |
| Build falha | Godot 3.6.3 Standard, recursos importados, Studio fechado e permissao para gravar na raiz |
| Mapa salvo nao mudou no jogo | Indicador de envio, destino vinculado e reinicio da fase, sem carregar savegame antigo |
| Campanha Studio nao abre | KeeperFX completo, dados originais, `keeporig_lnd` e escolha da campanha no menu do jogo |
