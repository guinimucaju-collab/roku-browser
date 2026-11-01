# Roku Browser — Cliente (SceneGraph / BrightScript)

Canal Roku que consome o JSON gerado pelo servidor de tradução (`roku-browser-server`) e renderiza os elementos na tela usando SceneGraph (`Rectangle` para caixas, `Label` para texto, `Poster` para imagens).

---

## 📁 Estrutura do projeto

```
roku-browser/
├── manifest                 # Metadados do canal (obrigatório na raiz do zip)
├── README.md
├── components/
│   ├── MainScene.brs        # Lógica da cena principal
│   ├── MainScene.xml        # Definição XML da cena (MainScene)
│   ├── TranslateTask.brs    # Task assíncrona que busca e parseia o JSON
│   └── TranslateTask.xml    # Definição XML da task
├── source/
│   ├── main.brs             # Ponto de entrada (sub Main)
│   └── utils.brs            # Utilitários: cor, montagem de nós, scroll
└── images/                  # Recursos visuais (obrigatórios pelo Roku)
    ├── icon_focus_hd.png    # Ícone em foco (768x432)
    ├── icon_side_hd.png     # Ícone lateral (230x162)
    └── splash_hd.png        # Tela de carregamento (1280x720)
```

---

## 📋 Pré-requisitos

- Um Roku com modo desenvolvedor ativado
- O servidor de tradução (`roku-browser-server`) rodando e acessível via HTTPS
- O arquivo `.zip` gerado a partir desta pasta (veja abaixo)

### 1. Configure a URL do servidor

Edite `components/MainScene.brs` e substitua pela URL real do seu deploy:

```brightscript
m.serverBase = "https://SEU-DEPLOY.vercel.app/api/translate"
```

Não inclua barra no final da URL.

### 2. (Opcional) Página de teste padrão

Em `MainScene.init()`, você pode definir a URL inicial:

```brightscript
if m.top.pageUrl = invalid or m.top.pageUrl = ""
    m.top.pageUrl = "https://exemplo.com"
end if
```

---

## 🎮 Controles do controle remoto

| Tecla | Ação |
|-------|------|
| `Replay` / `Enter` / `Play` | Executa a ação do elemento em foco (botão/link) ou recarrega a página |
| `Up` / `Down` | Navega entre elementos focáveis (botões/links) **ou** rolagem manual se não houver elementos focáveis |
| `Back` | Volta à página anterior no histórico; se não houver, sai do canal |
| `Home` | Volta à tela inicial do Roku |

---

## 🚀 Como instalar no Roku (sideload)

1. **Ative o modo desenvolvedor** no Roku: no controle, pressione `Home` 3×, `Up` 2×, `Rewind`, `Fast Forward`, `Rewind`, `Fast Forward`, `Rewind` (o "Konami code" da Roku; pode variar ligeiramente por modelo).
2. Anote o **IP** do aparelho e defina usuário/senha do instalador de desenvolvedor.
3. No navegador, acesse `http://IP-DO-ROKU`, faça login e suba o arquivo `.zip`.

### Sobre o .zip

O arquivo `.zip` deve conter **o conteúdo desta pasta**, com o `manifest` na raiz do zip (não dentro de uma subpasta). O Roku exige que o `manifest` fique na raiz para reconhecer o canal.

Para gerar o zip manualmente (exemplo no terminal, dentro da pasta do projeto):

```bash
# PowerShell (Windows)
Compress-Archive -Path manifest, components, source, images -DestinationPath ../roku-browser.zip

# Linux / macOS / Git Bash
zip -r ../roku-browser.zip manifest components source images
```

Suba o arquivo `roku-browser.zip` gerado no instalador de desenvolvedor do Roku (`http://IP-DO-ROKU`).

> **Importante:** não inclua a pasta `.git` nem arquivos temporários no zip. Apenas `manifest`, `components`, `source`, `images` e `README.md`.

### Ver logs do Roku

Durante o desenvolvimento, você pode acompanhar os logs do canal diretamente no aparelho:

1. No modo desenvolvedor, acesse `http://IP-DO-ROKU/plugin_console`
2. Ou use o comando `telnet` (ou um cliente SSH) na porta 8080 do IP do Roku para ver `print()` em tempo real

Os `print()` no código BrightScript (ex: em `TranslateTask.brs`) aparecem nesse console.

---

## 📦 Formato esperado do JSON

O servidor deve retornar um objeto com a chave `root`, contendo a árvore de nós:

```json
{
  "root": {
    "type": "box",
    "x": 0,
    "y": 0,
    "width": 1280,
    "height": 720,
    "style": { "backgroundColor": "#000000FF" },
    "children": [
      {
        "type": "text",
        "x": 100,
        "y": 100,
        "width": 500,
        "height": 40,
        "style": {
          "content": "Olá, Roku!",
          "color": "#FFFFFFFF",
          "fontSize": 24,
          "textAlign": "left"
        }
      },
      {
        "type": "image",
        "x": 100,
        "y": 200,
        "width": 200,
        "height": 150,
        "style": { "src": "https://exemplo.com/imagem.png" }
      }
    ]
  }
}
```

- As coordenadas `x`/`y` já devem vir **absolutas** (calculadas pelo servidor).
- Cores usam formato `#RRGGBBAA` e são convertidas internamente para `0xRRGGBBAA`.
- Tipos de nó suportados: `box`, `text`, `image`, `button`, `link`.

### Propriedades opcionais de estilo

| Propriedade | Aplica-se | Descrição |
|-------------|-----------|-----------|
| `borderColor` | `box`, `text`, `image`, `button` | Cor da borda em `#RRGGBBAA` |
| `borderWidth` | `box`, `text`, `image`, `button` | Largura da borda em pixels |
| `focusable` | qualquer nó | Marca o nó como navegável com Up/Down (`true`) |
| `vertAlign` | `text` | Alinhamento vertical (`top`, `center`, `bottom`) |

### Propriedade de ação

| Propriedade | Aplica-se | Descrição |
|-------------|-----------|-----------|
| `actionUrl` | `button`, `link`, ou qualquer nó com `focusable=true` | URL para navegar ao pressionar Enter/Replay |

### Exemplo com botão clicável

```json
{
  "root": {
    "type": "box",
    "x": 0,
    "y": 0,
    "width": 1280,
    "height": 720,
    "style": { "backgroundColor": "#000000FF" },
    "children": [
      {
        "type": "button",
        "x": 100,
        "y": 100,
        "width": 400,
        "height": 60,
        "label": "Abrir outra página",
        "actionUrl": "https://outra-pagina.com",
        "style": {
          "backgroundColor": "#0066CCFF",
          "color": "#FFFFFFFF",
          "fontSize": 20,
          "borderColor": "#00AAFFFF",
          "borderWidth": 2,
          "focusable": true
        }
      },
      {
        "type": "text",
        "x": 100,
        "y": 200,
        "width": 500,
        "height": 40,
        "style": {
          "content": "Conteúdo traduzido aqui...",
          "color": "#FFFFFFFF",
          "fontSize": 24
        }
      }
    ]
  }
}
```

Quando um elemento com `focusable=true` ou tipo `button`/`link` está em foco (destaque com borda cian), pressione **Enter/Replay** para navegar para a `actionUrl`.

---

## ✨ Melhorias nesta versão

- Ícones e splash screen em `images/` (obrigatórios para aparecer na tela inicial do Roku)
- Indicador de carregamento ("Carregando...") durante a requisição
- Mensagem de status/erro na parte inferior da tela
- **Elementos interativos**: tipos `button` e `link` com `actionUrl` para navegar entre páginas
- **Sistema de foco visual**: destaque com borda cian no elemento selecionado; navegue com Up/Down
- **Histórico de navegação**: o Back volta à página anterior visitada (pilha de até 10 URLs)
- **Retry automático**: até 2 tentativas em caso de falha de rede antes de exibir erro
- Timeout de rede de 30s no `TranslateTask` (evita travar o canal)
- **Scroll limitado**: não permite que o conteúdo saia completamente da tela
- Validação de estrutura JSON (exige chave `root`) e de campos opcionais (vertAlign, bordas, foco)
- Limpeza correta do conteúdo anterior ao carregar nova URL
- Tratamento de erro na criação da tela (`main.brs`)
- Cache da última URL carregada

---

## ⚠️ Limitações restantes

- Não roda JavaScript nem interpreta CSS (é SceneGraph/BrightScript, não navegador web)
- Scroll é manual (Up/Down no controle), não automático por toque
- Fonte é sempre a padrão do sistema Roku
- Histórico de navegação é perdido ao fechar e reabrir o canal
- Não há suporte a toque (Roku é controlado apenas por remote)

---

## 🛠️ Próximos passos

1. Testar contra o servidor real já deployado
2. Adicionar scroll automático suave
3. Fase 3: mapear eventos JS simples (onclick) para navegação/entrada do remote

---

## 🔧 Troubleshooting

| Problema | Provável causa / solução |
|----------|--------------------------|
| Canal não aparece na tela inicial | Confira se `images/` está no zip com os 3 PNGs exigidos pelo `manifest` |
| Canal fecha ao abrir | Verifique se a URL do servidor está correta e acessível |
| Tela fica branca / nada aparece | O servidor pode estar retornando JSON inválido ou fora do formato esperado |
| Erro de rede na tela | Confira se o Roku consegue alcançar a URL do servidor (firewall, HTTPS, etc.) |
| Konami code não ativa o modo dev | A sequência pode variar por modelo de Roku. Tente: Home 5×, Rewind 3×, Fast Forward 2× |
| Erro de certificado SSL | O servidor deve usar HTTPS com certificado válido. O Roku não aceita certificados self-signed sem configuração extra |
| Conteúdo não aparece mas sem erro | Verifique se o JSON do servidor tem a chave `root` e se as coordenadas `x`/`y` estão dentro da tela (1280×720) |
| Retry não funciona | O retry só ocorre em falha de rede/timeouts, não em JSON inválido (esse falha imediatamente) |
| Foco não move entre elementos | Verifique se os nós têm `focusable: true` no estilo ou são do tipo `button`/`link` |
| Enter não navega para outra página | Verifique se o elemento focado tem a propriedade `actionUrl` definida no JSON |
