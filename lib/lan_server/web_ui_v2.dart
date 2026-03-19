const String lanlockWebIndexHtmlV2 = r'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Lanlock</title>
  <style>
    :root{
      --bg: #09090b;
      --card: #111214;
      --card-2: #141518;
      --border: #232429;
      --muted: #a1a1aa;
      --text: #fafafa;
      --accent: #3f3f46;
      --ring: #6366f1;
      --danger: #b91c1c;
      --radius: 12px;
      --shadow: 0 8px 24px rgba(0,0,0,.35);
    }

    *{box-sizing:border-box}
    html,body{height:100%}
    body{
      margin:0;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif;
      background: radial-gradient(1200px 500px at 50% -220px, rgba(99,102,241,.10), transparent 45%), var(--bg);
      color: var(--text);
      line-height: 1.4;
      overflow-x: hidden;
    }

    .app{
      max-width: 1280px;
      margin: 0 auto;
      padding: 20px 16px 32px;
    }

    .topbar{
      position: sticky;
      top: 10px;
      z-index: 10;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 12px 14px;
      border: 1px solid var(--border);
      background: rgba(17,18,20,.85);
      backdrop-filter: blur(8px);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
    }

    .title h1{
      margin: 0;
      font-size: 15px;
      font-weight: 700;
      letter-spacing: .1px;
    }
    .title p{
      margin: 2px 0 0;
      color: var(--muted);
      font-size: 12px;
    }

    .row{
      display:flex;
      align-items:center;
      gap: 8px;
      flex-wrap: wrap;
    }
    .topbar .controls{
      justify-content: flex-end;
      flex: 1;
    }

    .input, .btn{
      border-radius: 10px;
      border: 1px solid var(--border);
      background: var(--card-2);
      color: var(--text);
      padding: 10px 12px;
      font: inherit;
      outline: none;
    }
    .input::placeholder{color:#71717a}
    .input:focus{
      border-color: var(--ring);
      box-shadow: 0 0 0 2px rgba(99,102,241,.2);
    }

    .btn{
      cursor: pointer;
      background: #1a1b1f;
      transition: background .12s ease, border-color .12s ease;
      user-select: none;
    }
    .btn:hover{background:#202228}
    .btn:active{background:#262830}
    .btn.primary{
      background: #24263a;
      border-color: #34365a;
    }
    .btn.primary:hover{background:#2b2d45}
    .btn.danger{
      background: #2a1718;
      border-color: #4b2326;
      color: #fecaca;
    }

    @media (max-width: 760px){
      .topbar{
        flex-direction: column;
        align-items: stretch;
        gap: 10px;
      }
      .topbar .title{
        display: flex;
        flex-direction: column;
        gap: 2px;
      }
      .topbar .controls{
        width: 100%;
        justify-content: stretch;
      }
      .topbar .controls .input{
        flex: 1 1 100%;
        width: 100% !important;
      }
      .topbar .controls .btn{
        flex: 1 1 auto;
        min-width: 0;
      }
    }

    .layout{
      margin-top: 14px;
      display: grid;
      grid-template-columns: 1fr;
      gap: 12px;
    }
    @media (min-width: 1024px){
      .layout{grid-template-columns: 360px minmax(0,1fr)}
    }

    .panel{
      border: 1px solid var(--border);
      background: var(--card);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
      min-height: 0;
      overflow: hidden;
    }
    .panel-head{
      display:flex;
      align-items:center;
      justify-content:space-between;
      gap:8px;
      padding: 12px 14px;
      border-bottom: 1px solid var(--border);
      background: rgba(255,255,255,.01);
    }
    .panel-head h2{
      margin: 0;
      font-size: 13px;
      font-weight: 600;
      color: #e4e4e7;
      letter-spacing: .1px;
    }
    .panel-body{padding: 12px}

    .muted{
      color: var(--muted);
      font-size: 12px;
    }

    .profiles{
      display: flex;
      flex-direction: column;
      gap: 8px;
      max-height: calc(100vh - 220px);
      overflow: auto;
      padding-right: 2px;
    }
    .profiles::-webkit-scrollbar{width:10px}
    .profiles::-webkit-scrollbar-thumb{
      background: #2f3138;
      border-radius: 999px;
      border: 2px solid transparent;
      background-clip: content-box;
    }

    .profile{
      border: 1px solid var(--border);
      background: #15161a;
      border-radius: 10px;
      padding: 10px 11px;
      cursor: pointer;
      transition: border-color .12s ease, background .12s ease;
    }
    .profile:hover{
      border-color: #3a3d47;
      background: #171920;
    }
    .profile.active{
      border-color: #4f46e5;
      background: #1b1d2c;
    }
    .profile-name{
      font-size: 13px;
      font-weight: 600;
      color: #f4f4f5;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .profile-id{
      margin-top: 6px;
      font-size: 11px;
      color: #a1a1aa;
    }

    .section{
      border: 1px solid var(--border);
      background: #15161a;
      border-radius: 10px;
      padding: 12px;
      margin-bottom: 10px;
    }
    .section:last-child{margin-bottom:0}
    .section h3{
      margin: 0 0 10px;
      font-size: 12px;
      font-weight: 600;
      color: #e4e4e7;
      letter-spacing: .1px;
    }

    .meta-list{display:flex; flex-direction:column; gap:8px}
    .meta-row{
      border: 1px solid var(--border);
      background: #17181c;
      border-radius: 9px;
      padding: 9px 10px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
    }
    .meta-key{
      min-width: 0;
      max-width: 62%;
      font-size: 12.5px;
      font-weight: 600;
      color: #f4f4f5;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .meta-actions{
      display:flex;
      gap:6px;
      flex-wrap: wrap;
      justify-content:flex-end;
    }
    .btn.sm{
      padding: 7px 10px;
      font-size: 12px;
      border-radius: 8px;
    }

    /* login */
    .login-wrap{
      max-width: 460px;
      margin: 10vh auto 0;
      padding: 0 14px;
    }

    /* modal */
    .overlay{
      position: fixed;
      inset: 0;
      display: none;
      align-items: center;
      justify-content: center;
      background: rgba(0,0,0,.65);
      padding: 14px;
      z-index: 50;
    }
    .modal{
      width: min(760px, 100%);
      border: 1px solid var(--border);
      background: #121317;
      border-radius: 12px;
      overflow: hidden;
      box-shadow: var(--shadow);
    }
    .modal-head, .modal-foot{
      padding: 12px 14px;
      border-bottom: 1px solid var(--border);
      display:flex;
      align-items:center;
      justify-content:space-between;
      gap:8px;
    }
    .modal-foot{
      border-bottom: 0;
      border-top: 1px solid var(--border);
      justify-content:flex-end;
    }
    .modal-head h4{
      margin:0;
      font-size: 13px;
      font-weight: 600;
      color: #f4f4f5;
    }
    .modal-body{padding: 14px}
    pre{
      margin:0;
      padding: 12px;
      border-radius: 10px;
      border: 1px solid var(--border);
      background: #15161a;
      white-space: pre-wrap;
      word-break: break-word;
      max-height: 360px;
      overflow:auto;
      color: #e4e4e7;
      font-size: 13px;
    }

    /* toast */
    .toast{
      position: fixed;
      left: 50%;
      bottom: 16px;
      transform: translateX(-50%);
      border: 1px solid var(--border);
      background: #15161a;
      color: #f4f4f5;
      border-radius: 10px;
      padding: 10px 12px;
      max-width: min(560px, calc(100% - 20px));
      display: none;
      z-index: 60;
      box-shadow: var(--shadow);
      font-size: 13px;
    }
    .toast.show{display:block}
  </style>
</head>
<body>
  <div class="toast" id="toast"></div>

  <div class="overlay" id="overlay">
    <div class="modal" role="dialog" aria-modal="true">
      <div class="modal-head">
        <h4 id="mTitle">Modal</h4>
        <button class="btn sm" id="mClose">Close</button>
      </div>
      <div class="modal-body" id="mBody"></div>
      <div class="modal-foot" id="mFoot"></div>
    </div>
  </div>

  <div class="login-wrap" id="login">
    <div class="panel">
      <div class="panel-head">
        <h2>Lanlock Login</h2>
      </div>
      <div class="panel-body">
        <p class="muted" style="margin:0 0 10px">Enter the server password configured in the app.</p>
        <div class="row">
          <input class="input" id="pw" type="password" placeholder="Server password" style="flex:1; min-width:220px" />
          <button class="btn primary" id="btnLogin" style="min-width:96px">Login</button>
        </div>
      </div>
    </div>
  </div>

  <div class="app" id="app" style="display:none">
    <div class="topbar">
      <div class="title">
        <h1>Lanlock</h1>
        <p>Read-only password profiles</p>
      </div>
      <div class="row controls">
        <input class="input" id="q" placeholder="Search profiles..." style="width:240px; max-width:70vw" />
        <button class="btn" id="btnRefresh">Refresh</button>
        <button class="btn danger" id="btnLogout">Logout</button>
      </div>
    </div>

    <div class="layout">
      <div class="panel">
        <div class="panel-head">
          <h2>Profiles</h2>
          <span class="muted" id="profilesCount">0</span>
        </div>
        <div class="panel-body">
          <div class="profiles" id="plist"></div>
        </div>
      </div>

      <div class="panel">
        <div class="panel-head">
          <h2 id="detailTitle">Details</h2>
          <span class="muted" id="detailSub"></span>
        </div>
        <div class="panel-body" id="detail">
          <span class="muted">Select a profile from the list.</span>
        </div>
      </div>
    </div>
  </div>

  <script>
    const $ = (id) => document.getElementById(id);

    function toast(msg, ok=true){
      const t = $('toast');
      t.textContent = msg;
      t.style.borderColor = ok ? '#264e36' : '#5b2026';
      t.classList.add('show');
      clearTimeout(window.__toastTimer);
      window.__toastTimer = setTimeout(()=>t.classList.remove('show'), 2400);
    }

    function escapeHtml(str){
      return (str ?? '').toString().replace(/[&<>"']/g, (c)=>({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]));
    }

    async function copyText(text){
      try{
        if (navigator.clipboard && window.isSecureContext){
          await navigator.clipboard.writeText(text);
          return true;
        }
      }catch(_){}
      try{
        const ta = document.createElement('textarea');
        ta.value = text;
        ta.setAttribute('readonly', '');
        ta.style.position = 'fixed';
        ta.style.top = '-1000px';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.select();
        ta.setSelectionRange(0, ta.value.length);
        const ok = document.execCommand('copy');
        document.body.removeChild(ta);
        return ok;
      }catch(_){
        return false;
      }
    }

    const overlay = $('overlay');
    $('mClose').onclick = () => overlay.style.display = 'none';
    overlay.onclick = (e) => { if (e.target === overlay) overlay.style.display = 'none'; };

    function openModal(title, bodyHtml, footButtons){
      $('mTitle').textContent = title;
      $('mBody').innerHTML = bodyHtml;
      const foot = $('mFoot');
      foot.innerHTML = '';
      (footButtons || []).forEach((b) => {
        const btn = document.createElement('button');
        btn.textContent = b.text;
        btn.className = 'btn' + (b.kind === 'primary' ? ' primary' : '');
        if (b.kind === 'danger') btn.className += ' danger';
        btn.onclick = b.onClick;
        foot.appendChild(btn);
      });
      overlay.style.display = 'flex';
    }

    async function api(path, opts={}){
      const res = await fetch(path, Object.assign({credentials:'same-origin'}, opts));
      const ct = res.headers.get('content-type') || '';
      const data = ct.includes('application/json') ? await res.json().catch(()=>null) : await res.text().catch(()=>null);
      if (res.status === 401) throw new Error('unauthorized');
      if (!res.ok){
        const msg = (data && data.error) ? data.error : (typeof data === 'string' ? data : 'request failed');
        throw new Error(msg);
      }
      return data;
    }

    function setLoginVisible(show){
      $('login').style.display = show ? 'block' : 'none';
      $('app').style.display = show ? 'none' : 'block';
    }

    async function ensureAuth(){
      try{
        await api('/api/me');
        setLoginVisible(false);
        return true;
      }catch(_){
        setLoginVisible(true);
        return false;
      }
    }

    let profiles = [];
    let selected = null;
    let metaLoadToken = 0;

    function renderProfiles(){
      const plist = $('plist');
      plist.innerHTML = '';
      $('profilesCount').textContent = String(profiles.length);
      if (!profiles.length){
        plist.innerHTML = '<span class="muted">No profiles found.</span>';
        return;
      }
      profiles.forEach((p) => {
        const div = document.createElement('div');
        div.className = 'profile' + (selected && selected.id === p.id ? ' active' : '');
        div.innerHTML = `
          <div class="profile-name" title="${escapeHtml(p.name)}">${escapeHtml(p.name)}</div>
          <div class="profile-id">#${p.id}</div>
        `;
        div.onclick = () => selectProfile(p);
        plist.appendChild(div);
      });
    }

    function renderDetail(){
      if (!selected){
        $('detail').innerHTML = '<span class="muted">Select a profile from the list.</span>';
        $('detailTitle').textContent = 'Details';
        $('detailSub').textContent = '';
        return;
      }

      $('detailTitle').textContent = selected.name;
      $('detailSub').textContent = 'ID ' + selected.id;
      $('detail').innerHTML = `
        <div class="section">
          <h3>Password</h3>
          <div class="row">
            <button class="btn sm" id="btnViewPw">View</button>
            <button class="btn sm" id="btnCopyPw">Copy</button>
          </div>
          <p class="muted" style="margin:10px 0 0">Password is decrypted only after successful login.</p>
        </div>

        <div class="section">
          <h3>Metadata Keys</h3>
          <div class="meta-list" id="metaList"></div>
        </div>
      `;

      $('btnViewPw').onclick = async () => {
        const d = await api('/api/profile/' + selected.id + '/password');
        openModal('Password', '<pre>' + escapeHtml(d.password) + '</pre>', [
          { text:'Copy', kind:'primary', onClick: async () => {
            const ok = await copyText(d.password);
            toast(ok ? 'Copied' : 'Copy blocked by browser', ok);
            overlay.style.display = 'none';
          }},
          { text:'Close', onClick: () => overlay.style.display = 'none' }
        ]);
      };

      $('btnCopyPw').onclick = async () => {
        const d = await api('/api/profile/' + selected.id + '/password');
        const ok = await copyText(d.password);
        toast(ok ? 'Password copied' : 'Copy blocked by browser', ok);
      };
    }

    async function loadMeta(profileId){
      const token = ++metaLoadToken;
      const metaList = $('metaList');
      if (!metaList) return;
      metaList.innerHTML = '<span class="muted">Loading metadata...</span>';
      const d = await api('/api/profile/' + profileId + '/meta_keys');
      if (token !== metaLoadToken || !selected || selected.id !== profileId) return;

      const keys = d.keys || [];
      if (!keys.length){
        metaList.innerHTML = '<span class="muted">No metadata found for this profile.</span>';
        return;
      }

      metaList.innerHTML = '';
      keys.forEach((k) => {
        const row = document.createElement('div');
        row.className = 'meta-row';
        row.innerHTML = `
          <div class="meta-key" title="${escapeHtml(k.keyName)}">${escapeHtml(k.keyName)}</div>
          <div class="meta-actions">
            <button class="btn sm" data-a="view">View</button>
            <button class="btn sm" data-a="copy">Copy</button>
          </div>
        `;
        row.querySelector('[data-a="view"]').onclick = async () => {
          const v = await api('/api/meta/' + k.id + '/value');
          openModal(k.keyName, '<pre>' + escapeHtml(v.value) + '</pre>', [
            { text:'Copy', kind:'primary', onClick: async () => {
              const ok = await copyText(v.value);
              toast(ok ? 'Copied' : 'Copy blocked by browser', ok);
              overlay.style.display = 'none';
            }},
            { text:'Close', onClick: () => overlay.style.display = 'none' }
          ]);
        };
        row.querySelector('[data-a="copy"]').onclick = async () => {
          const v = await api('/api/meta/' + k.id + '/value');
          const ok = await copyText(v.value);
          toast(ok ? 'Value copied' : 'Copy blocked by browser', ok);
        };
        metaList.appendChild(row);
      });
    }

    async function selectProfile(p){
      selected = p;
      renderProfiles();
      renderDetail();
      await loadMeta(selected.id);
    }

    async function refreshProfiles(){
      const q = $('q').value.trim();
      const d = await api('/api/profiles' + (q ? ('?q=' + encodeURIComponent(q)) : ''));
      profiles = d.profiles || [];
      if (selected && !profiles.find((x) => x.id === selected.id)) selected = null;

      renderProfiles();
      if (!selected && profiles.length) {
        await selectProfile(profiles[0]);
      } else if (!selected) {
        renderDetail();
      } else {
        await selectProfile(selected);
      }
    }

    $('btnRefresh').onclick = async () => { await refreshProfiles(); };
    $('q').addEventListener('input', () => {
      clearTimeout(window.__qTimer);
      window.__qTimer = setTimeout(refreshProfiles, 250);
    });

    $('btnLogout').onclick = async () => {
      try { await api('/api/logout', {method:'POST', body:'{}'}); } catch(_) {}
      selected = null;
      setLoginVisible(true);
    };

    $('btnLogin').onclick = async () => {
      const pw = $('pw').value || '';
      if (!pw) return;
      try{
        await api('/api/login', {method:'POST', body: JSON.stringify({password: pw})});
        $('pw').value = '';
        toast('Welcome');
        const ok = await ensureAuth();
        if (ok) await refreshProfiles();
      }catch(_){
        toast('Wrong password', false);
      }
    };
    $('pw').addEventListener('keydown', (e) => {
      if (e.key === 'Enter') $('btnLogin').click();
    });

    (async () => {
      const ok = await ensureAuth();
      if (ok) await refreshProfiles();
    })();
  </script>
</body>
</html>''';

