// GENERATED from the web player's index.html. The whole page (HTML, CSS and
// JS) is served by WebUiServer; it has no external dependencies besides the
// poster images it loads from the metadata provider.
// ignore_for_file: lines_longer_than_80_chars

const String kWebUiHtml = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#0b0d12">
<link rel="icon" href="data:,">
<title>PlayTorrio</title>
<style>
:root{
  --bg:#0b0d12;--bg2:#12151e;--bg3:#1a1e2a;--line:rgba(255,255,255,.08);
  --ink:#f2f3f7;--muted:rgba(255,255,255,.66);--subtle:rgba(255,255,255,.42);
  --accent:#7c5cff;--accent2:#9d84ff;--good:#10b981;--warn:#f59e0b;--bad:#ef4444;
  --radius:12px;
}
*{box-sizing:border-box}
html,body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.45 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;-webkit-font-smoothing:antialiased}
a{color:inherit;text-decoration:none}
button{font:inherit;color:inherit;background:none;border:0;cursor:pointer}
img{display:block}
.hidden{display:none!important}

/* Header */
header{position:sticky;top:0;z-index:20;display:flex;align-items:center;gap:14px;padding:12px 24px;background:linear-gradient(#0b0d12 60%,rgba(11,13,18,.85));backdrop-filter:blur(8px)}
.logo{font-weight:800;font-size:20px;letter-spacing:-.3px;white-space:nowrap}
.logo span{color:var(--accent2)}
.search{flex:1;max-width:520px;margin-left:auto;position:relative}
.search input{width:100%;padding:10px 14px 10px 38px;border-radius:999px;border:1px solid var(--line);background:var(--bg2);color:var(--ink);font:inherit;outline:none}
.search input:focus{border-color:var(--accent)}
.search svg{position:absolute;left:12px;top:50%;transform:translateY(-50%);opacity:.6}
main{padding:8px 24px 60px}
.banner{margin:10px 0;padding:10px 14px;border-radius:10px;background:rgba(245,158,11,.12);border:1px solid rgba(245,158,11,.35);color:#fcd34d;font-size:13.5px}

/* Rows / grid */
.row{margin:22px 0}
.row h2{font-size:18px;margin:0 0 10px;font-weight:700}
.strip{display:flex;gap:12px;overflow-x:auto;padding-bottom:8px;scroll-snap-type:x proximity}
.strip::-webkit-scrollbar{height:6px}.strip::-webkit-scrollbar-thumb{background:#2a2f3d;border-radius:9px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:14px}
.card{flex:0 0 150px;scroll-snap-align:start;cursor:pointer;border-radius:var(--radius);overflow:hidden;background:var(--bg2);position:relative;transition:transform .15s}
.card:hover{transform:translateY(-3px)}
.card .poster{aspect-ratio:2/3;width:100%;object-fit:cover;background:var(--bg3)}
.card .noimg{aspect-ratio:2/3;display:flex;align-items:center;justify-content:center;padding:10px;text-align:center;color:var(--muted);font-weight:600}
.card .cap{padding:8px 10px 10px}
.card .t{font-size:13.5px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.card .s{font-size:12px;color:var(--subtle)}
.card .bar{position:absolute;left:0;right:0;bottom:0;height:4px;background:rgba(255,255,255,.15)}
.card .bar i{display:block;height:100%;background:var(--accent)}
.card.wide{flex-basis:260px}
.card.wide .poster,.card.wide .noimg{aspect-ratio:16/9}

/* Details */
.hero{position:relative;margin:0 -24px;min-height:420px;display:flex;align-items:flex-end;padding:40px 24px 28px;background-size:cover;background-position:center top}
.hero::before{content:"";position:absolute;inset:0;background:linear-gradient(90deg,rgba(11,13,18,.96) 0%,rgba(11,13,18,.75) 45%,rgba(11,13,18,.25) 100%),linear-gradient(0deg,var(--bg) 0%,transparent 45%)}
.hero>*{position:relative}
.hero .inner{max-width:720px}
.hero .logoimg{max-width:420px;max-height:140px;object-fit:contain;margin-bottom:14px}
.hero h1{font-size:40px;margin:0 0 10px;letter-spacing:-.5px;line-height:1.1}
.meta{display:flex;flex-wrap:wrap;gap:6px 12px;color:var(--muted);font-size:14px;margin-bottom:12px}
.meta .imdb{color:#fbbf24;font-weight:700}
.desc{color:rgba(255,255,255,.85);max-width:680px}
.cast{color:var(--subtle);font-size:13px;margin-top:8px}
.btns{display:flex;gap:10px;margin-top:18px;flex-wrap:wrap}
.btn{display:inline-flex;align-items:center;gap:8px;padding:11px 20px;border-radius:10px;font-weight:700;background:var(--ink);color:#000}
.btn.secondary{background:rgba(255,255,255,.14);color:var(--ink)}
.btn.accent{background:var(--accent);color:#fff}
.btn:disabled{opacity:.5;cursor:default}
.seasons{display:flex;gap:8px;flex-wrap:wrap;margin:22px 0 12px}
.chip{padding:7px 14px;border-radius:999px;background:var(--bg2);border:1px solid var(--line);font-size:13.5px;font-weight:600;color:var(--muted)}
.chip.on{background:rgba(124,92,255,.22);border-color:var(--accent);color:var(--ink)}
.eps{display:flex;flex-direction:column;gap:10px}
.ep{display:flex;gap:14px;padding:10px;border-radius:var(--radius);background:var(--bg2);border:1px solid transparent;cursor:pointer;align-items:flex-start}
.ep:hover{border-color:rgba(124,92,255,.5)}
.ep .th{flex:0 0 180px;aspect-ratio:16/9;border-radius:8px;overflow:hidden;background:var(--bg3);position:relative}
.ep .th img{width:100%;height:100%;object-fit:cover}
.ep .th .bar{position:absolute;left:0;right:0;bottom:0;height:4px;background:rgba(255,255,255,.2)}
.ep .th .bar i{display:block;height:100%;background:var(--accent)}
.ep .n{font-weight:700}
.ep .o{color:var(--muted);font-size:13.5px;display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}
.ep .d{color:var(--subtle);font-size:12px}

/* Sheet (sources) */
.scrim{position:fixed;inset:0;background:rgba(0,0,0,.6);z-index:40;display:flex;justify-content:center;align-items:flex-end}
.sheet{width:min(760px,100%);max-height:86vh;background:var(--bg2);border:1px solid var(--line);border-radius:18px 18px 0 0;display:flex;flex-direction:column;animation:up .2s ease-out}
@keyframes up{from{transform:translateY(30px);opacity:.4}to{transform:none;opacity:1}}
@media (min-width:800px){.scrim{align-items:center}.sheet{border-radius:18px}}
.sheet .hd{display:flex;align-items:center;gap:10px;padding:16px 18px 10px}
.sheet .hd h3{margin:0;font-size:17px;flex:1}
.sheet .sub{padding:0 18px;color:var(--muted);font-size:13px}
.filters{display:flex;gap:6px;flex-wrap:wrap;padding:10px 18px}
.filters .chip{padding:5px 11px;font-size:12.5px}
.list{overflow:auto;padding:4px 10px 14px}
.src{display:flex;gap:12px;align-items:flex-start;padding:10px;border-radius:10px;cursor:pointer}
.src:hover{background:var(--bg3)}
.q{flex:0 0 52px;text-align:center;font-size:12px;font-weight:800;padding:4px 0;border-radius:6px;background:rgba(255,255,255,.1)}
.q.k4{background:rgba(251,191,36,.18);color:#fcd34d}.q.k1080{background:rgba(124,92,255,.25);color:#c4b5fd}.q.k720{background:rgba(16,185,129,.18);color:#6ee7b7}
.src .tt{font-size:13.5px;white-space:pre-line;display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden;word-break:break-word}
.src .mm{display:flex;flex-wrap:wrap;gap:4px 10px;color:var(--subtle);font-size:12px;margin-top:3px}
.kind{font-weight:700}.kind.torrent{color:#fbbf24}.kind.debrid{color:#67e8f9}.kind.direct{color:#6ee7b7}
.empty{color:var(--muted);text-align:center;padding:30px 10px}
.spin{width:22px;height:22px;border:3px solid rgba(255,255,255,.2);border-top-color:var(--accent2);border-radius:50%;animation:rot .8s linear infinite;display:inline-block;vertical-align:middle}
@keyframes rot{to{transform:rotate(360deg)}}
.x{width:34px;height:34px;border-radius:50%;display:flex;align-items:center;justify-content:center;background:rgba(255,255,255,.08)}

/* Player */
#player{position:fixed;inset:0;background:#000;z-index:60;user-select:none}
#player video{position:absolute;inset:0;width:100%;height:100%;background:#000}
#subs{position:absolute;left:5%;right:5%;bottom:9%;text-align:center;pointer-events:none;transition:bottom .2s}
#player.ui #subs{bottom:120px}
#subs span{display:inline;background:rgba(0,0,0,.62);color:#fff;font-size:clamp(16px,2.6vw,34px);line-height:1.35;padding:2px 10px;border-radius:4px;white-space:pre-line;box-decoration-break:clone;-webkit-box-decoration-break:clone;text-shadow:0 1px 2px #000}
.pl-top,.pl-bot{position:absolute;left:0;right:0;padding:16px 22px;opacity:0;transition:opacity .2s;pointer-events:none}
#player.ui .pl-top,#player.ui .pl-bot{opacity:1;pointer-events:auto}
#player.ui{cursor:default}#player:not(.ui){cursor:none}
.pl-top{top:0;display:flex;align-items:center;gap:14px;background:linear-gradient(rgba(0,0,0,.75),transparent)}
.pl-top .ttl{font-weight:700;font-size:17px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.pl-top .st{font-size:13px;color:var(--muted)}
.pl-bot{bottom:0;background:linear-gradient(transparent,rgba(0,0,0,.85));padding-top:40px}
.seek{position:relative;height:18px;display:flex;align-items:center;cursor:pointer;touch-action:none}
.seek .track{position:absolute;left:0;right:0;height:4px;border-radius:9px;background:rgba(255,255,255,.22);transition:height .12s}
.seek:hover .track{height:6px}
.seek .buf{position:absolute;left:0;height:100%;background:rgba(255,255,255,.35);border-radius:9px}
.seek .fill{position:absolute;left:0;height:100%;background:var(--accent);border-radius:9px}
.seek .knob{position:absolute;width:14px;height:14px;margin-left:-7px;border-radius:50%;background:#fff;box-shadow:0 0 0 4px rgba(124,92,255,.35)}
.seek .tip{position:absolute;bottom:22px;transform:translateX(-50%);background:rgba(0,0,0,.85);padding:3px 8px;border-radius:6px;font-size:12.5px;font-variant-numeric:tabular-nums;display:none}
.seek:hover .tip,.seek.drag .tip{display:block}
.ctl{display:flex;align-items:center;gap:6px;margin-top:8px}
.ib{width:42px;height:42px;border-radius:50%;display:flex;align-items:center;justify-content:center;position:relative}
.ib:hover{background:rgba(255,255,255,.12)}
.ib svg{width:26px;height:26px;fill:#fff}
.ib small{position:absolute;font-size:9.5px;font-weight:800;top:15px}
.time{font-variant-numeric:tabular-nums;font-size:14px;color:rgba(255,255,255,.9);margin:0 8px;white-space:nowrap}
.grow{flex:1}
.vol{width:90px;accent-color:var(--accent)}
.pill{padding:6px 12px;border-radius:999px;background:rgba(255,255,255,.12);font-size:13px;font-weight:700;white-space:nowrap}
.menu{position:absolute;right:22px;bottom:88px;min-width:300px;max-width:min(400px,92vw);max-height:60vh;overflow:auto;background:rgba(20,22,30,.97);border:1px solid var(--line);border-radius:12px;padding:6px;z-index:5}
.menu h4{margin:6px 10px 6px;font-size:12px;color:var(--subtle);text-transform:uppercase;letter-spacing:.7px}
.menu .mi{display:flex;align-items:center;gap:10px;width:100%;padding:9px 10px;border-radius:8px;text-align:left;font-size:14px}
.menu .mi:hover{background:rgba(255,255,255,.08)}
.menu .mi .ck{width:16px;color:var(--accent2);font-weight:900}
.menu .mi .sm{margin-left:auto;color:var(--subtle);font-size:12px;padding-left:10px;text-align:right}
.menu .mi>span:nth-child(2){white-space:nowrap}
.menu .mi[disabled]{opacity:.4;cursor:default}
.center{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px;pointer-events:none;text-align:center;padding:20px}
.center .big{width:54px;height:54px;border-width:4px}
.center .msg{color:var(--muted);font-size:14.5px;max-width:460px}
.center .err{color:#fca5a5;pointer-events:auto}
.toast{position:absolute;left:50%;top:70px;transform:translateX(-50%);background:rgba(20,22,30,.95);border:1px solid var(--line);padding:9px 16px;border-radius:10px;font-size:13.5px;z-index:6;max-width:90vw;text-align:center}
.flash{position:absolute;top:50%;transform:translateY(-50%);width:90px;height:90px;border-radius:50%;background:rgba(0,0,0,.45);display:flex;align-items:center;justify-content:center;font-weight:800;opacity:0;transition:opacity .35s;pointer-events:none}
.flash.l{left:12%}.flash.r{right:12%}.flash.show{opacity:1;transition:none}

@media (max-width:640px){
  header{padding:10px 14px}main{padding:6px 14px 50px}
  .hero{margin:0 -14px;padding:30px 14px 20px;min-height:340px}.hero h1{font-size:28px}
  .card{flex-basis:118px}.card.wide{flex-basis:220px}
  .grid{grid-template-columns:repeat(auto-fill,minmax(110px,1fr))}
  .ep .th{flex-basis:120px}
  .vol,.hide-sm{display:none}
  .pl-top,.pl-bot{padding-left:12px;padding-right:12px}
  .ib{width:38px;height:38px}
  .menu{right:10px;bottom:80px}
}
</style>
</head>
<body>
<header>
  <a class="logo" href="#/">Play<span>Torrio</span></a>
  <label class="search">
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.4"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>
    <input id="q" type="search" placeholder="Search movies & shows" autocomplete="off">
  </label>
</header>
<main id="main"></main>

<div id="sheet" class="scrim hidden"></div>

<div id="player" class="hidden">
  <video id="v" playsinline preload="auto"></video>
  <div id="subs"></div>
  <div class="center" id="pcenter"></div>
  <div class="flash l" id="flashL">−10</div>
  <div class="flash r" id="flashR">+10</div>
  <div class="pl-top">
    <button class="x" id="pBack" title="Back (Esc)"><svg width="20" height="20" viewBox="0 0 24 24" fill="#fff"><path d="M15.4 5.4 14 4l-8 8 8 8 1.4-1.4L8.8 12z"/></svg></button>
    <div style="min-width:0;flex:1"><div class="ttl" id="pTitle"></div><div class="st" id="pSub"></div></div>
  </div>
  <div class="pl-bot">
    <div class="seek" id="seek"><div class="track"><div class="buf" id="sBuf"></div><div class="fill" id="sFill"></div></div><div class="knob" id="sKnob"></div><div class="tip" id="sTip">0:00</div></div>
    <div class="ctl">
      <button class="ib" id="bPlay" title="Play/Pause (Space)"></button>
      <button class="ib" id="bBack" title="Back 10s (←)"><svg viewBox="0 0 24 24"><path d="M12 5V1L7 6l5 5V7c3.3 0 6 2.7 6 6s-2.7 6-6 6-6-2.7-6-6H4c0 4.4 3.6 8 8 8s8-3.6 8-8-3.6-8-8-8z"/></svg><small>10</small></button>
      <button class="ib" id="bFwd" title="Forward 10s (→)"><svg viewBox="0 0 24 24"><path d="M12 5V1l5 5-5 5V7c-3.3 0-6 2.7-6 6s2.7 6 6 6 6-2.7 6-6h2c0 4.4-3.6 8-8 8s-8-3.6-8-8 3.6-8 8-8z"/></svg><small>10</small></button>
      <button class="ib" id="bMute" title="Mute (M)"></button>
      <input class="vol" id="vol" type="range" min="0" max="1" step="0.02" value="1">
      <div class="time" id="time">0:00 / 0:00</div>
      <div class="grow"></div>
      <button class="pill hidden" id="bNext" title="Next episode">Next ▸</button>
      <button class="ib" id="bSubs" title="Subtitles & audio"><svg viewBox="0 0 24 24"><path d="M20 4H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2zM4 12h4v2H4v-2zm10 6H4v-2h10v2zm6 0h-4v-2h4v2zm0-4H10v-2h10v2z"/></svg></button>
      <button class="pill" id="bQual" title="Quality">Auto</button>
      <button class="ib" id="bFs" title="Fullscreen (F)"><svg viewBox="0 0 24 24"><path d="M7 14H5v5h5v-2H7v-3zm-2-4h2V7h3V5H5v5zm12 7h-3v2h5v-5h-2v3zM14 5v2h3v3h2V5h-5z"/></svg></button>
    </div>
  </div>
  <div class="menu hidden" id="menu"></div>
</div>

<script>
(() => {
'use strict';
const $ = (s, el = document) => el.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const main = $('#main');

async function api(path, body) {
  const opt = body ? {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body)} : {};
  const r = await fetch(path, opt);
  let j = {};
  try { j = await r.json(); } catch (_) {}
  if (!r.ok && !j.state) throw new Error(j.error || ('HTTP ' + r.status));
  return j;
}
function fmt(t) {
  t = Math.max(0, Math.floor(t || 0));
  const h = Math.floor(t / 3600), m = Math.floor(t % 3600 / 60), s = t % 60;
  return (h ? h + ':' + String(m).padStart(2, '0') : m) + ':' + String(s).padStart(2, '0');
}

/* ---------- Watch progress (this browser only) ---------- */
const PKEY = 'pt_progress_v1';
function loadProg() { try { return JSON.parse(localStorage.getItem(PKEY) || '{}'); } catch (_) { return {}; } }
function saveProg(key, rec) {
  try {
    const all = loadProg(); all[key] = rec;
    const keys = Object.keys(all).sort((a, b) => all[b].ts - all[a].ts);
    for (const k of keys.slice(200)) delete all[k];
    localStorage.setItem(PKEY, JSON.stringify(all));
  } catch (_) {}
}
function progFor(key) { return loadProg()[key]; }

/* ---------- Router ---------- */
let homeCache = null, ffmpegOk = true;
window.addEventListener('hashchange', route);
function route() {
  const h = location.hash.slice(1) || '/';
  if (!h.endsWith('/watch') && player.open) closePlayer(true);
  if (h.endsWith('/watch')) { if (!player.open) history.replaceState(null, '', '#' + h.slice(0, -6)); else return; }
  closeSheet();
  const path = (location.hash.slice(1) || '/').split('?')[0];
  const parts = path.split('/').filter(Boolean);
  if (parts[0] === 'search') return renderSearch(decodeURIComponent(parts.slice(1).join('/')));
  if (parts[0] === 'title' && parts.length >= 3) return renderTitle(parts[1], decodeURIComponent(parts[2]));
  renderHome();
}

/* ---------- Home ---------- */
function card(it, opts = {}) {
  const img = it.poster ? `<img class="poster" loading="lazy" src="${esc(it.poster)}" alt="" onerror="this.style.visibility='hidden'">` : `<div class="noimg">${esc(it.name)}</div>`;
  const bar = opts.progress ? `<div class="bar"><i style="width:${Math.min(100, opts.progress * 100).toFixed(1)}%"></i></div>` : '';
  return `<a class="card" href="#/title/${esc(it.type)}/${encodeURIComponent(it.id)}">${img}<div class="cap"><div class="t">${esc(it.name)}</div><div class="s">${esc(opts.sub || [it.year, it.rating ? '★ ' + it.rating : ''].filter(Boolean).join(' · '))}</div></div>${bar}</a>`;
}
async function renderHome() {
  document.title = 'PlayTorrio';
  $('#q').value = '';
  main.innerHTML = (ffmpegOk ? '' : '<div class="banner">FFmpeg wasn\'t found on the PlayTorrio computer, so only some videos will play here.</div>') + continueRow() + '<div id="rows"><div class="empty"><span class="spin"></span></div></div>';
  try {
    homeCache = homeCache || await api('api/home');
    const el = $('#rows');
    if (!el) return;
    el.innerHTML = homeCache.rows.map((r) => `<section class="row"><h2>${esc(r.title)}</h2><div class="strip">${r.items.map((i) => card(i)).join('')}</div></section>`).join('') || '<div class="empty">Nothing to show. Is the PlayTorrio computer online?</div>';
  } catch (e) {
    const el = $('#rows'); if (el) el.innerHTML = `<div class="empty">Couldn't load: ${esc(e.message)}</div>`;
  }
}
function continueRow() {
  const all = loadProg();
  const byTitle = {};
  for (const [k, r] of Object.entries(all)) {
    if (!r.metaId || !r.dur) continue;
    const frac = r.pos / r.dur;
    if (frac < 0.02 || frac > 0.95) continue;
    if (!byTitle[r.metaId] || byTitle[r.metaId].ts < r.ts) byTitle[r.metaId] = r;
  }
  const items = Object.values(byTitle).sort((a, b) => b.ts - a.ts).slice(0, 20);
  if (!items.length) return '';
  return `<section class="row"><h2>Continue Watching</h2><div class="strip">${items.map((r) => card({id: r.metaId, type: r.type, name: r.name, poster: r.poster}, {progress: r.pos / r.dur, sub: r.epLabel || (fmt(r.dur - r.pos) + ' left')})).join('')}</div></section>`;
}

/* ---------- Search ---------- */
let searchTimer = null;
$('#q').addEventListener('input', (e) => {
  clearTimeout(searchTimer);
  const v = e.target.value.trim();
  searchTimer = setTimeout(() => {
    if (v.length >= 2) location.hash = '#/search/' + encodeURIComponent(v);
    else if (!v && location.hash.startsWith('#/search')) location.hash = '#/';
  }, 350);
});
async function renderSearch(q) {
  document.title = q + ' · PlayTorrio';
  if ($('#q').value.trim() !== q) $('#q').value = q;
  main.innerHTML = '<div class="empty"><span class="spin"></span></div>';
  try {
    const r = await api('api/search?q=' + encodeURIComponent(q));
    if (location.hash.slice(1) !== '/search/' + encodeURIComponent(q)) return;
    const sec = (t, items) => items.length ? `<section class="row"><h2>${t}</h2><div class="grid">${items.map((i) => card(i)).join('')}</div></section>` : '';
    main.innerHTML = (sec('Movies', r.movies) + sec('Shows', r.series)) || `<div class="empty">No results for “${esc(q)}”.</div>`;
  } catch (e) { main.innerHTML = `<div class="empty">Search failed: ${esc(e.message)}</div>`; }
}

/* ---------- Title details ---------- */
let current = null; // {meta, type, season}
async function renderTitle(type, id) {
  main.innerHTML = '<div class="empty" style="padding-top:120px"><span class="spin"></span></div>';
  let meta;
  try { meta = await api(`api/meta?type=${encodeURIComponent(type)}&id=${encodeURIComponent(id)}`); }
  catch (e) { main.innerHTML = `<div class="empty">Couldn't load this title: ${esc(e.message)}</div>`; return; }
  document.title = meta.name + ' · PlayTorrio';
  const isSeries = (meta.type === 'series' || type === 'series') && meta.videos && meta.videos.length;
  current = {meta, type, isSeries};
  const seasons = isSeries ? [...new Set(meta.videos.map((v) => v.season ?? 0))].sort((a, b) => (a === 0) - (b === 0) || a - b) : [];
  const resumeKey = !isSeries ? meta.id : null;
  const rp = resumeKey ? progFor(resumeKey) : null;
  let lastEp = null;
  if (isSeries) {
    const all = loadProg(); let best = null;
    for (const r of Object.values(all)) if (r.metaId === meta.id && (!best || r.ts > best.ts)) best = r;
    if (best) lastEp = meta.videos.find((v) => v.id === best.videoId);
  }
  current.season = lastEp ? (lastEp.season ?? 0) : (seasons.find((s) => s > 0) ?? seasons[0]);
  const firstEp = isSeries ? epsOf(current.season)[0] : null;
  const metaLine = [meta.year, meta.runtime, (meta.genres || []).slice(0, 3).join(', ')].filter(Boolean).map(esc);
  main.innerHTML = `
    <div class="hero" style="background-image:url('${esc(meta.background || meta.poster || '')}')">
      <div class="inner">
        ${meta.logo ? `<img class="logoimg" src="${esc(meta.logo)}" alt="${esc(meta.name)}" onerror="this.nextElementSibling.classList.remove('hidden');this.remove()"><h1 class="hidden">${esc(meta.name)}</h1>` : `<h1>${esc(meta.name)}</h1>`}
        <div class="meta">${meta.rating ? `<span class="imdb">IMDb ${esc(meta.rating)}</span>` : ''}${metaLine.map((m) => `<span>${m}</span>`).join('')}</div>
        <div class="desc">${esc(meta.description || '')}</div>
        ${meta.cast && meta.cast.length ? `<div class="cast">Starring ${esc(meta.cast.slice(0, 5).join(', '))}</div>` : ''}
        <div class="btns">
          ${!isSeries ? `<button class="btn" id="playMovie">▶ ${rp && rp.pos > 30 && rp.pos / rp.dur < 0.95 ? 'Resume ' + fmt(rp.pos) : 'Play'}</button>` : ''}
          ${isSeries && lastEp ? `<button class="btn" id="playLast">▶ Continue S${lastEp.season}:E${lastEp.episode}</button>` : ''}
          ${isSeries && !lastEp && firstEp ? `<button class="btn" id="playFirst">▶ Play S${firstEp.season}:E${firstEp.episode}</button>` : ''}
        </div>
      </div>
    </div>
    ${isSeries ? `<div class="seasons" id="seasons">${seasons.map((s) => `<button class="chip ${s === current.season ? 'on' : ''}" data-s="${s}">${s === 0 ? 'Specials' : 'Season ' + s}</button>`).join('')}</div><div class="eps" id="eps"></div>` : ''}`;
  if (!isSeries) $('#playMovie').onclick = () => openSources(null);
  else {
    if (lastEp) $('#playLast').onclick = () => openSources(lastEp);
    const pf = $('#playFirst');
    if (pf) pf.onclick = () => openSources(firstEp);
    $('#seasons').onclick = (e) => {
      const b = e.target.closest('[data-s]'); if (!b) return;
      current.season = Number(b.dataset.s);
      for (const c of document.querySelectorAll('#seasons .chip')) c.classList.toggle('on', c === b);
      renderEps();
    };
    renderEps();
  }
}
function epsOf(season) {
  return current.meta.videos.filter((v) => (v.season ?? 0) === season).sort((a, b) => (a.episode ?? 0) - (b.episode ?? 0));
}
function renderEps() {
  const list = epsOf(current.season);
  const prog = loadProg();
  $('#eps').innerHTML = list.map((v) => {
    const p = prog[v.id];
    const frac = p && p.dur ? Math.min(1, p.pos / p.dur) : 0;
    const date = v.released ? new Date(v.released) : null;
    const future = date && date > new Date();
    return `<div class="ep" data-id="${esc(v.id)}">
      <div class="th">${v.thumbnail ? `<img loading="lazy" src="${esc(v.thumbnail)}" alt="" onerror="this.remove()">` : ''}${frac > 0.01 ? `<div class="bar"><i style="width:${(frac * 100).toFixed(1)}%"></i></div>` : ''}</div>
      <div style="min-width:0"><div class="n">${v.episode ?? ''}. ${esc(v.title || 'Episode ' + v.episode)}</div>
      <div class="d">${date ? esc(date.toLocaleDateString(undefined, {timeZone: 'UTC'})) + (future ? ' · upcoming' : '') : ''}</div>
      <div class="o">${esc(v.overview || '')}</div></div></div>`;
  }).join('') || '<div class="empty">No episodes listed.</div>';
  $('#eps').onclick = (e) => {
    const el = e.target.closest('.ep'); if (!el) return;
    const v = current.meta.videos.find((x) => x.id === el.dataset.id);
    if (v) openSources(v);
  };
}

/* ---------- Sources sheet ---------- */
const sheet = $('#sheet');
let srcState = null;
function closeSheet() {
  if (srcState) srcState.cancelled = true;
  srcState = null;
  sheet.classList.add('hidden');
  sheet.innerHTML = '';
}
sheet.addEventListener('click', (e) => { if (e.target === sheet) closeSheet(); });
function epLabel(ep) { return ep ? `S${ep.season}:E${ep.episode}${ep.title ? ' · ' + ep.title : ''}` : ''; }
function scoreSource(s) {
  let sc = 0;
  if (s.kind === 'debrid') sc += 60;
  else if (s.kind === 'direct') sc += 30;
  else { const sd = s.seeders ?? 0; sc += Math.min(sd, 300) / 4; if (sd === 0) sc -= 60; }
  if (s.quality === '1080p') sc += 40; else if (s.quality === '4K') sc += 22; else if (s.quality === '720p') sc += 25; else if (s.quality === '480p') sc += 5;
  const gb = (s.sizeBytes || 0) / 1073741824;
  if (gb > 25) sc -= 15;
  if (/\b(cam|hdcam|telesync|\bts\b)\b/i.test(s.title || '')) sc -= 80;
  return sc;
}
async function openSources(ep) {
  closeSheet();
  const meta = current.meta;
  const st = srcState = {ep, sources: [], job: null, filter: 'all', done: false, cancelled: false};
  sheet.classList.remove('hidden');
  sheet.innerHTML = `<div class="sheet"><div class="hd"><h3>${esc(meta.name)}${ep ? ' · ' + esc(epLabel(ep)) : ''}</h3><button class="x" id="shClose">✕</button></div>
    <div class="sub" id="shSub"><span class="spin" style="width:14px;height:14px;border-width:2px"></span> Searching sources…</div>
    <div class="filters" id="shF"></div><div class="list" id="shL"></div></div>`;
  $('#shClose').onclick = closeSheet;
  try {
    const r = await api('api/sources/start', {type: current.isSeries ? 'series' : (meta.type || 'movie'), id: ep ? ep.id : meta.id, title: meta.name, year: parseInt(meta.year) || null, season: ep ? ep.season : null, episode: ep ? ep.episode : null});
    st.job = r.job;
  } catch (e) { $('#shSub').textContent = 'Search failed: ' + e.message; return; }
  const poll = async () => {
    if (st.cancelled) return;
    try {
      const r = await api(`api/sources/poll?job=${st.job}&since=${st.sources.length}`);
      st.sources.push(...r.sources);
      st.done = r.done;
      drawSources(st);
      if (!r.done) setTimeout(poll, 800);
    } catch (e) { if (!st.cancelled) $('#shSub').textContent = 'Lost the source search: ' + e.message; }
  };
  poll();
}
function drawSources(st) {
  if (st !== srcState) return;
  const n = st.sources.length;
  $('#shSub').innerHTML = st.done ? `${n} source${n === 1 ? '' : 's'} found` : `<span class="spin" style="width:14px;height:14px;border-width:2px"></span> Searching… ${n} found so far`;
  const kinds = ['all', ...['debrid', 'direct', 'torrent'].filter((k) => st.sources.some((s) => s.kind === k))];
  const quals = ['4K', '1080p', '720p'].filter((q) => st.sources.some((s) => s.quality === q));
  const label = {all: 'All', debrid: 'Debrid', direct: 'Direct', torrent: 'Torrent'};
  $('#shF').innerHTML = (n ? `<button class="chip accent" id="shBest" style="background:var(--accent);color:#fff;border-color:var(--accent)">▶ Play best</button>` : '') +
    kinds.map((k) => `<button class="chip ${st.filter === k ? 'on' : ''}" data-f="${k}">${label[k]}</button>`).join('') +
    quals.map((q) => `<button class="chip ${st.filter === q ? 'on' : ''}" data-f="${q}">${q}</button>`).join('');
  $('#shF').onclick = (e) => {
    if (e.target.id === 'shBest') { const b = [...st.sources].sort((a, c) => scoreSource(c) - scoreSource(a))[0]; if (b) startPlay(st, b); return; }
    const b = e.target.closest('[data-f]'); if (!b) return;
    st.filter = b.dataset.f; drawSources(st);
  };
  let list = st.sources.filter((s) => st.filter === 'all' || s.kind === st.filter || s.quality === st.filter);
  list = list.sort((a, b) => scoreSource(b) - scoreSource(a));
  const L = $('#shL');
  L.innerHTML = list.map((s) => {
    const qc = s.quality === '4K' ? 'k4' : s.quality === '1080p' ? 'k1080' : s.quality === '720p' ? 'k720' : '';
    const meta = [`<span class="kind ${s.kind}">${label[s.kind]}</span>`, esc(s.addon), s.size ? esc(s.size) : '', s.seeders != null && s.kind === 'torrent' ? '👤 ' + s.seeders : '', s.hdr ? 'HDR' : '', s.codec ? esc(s.codec) : ''].filter(Boolean);
    return `<div class="src" data-i="${s.i}"><div class="q ${qc}">${esc(s.quality || 'SD?')}</div><div style="min-width:0"><div class="tt">${esc(s.title || s.name)}</div><div class="mm">${meta.join('<span>·</span>')}</div></div></div>`;
  }).join('') || (st.done ? '<div class="empty">No sources found. Check your addons / providers in PlayTorrio.</div>' : '');
  L.onclick = (e) => {
    const el = e.target.closest('.src'); if (!el) return;
    const s = st.sources.find((x) => x.i === Number(el.dataset.i));
    if (s) startPlay(st, s);
  };
}

/* ---------- Player ---------- */
const P = $('#player'), V = $('#v');
const player = {open: false};
const ICON = {
  play: '<svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>',
  pause: '<svg viewBox="0 0 24 24"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>',
  vol: '<svg viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3A4.5 4.5 0 0 0 14 8v8a4.5 4.5 0 0 0 2.5-4zM14 3.2v2.1a7 7 0 0 1 0 13.4v2.1a9 9 0 0 0 0-17.6z"/></svg>',
  mute: '<svg viewBox="0 0 24 24"><path d="M16.5 12A4.5 4.5 0 0 0 14 8v2.2l2.5 2.5v-.7zM19 12c0 .9-.2 1.8-.5 2.6l1.5 1.5A9 9 0 0 0 14 3.2v2.1c2.9.9 5 3.5 5 6.7zM4.3 3 3 4.3 7.7 9H3v6h4l5 5v-6.7l4.3 4.3c-.7.5-1.4.9-2.3 1.2v2.1a9 9 0 0 0 3.7-1.8l2 2 1.3-1.3L4.3 3zM12 4 9.9 6.1 12 8.2V4z"/></svg>',
};
const CODEC_TYPES = {
  h264: ['video/mp4; codecs="avc1.640028"'],
  hevc: ['video/mp4; codecs="hvc1.1.6.L120.90"', 'video/mp4; codecs="hev1.1.6.L120.90"'],
  av1: ['video/mp4; codecs="av01.0.08M.08"'],
  vp9: ['video/mp4; codecs="vp09.00.40.08"'],
};
function canPlayCodec(c) {
  const types = CODEC_TYPES[c]; if (!types) return false;
  return types.some((t) => (window.MediaSource && MediaSource.isTypeSupported && MediaSource.isTypeSupported(t)) || V.canPlayType(t) === 'probably' || V.canPlayType(t) === 'maybe');
}

let S = null; // current playback state
function ptxt(html, isErr) {
  $('#pcenter').innerHTML = html ? (isErr ? `<div class="msg err">${html}</div>` : `<span class="spin big"></span><div class="msg">${html}</div>`) : '';
}
async function startPlay(st, src) {
  const meta = current.meta, ep = st.ep;
  closeSheet();
  openPlayerShell(meta.name, ep ? epLabel(ep) : (meta.year || ''));
  ptxt('Starting…');
  const key = ep ? ep.id : meta.id;
  const saved = progFor(key);
  const resume = saved && saved.pos > 30 && saved.dur && saved.pos / saved.dur < 0.95 ? saved.pos : 0;
  let r;
  try {
    r = await api('api/play', {job: st.job, i: src.i, title: meta.name, imdb: ep ? ep.id : meta.id, season: ep ? ep.season : null, episode: ep ? ep.episode : null, year: parseInt(meta.year) || null});
  } catch (e) { ptxt('Couldn\'t start: ' + esc(e.message), true); return; }
  let savedQ = 'auto';
  try { savedQ = localStorage.getItem('pt_quality') || 'auto'; } catch (_) {}
  S = {sid: r.sid, info: null, key, meta, ep, src, st, resume, mode: null, q: null, qPref: savedQ, a: 0, offset: 0, dur: 0, subs: null, subCues: null, subId: -1, nonce: 0, lastSave: 0, failures: 0};
  const my = S;
  while (my === S && player.open) {
    let s;
    try { s = await api('api/session?sid=' + my.sid); } catch (e) { s = {state: 'error', message: e.message}; }
    if (my !== S || !player.open) return;
    if (s.state === 'ready') { my.info = s; break; }
    if (s.state === 'error') { ptxt(esc(s.message || 'Failed') + '<br><br><button class="btn secondary" onclick="history.back()">Pick another source</button>', true); return; }
    ptxt(esc(s.message || 'Starting…'));
    await new Promise((res) => setTimeout(res, 900));
  }
  if (my !== S) return;
  my.dur = my.info.duration || 0;
  if (my.qPref !== 'auto' && my.qPref !== 'original' && !(my.info.qualities || []).some((q) => q.id === my.qPref)) my.qPref = 'auto';
  const vi = my.info.video || {};
  $('#pSub').textContent = [ep ? epLabel(ep) : '', vi.height ? vi.height + 'p ' + (vi.codec || '').toUpperCase() : '', my.info.audio && my.info.audio[0] ? (my.info.audio[0].codec || '').toUpperCase() : ''].filter(Boolean).join(' · ');
  $('#bNext').classList.toggle('hidden', !nextEpisode());
  chooseAndLoad(resume, true);
}
// Auto = the PlayTorrio PC converts to plain H.264 at the best size up to
// 1080p, so this device only has to play an easy, standard stream.
function autoQuality() {
  const i = S.info;
  return (i.qualities && i.qualities[0] && i.qualities[0].id) || '720';
}
function effectiveQuality() {
  if (S.qPref === 'auto') return autoQuality();
  if (S.qPref === 'original') {
    if (S.info.direct && S.a === 0) return 'direct';
    return 'original';
  }
  return S.qPref;
}
function chooseAndLoad(at, first) {
  const q = effectiveQuality();
  S.q = q;
  S.mode = q === 'direct' ? 'direct' : 'stream';
  S.nonce++;
  ptxt('Loading…');
  $('#bQual').textContent = qualityLabel();
  if (S.mode === 'direct') {
    S.offset = 0;
    V.src = `s/${S.sid}/raw`;
    const seekOnce = () => { V.removeEventListener('loadedmetadata', seekOnce); if (at > 1) V.currentTime = at; };
    V.addEventListener('loadedmetadata', seekOnce);
  } else {
    S.offset = Math.max(0, at || 0);
    V.src = `s/${S.sid}/video.mp4?q=${encodeURIComponent(q)}&t=${S.offset.toFixed(2)}&a=${S.a}&n=${S.nonce}`;
  }
  const p = V.play();
  if (p && p.catch) p.catch(() => { ptxt(''); showUi(); });
  if (first && at > 1) toast('Resuming from ' + fmt(at));
}
function qualityLabel() {
  const vi = S.info.video || {};
  const name = S.q === 'direct' || S.q === 'original' ? (vi.height ? vi.height + 'p' : 'Original') : S.q + 'p';
  return S.qPref === 'auto' ? 'Auto · ' + name : name;
}
function pos() { return S ? (S.mode === 'direct' ? V.currentTime : S.offset + V.currentTime) : 0; }
function duration() { return S ? (S.dur || (S.mode === 'direct' ? V.duration : 0) || 0) : 0; }
function seekTo(t) {
  if (!S || !S.info) return;
  const d = duration();
  t = Math.max(0, d ? Math.min(t, d - 2) : t);
  if (S.mode === 'direct') { V.currentTime = t; return; }
  const rel = t - S.offset;
  for (let i = 0; i < V.buffered.length; i++) {
    if (rel >= V.buffered.start(i) && rel <= V.buffered.end(i) - 0.5) { V.currentTime = rel; return; }
  }
  const wasPaused = V.paused && V.readyState > 0;
  chooseAndLoad(t);
  if (wasPaused) V.addEventListener('playing', () => V.pause(), {once: true});
}
function skip(d) {
  seekTo(pos() + d);
  const el = d < 0 ? $('#flashL') : $('#flashR');
  el.classList.add('show'); setTimeout(() => el.classList.remove('show'), 60);
}
function nextEpisode() {
  if (!S || !S.ep || !current || current.meta !== S.meta) return null;
  const vids = S.meta.videos.filter((v) => (v.season ?? 0) > 0).sort((a, b) => (a.season - b.season) || (a.episode - b.episode));
  const i = vids.findIndex((v) => v.id === S.ep.id);
  return i >= 0 && i + 1 < vids.length ? vids[i + 1] : null;
}

function openPlayerShell(title, sub) {
  if (!player.open) {
    player.open = true;
    history.pushState(null, '', location.hash + '/watch');
  }
  P.classList.remove('hidden');
  document.body.style.overflow = 'hidden';
  $('#pTitle').textContent = title;
  $('#pSub').textContent = sub || '';
  $('#subs').innerHTML = '';
  hideMenu();
  showUi();
}
function stopSession() {
  if (S && S.sid) { const sid = S.sid; fetch('api/session/stop', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({sid}), keepalive: true}).catch(() => {}); }
}
function closePlayer(fromRoute) {
  if (!player.open) return;
  saveNow();
  player.open = false;
  stopSession();
  S = null;
  V.pause(); V.removeAttribute('src'); V.load();
  P.classList.add('hidden');
  document.body.style.overflow = '';
  if (document.fullscreenElement) document.exitFullscreen().catch(() => {});
  // Going back re-renders the title page, which refreshes resume points.
  if (!fromRoute) history.back();
}
$('#pBack').onclick = () => closePlayer(false);

function saveNow(finished) {
  if (!S || !S.info) return;
  const d = duration(), p = finished ? d : pos();
  if (!d || p < 5) return;
  saveProg(S.key, {pos: p, dur: d, ts: Date.now(), metaId: S.meta.id, type: current && current.isSeries ? 'series' : (S.meta.type || 'movie'), name: S.meta.name, poster: S.meta.poster, videoId: S.ep ? S.ep.id : null, epLabel: S.ep ? `S${S.ep.season}:E${S.ep.episode}` : null});
}

/* video events */
V.addEventListener('waiting', () => { if (S && S.info) ptxt('Buffering…'); });
V.addEventListener('playing', () => { ptxt(''); S && (S.failures = 0); });
V.addEventListener('canplay', () => { if (!V.paused) ptxt(''); });
V.addEventListener('pause', () => { drawPlay(); showUi(); });
V.addEventListener('play', drawPlay);
V.addEventListener('volumechange', drawVol);
V.addEventListener('error', () => {
  if (!S || !S.info || !V.getAttribute('src')) return;
  S.failures++;
  const at = pos();
  if (S.failures > 3) { ptxt('Playback failed in this browser. Try a lower quality or another source.', true); return; }
  if (S.q === 'direct') { S.info.direct = false; toast('Switching to streaming mode…'); chooseAndLoad(at); return; }
  if (S.q === 'original') {
    S.info.copyVideo = false;
    if (S.qPref === 'original') S.qPref = 'auto';
    toast('Your browser can\'t play the original video format, so it\'s being converted.');
    chooseAndLoad(at); return;
  }
  chooseAndLoad(at);
});
V.addEventListener('ended', () => {
  if (!S) return;
  const d = duration();
  // A stream can end early if the source hiccups; resume from where it stopped.
  if (S.mode === 'stream' && d && pos() < d - 15) { chooseAndLoad(pos()); return; }
  saveNow(true);
  const n = nextEpisode();
  if (n) { toast('Up next: ' + epLabel(n)); setTimeout(() => { if (S && V.ended) playNext(); }, 5000); }
});

/* controls */
function drawPlay() { $('#bPlay').innerHTML = V.paused ? ICON.play : ICON.pause; }
function drawVol() { $('#bMute').innerHTML = V.muted || V.volume === 0 ? ICON.mute : ICON.vol; $('#vol').value = V.muted ? 0 : V.volume; }
drawPlay(); drawVol();
try { const vv = parseFloat(localStorage.getItem('pt_vol')); if (vv >= 0 && vv <= 1) V.volume = vv; } catch (_) {}
function togglePlay() { if (!S || !S.info) return; if (V.paused) V.play().catch(() => {}); else V.pause(); }
$('#bPlay').onclick = togglePlay;
$('#bBack').onclick = () => skip(-10);
$('#bFwd').onclick = () => skip(10);
$('#bMute').onclick = () => { V.muted = !V.muted; };
$('#vol').oninput = (e) => { V.volume = Number(e.target.value); V.muted = V.volume === 0; try { localStorage.setItem('pt_vol', V.volume); } catch (_) {} };
$('#bFs').onclick = toggleFs;
function toggleFs() { if (document.fullscreenElement) document.exitFullscreen().catch(() => {}); else (P.requestFullscreen ? P.requestFullscreen() : Promise.reject()).catch(() => { if (V.webkitEnterFullscreen) V.webkitEnterFullscreen(); }); }
$('#bNext').onclick = playNext;
function playNext() {
  const n = nextEpisode(); if (!n || !S) return;
  saveNow();
  stopSession();
  const st = {ep: n};
  V.pause(); V.removeAttribute('src'); V.load();
  S = null;
  // Look up sources for the next episode, then play the best one automatically.
  openPlayerShell(current.meta.name, epLabel(n));
  ptxt('Finding sources for ' + esc(epLabel(n)) + '…');
  (async () => {
    try {
      const r = await api('api/sources/start', {type: 'series', id: n.id, title: current.meta.name, year: parseInt(current.meta.year) || null, season: n.season, episode: n.episode});
      st.job = r.job;
      let sources = [], done = false, t0 = Date.now();
      while (!done && player.open && Date.now() - t0 < 60000) {
        await new Promise((res) => setTimeout(res, 1000));
        const p = await api(`api/sources/poll?job=${r.job}&since=${sources.length}`);
        sources.push(...p.sources); done = p.done;
        if (sources.length && (done || Date.now() - t0 > 12000)) break;
      }
      if (!player.open) return;
      const best = sources.sort((a, b) => scoreSource(b) - scoreSource(a))[0];
      if (!best) { ptxt('No sources found for the next episode.', true); return; }
      startPlay(st, best);
    } catch (e) { ptxt('Couldn\'t load the next episode: ' + esc(e.message), true); }
  })();
}

/* seek bar */
const seekEl = $('#seek');
let dragging = false, dragT = 0;
function seekFrac(ev) { const r = seekEl.getBoundingClientRect(); return Math.min(1, Math.max(0, ((ev.touches ? ev.touches[0].clientX : ev.clientX) - r.left) / r.width)); }
seekEl.addEventListener('pointermove', (ev) => { const d = duration(); if (!d) return; const f = seekFrac(ev); $('#sTip').style.left = (f * 100) + '%'; $('#sTip').textContent = fmt(f * d); if (dragging) { dragT = f * d; drawSeek(); } });
seekEl.addEventListener('pointerdown', (ev) => { if (!duration()) return; dragging = true; seekEl.classList.add('drag'); seekEl.setPointerCapture(ev.pointerId); dragT = seekFrac(ev) * duration(); drawSeek(); });
seekEl.addEventListener('pointerup', () => { if (!dragging) return; dragging = false; seekEl.classList.remove('drag'); seekTo(dragT); });
seekEl.addEventListener('pointercancel', () => { dragging = false; seekEl.classList.remove('drag'); });
function drawSeek() {
  const d = duration();
  const p = dragging ? dragT : pos();
  const f = d ? Math.min(1, p / d) : 0;
  $('#sFill').style.width = (f * 100) + '%';
  $('#sKnob').style.left = (f * 100) + '%';
  let bufEnd = 0;
  if (S && V.buffered.length) bufEnd = (S.mode === 'direct' ? 0 : S.offset) + V.buffered.end(V.buffered.length - 1);
  $('#sBuf').style.width = (d ? Math.min(100, bufEnd / d * 100) : 0) + '%';
  $('#time').textContent = fmt(p) + ' / ' + fmt(d);
}

/* UI auto-hide */
let uiTimer = null;
function showUi() {
  P.classList.add('ui');
  clearTimeout(uiTimer);
  uiTimer = setTimeout(() => { if (!V.paused && $('#menu').classList.contains('hidden') && !dragging) P.classList.remove('ui'); }, 3000);
}
P.addEventListener('pointermove', showUi);
P.addEventListener('click', (e) => {
  if (e.target === V || e.target.id === 'subs' || e.target.closest('.center')) {
    if (!$('#menu').classList.contains('hidden')) { hideMenu(); return; }
    if (matchMedia('(pointer:coarse)').matches && !P.classList.contains('ui')) { showUi(); return; }
    togglePlay(); showUi();
  }
});
P.addEventListener('dblclick', (e) => { if (e.target === V) toggleFs(); });
document.addEventListener('keydown', (e) => {
  if (!player.open || e.target.tagName === 'INPUT') return;
  const k = e.key;
  if (k === ' ' || k === 'k') { e.preventDefault(); togglePlay(); }
  else if (k === 'ArrowLeft' || k === 'j') { e.preventDefault(); skip(-10); }
  else if (k === 'ArrowRight' || k === 'l') { e.preventDefault(); skip(10); }
  else if (k === 'ArrowUp') { e.preventDefault(); V.volume = Math.min(1, V.volume + 0.05); V.muted = false; }
  else if (k === 'ArrowDown') { e.preventDefault(); V.volume = Math.max(0, V.volume - 0.05); }
  else if (k === 'f') toggleFs();
  else if (k === 'm') V.muted = !V.muted;
  else if (k === 'Escape' && !document.fullscreenElement) { if (!$('#menu').classList.contains('hidden')) hideMenu(); else closePlayer(false); }
  showUi();
});

/* menus */
const menu = $('#menu');
function hideMenu() { menu.classList.add('hidden'); menu.innerHTML = ''; }
function mi(label, on, attrs, small) { return `<button class="mi" ${attrs}><span class="ck">${on ? '✓' : ''}</span><span>${label}</span>${small ? `<span class="sm">${small}</span>` : ''}</button>`; }
$('#bQual').onclick = (e) => {
  e.stopPropagation();
  if (!S || !S.info) return;
  if (!menu.classList.contains('hidden') && menu.dataset.kind === 'q') { hideMenu(); return; }
  const i = S.info, vi = i.video || {};
  const origPlayable = (i.direct && S.a === 0) || (i.copyVideo && canPlayCodec(vi.codec));
  let h = '<h4>Quality</h4>';
  const top = (i.qualities && i.qualities[0]) ? i.qualities[0].label : '';
  h += mi('Auto', S.qPref === 'auto', 'data-q="auto"', (top ? top + ', ' : '') + 'converted by the PlayTorrio PC');
  for (const q of i.qualities || []) h += mi(q.label, S.qPref === q.id, `data-q="${q.id}"`, (q.kbps / 1000).toFixed(1) + ' Mbps');
  h += mi(`Original${vi.height ? ' · ' + vi.height + 'p' : ''}`, S.qPref === 'original', 'data-q="original"', origPlayable ? 'untouched, this device decodes it' : 'full size, converted (browser can\'t play ' + esc((vi.codec || '?').toUpperCase()) + ')');
  menu.innerHTML = h; menu.dataset.kind = 'q'; menu.classList.remove('hidden');
  menu.onclick = (ev) => {
    const b = ev.target.closest('[data-q]'); if (!b) return;
    const t = pos();
    S.qPref = b.dataset.q; hideMenu();
    try { localStorage.setItem('pt_quality', S.qPref); } catch (_) {}
    const next = effectiveQuality();
    if (next !== S.q) chooseAndLoad(t); else $('#bQual').textContent = qualityLabel();
  };
  showUi();
};
$('#bSubs').onclick = async (e) => {
  e.stopPropagation();
  if (!S || !S.info) return;
  if (!menu.classList.contains('hidden') && menu.dataset.kind === 's') { hideMenu(); return; }
  menu.dataset.kind = 's';
  const draw = () => {
    let h = '';
    const aud = S.info.audio || [];
    if (aud.length > 1) {
      h += '<h4>Audio</h4>';
      for (const a of aud) h += mi(esc(langName(a.lang) || ('Track ' + (a.index + 1))) + (a.title ? ' · ' + esc(a.title) : ''), S.a === a.index, `data-a="${a.index}"`, esc((a.codec || '').toUpperCase()) + (a.channels > 2 ? ' ' + (a.channels === 6 ? '5.1' : a.channels === 8 ? '7.1' : a.channels + 'ch') : ''));
    }
    h += '<h4>Subtitles</h4>' + mi('Off', S.subId < 0, 'data-s="-1"');
    if (!S.subs) h += '<div class="mi" style="cursor:default"><span class="ck"></span><span class="spin" style="width:14px;height:14px;border-width:2px"></span><span>Finding subtitles…</span></div>';
    else if (!S.subs.length) h += '<div class="mi" style="cursor:default;color:var(--subtle)"><span class="ck"></span>None found</div>';
    else for (const s of S.subs) h += mi(esc(s.lang), S.subId === s.id, `data-s="${s.id}"`, esc(((s.provider || '') + (s.label && s.label !== s.lang ? ' · ' + s.label : '')).slice(0, 60)));
    menu.innerHTML = h;
  };
  draw(); menu.classList.remove('hidden'); showUi();
  menu.onclick = async (ev) => {
    const a = ev.target.closest('[data-a]');
    if (a) { const t = pos(); S.a = Number(a.dataset.a); hideMenu(); chooseAndLoad(t); toast('Switching audio…'); return; }
    const s = ev.target.closest('[data-s]'); if (!s) return;
    const id = Number(s.dataset.s); hideMenu();
    if (id < 0) { S.subId = -1; S.subCues = null; $('#subs').innerHTML = ''; return; }
    toast('Loading subtitles…');
    try {
      const my = S;
      const r = await fetch(`api/sub?sid=${S.sid}&id=${id}`);
      if (!r.ok) throw new Error('download failed');
      const cues = parseVtt(await r.text());
      if (my !== S) return;
      if (!cues.length) throw new Error('empty file');
      S.subId = id; S.subCues = cues; toast('Subtitles on');
    } catch (err) { toast('Couldn\'t load that subtitle (' + err.message + '). Try another.'); }
  };
  if (!S.subs) {
    const my = S;
    try { const r = await api('api/subs?sid=' + S.sid); if (my === S) my.subs = r.subs || []; } catch (_) { if (my === S) my.subs = []; }
    if (my === S && menu.dataset.kind === 's' && !menu.classList.contains('hidden')) draw();
  }
};
document.addEventListener('click', (e) => { if (!menu.contains(e.target) && !menu.classList.contains('hidden') && !e.target.closest('#bQual,#bSubs')) hideMenu(); });
const LANGS = {eng: 'English', en: 'English', jpn: 'Japanese', ja: 'Japanese', spa: 'Spanish', es: 'Spanish', fre: 'French', fra: 'French', fr: 'French', ger: 'German', deu: 'German', de: 'German', ita: 'Italian', it: 'Italian', por: 'Portuguese', pt: 'Portuguese', rus: 'Russian', ru: 'Russian', hin: 'Hindi', hi: 'Hindi', kor: 'Korean', ko: 'Korean', chi: 'Chinese', zho: 'Chinese', zh: 'Chinese', ara: 'Arabic', ar: 'Arabic', tur: 'Turkish', pol: 'Polish', dut: 'Dutch', nld: 'Dutch', swe: 'Swedish'};
function langName(l) { return l ? (LANGS[l.toLowerCase()] || l.toUpperCase()) : ''; }

/* subtitles */
function parseVtt(text) {
  const cues = [];
  const re = /(?:(\d+):)?(\d{1,2}):(\d{2})[.,](\d{1,3})\s*-->\s*(?:(\d+):)?(\d{1,2}):(\d{2})[.,](\d{1,3})/;
  const toS = (h, m, s, ms) => (Number(h || 0) * 3600) + Number(m) * 60 + Number(s) + Number((ms + '00').slice(0, 3)) / 1000;
  for (const block of text.replace(/\r/g, '').split(/\n\s*\n/)) {
    const lines = block.split('\n');
    const i = lines.findIndex((l) => re.test(l));
    if (i < 0) continue;
    const m = lines[i].match(re);
    const body = lines.slice(i + 1).join('\n').replace(/<(?!\/?(i|b|u)>)[^>]+>/g, '').trim();
    if (body) cues.push({s: toS(m[1], m[2], m[3], m[4]), e: toS(m[5], m[6], m[7], m[8]), t: body});
  }
  return cues.sort((a, b) => a.s - b.s);
}
let lastSubHtml = '';
function drawSubs() {
  if (!S || !S.subCues) { if (lastSubHtml) { $('#subs').innerHTML = ''; lastSubHtml = ''; } return; }
  const t = pos();
  const on = S.subCues.filter((c) => t >= c.s && t <= c.e);
  const html = on.map((c) => `<span>${c.t.replace(/&/g, '&amp;').replace(/<(?!\/?(i|b|u)>)/g, '&lt;')}</span>`).join('<br>');
  if (html !== lastSubHtml) { $('#subs').innerHTML = html; lastSubHtml = html; }
}

/* ticker */
function tick() {
  if (player.open && S) {
    drawSeek();
    drawSubs();
    if (S.info && !V.paused && Date.now() - S.lastSave > 5000) { S.lastSave = Date.now(); saveNow(); }
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
window.addEventListener('pagehide', () => { saveNow(); stopSession(); });

let toastTimer = null;
function toast(msg) {
  let t = $('.toast', P);
  if (!t) { t = document.createElement('div'); t.className = 'toast'; P.appendChild(t); }
  t.textContent = msg;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.remove(), 3500);
}

/* boot */
api('api/status').then((s) => { ffmpegOk = !!s.ffmpeg; if (!ffmpegOk && (location.hash || '#/') === '#/') renderHome(); }).catch(() => {});
route();
})();
</script>
</body>
</html>
''';
