# Roku Browser Server v2

Servidor robusto para o Roku Browser. Recebe uma URL, busca a página HTML, extrai conteúdo e retorna JSON no formato SceneGraph que o cliente Roku renderiza.

## Arquivos

```
roku-server/
├── api/
│   ├── translate.js      # Função principal (Vercel Serverless)
│   └── health.js         # Health check
├── package.json
├── vercel.json
└── README.md
```

## Deploy no Vercel

### Via GitHub

1. Crie um repositório no GitHub
2. Envie esta pasta (`roku-server/`) para o repositório
3. Acesse [vercel.com](https://vercel.com)
4. "Add New Project" → importe seu repositório
5. Defina o **Root Directory** como `roku-server` (se o repo contiver mais pastas)
6. Clique em "Deploy"

### Via CLI

```bash
npm i -g vercel
cd roku-server
vercel login
vercel
```

## Endpoints

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/api/health` | GET | Verifica se o servidor está online |
| `/api/translate?url=...` | GET | Converte uma página web em JSON SceneGraph |

### Exemplo de uso

```
https://SEU-PROJETO.vercel.app/api/translate?url=https://exemplo.com
```

## Configurar no cliente Roku

Edite `components/MainScene.brs` no cliente Roku:

```brightscript
m.serverBase = "https://SEU-PROJETO.vercel.app/api/translate"
```

Depois rezip o cliente e instale no Roku via sideload.

## Recursos

- ✅ Parser HTML real (cheerio) em vez de regex
- ✅ Layout automático (não exige coordenadas do servidor)
- ✅ Proteção contra SSRF (URLs privadas bloqueadas)
- ✅ Rate limiting implícito via cache e timeouts
- ✅ Cache em memória (5 min TTL)
- ✅ Timeout de requisição (8s)
- ✅ Health check endpoint
- ✅ CORS habilitado
- ✅ Botões focáveis para links da página
- ✅ Metadados na resposta (título, URL, contagem de nós)

## Limitações

- Não executa JavaScript da página alvo (apenas HTML estático)
- Cache em memória (perdido em cold starts do Vercel)
- Máximo de ~15 nós de texto e 6 botões por página
