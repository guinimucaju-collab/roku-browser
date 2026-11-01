import cheerio from 'cheerio';

// ============================================================================
// CONFIGURAÇÃO E CONSTANTES
// ============================================================================

const MAX_URL_LENGTH = 2048;
const REQUEST_TIMEOUT = 8000; // ms
const MAX_CONTENT_LENGTH = 5 * 1024 * 1024; // 5 MB
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutos

// Padrões de URL interna/privada para prevenir SSRF
const PRIVATE_IP_PATTERNS = [
  /^localhost$/i,
  /^127\./i,
  /^10\./i,
  /^172\.(1[6-9]|2[0-9]|3[01])\./i,
  /^192\.168\./i,
  /^0\.0\.0\.0$/i,
  /^::1$/i,
  /^::ffff:127\./i,
  /^::ffff:10\./i,
  /^::ffff:172\.(1[6-9]|2[0-9]|3[01])\./i,
  /^::ffff:192\.168\./i
];

// Cache simples em memória (key: url, value: { data, timestamp })
const cache = new Map();

// ============================================================================
// UTILITÁRIOS DE SEGURANÇA
// ============================================================================

function isValidUrl(url) {
  try {
    const parsed = new URL(url);
    if (!parsed.protocol || !['http:', 'https:'].includes(parsed.protocol)) {
      return false;
    }
    if (url.length > MAX_URL_LENGTH) {
      return false;
    }
    // Prevenir SSRF
    for (const pattern of PRIVATE_IP_PATTERNS) {
      if (pattern.test(parsed.hostname)) {
        return false;
      }
    }
    return true;
  } catch {
    return false;
  }
}

function getCacheKey(url) {
  return url;
}

function getFromCache(key) {
  const entry = cache.get(key);
  if (!entry) return null;
  if (Date.now() - entry.timestamp > CACHE_TTL_MS) {
    cache.delete(key);
    return null;
  }
  return entry.data;
}

function setCache(key, data) {
  cache.set(key, { data, timestamp: Date.now() });
  // Limite simples de cache: se exceder 100 entradas, remove as mais antigas
  if (cache.size > 100) {
    const firstKey = cache.keys().next().value;
    cache.delete(firstKey);
  }
}

// ============================================================================
// CONVERSÃO DE COR
// ============================================================================

function cssColorToRoku(color) {
  if (!color) return '0xFFFFFFFF';
  // Já está no formato hex do Roku (#RRGGBBAA ou #RRGGBB)
  if (color.startsWith('#')) {
    const hex = color.replace('#', '');
    if (hex.length === 8) {
      return '0x' + hex;
    }
    if (hex.length === 6) {
      return '0x' + hex + 'FF';
    }
  }
  // Cores nomeadas básicas
  const namedColors = {
    'black': '0x000000FF',
    'white': '0xFFFFFFFF',
    'red': '0xFF0000FF',
    'green': '0x00FF00FF',
    'blue': '0x0000FFFF',
    'yellow': '0xFFFF00FF',
    'cyan': '0x00FFFFFF',
    'magenta': '0xFF00FFFF',
    'gray': '0x808080FF',
    'grey': '0x808080FF',
    'orange': '0xFFA500FF',
    'purple': '0x800080FF',
    'transparent': '0x00000000'
  };
  const lower = color.toLowerCase().trim();
  if (namedColors[lower]) return namedColors[lower];
  return '0xFFFFFFFF';
}

// ============================================================================
// LAYOUT AUTOMÁTICO
// ============================================================================

const SCREEN_WIDTH = 1280;
const SCREEN_HEIGHT = 720;
const MARGIN = 40;
const CONTENT_WIDTH = SCREEN_WIDTH - MARGIN * 2;

class LayoutCursor {
  constructor() {
    this.y = 60; // começar abaixo do topo
    this.maxY = 0;
  }

  next(h, gap = 20) {
    const y = this.y;
    this.y = y + h + gap;
    this.maxY = Math.max(this.maxY, this.y);
    return y;
  }

  fits(h) {
    return this.y + h <= SCREEN_HEIGHT - 60;
  }
}

// ============================================================================
// PARSE DE HTML PARA JSON SCENEGRAPH
// ============================================================================

function htmlParaRoku(html, baseUrl) {
  const $ = cheerio.load(html);
  const nodes = [];
  const layout = new LayoutCursor();

  // Título da página
  const title = $('title').first().text().trim() || 'Página';
  if (title) {
    nodes.push({
      type: 'text',
      x: MARGIN,
      y: layout.next(60),
      width: CONTENT_WIDTH,
      height: 60,
      style: {
        content: title,
        color: '#FFFFFFFF',
        fontSize: 36,
        textAlign: 'left',
        fontWeight: 'bold'
      }
    });
  }

  // Meta description (como subtítulo)
  const description = $('meta[name="description"]').attr('content') ||
                      $('meta[property="og:description"]').attr('content') || '';
  if (description) {
    nodes.push({
      type: 'text',
      x: MARGIN,
      y: layout.next(40),
      width: CONTENT_WIDTH,
      height: 40,
      style: {
        content: description,
        color: '#AAAAAAFF',
        fontSize: 18,
        textAlign: 'left'
      }
    });
  }

  // Imagem principal (og:image ou primeira img)
  const ogImage = $('meta[property="og:image"]').attr('content');
  let mainImageUrl = null;
  if (ogImage) {
    mainImageUrl = new URL(ogImage, baseUrl).href;
  } else {
    const firstImg = $('img').first().attr('src');
    if (firstImg) {
      mainImageUrl = new URL(firstImg, baseUrl).href;
    }
  }

  if (mainImageUrl) {
    const imgHeight = 240;
    if (layout.fits(imgHeight)) {
      nodes.push({
        type: 'image',
        x: MARGIN,
        y: layout.next(imgHeight),
        width: CONTENT_WIDTH,
        height: imgHeight,
        style: {
          src: mainImageUrl,
          borderColor: '#333333FF',
          borderWidth: 1
        }
      });
    }
  }

  // Texto do corpo (parágrafos e headings)
  const textSelectors = ['h1', 'h2', 'h3', 'h4', 'p', 'li'];
  let textCount = 0;

  $(textSelectors.join(',')).each((i, el) => {
    const $el = $(el);
    const text = $el.text().trim();
    if (!text || text.length < 3) return;
    if (textCount >= 15) return; // limitar quantidade de nós

    const tag = el.tagName.toLowerCase();
    let fontSize = 20;
    let color = '#E0E0E0FF';
    let height = 40;
    let weight = 'normal';

    if (tag === 'h1') { fontSize = 28; color = '#FFFFFFFF'; height = 50; weight = 'bold'; }
    else if (tag === 'h2') { fontSize = 24; color = '#FFFFFFFF'; height = 45; weight = 'bold'; }
    else if (tag === 'h3') { fontSize = 22; color = '#FFFFFFFF'; height = 42; weight = 'bold'; }
    else if (tag === 'h4') { fontSize = 20; color = '#FFFFFFFF'; height = 40; weight = 'bold'; }
    else if (tag === 'li') { fontSize = 18; color = '#D0D0D0FF'; height = 36; }

    // Evitar duplicar o título já adicionado
    if (tag === 'h1' && text === title) return;

    if (!layout.fits(height)) return;

    nodes.push({
      type: 'text',
      x: MARGIN,
      y: layout.next(height, 12),
      width: CONTENT_WIDTH,
      height: height,
      style: {
        content: text.substring(0, 200), // truncar se muito longo
        color: color,
        fontSize: fontSize,
        textAlign: 'left',
        fontWeight: weight
      }
    });

    textCount++;
  });

  // Links encontrados (como botões focáveis)
  let linkCount = 0;
  $('a[href]').each((i, el) => {
    if (linkCount >= 6) return;
    const $el = $(el);
    const href = $el.attr('href');
    const text = $el.text().trim();
    if (!text || text.length < 2) return;

    try {
      const linkUrl = new URL(href, baseUrl).href;
      if (!isValidUrl(linkUrl)) return;

      if (!layout.fits(50)) return;

      nodes.push({
        type: 'button',
        x: MARGIN,
        y: layout.next(50, 16),
        width: Math.min(400, CONTENT_WIDTH),
        height: 50,
        label: text.substring(0, 30),
        actionUrl: linkUrl,
        style: {
          backgroundColor: '#0066CCFF',
          color: '#FFFFFFFF',
          fontSize: 18,
          borderColor: '#00AAFFFF',
          borderWidth: 2,
          focusable: true
        }
      });

      linkCount++;
    } catch {
      // ignorar links inválidos
    }
  });

  // Se não encontrou conteúdo significativo, mostra aviso
  if (nodes.length === 0) {
    nodes.push({
      type: 'text',
      x: MARGIN,
      y: 100,
      width: CONTENT_WIDTH,
      height: 60,
      style: {
        content: 'Não foi possível extrair conteúdo desta página.',
        color: '#FFFF00FF',
        fontSize: 24,
        textAlign: 'left'
      }
    });
  }

  // Rodapé com info da fonte
  nodes.push({
    type: 'text',
    x: MARGIN,
    y: Math.min(layout.y, SCREEN_HEIGHT - 40),
    width: CONTENT_WIDTH,
    height: 30,
    style: {
      content: 'Fonte: ' + new URL(baseUrl).hostname,
      color: '#666666FF',
      fontSize: 14,
      textAlign: 'right'
    }
  });

  return {
    root: {
      type: 'box',
      x: 0,
      y: 0,
      width: SCREEN_WIDTH,
      height: SCREEN_HEIGHT,
      style: { backgroundColor: '#000000FF' },
      children: nodes
    },
    meta: {
      title: title,
      url: baseUrl,
      nodeCount: nodes.length
    }
  };
}

// ============================================================================
// HANDLER PRINCIPAL
// ============================================================================

export default async function handler(req, res) {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const { url } = req.query;

  if (!url || typeof url !== 'string') {
    res.status(400).json({ error: 'Parâmetro "url" é obrigatório' });
    return;
  }

  if (!isValidUrl(url)) {
    res.status(400).json({ error: 'URL inválida ou não permitida' });
    return;
  }

  // Verificar cache
  const cacheKey = getCacheKey(url);
  const cached = getFromCache(cacheKey);
  if (cached) {
    res.status(200).json(cached);
    return;
  }

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT);

    const response = await fetch(url, {
      signal: controller.signal,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; RokuBrowser/2.0; +https://roku-browser.example)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8'
      },
      redirect: 'follow'
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      res.status(response.status).json({
        error: `Erro ao buscar a página: HTTP ${response.status}`
      });
      return;
    }

    const contentType = response.headers.get('content-type') || '';
    if (!contentType.includes('text/html') && !contentType.includes('application/xhtml')) {
      res.status(400).json({ error: 'Conteúdo não é HTML' });
      return;
    }

    const html = await response.text();

    if (html.length === 0) {
      res.status(400).json({ error: 'Página vazia' });
      return;
    }

    const json = htmlParaRoku(html, url);

    // Salvar no cache
    setCache(cacheKey, json);

    res.status(200).json(json);
  } catch (err) {
    console.error('[roku-browser-server] Erro:', err.message);

    if (err.name === 'AbortError') {
      res.status(504).json({ error: 'Tempo esgotado ao buscar a página' });
      return;
    }

    if (err.code === 'ENOTFOUND' || err.code === 'ECONNREFUSED') {
      res.status(502).json({ error: 'Não foi possível conectar ao site' });
      return;
    }

    res.status(500).json({ error: 'Erro interno do servidor' });
  }
}
