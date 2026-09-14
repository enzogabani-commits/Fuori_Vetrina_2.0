'use strict';

const body = document.body;
const themeToggle = document.getElementById('themeToggle');
const menuToggle = document.getElementById('menuToggle');
const mobileNav = document.getElementById('mobileNav');
const toast = document.getElementById('toast');
const dialog = document.getElementById('readingDialog');
const dialogContent = document.getElementById('dialogContent');

const storedTheme = localStorage.getItem('fuori-vetrina-theme');
if (storedTheme === 'dark') body.classList.add('dark');
updateThemeButton();

function updateThemeButton(){
  const dark = body.classList.contains('dark');
  themeToggle.setAttribute('aria-label', dark ? 'Attiva modalità chiara' : 'Attiva modalità scura');
  themeToggle.title = dark ? 'Modalità chiara' : 'Modalità scura';
}

themeToggle.addEventListener('click', () => {
  body.classList.toggle('dark');
  localStorage.setItem('fuori-vetrina-theme', body.classList.contains('dark') ? 'dark' : 'light');
  updateThemeButton();
});

menuToggle.addEventListener('click', () => {
  const open = menuToggle.getAttribute('aria-expanded') === 'true';
  menuToggle.setAttribute('aria-expanded', String(!open));
  mobileNav.hidden = open;
});

mobileNav.querySelectorAll('a').forEach(a => a.addEventListener('click', () => {
  mobileNav.hidden = true;
  menuToggle.setAttribute('aria-expanded','false');
}));

document.querySelectorAll('[data-toast]').forEach(btn => btn.addEventListener('click', () => showToast(btn.dataset.toast)));
document.querySelectorAll('[data-comment]').forEach(btn => btn.addEventListener('click', () => showToast('I commenti saranno attivati con il sistema di moderazione definitivo.')));
document.querySelectorAll('[data-share]').forEach(btn => btn.addEventListener('click', () => shareText(btn.dataset.share)));

document.querySelectorAll('[data-category]').forEach(btn => btn.addEventListener('click', () => {
  document.getElementById('categoryFilter').value = btn.dataset.category;
  document.getElementById('storie').scrollIntoView({behavior:'smooth'});
  renderStories();
}));

const stories = [];
async function loadStories() {
    try {
        const response = await fetch('/api/stories');
                                        
        if (!response.ok) {
            throw new Error(`Errore API: ${response.status}`);
        }

        const data = await response.json();

        stories.push(...data);
        renderStories();
    } catch (error) {
        console.error('Errore caricamento storie:', error);
    }
}
loadStories();
const searchInput = document.getElementById('searchInput');
const categoryFilter = document.getElementById('categoryFilter');
searchInput.addEventListener('input', renderStories);
categoryFilter.addEventListener('change', renderStories);

function renderStories(){
  const list = document.getElementById('storyList');
  const q = searchInput.value.trim().toLowerCase();
  const cat = categoryFilter.value;
  const found = stories.filter(s => (cat === 'all' || s.category.toLowerCase() === cat) && (!q || `${s.title} ${s.body} ${s.category} ${s.name}`.toLowerCase().includes(q)));
  if (!found.length) {
    list.innerHTML = '<div class="empty-state">Non ci sono contenuti pubblici che corrispondono alla ricerca. I contenuti verranno aggiunti solo dopo verifica editoriale.</div>';
    return;
  }
  list.innerHTML = found.map(s => `<article class="reading-card"><div class="reading-icon">${escapeHtml(s.category.slice(0,2).toUpperCase())}</div><div><span class="tag">${escapeHtml(s.category)}</span><h3>${escapeHtml(s.title)}</h3><p>${escapeHtml(s.body.slice(0,180))}${s.body.length>180?'…':''}</p><p class="source">${escapeHtml(s.name || 'Anonimo')}</p><button class="text-btn" type="button" data-story-id="${s.id}">Leggi →</button></div></article>`).join('');
  list.querySelectorAll('[data-story-id]').forEach(btn => btn.addEventListener('click', () => openStory(Number(btn.dataset.storyId))));
}
renderStories();

function openStory(id){
  const s = stories.find(x => Number(x.id) === Number(id));
  if(!s) return;
  dialogContent.innerHTML = `<span class="tag">${escapeHtml(s.category)}</span><h2>${escapeHtml(s.title)}</h2><p class="source">${escapeHtml(s.name || 'Anonimo')}</p><p>${escapeHtml(s.body).replace(/\n/g,'</p><p>')}</p>`;
  dialog.showModal();
}

document.querySelectorAll('[data-open-reading]').forEach(btn => btn.addEventListener('click', () => {
  const isPoem = btn.dataset.openReading === 'poem';
  dialogContent.innerHTML = `<span class="tag">${isPoem ? 'Poesia' : 'Racconto'}</span><h2>Contenuto da selezionare</h2><p>Questa è una funzione pronta per il contenuto editoriale definitivo. Prima della pubblicazione inseriremo soltanto un testo scelto e verificato, con autore, opera, fonte e diritti controllati.</p>`;
  dialog.showModal();
}));
dialog.querySelector('.modal-close').addEventListener('click', () => dialog.close());
dialog.addEventListener('click', e => { if(e.target === dialog) dialog.close(); });

document.getElementById('storyForm').addEventListener('submit', async e => {
  e.preventDefault();

  const form = e.currentTarget;
  const data = new FormData(form);

  const categoryIds = {
    Vita: 1,
    Esperienze: 2,
    Persone: 3,
    Pensieri: 4,
    Incontri: 5,
    Curiosità: 6
  };

  const category = data.get('category');
  const category_id = categoryIds[category];
  console.log("PROVA DATI:", { category, category_id, title: data.get('title'), body: data.get('story') });
  if (!category_id) {
    document.getElementById('formStatus').textContent =
      'Seleziona una categoria valida.';
    return;
  }
 
    const payload = {
    author_name: data.get('name')?.trim() || 'Anonimo',
    title: data.get('title')?.trim(),
    body: data.get('body')?.trim(),
    category_id: category_id,
    consent_confirmed: data.get('consent') === 'on'
  };

  try {
    const response = await fetch('http://localhost:3000/api/stories', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });

    const result = await response.json();

    if (!response.ok) {
      throw new Error(result.error || 'Errore durante l’invio');
    }

    document.getElementById('formStatus').textContent =
      'Grazie. Il tuo contributo è stato ricevuto e sarà letto prima della pubblicazione.';

    form.reset();

  } catch (error) {
    console.error('Errore invio contributo:', error);
    document.getElementById('formStatus').textContent =
      'Non è stato possibile inviare il contributo. Riprova tra poco.';
  }
});

async function shareText(label){
  const data = {title:'Fuori Vetrina', text:label, url:location.href};
  if(navigator.share){ try{ await navigator.share(data); }catch{} }
  else { try{ await navigator.clipboard.writeText(location.href); showToast('Link copiato negli appunti.'); }catch{ showToast('Copia questo indirizzo per condividere.'); } }
}
function showToast(message){
  toast.textContent = message; toast.classList.add('show'); clearTimeout(showToast.timer); showToast.timer=setTimeout(()=>toast.classList.remove('show'),3000);
}
function escapeHtml(value){return String(value).replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));}
