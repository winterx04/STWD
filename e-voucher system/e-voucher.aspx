<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="0">
<title>E-Voucher Request System</title>
<link rel="icon" type="image/png" href="https://raw.githubusercontent.com/winterx04/STWD/main/icons/e-voucher.png">
<script>
  // Bump this string every time this file is re-uploaded to the document library.
  // Browsers/SharePoint can keep serving an old cached copy of this page after a
  // re-upload; this quietly re-fetches the page in the background (bypassing the
  // HTTP cache) and force-reloads once if the server's copy has a newer version.
  window.__EVOUCHER_VERSION__ = '2026.10.24.20';
  (function(){
    // Never do this during a sign-in redirect round trip - its response (code/state/
    // session_state) lives in the query string or hash of THIS exact page load, and a
    // forced navigation here would wipe it out before MSAL reads it.
    var looksLikeAuthCallback = /[?&#](code|error)=/.test(location.href);
    if (looksLikeAuthCallback) return;
    // A plain browser refresh re-runs whatever copy of this file is already in the
    // browser's HTTP cache, which can be older than what's actually on SharePoint - this
    // re-fetches the real, current file (bypassing that cache) and reloads once if it's
    // different, so refreshing always ends up running the latest uploaded code. Safe to
    // do even while signed in: MSAL's account/token cache lives in sessionStorage, which
    // survives a same-tab reload, so the user stays signed in across it.
    if (sessionStorage.getItem('evoucherReloadedFor') === window.__EVOUCHER_VERSION__) return;
    // If the user starts typing/clicking before the version check below comes back, don't
    // yank the page out from under them mid-keystroke - a forced reload landing right then
    // would silently wipe whatever they'd just typed (e.g. a matter number), which reads as
    // "my input doesn't show, a blank new voucher form appears instead" (reported 2026-10-20).
    // Just skip the reload this one time; the next genuine page load/refresh (when they're
    // not actively typing) will pick up the new version as normal.
    var userInteracted = false;
    document.addEventListener('input', function(){ userInteracted = true; }, { capture: true, once: true });
    document.addEventListener('keydown', function(){ userInteracted = true; }, { capture: true, once: true });
    fetch(location.pathname + location.search, { cache: 'no-store' }).then(function(res){
      return res.text();
    }).then(function(html){
      var m = html.match(/__EVOUCHER_VERSION__\s*=\s*'([^']+)'/);
      if (m && m[1] && m[1] !== window.__EVOUCHER_VERSION__ && !userInteracted){
        sessionStorage.setItem('evoucherReloadedFor', m[1]);
        var url = new URL(location.href);
        url.searchParams.set('_v', Date.now());
        location.replace(url.toString());
      }
    }).catch(function(){ /* offline or blocked - don't disrupt the app */ });
  })();
</script>
<script src="https://alcdn.msauth.net/browser/2.38.2/js/msal-browser.min.js"></script>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.7.2/css/all.min.css">
<style>
  :root{
    --primary:#e06c23;
    --primary-dark:#b8551a;
    --primary-light:#fdece0;
    --navy:#01345f;
    --navy-light:#024a85;
    --white:#ffffff;
    --bg:#f2f4f7;
    --border:#dfe4ea;
    --text:#1f2a37;
    --text-muted:#66748a;
    --danger:#d64545;
    --danger-bg:#fdecec;
    --success:#1f8a4c;
    --radius:12px;
    --shadow:0 2px 10px rgba(1,52,95,0.08);
    --sidebar-w:258px;
    --sidebar-w-collapsed:64px;
    --brand-w:340px;
    --topbar-h:92px;
  }
  *,*::before,*::after{box-sizing:border-box;}
  [hidden]{display:none !important;}
  body{
    margin:0;
    overflow-x:hidden;
    font-family:'Segoe UI',system-ui,-apple-system,Roboto,Arial,sans-serif;
    background:var(--bg);
    color:var(--text);
    -webkit-font-smoothing:antialiased;
  }

  /* ---------- App shell ---------- */
  .sidebar{
    position:fixed;top:var(--topbar-h);left:0;bottom:0;width:var(--sidebar-w);
    background:var(--navy);
    display:flex;flex-direction:column;
    overflow-y:auto;overflow-x:hidden;
    z-index:30;
    transition:width .18s ease;
  }

  .nav{display:flex;flex-direction:column;gap:3px;padding:10px;flex:1;}
  .nav-item{
    display:flex;align-items:center;gap:12px;
    padding:10px 12px;border-radius:8px;
    background:none;border:none;cursor:pointer;
    color:rgba(255,255,255,0.65);
    font-size:13px;font-weight:600;font-family:inherit;
    text-align:left;width:100%;
    transition:background .15s, color .15s;
  }
  .nav-item svg{width:18px;height:18px;flex-shrink:0;}
  .nav-item i{width:18px;flex-shrink:0;text-align:center;font-size:15px;}
  .nav-item span{white-space:nowrap;}
  .nav-item:hover{background:rgba(255,255,255,0.08);color:var(--white);}
  .nav-item.active{background:rgba(255,255,255,0.14);color:var(--white);}

  .sidebar-footer{
    padding:14px 18px;
    font-size:11px;
    color:rgba(255,255,255,0.45);
    border-top:1px solid rgba(255,255,255,0.12);
  }

  /* Anchored inside the sidebar's own bottom-right corner (not overflowing it, since the
     sidebar itself scrolls with overflow-y:auto - an overflowing child would either get
     clipped by overflow-x:hidden or force an unwanted horizontal scrollbar). */
  .sidebar-collapse-btn{
    position:absolute;right:14px;bottom:20px;
    width:28px;height:28px;border-radius:50%;
    background:var(--white);color:var(--navy);
    border:1px solid var(--border);box-shadow:var(--shadow);
    display:flex;align-items:center;justify-content:center;
    font-size:12px;cursor:pointer;z-index:31;
    transition:transform .18s ease;
  }
  .sidebar-collapse-btn:hover{color:var(--primary);}

  /* Collapse only applies at desktop widths - below 760px the sidebar already becomes a
     horizontal top nav (see the max-width:760px block further down), which this would
     otherwise conflict with. */
  @media (min-width:761px){
    body.sidebar-collapsed .sidebar{width:var(--sidebar-w-collapsed);}
    body.sidebar-collapsed .nav-item{justify-content:center;padding:10px;}
    body.sidebar-collapsed .nav-item span{display:none;}
    body.sidebar-collapsed .sidebar-collapse-btn{transform:rotate(180deg);}
    body.sidebar-collapsed .main{margin-left:var(--sidebar-w-collapsed);}
    /* Let the form/table actually use the space freed up by collapsing, instead of just
       shifting left and leaving it as empty margin either side. */
    body.sidebar-collapsed .submit-layout{max-width:1400px;}
    body.sidebar-collapsed .view-wrap{max-width:1400px;}
  }

  .main{
    margin-left:var(--sidebar-w);margin-top:var(--topbar-h);
    min-height:calc(100vh - var(--topbar-h));display:flex;flex-direction:column;
    transition:margin-left .18s ease;
  }

  /* ---------- Full-width top bar: brand zone (own width, independent of sidebar) + page zone ---------- */
  .topbar-full{
    position:fixed;top:0;left:0;right:0;height:var(--topbar-h);
    display:flex;
    box-shadow:0 1px 0 var(--border);
    z-index:40;
  }
  .topbar-brand{
    width:var(--brand-w);flex-shrink:0;
    background:var(--white);
    display:flex;align-items:center;justify-content:center;
    padding:0 18px;
  }
  .brand-full-logo{max-width:100%;max-height:64px;width:auto;height:auto;display:block;}

  .topbar-page{
    flex:1;min-width:0;
    background:var(--white);
    padding:0 28px;
    display:flex;align-items:center;justify-content:space-between;
    gap:20px;flex-wrap:wrap;
  }
  .topbar-left{min-width:0;}
  .topbar-left h2{margin:0;font-size:19px;font-weight:700;color:var(--navy);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}
  .topbar-left p{margin:2px 0 0;font-size:13px;color:var(--text-muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}

  .topbar-right{display:flex;align-items:center;gap:26px;flex-wrap:wrap;min-width:0;}

  .profile-chip{display:flex;align-items:center;gap:10px;min-width:0;}
  .profile-avatar{
    width:38px;height:38px;flex-shrink:0;border-radius:50%;
    background:var(--primary);color:var(--white);
    display:flex;align-items:center;justify-content:center;
    font-size:13px;font-weight:700;
  }
  .profile-text{line-height:1.35;min-width:0;overflow:hidden;}
  .profile-name{font-size:13px;font-weight:700;color:var(--navy);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}
  .profile-email{font-size:11.5px;color:var(--text-muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}

  /* ---------- Submit-request layout: form + jump-to-section panel ---------- */
  .submit-layout{display:flex;align-items:flex-start;gap:24px;max-width:1100px;margin:0 auto;transition:max-width .18s ease;}
  .submit-main{flex:1;min-width:0;}
  .submit-tracker-panel{width:230px;flex-shrink:0;position:sticky;top:calc(var(--topbar-h) + 12px);}

  .tracker-card{
    background:var(--white);
    border:1px solid var(--border);
    border-radius:var(--radius);
    box-shadow:var(--shadow);
    padding:18px 16px;
  }
  .tracker-card-label{
    font-size:11px;font-weight:700;letter-spacing:.6px;text-transform:uppercase;
    color:var(--text-muted);
    margin-bottom:8px;
  }
  .jump-list{display:flex;flex-direction:column;}
  .jump-item{
    display:flex;align-items:center;gap:12px;
    height:36px;padding:0 4px;
    background:none;border:none;cursor:pointer;
    text-align:left;width:100%;font-family:inherit;
    border-radius:8px;
    transition:background .15s;
  }
  .jump-item:hover{background:var(--bg);}
  .jump-item:disabled{cursor:default;}
  .jump-item:disabled:hover{background:none;}
  .jump-dot{
    position:relative;
    width:18px;height:18px;flex-shrink:0;border-radius:50%;
    background:var(--border);
    box-sizing:border-box;
    display:flex;align-items:center;justify-content:center;
    transition:background .2s, border-color .2s;
  }
  .jump-dot-check{
    font-size:10px;color:var(--white);line-height:1;
    opacity:0;transform:scale(.4);
    transition:opacity .15s, transform .15s;
  }
  .jump-item:not(:last-child) .jump-dot::after{
    content:'';position:absolute;top:18px;left:50%;transform:translateX(-50%);
    width:2px;height:22px;background:var(--border);
    transition:background .2s;
  }
  .jump-item.done .jump-dot{background:var(--success);}
  .jump-item.done .jump-dot::after{background:var(--success);}
  .jump-item.done .jump-dot-check{opacity:1;transform:scale(1);}
  .jump-item.current .jump-dot{background:var(--primary);box-shadow:0 0 0 4px rgba(224,108,35,0.18);}
  .jump-label{font-size:12.5px;font-weight:600;color:var(--text-muted);transition:color .2s;}
  .jump-item.done .jump-label{color:var(--text);}
  .jump-item.current .jump-label{color:var(--navy);font-weight:700;}

  .tracker-total{margin-top:12px;padding-top:14px;border-top:1px solid var(--border);}
  .tracker-total .stat-label{
    font-size:11px;font-weight:600;letter-spacing:.5px;text-transform:uppercase;
    color:var(--text-muted);
  }
  .tracker-total .stat-value{font-size:18px;font-weight:700;color:var(--navy);margin-top:2px;}

  .content{flex:1;padding:24px 28px 60px;}
  .view-wrap{max-width:1180px;margin:0 auto;transition:max-width .18s ease;}

  @media (max-width:960px){
    .submit-layout{flex-direction:column;align-items:stretch;}
    .submit-tracker-panel{display:none;}
  }

  @media (max-width:760px){
    .topbar-full{position:static;height:auto;flex-direction:column;}
    .topbar-brand{width:100%;padding:10px 16px;}
    .brand-full-logo{max-height:44px;}
    .topbar-page{padding:12px 16px;}
    .sidebar{position:static;width:100%;height:auto;flex-direction:row;align-items:center;padding:0;top:auto;}
    .sidebar-footer{display:none;}
    .sidebar-collapse-btn{display:none;}
    .nav{flex-direction:row;padding:8px;gap:2px;overflow-x:auto;flex:none;}
    .nav-item span{display:none;}
    .nav-item{padding:10px;}
    .main{margin-left:0;margin-top:0;min-height:auto;}
    .profile-email{display:none;}
    .content{padding:16px 16px 50px;}
  }

  @media (max-width:600px){
    .profile-text{display:none;}
  }

  /* ---------- Placeholder views ---------- */
  .placeholder-card{
    background:var(--white);
    border:1.5px dashed var(--border);
    border-radius:var(--radius);
    padding:56px 30px;
    text-align:center;
    max-width:480px;
    margin:40px auto;
  }
  .placeholder-icon{
    width:60px;height:60px;border-radius:50%;
    background:var(--primary-light);color:var(--primary);
    display:flex;align-items:center;justify-content:center;
    margin:0 auto 18px;
  }
  .placeholder-icon svg{width:28px;height:28px;}
  .placeholder-card h3{margin:0 0 8px;color:var(--navy);font-size:17px;}
  .placeholder-card p{margin:0;color:var(--text-muted);font-size:13.5px;line-height:1.5;}

  /* ---------- Cards / form (unchanged from single-page build) ---------- */
  .card{
    background:var(--white);
    border:1px solid var(--border);
    border-radius:var(--radius);
    box-shadow:var(--shadow);
    padding:22px 24px;
    margin-bottom:20px;
    scroll-margin-top:calc(var(--topbar-h) + 12px);
  }
  .card h2{
    margin:0 0 16px;
    font-size:16px;
    color:var(--navy);
    display:flex;
    align-items:center;
    gap:10px;
  }
  .card-icon{color:var(--primary);font-size:15px;}
  .step{
    display:inline-flex;
    align-items:center;justify-content:center;
    width:24px;height:24px;
    border-radius:50%;
    background:var(--primary);
    color:var(--white);
    font-size:11px;font-weight:700;
    flex-shrink:0;
  }

  .grid-2{display:grid;grid-template-columns:1fr 1fr;gap:16px;}
  .grid-3{display:grid;grid-template-columns:1fr 1fr 1fr;gap:16px;}
  .field.full{grid-column:1 / -1;}
  .matter-fields{margin-top:18px;padding-top:18px;border-top:1px solid var(--border);}
  @media (max-width:680px){
    .grid-2,.grid-3{grid-template-columns:1fr;}
  }

  .field{display:flex;flex-direction:column;gap:6px;}
  label{font-size:13px;font-weight:600;color:var(--navy);}
  label .opt{font-weight:400;color:var(--text-muted);}
  input[type=text],input[type=number],input[type=date],select,textarea{
    padding:10px 12px;
    border:1px solid var(--border);
    border-radius:8px;
    font-size:14px;
    font-family:inherit;
    color:var(--text);
    background:var(--white);
    transition:border-color .15s, box-shadow .15s;
    width:100%;
  }
  input:focus,select:focus,textarea:focus{
    outline:none;
    border-color:var(--primary);
    box-shadow:0 0 0 3px rgba(224,108,35,0.15);
  }
  input[readonly]{background:#f7f8fa;color:var(--text-muted);}
  input:disabled,select:disabled,textarea:disabled{
    background:#e3e6eb;color:var(--text-muted);cursor:not-allowed;border-color:var(--border);
  }
  input.invalid,select.invalid{border-color:var(--danger);background:var(--danger-bg);}
  .hint{font-size:12.5px;color:var(--text-muted);margin:8px 0 0;}
  .hint.warning{color:var(--danger);font-weight:600;}

  .alert{
    padding:14px 16px;border-radius:10px;font-size:14px;margin-bottom:18px;
    display:flex;gap:10px;align-items:flex-start;
  }
  .alert-error{background:var(--danger-bg);color:var(--danger);border:1px solid #f3c6c6;}
  .alert ul{margin:6px 0 0;padding-left:18px;}

  .table-wrap{overflow-x:auto;border:1px solid var(--border);border-radius:8px;}
  table{width:100%;border-collapse:collapse;min-width:640px;}
  thead th{
    background:var(--navy);
    color:var(--white);
    font-size:12.5px;
    text-align:left;
    padding:10px 12px;
    white-space:nowrap;
  }
  tbody td{padding:8px;border-top:1px solid var(--border);vertical-align:top;}
  tbody tr:nth-child(even){background:#fafbfc;}
  td input{min-width:110px;}
  td .desc-input{min-width:280px;min-height:40px;resize:vertical;font-family:inherit;line-height:1.4;}
  .char-count{font-size:11px;color:var(--text-muted);text-align:right;margin-top:3px;}
  .char-count.char-count-limit{color:var(--danger);font-weight:700;text-align:left;}
  #lineItemsBody td{vertical-align:middle;}
  td.amount-cell input{text-align:right;min-width:130px;}
  /* Give the description column the lion's share of the row - it's the field most likely
     to need real room, while Invoice No./Amount/the remove button stay compact. */
  #lineItemsTable{table-layout:fixed;}
  #lineItemsTable th{white-space:normal;}
  #lineItemsTable th:nth-child(1),#lineItemsTable td:nth-child(1){width:52%;}
  #lineItemsTable th:nth-child(2),#lineItemsTable td:nth-child(2){width:23%;}
  #lineItemsTable th:nth-child(3),#lineItemsTable td:nth-child(3){width:17%;}
  #lineItemsTable th:nth-child(4),#lineItemsTable td:nth-child(4){width:8%;}
  td.remove-cell{vertical-align:middle;}
  .row-remove{
    background:none;border:none;color:var(--danger);cursor:pointer;
    font-size:18px;line-height:1;padding:4px 8px;border-radius:6px;
  }
  .row-remove:hover{background:var(--danger-bg);}

  .totals{margin-top:18px;}

  .btn{
    display:inline-flex;align-items:center;justify-content:center;gap:8px;
    border:none;border-radius:8px;padding:11px 20px;
    font-size:14px;font-weight:600;cursor:pointer;
    transition:transform .05s, background .15s, box-shadow .15s;
  }
  .btn:active{transform:translateY(1px);}
  .btn-primary{background:var(--primary);color:var(--white);}
  .btn-primary:hover{background:var(--primary-dark);}
  .btn-secondary{background:var(--navy);color:var(--white);}
  .btn-secondary:hover{background:var(--navy-light);}
  .btn-outline{background:var(--white);color:var(--navy);border:1.5px solid var(--navy);}
  .btn-outline:hover{background:#eef3f8;}
  .btn-ghost{background:transparent;color:var(--text-muted);}
  .btn-ghost:hover{color:var(--danger);}
  .btn-success{background:var(--success);color:var(--white);}
  .btn-success:hover{background:#176b3a;}
  .btn-danger{background:var(--danger);color:var(--white);}
  .btn-danger:hover{background:#b93636;}
  .btn:disabled{opacity:.5;cursor:not-allowed;}

  .actions{
    display:flex;justify-content:flex-end;gap:12px;flex-wrap:wrap;
    padding-top:6px;
  }

  .dropzone{
    border:2px dashed var(--border);
    border-radius:10px;
    padding:26px;text-align:center;
    cursor:pointer;
    transition:border-color .15s, background .15s;
    background:#fafbfc;
  }
  .dropzone.drag-over{border-color:var(--primary);background:var(--primary-light);}
  .dropzone.invalid{border-color:var(--danger);background:var(--danger-bg);}
  .dropzone p{margin:4px 0;color:var(--text-muted);font-size:14px;}
  .dropzone-icon{display:block;font-size:26px;color:var(--primary);margin-bottom:10px;}

  /* ---------- Custom dropdown (replaces native <select> popup styling) ---------- */
  .custom-select-wrap{position:relative;}
  .custom-select-wrap select{
    position:absolute;inset:0;width:100%;height:100%;
    opacity:0;pointer-events:none;
  }
  .custom-select-wrap:has(select[hidden]) .cst-trigger,
  .custom-select-wrap:has(select[hidden]) .cst-search-caret,
  .custom-select-wrap:has(select[hidden]) .cst-panel{display:none;}
  .custom-select-wrap:has(select.invalid) .cst-trigger{border-color:var(--danger);background:var(--danger-bg);}
  .custom-select-wrap:has(select:disabled) .cst-trigger,
  .custom-select-wrap:has(select:disabled) .cst-search-caret{cursor:not-allowed;}
  .custom-select-wrap:has(select:disabled) .cst-trigger{background:#e3e6eb;color:var(--text-muted);}
  .cst-trigger{
    display:flex;align-items:center;justify-content:space-between;gap:10px;
    width:100%;padding:10px 12px;
    border:1px solid var(--border);border-radius:8px;
    font-size:14px;font-family:inherit;color:var(--text);
    background:var(--white);cursor:pointer;text-align:left;
    transition:border-color .15s, box-shadow .15s;
  }
  .cst-trigger:focus{outline:none;border-color:var(--primary);box-shadow:0 0 0 3px rgba(224,108,35,0.15);}
  .cst-trigger.open{border-color:var(--primary);}
  .cst-label{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}
  .cst-label.cst-placeholder{color:var(--text-muted);}
  .cst-caret{color:var(--text-muted);font-size:12px;flex-shrink:0;transition:transform .15s;}
  .cst-trigger.open .cst-caret{transform:rotate(180deg);}
  .cst-panel{
    position:absolute;top:100%;left:0;right:0;margin-top:4px;
    background:var(--white);border:1px solid var(--border);border-radius:8px;
    box-shadow:var(--shadow);z-index:20;max-height:240px;overflow-y:auto;
  }
  .cst-option{padding:9px 12px;font-size:14px;cursor:pointer;}
  .cst-option:hover{background:var(--bg);}
  .cst-option.selected{background:var(--primary-light);color:var(--primary-dark);font-weight:600;}
  .cst-option-empty{color:var(--text-muted);cursor:default;}
  .cst-option-empty:hover{background:none;}
  .cst-search-input{cursor:pointer;padding-right:34px;}
  .cst-search-caret{
    position:absolute;top:0;right:12px;bottom:0;
    display:flex;align-items:center;
    color:var(--text-muted);font-size:12px;pointer-events:none;
    transition:transform .15s;
  }
  .cst-search-caret.open{transform:rotate(180deg);}

  .people-picker{position:relative;}
  .people-picker input[type=text]{padding-right:34px;cursor:pointer;}
  .people-picker-caret{
    position:absolute;top:0;right:12px;bottom:0;
    display:flex;align-items:center;
    color:var(--text-muted);font-size:12px;
    pointer-events:none;
    transition:transform .15s;
  }
  .people-picker.open .people-picker-caret{transform:rotate(180deg);}
  .people-suggestions{
    position:absolute;top:100%;left:0;right:0;margin-top:4px;
    background:var(--white);border:1px solid var(--border);border-radius:8px;
    box-shadow:var(--shadow);z-index:20;max-height:240px;overflow-y:auto;
  }
  .people-suggestion{padding:9px 12px;font-size:14px;color:var(--text);cursor:pointer;}
  .people-suggestion:hover,.people-suggestion.active{background:var(--bg);}
  .people-suggestion .p-name{font:inherit;color:inherit;}
  .people-suggestions .p-status{padding:10px 12px;font-size:12.5px;color:var(--text-muted);}
  .dropzone .link{color:var(--primary);font-weight:600;text-decoration:underline;}

  .file-list{list-style:none;margin:14px 0 0;padding:0;display:flex;flex-direction:column;gap:8px;}
  .file-list li{
    display:flex;justify-content:space-between;align-items:center;
    background:#f7f8fa;border:1px solid var(--border);border-radius:8px;
    padding:8px 12px;font-size:13px;
  }
  .file-list button{
    background:none;border:none;color:var(--danger);cursor:pointer;font-size:16px;
  }

  .matrix-info{font-size:14px;}
  .matrix-row{
    display:flex;justify-content:space-between;gap:16px;
    padding:8px 0;border-bottom:1px dashed var(--border);
    flex-wrap:wrap;
  }
  .matrix-row:last-child{border-bottom:none;}
  .matrix-row .label{color:var(--text-muted);font-weight:600;min-width:110px;}
  .matrix-row .value{color:var(--navy);font-weight:700;text-align:right;}
  .matrix-row .value.value-muted{color:var(--text-muted);font-weight:600;font-style:italic;}

  .status-badge{
    display:inline-block;padding:4px 10px;border-radius:20px;
    font-size:11.5px;font-weight:700;white-space:nowrap;
  }
  .status-badge.pending{background:var(--primary-light);color:var(--primary-dark);}
  .status-badge.approved{background:#e3f5ea;color:var(--success);}
  .status-badge.rejected{background:var(--danger-bg);color:var(--danger);}

  .btn-sm{padding:6px 14px;font-size:12.5px;}

  /* ---------- View Requests: stat cards, section headers, modernised table ---------- */
  .stats-row{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-bottom:24px;}
  @media (max-width:680px){.stats-row{grid-template-columns:1fr;}}

  .requests-search{
    position:relative;margin-bottom:18px;
  }
  .requests-search-icon{
    position:absolute;top:0;bottom:0;left:14px;
    display:flex;align-items:center;
    color:var(--text-muted);font-size:14px;pointer-events:none;
  }
  .requests-search input{padding-left:38px;padding-right:38px;}
  .requests-search-clear{
    position:absolute;top:0;bottom:0;right:6px;
    display:flex;align-items:center;justify-content:center;
    width:28px;background:none;border:none;cursor:pointer;
    color:var(--text-muted);font-size:13px;
  }
  .requests-search-clear:hover{color:var(--danger);}
  .stat-card{
    background:var(--white);border:1px solid var(--border);border-radius:var(--radius);
    box-shadow:var(--shadow);padding:18px 20px;display:flex;align-items:center;gap:14px;
    cursor:pointer;user-select:none;transition:border-color .15s,box-shadow .15s,transform .1s;
  }
  .stat-card:hover{border-color:var(--primary);}
  .stat-card:active{transform:scale(.98);}
  .stat-card:focus-visible{outline:none;border-color:var(--primary);box-shadow:0 0 0 3px rgba(224,108,35,0.15);}
  .stat-card.pending .stat-icon{background:var(--primary-light);color:var(--primary-dark);}
  .stat-card.approved .stat-icon{background:#e3f5ea;color:var(--success);}
  .stat-card.rejected .stat-icon{background:var(--danger-bg);color:var(--danger);}
  .stat-card.active{border-color:currentColor;box-shadow:0 0 0 2px rgba(224,108,35,0.18);}
  .stat-card.pending.active{color:var(--primary-dark);}
  .stat-card.approved.active{color:var(--success);}
  .stat-card.rejected.active{color:var(--danger);}
  .stat-card .stat-icon{
    width:46px;height:46px;border-radius:12px;flex-shrink:0;
    display:flex;align-items:center;justify-content:center;font-size:18px;
  }
  .stat-card .stat-num{font-size:24px;font-weight:800;color:var(--navy);line-height:1.1;}
  .stat-card .stat-text{font-size:12.5px;color:var(--text-muted);margin-top:3px;font-weight:600;}
  .stat-filter-hint{
    display:flex;align-items:center;gap:8px;font-size:13px;font-weight:600;color:var(--primary-dark);
    background:var(--primary-light);border-radius:10px;padding:10px 14px;margin-top:14px;
  }
  .stat-filter-hint button{
    margin-left:auto;background:none;border:none;color:var(--primary-dark);font-weight:700;
    font-size:12.5px;cursor:pointer;text-decoration:underline;
  }

  .section-head{
    display:flex;align-items:center;justify-content:space-between;gap:12px;
    flex-wrap:wrap;margin-bottom:18px;
  }
  .section-head-left{display:flex;align-items:center;gap:12px;}
  .section-icon{
    width:38px;height:38px;border-radius:10px;flex-shrink:0;
    background:var(--primary-light);color:var(--primary-dark);
    display:flex;align-items:center;justify-content:center;font-size:15px;
  }
  .section-icon.done{background:#e3f5ea;color:var(--success);}
  .section-head h2{margin:0;font-size:16.5px;color:var(--navy);}
  .section-sub{font-size:12.5px;color:var(--text-muted);margin-top:2px;}
  .section-count{
    background:var(--bg);color:var(--navy);font-size:12.5px;font-weight:700;
    padding:5px 14px;border-radius:20px;flex-shrink:0;
  }

  .requests-table{min-width:0;width:100%;}
  .requests-table thead th{font-weight:700;letter-spacing:.3px;padding:12px 14px;}
  .requests-table tbody td{padding:14px;}
  .requests-table tbody tr:nth-child(even){background:var(--white);}
  .requests-table tbody tr{transition:background .12s;}
  .requests-table tbody tr:hover{background:var(--primary-light);}

  /* Below tablet width, swap the table for a stacked card layout per row instead of
     squeezing 7 columns into a horizontal scroll strip. */
  @media (max-width:760px){
    .requests-table thead{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);}
    .requests-table, .requests-table tbody, .requests-table tr, .requests-table td{display:block;width:100%;}
    .requests-table tr{
      border:1px solid var(--border);border-radius:10px;padding:4px 12px;margin-bottom:12px;
    }
    .requests-table tbody tr:nth-child(even){background:var(--white);}
    .requests-table tbody tr:hover{background:transparent;}
    .requests-table td{
      display:flex;align-items:center;justify-content:space-between;gap:12px;
      padding:9px 0;border-top:1px solid var(--border);text-align:right;
    }
    .requests-table td:first-child{border-top:none;}
    .requests-table td::before{
      content:attr(data-label);font-weight:700;color:var(--navy);font-size:12px;text-align:left;
    }
    .requests-table td:last-child{justify-content:flex-end;padding-top:12px;}
    .requests-table td:last-child::before{content:none;}
    .table-wrap:has(.requests-table){border:none;overflow-x:visible;}
  }

  .ref-chip{
    font-family:'Courier New',monospace;font-weight:700;color:var(--navy);
    background:var(--bg);padding:4px 10px;border-radius:6px;font-size:12.5px;letter-spacing:.2px;
  }
  .type-pill{display:inline-block;padding:4px 10px;border-radius:20px;font-size:11.5px;font-weight:700;white-space:nowrap;color:#fff;}
  .type-pill.matter{background:#0078d4;}
  .type-pill.office{background:#498205;}
  .type-pill.staff{background:#9e6c00;}
  .type-pill.staff-matter{background:#d4e7f6;color:#0c70bb;}
  .type-pill.staff-office{background:#caf0cc;color:#437406;}

  .btn-view-row{border-radius:20px;}
  .btn-view-row:hover{background:var(--navy);color:var(--white);}

  .empty-state{
    text-align:center;padding:40px 20px;color:var(--text-muted);font-size:13.5px;
  }
  .empty-state i{display:block;font-size:26px;color:var(--border);margin-bottom:10px;}

  .pagination{display:flex;align-items:center;justify-content:center;gap:16px;padding:16px 0 4px;}
  .pagination-btn{
    width:32px;height:32px;border-radius:8px;border:1px solid var(--border);background:var(--white);
    display:flex;align-items:center;justify-content:center;cursor:pointer;color:var(--navy);font-size:12.5px;
    transition:background .15s ease,opacity .15s ease;
  }
  .pagination-btn:hover:not(:disabled){background:var(--bg);}
  .pagination-btn:disabled{opacity:.4;cursor:not-allowed;}
  .pagination-info{font-size:12.5px;font-weight:600;color:var(--text-muted);min-width:90px;text-align:center;}

  .modal{
    position:fixed;inset:0;background:rgba(1,52,95,0.55);
    display:flex;align-items:center;justify-content:center;
    padding:20px;z-index:50;
  }
  .modal[hidden]{display:none;}
  .modal-card{
    position:relative;
    background:var(--white);border-radius:14px;padding:30px;max-width:420px;width:100%;
    text-align:center;box-shadow:0 10px 40px rgba(0,0,0,0.3);
  }
  .modal-close-x{
    position:absolute;top:14px;right:14px;
    width:30px;height:30px;border-radius:50%;
    display:flex;align-items:center;justify-content:center;
    background:none;border:none;color:var(--text-muted);font-size:15px;cursor:pointer;
    transition:background .15s, color .15s;
  }
  .modal-close-x:hover{background:var(--bg);color:var(--navy);}
  .modal-card .icon{
    width:56px;height:56px;border-radius:50%;background:#e9f7ee;color:var(--success);
    display:flex;align-items:center;justify-content:center;margin:0 auto 14px;font-size:28px;
  }
  .modal-card .icon.icon-error{background:var(--danger-bg);color:var(--danger);}
  .modal-card h2{margin:0 0 8px;color:var(--navy);}
  .modal-card p{color:var(--text-muted);font-size:14px;margin:4px 0;}
  .modal-card strong{color:var(--navy);}
  .modal-error-list{
    text-align:left;margin:4px 0 0;padding-left:22px;color:var(--navy);font-size:13.5px;
    max-height:40vh;overflow-y:auto;
  }
  .modal-error-list li{margin-bottom:8px;line-height:1.4;}
  .modal-error-list li:last-child{margin-bottom:0;}

  .modal-card-details{max-width:900px;text-align:left;max-height:94vh;overflow-y:auto;}
  .modal-card-details h2{font-size:19px;margin-bottom:16px;}
  .rd-hero{
    display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;
    margin:-4px 0 16px;padding-bottom:16px;border-bottom:1px solid var(--border);
  }
  .rd-hero .status-badge{font-size:12.5px;padding:6px 14px;}
  .rd-section{background:var(--bg);border-radius:10px;padding:2px 16px;margin-bottom:14px;}
  .rd-section-title{
    font-size:11px;font-weight:700;letter-spacing:.4px;text-transform:uppercase;
    color:var(--text-muted);padding:12px 0 4px;
  }
  .rd-section .matrix-row{border-bottom:1px solid var(--border);}
  .rd-section .matrix-row:last-child{border-bottom:none;}
  .rd-table{width:100%;min-width:0;table-layout:fixed;border-collapse:collapse;margin:2px 0 10px;}
  .rd-table th{
    background:none;text-align:left;font-size:11px;font-weight:700;letter-spacing:.3px;
    text-transform:uppercase;color:var(--text-muted);padding:8px 0 6px;
    border-bottom:1px solid var(--border);white-space:normal;
  }
  .rd-table td{padding:8px 10px 8px 0;border-bottom:1px solid var(--border);font-size:13.5px;color:var(--navy);word-break:break-word;}
  .rd-table tr:last-child td{border-bottom:none;}
  .rd-table th:nth-child(1),.rd-table td:nth-child(1){width:65%;}
  .rd-table th:nth-child(2),.rd-table td:nth-child(2){width:15%;}
  .rd-table th:last-child,.rd-table td:last-child{width:20%;text-align:right;white-space:nowrap;padding-right:0;}
  .rd-table tr.rd-table-total td{font-weight:700;border-top:1px solid var(--border);border-bottom:none;}
  .rd-section-approval{padding:12px 16px 10px;}
  .approval-card{background:var(--white);border-radius:10px;padding:12px 14px;margin-bottom:10px;}
  .approval-card:last-child{margin-bottom:0;}
  .approval-card-top{display:flex;align-items:center;justify-content:space-between;gap:10px;}
  .approval-role{font-size:11px;font-weight:700;letter-spacing:.3px;text-transform:uppercase;color:var(--text-muted);}
  .approval-status-muted{font-size:12px;color:var(--text-muted);font-style:italic;font-weight:600;}
  .approval-card-name{font-size:14.5px;font-weight:700;color:var(--navy);margin-top:6px;}
  .approval-card-name.value-muted{color:var(--text-muted);font-weight:600;font-style:italic;}
  .approval-remarks{
    display:flex;gap:7px;align-items:flex-start;margin-top:10px;padding-top:10px;
    border-top:1px solid var(--border);font-size:12.5px;color:var(--navy);font-weight:500;
  }
  .approval-remarks i{margin-top:2px;color:var(--primary);}
  .rd-attachments{display:flex;flex-direction:column;gap:6px;padding:4px 0 12px;}
  .rd-attachment{
    display:flex;align-items:center;gap:8px;font-size:13px;font-weight:600;color:var(--primary);
    text-decoration:none;word-break:break-all;
  }
  .rd-attachment:hover{text-decoration:underline;}
  .rd-attachment i{color:var(--text-muted);}
  .rd-no-attachments{font-size:13px;color:var(--text-muted);font-style:italic;padding:4px 0 12px;}
  .rd-inline-note{
    display:flex;gap:6px;align-items:flex-start;font-size:12.5px;color:var(--text-muted);
    font-style:italic;padding:8px 0 10px;
  }
  .rd-inline-note i{margin-top:2px;}
  .rd-actions{margin-top:8px;display:flex;gap:10px;justify-content:flex-end;}
  @media (max-width:480px){.rd-actions{justify-content:stretch;}.rd-actions .btn{flex:1;}}
  .rd-remarks-box{
    margin-top:14px;margin-bottom:12px;text-align:left;padding:14px;border-radius:10px;
    background:#f5f7fa;border:1px solid #e3e7ee;
  }
  .rd-remarks-box .hint{margin:6px 0 0;}
  .rd-remarks-box label{display:block;margin-bottom:6px;font-size:13px;font-weight:600;color:var(--navy);}
  .rd-remarks-box textarea{width:100%;resize:vertical;}
  .rd-remarks-box .rd-actions{margin-top:10px;}

  .copy-from-card{background:var(--primary-light);border:1px solid #f4d7bd;}
  .copy-from-row{display:flex;align-items:center;gap:14px;flex-wrap:wrap;}
  .copy-from-icon{font-size:18px;color:var(--primary-dark);flex-shrink:0;}
  .copy-from-text{display:flex;flex-direction:column;gap:2px;flex:1;min-width:200px;}
  .copy-from-text strong{font-size:13.5px;color:var(--navy);}
  .copy-from-text span{font-size:12px;color:var(--text-muted);}
  .copy-from-row input{width:120px;flex:none;}
  @media (max-width:680px){
    .copy-from-row input{width:100%;}
    .copy-from-row .btn{width:100%;}
  }

  /* ---------- MSAL sign-in gate ---------- */
  body.pre-auth .sidebar,
  body.pre-auth .topbar-full,
  body.pre-auth .main{display:none;}
  .auth-gate{display:none;}
  body.pre-auth .auth-gate{display:flex;}
  .auth-gate{
    position:fixed;inset:0;background:var(--bg);
    align-items:center;justify-content:center;
    z-index:100;
  }
  .auth-gate-card{
    text-align:center;
  }
  .spinner{
    width:40px;height:40px;
    border:4px solid var(--border);
    border-top-color:var(--primary);
    border-radius:50%;
    margin:0 auto 20px;
    animation:auth-spin 0.8s linear infinite;
  }
  @keyframes auth-spin{ to{ transform:rotate(360deg); } }
  .auth-gate-status{color:var(--navy);font-size:14px;font-weight:600;}
  .auth-gate-error{color:var(--danger);font-size:12.5px;margin-top:14px;}

  .btn-signout{
    background:none;border:1px solid var(--border);color:var(--text-muted);
    border-radius:8px;padding:6px 10px;font-size:12px;font-weight:600;
    cursor:pointer;flex-shrink:0;
  }
  .btn-signout:hover{background:var(--bg);color:var(--text);}

  @media print{
    .sidebar,.topbar-full,.actions,.dropzone,.submit-tracker-panel{display:none !important;}
    .main{margin-left:0;margin-top:0;}
    .card{box-shadow:none;border:1px solid #ccc;}
  }
</style>
</head>
<body class="pre-auth">

<div class="auth-gate" id="authGate">
  <div class="auth-gate-card">
    <div class="spinner" id="authGateSpinner" aria-hidden="true"></div>
    <p class="auth-gate-status" id="authGateStatus">Signing you in...</p>
    <p class="auth-gate-error" id="authGateError" hidden></p>
  </div>
</div>

<header class="topbar-full">
  <div class="topbar-brand">
    <img class="brand-full-logo" alt="Sidek Teoh Wong &amp; Dennis" src="https://raw.githubusercontent.com/winterx04/STWD/main/logo/logo_full.jpg">
  </div>
  <div class="topbar-page">
      <div class="topbar-left">
        <h2 id="topbarTitle">E-Voucher System</h2>
        <p id="topbarSubtitle">Payment nominal request</p>
      </div>
      <div class="topbar-right" id="topbarRight">
        <div class="profile-chip">
          <div class="profile-avatar" id="profileAvatar">--</div>
          <div class="profile-text">
            <div class="profile-name" id="profileName">Not signed in</div>
            <div class="profile-email" id="profileEmail"></div>
          </div>
          <button type="button" class="btn-signout" id="signOutBtn" title="Sign out"><i class="fa-solid fa-right-from-bracket"></i> Sign out</button>
        </div>
      </div>
  </div>
</header>

<div class="sidebar">

  <nav class="nav" id="mainNav">
    <button type="button" class="nav-item active" data-view="submit">
      <i class="fa-solid fa-square-plus"></i>
      <span>Submit payment request</span>
    </button>
    <button type="button" class="nav-item" data-view="requests">
      <i class="fa-solid fa-list-check"></i>
      <span>View requests</span>
    </button>
    <!-- Only revealed for members of the approvers security group - see
         checkCurrentUserIsApprover in the SharePoint integration script block. -->
    <button type="button" class="nav-item" data-view="accounts" id="accountsNavItem" hidden>
      <i class="fa-solid fa-clipboard-check"></i>
      <span>Accounts Approval</span>
    </button>
  </nav>

  <!-- <div class="sidebar-footer">Front-end preview &middot; no sign-in required</div> -->

  <button type="button" class="sidebar-collapse-btn" id="sidebarCollapseBtn" title="Collapse sidebar" aria-label="Collapse sidebar">
    <i class="fa-solid fa-chevron-left"></i>
  </button>
</div>

<div class="main">
  
  <div class="content">

    <section id="view-submit" class="view">
      <div class="submit-layout">
      <div class="submit-main">

        <form id="voucherForm" novalidate>

          <div class="card copy-from-card">
            <div class="copy-from-row">
              <i class="fa-solid fa-copy copy-from-icon"></i>
              <div class="copy-from-text">
                <strong>Copy From An Existing Request</strong>
                <span>Loads everything except attachments and each line item's amount - edit anything, then submit as a new request.</span>
              </div>
              <input type="text" id="copyFromIdInput" inputmode="numeric" placeholder="Enter ID">
              <button type="button" class="btn btn-outline" id="copyFromIdBtn">Load</button>
            </div>
            <p class="hint warning" id="copyFromIdError" hidden></p>
          </div>

          <section class="card" id="form-section-1">
            <h2><span class="step">1</span><i class="fa-solid fa-file-signature card-icon"></i>Request Type</h2>
            <div class="grid-2">
              <div class="field">
                <label for="nominalType">Payment Nominal Request For *</label>
                <select id="nominalType" required>
                  <option value="">Select type</option>
                  <option value="matter">E-Voucher on Matter Related</option>
                  <option value="office">E-Voucher on Office Related</option>
                  <option value="staff">E-Voucher on Staff Claims</option>
                </select>
              </div>
              <div class="field" id="staffSubtypeField" hidden>
                <label for="staffSubtype">Staff Claim Category *</label>
                <select id="staffSubtype">
                  <option value="matter">Matter Related</option>
                  <option value="office">Office Related</option>
                </select>
              </div>
            </div>

            <div id="matterSection" class="matter-fields" hidden>
              <div class="grid-3">
                <div class="field">
                  <label for="matterNumber">Matter Number *</label>
                  <input type="text" id="matterNumber" placeholder="Enter matter number">
                  <p class="hint warning" id="matterNumberError" hidden>Matter number does not exist.</p>
                </div>
                <div class="field">
                  <label for="clientName">Client Name</label>
                  <input type="text" id="clientName" readonly>
                </div>
                <div class="field full">
                  <label for="matterDescription">Matter Description</label>
                  <input type="text" id="matterDescription" readonly>
                </div>
              </div>
              <p class="hint">Client name and matter description auto-fill from the matter record when a recognised matter number is entered. You may edit them if needed.</p>
            </div>
          </section>

          <section class="card" id="form-section-2">
            <h2><span class="step">2</span><i class="fa-solid fa-money-check-dollar card-icon"></i>Payee &amp; Payment Details</h2>
            <div class="grid-2">
              <div class="field">
                <label for="payee">Payee *</label>
                <input type="text" id="payee" required>
              </div>
              <div class="field">
                <label for="modeOfPayment">Mode Of Payment *</label>
                <select id="modeOfPayment" required>
                  <option value="">Select mode</option>
                  <option>Bank Draft</option>
                  <option>Cheque</option>
                  <option>InterBank GIRO (IBG)</option>
                  <option>Rentas</option>
                  <option>Telegraphic Transfer (TT)</option>
                  <option>FPX</option>
                  <option>JomPAY</option>
                </select>
              </div>
              <div class="field">
                <label for="bankName">Bank Name *</label>
                <select id="bankName" required>
                  <option value="">Select bank</option>
                  <option>AEON Bank (M) Berhad</option>
                  <option>Affin Bank Berhad</option>
                  <option>Affin Islamic Bank Berhad</option>
                  <option>Al Rajhi Banking &amp; Investment Corporation (Malaysia) Berhad</option>
                  <option>Alliance Bank Malaysia Berhad</option>
                  <option>Alliance Islamic Bank Berhad</option>
                  <option>AmBank (M) Berhad</option>
                  <option>AmBank Islamic Berhad</option>
                  <option>Bangkok Bank Berhad</option>
                  <option>Bank Islam Malaysia Berhad</option>
                  <option>Bank Muamalat Malaysia Berhad</option>
                  <option>Bank of America Malaysia Berhad</option>
                  <option>Bank of China (Malaysia) Berhad</option>
                  <option>BNP Paribas Malaysia Berhad</option>
                  <option>Boost Bank Berhad</option>
                  <option>CIMB Bank Berhad</option>
                  <option>CIMB Islamic Bank Berhad</option>
                  <option>Citibank Berhad</option>
                  <option>Deutsche Bank (Malaysia) Berhad</option>
                  <option>GX Bank Berhad</option>
                  <option>Hong Leong Bank Berhad</option>
                  <option>Hong Leong Islamic Bank Berhad</option>
                  <option>HSBC Amanah Malaysia Berhad</option>
                  <option>HSBC Bank Malaysia Berhad</option>
                  <option>India International Bank (Malaysia) Berhad</option>
                  <option>Industrial and Commercial Bank of China (Malaysia) Berhad</option>
                  <option>J.P. Morgan Chase Bank Berhad</option>
                  <option>KAF Digital Bank Berhad</option>
                  <option>Kuwait Finance House (Malaysia) Berhad</option>
                  <option>Malayan Banking Berhad (Maybank)</option>
                  <option>Maybank Islamic Berhad</option>
                  <option>MBSB Bank Berhad</option>
                  <option>Mizuho Bank (Malaysia) Berhad</option>
                  <option>MUFG Bank (Malaysia) Berhad</option>
                  <option>OCBC Al-Amin Bank Berhad</option>
                  <option>OCBC Bank (Malaysia) Berhad</option>
                  <option>Public Bank Berhad</option>
                  <option>Public Islamic Bank Berhad</option>
                  <option>RHB Bank Berhad</option>
                  <option>RHB Islamic Bank Berhad</option>
                  <option>Ryt Bank</option>
                  <option>Standard Chartered Bank Malaysia Berhad</option>
                  <option>Standard Chartered Saadiq Berhad</option>
                  <option>Sumitomo Mitsui Banking Corporation Malaysia Berhad</option>
                  <option>United Overseas Bank (Malaysia) Bhd (UOB)</option>
                  <option>Others</option>
                </select>
                <input type="text" id="bankNameManual" placeholder="Type bank name" hidden>
                <p class="hint" id="bankNameForeignHint" hidden>Foreign currency selected &mdash; please type the bank name manually.</p>
              </div>
              <div class="field">
                <label for="bankAccountNumber" id="bankAccountNumberLabel">Bank Account Number *</label>
                <input type="text" id="bankAccountNumber" required>
              </div>
            </div>
          </section>

          <section class="card" id="form-section-3">
            <h2><span class="step">3</span><i class="fa-solid fa-user-check card-icon"></i>Approval Routing</h2>
            <div class="grid-2">
              <div class="field" id="lawyerInChargeField">
                <label for="lawyerInCharge" id="lawyerInChargeLabel">Lawyer-In-Charge *</label>
                <div class="people-picker" id="lawyerInChargePicker">
                  <input type="text" id="lawyerInCharge" autocomplete="off" spellcheck="false" placeholder="Click or type to search..." required>
                  <input type="hidden" id="lawyerInChargeEmail">
                  <i class="fa-solid fa-chevron-down people-picker-caret"></i>
                  <div class="people-suggestions" id="lawyerInChargeSuggestions" hidden></div>
                </div>
              </div>
              <div class="field">
                <label for="partnerInCharge" id="partnerInChargeLabel">Partner-In-Charge *</label>
                <div class="people-picker" id="partnerInChargePicker">
                  <input type="text" id="partnerInCharge" autocomplete="off" spellcheck="false" placeholder="Click or type to search..." required>
                  <input type="hidden" id="partnerInChargeEmail">
                  <i class="fa-solid fa-chevron-down people-picker-caret"></i>
                  <div class="people-suggestions" id="partnerInChargeSuggestions" hidden></div>
                </div>
              </div>
              <div class="field" id="seniorPartnerField" hidden>
                <label for="seniorPartner">Senior Partner 1 *</label>
                <div class="people-picker" id="seniorPartnerPicker">
                  <input type="text" id="seniorPartner" autocomplete="off" spellcheck="false" placeholder="Click or type to search...">
                  <input type="hidden" id="seniorPartnerEmail">
                  <i class="fa-solid fa-chevron-down people-picker-caret"></i>
                  <div class="people-suggestions" id="seniorPartnerSuggestions" hidden></div>
                </div>
              </div>
              <div class="field" id="seniorPartner2Field" hidden>
                <label for="seniorPartner2">Senior Partner 2 *</label>
                <div class="people-picker" id="seniorPartner2Picker">
                  <input type="text" id="seniorPartner2" autocomplete="off" spellcheck="false" placeholder="Click or type to search...">
                  <input type="hidden" id="seniorPartner2Email">
                  <i class="fa-solid fa-chevron-down people-picker-caret"></i>
                  <div class="people-suggestions" id="seniorPartner2Suggestions" hidden></div>
                </div>
              </div>
            </div>
          </section>

          <section class="card" id="form-section-4">
            <h2><span class="step">4</span><i class="fa-solid fa-table-list card-icon"></i>Payment Line Items</h2>
            <div class="table-wrap">
              <table id="lineItemsTable">
                <thead>
                  <tr>
                    <th>Payment Description</th>
                    <th>Invoice Number/Reference Number</th>
                    <th>Amount</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody id="lineItemsBody"></tbody>
              </table>
            </div>
            <div style="margin-top:12px;">
              <button type="button" class="btn btn-outline" id="addRowBtn"><i class="fa-solid fa-plus"></i> Add line item</button>
            </div>

            <p class="hint warning" id="staffCapWarning" hidden>&#9888; Staff claims must not exceed RM10,000.00 per claim. Please adjust the highlighted line(s).</p>
            <p class="hint warning" id="lineItemLimitWarning" hidden>&#9888; A maximum of 5 line items is allowed per request.</p>

            <div class="grid-2 totals">
              <div class="field">
                <label for="currency">Currency *</label>
                <select id="currency" required>
                  <option value="MYR">MYR</option>
                  <option value="USD">USD</option>
                  <option value="SGD">SGD</option>
                  <option value="EUR">EUR</option>
                  <option value="GBP">GBP</option>
                  <option value="RMB">RMB</option>
                </select>
              </div>
              <div class="field">
                <label for="totalAmount">Total Amount</label>
                <input type="text" id="totalAmount" readonly value="0.00">
              </div>
            </div>
          </section>

          <section class="card" id="form-section-5">
            <h2><span class="step">5</span><i class="fa-solid fa-paperclip card-icon"></i>Attachment</h2>
            <div class="dropzone" id="dropzone">
              <input type="file" id="attachment" multiple hidden>
              <i class="fa-solid fa-cloud-arrow-up dropzone-icon"></i>
              <p><span class="link">Browse files</span> or drag them here</p>
              <p>Invoice, bill, or other supporting documents (max 5MB per file)</p>
            </div>
            <p class="hint warning" id="attachmentError" hidden></p>
            <ul class="file-list" id="fileList"></ul>
          </section>

          <div class="actions">
            <button type="button" class="btn btn-ghost" id="resetBtn"><i class="fa-solid fa-rotate-left"></i> Reset</button>
            <button type="submit" class="btn btn-primary" id="submitBtn"><i class="fa-solid fa-paper-plane"></i> Submit Payment Request</button>
          </div>
        </form>
      </div>

      <aside class="submit-tracker-panel">
        <div class="tracker-card">
          <div class="tracker-card-label">Quick Navigation</div>
          <div class="jump-list" id="jumpList">
            <button type="button" class="jump-item" data-step="1" data-target="form-section-1">
              <span class="jump-dot"><i class="fa-solid fa-check jump-dot-check"></i></span><span class="jump-label">Request Type</span>
            </button>
            <button type="button" class="jump-item" data-step="2" data-target="form-section-2">
              <span class="jump-dot"><i class="fa-solid fa-check jump-dot-check"></i></span><span class="jump-label">Payee &amp; Payment</span>
            </button>
            <button type="button" class="jump-item" data-step="3" data-target="form-section-3">
              <span class="jump-dot"><i class="fa-solid fa-check jump-dot-check"></i></span><span class="jump-label">Approval Routing</span>
            </button>
            <button type="button" class="jump-item" data-step="4" data-target="form-section-4">
              <span class="jump-dot"><i class="fa-solid fa-check jump-dot-check"></i></span><span class="jump-label">Line Items</span>
            </button>
            <button type="button" class="jump-item" data-step="5" data-target="form-section-5">
              <span class="jump-dot"><i class="fa-solid fa-check jump-dot-check"></i></span><span class="jump-label">Attachment</span>
            </button>
          </div>
          <div class="tracker-total">
            <div class="stat-label">Total</div>
            <div class="stat-value" id="headerTotal">MYR 0.00</div>
          </div>
        </div>
      </aside>
      </div>
    </section>

    <section id="view-requests" class="view" hidden>
      <div class="view-wrap">
        <div class="alert alert-error" id="requestsLoadError" hidden>
          <i class="fa-solid fa-triangle-exclamation"></i>
          <span id="requestsLoadErrorText"></span>
        </div>
        <div class="stats-row">
          <div class="stat-card pending" id="statCardPending" data-filter="pending" role="button" tabindex="0" aria-pressed="false">
            <div class="stat-icon"><i class="fa-solid fa-hourglass-half"></i></div>
            <div>
              <div class="stat-num" id="statPendingCount">0</div>
              <div class="stat-text">Pending</div>
            </div>
          </div>
          <div class="stat-card approved" id="statCardApproved" data-filter="approved" role="button" tabindex="0" aria-pressed="false">
            <div class="stat-icon"><i class="fa-solid fa-circle-check"></i></div>
            <div>
              <div class="stat-num" id="statApprovedCount">0</div>
              <div class="stat-text">Approved</div>
            </div>
          </div>
          <div class="stat-card rejected" id="statCardRejected" data-filter="rejected" role="button" tabindex="0" aria-pressed="false">
            <div class="stat-icon"><i class="fa-solid fa-circle-xmark"></i></div>
            <div>
              <div class="stat-num" id="statRejectedCount">0</div>
              <div class="stat-text">Rejected</div>
            </div>
          </div>
        </div>
        <div class="stat-filter-hint" id="statFilterHint" hidden>
          <i class="fa-solid fa-filter"></i><span id="statFilterHintText"></span>
          <button type="button" id="statFilterClearBtn">Clear filter</button>
        </div>

        <div class="requests-search">
          <i class="fa-solid fa-magnifying-glass requests-search-icon"></i>
          <input type="text" id="requestsSearchInput" placeholder="Search by ID, Type, Matter No, Created By, Status, Amount, Payee, Date...">
          <button type="button" class="requests-search-clear" id="requestsSearchClear" hidden title="Clear search"><i class="fa-solid fa-xmark"></i></button>
        </div>

        <div class="card">
          <div class="section-head">
            <div class="section-head-left">
              <div class="section-icon"><i class="fa-solid fa-hourglass-half"></i></div>
              <div>
                <h2>Pending Requests</h2>
                <div class="section-sub">Awaiting verification or approval</div>
              </div>
            </div>
            <span class="section-count" id="pendingCountBadge">0</span>
          </div>
          <div class="table-wrap">
            <table class="requests-table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Type</th>
                  <th>Matter No</th>
                  <th>Created By</th>
                  <th>Payee</th>
                  <th>Amount</th>
                  <th>Date</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody id="requestsPendingBody"></tbody>
            </table>
          </div>
          <div class="empty-state" id="requestsPendingEmpty" hidden><i class="fa-solid fa-inbox"></i>No pending requests right now.</div>
          <div class="pagination" id="pendingPagination" hidden>
            <button type="button" class="pagination-btn" id="pendingPrevBtn" aria-label="Previous page"><i class="fa-solid fa-chevron-left"></i></button>
            <span class="pagination-info" id="pendingPageInfo">Page 1 of 1</span>
            <button type="button" class="pagination-btn" id="pendingNextBtn" aria-label="Next page"><i class="fa-solid fa-chevron-right"></i></button>
          </div>
        </div>

        <div class="card">
          <div class="section-head">
            <div class="section-head-left">
              <div class="section-icon done"><i class="fa-solid fa-clipboard-check"></i></div>
              <div>
                <h2>Completed &amp; Rejected Requests</h2>
                <div class="section-sub">Finalised request history</div>
              </div>
            </div>
            <span class="section-count" id="completedCountBadge">0</span>
          </div>
          <div class="table-wrap">
            <table class="requests-table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Type</th>
                  <th>Matter No</th>
                  <th>Created By</th>
                  <th>Payee</th>
                  <th>Amount</th>
                  <th>Date</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody id="requestsCompletedBody"></tbody>
            </table>
          </div>
          <div class="empty-state" id="requestsCompletedEmpty" hidden><i class="fa-solid fa-inbox"></i>No completed or rejected requests yet.</div>
          <div class="pagination" id="completedPagination" hidden>
            <button type="button" class="pagination-btn" id="completedPrevBtn" aria-label="Previous page"><i class="fa-solid fa-chevron-left"></i></button>
            <span class="pagination-info" id="completedPageInfo">Page 1 of 1</span>
            <button type="button" class="pagination-btn" id="completedNextBtn" aria-label="Next page"><i class="fa-solid fa-chevron-right"></i></button>
          </div>
        </div>
      </div>
    </section>

    <!-- Nav item + view are hidden unless checkCurrentUserIsApprover confirms group membership -
         see the SharePoint integration script block. -->
    <section id="view-accounts" class="view" hidden>
      <div class="view-wrap">
        <div class="alert alert-error" id="accountsLoadError" hidden>
          <i class="fa-solid fa-triangle-exclamation"></i>
          <span id="accountsLoadErrorText"></span>
        </div>
        <div class="card">
          <div class="section-head">
            <div class="section-head-left">
              <div class="section-icon"><i class="fa-solid fa-clipboard-check"></i></div>
              <div>
                <h2>Pending Accounts Approval</h2>
                <div class="section-sub">Cleared all required Lawyer/Partner/Senior Partner approvals - awaiting Accounts</div>
              </div>
            </div>
            <span class="section-count" id="accountsCountBadge">0</span>
          </div>
          <div class="table-wrap">
            <table class="requests-table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Type</th>
                  <th>Payee</th>
                  <th>Amount</th>
                  <th>Date</th>
                  <th></th>
                </tr>
              </thead>
              <tbody id="accountsPendingBody"></tbody>
            </table>
          </div>
          <div class="empty-state" id="accountsPendingEmpty" hidden><i class="fa-solid fa-inbox"></i>No requests waiting on Accounts right now.</div>
          <div class="pagination" id="accountsPagination" hidden>
            <button type="button" class="pagination-btn" id="accountsPrevBtn" aria-label="Previous page"><i class="fa-solid fa-chevron-left"></i></button>
            <span class="pagination-info" id="accountsPageInfo">Page 1 of 1</span>
            <button type="button" class="pagination-btn" id="accountsNextBtn" aria-label="Next page"><i class="fa-solid fa-chevron-right"></i></button>
          </div>
        </div>
      </div>
    </section>

  </div>
</div>

<div class="modal" id="requestDetailsModal" hidden>
  <div class="modal-card modal-card-details">
    <button type="button" class="modal-close-x" id="closeRequestDetailsBtn" title="Close" aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
    <h2>Request Details</h2>
    <div id="requestDetailsBody" class="matrix-info"></div>
    <!-- Shown alongside Reject/Mark Complete; saved to AccountsRemarks and included in the
         submitter's email. Optional for Mark Complete, required for Reject. -->
    <div class="rd-remarks-box" id="accountsRemarksBox" hidden>
      <label for="accountsRemarksInput">Accounts Remarks</label>
      <textarea id="accountsRemarksInput" rows="3" maxlength="1000" placeholder="Optional for Mark Complete, required for Reject. Sent to the submitter."></textarea>
      <p class="hint warning" id="accountsRemarksError" hidden>Please enter remarks explaining why this request is being rejected.</p>
    </div>
    <div class="rd-actions" id="rdMainActions">
      <button type="button" class="btn btn-primary" id="resubmitRequestBtn" hidden><i class="fa-solid fa-pen-to-square"></i> Edit &amp; Resubmit</button>
      <button type="button" class="btn btn-danger" id="accountsRejectBtn" hidden><i class="fa-solid fa-circle-xmark"></i> Reject</button>
      <button type="button" class="btn btn-success" id="accountsCompleteBtn" hidden><i class="fa-solid fa-circle-check"></i> Mark Complete</button>
    </div>
  </div>
</div>

<div class="modal" id="successModal" hidden>
  <div class="modal-card">
    <button type="button" class="modal-close-x" id="closeModalXBtn" title="Close" aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
    <div class="icon">&#10003;</div>
    <h2>Request Submitted</h2>
    <p>Request ID: <strong id="refNumber"></strong></p>
    <p id="successSummary"></p>
    <p class="hint" style="margin-top:14px;">Your request has been recorded in SharePoint and routed for verification and approval.</p>
    <div style="margin-top:18px;">
      <button type="button" class="btn btn-primary" id="closeModalBtn">Close</button>
    </div>
  </div>
</div>

<div class="modal" id="errorModal" hidden>
  <div class="modal-card">
    <button type="button" class="modal-close-x" id="closeErrorModalBtn" title="Close" aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
    <div class="icon icon-error"><i class="fa-solid fa-triangle-exclamation"></i></div>
    <h2>Please Fix The Following</h2>
    <ul class="modal-error-list" id="errorList"></ul>
    <div style="margin-top:18px;">
      <button type="button" class="btn btn-primary" id="errorModalOkBtn">Got It</button>
    </div>
  </div>
</div>

<script>
window.eVoucherSignInHandlers = window.eVoucherSignInHandlers || [];
</script>

<script>
(function(){
  'use strict';

  var nominalType = document.getElementById('nominalType');
  var staffSubtypeField = document.getElementById('staffSubtypeField');
  var staffSubtype = document.getElementById('staffSubtype');
  var matterSection = document.getElementById('matterSection');
  var matterNumber = document.getElementById('matterNumber');
  var clientName = document.getElementById('clientName');
  var matterDescription = document.getElementById('matterDescription');
  var matterNumberError = document.getElementById('matterNumberError');
  var lineItemsBody = document.getElementById('lineItemsBody');
  var addRowBtn = document.getElementById('addRowBtn');
  var totalAmountField = document.getElementById('totalAmount');
  var staffCapWarning = document.getElementById('staffCapWarning');
  var lineItemLimitWarning = document.getElementById('lineItemLimitWarning');
  var MAX_LINE_ITEMS = 5;
  var dropzone = document.getElementById('dropzone');
  var attachmentInput = document.getElementById('attachment');
  var fileList = document.getElementById('fileList');
  var attachmentError = document.getElementById('attachmentError');
  var copyFromIdInput = document.getElementById('copyFromIdInput');
  var copyFromIdBtn = document.getElementById('copyFromIdBtn');
  var copyFromIdError = document.getElementById('copyFromIdError');
  var form = document.getElementById('voucherForm');
  var errorModal = document.getElementById('errorModal');
  var errorList = document.getElementById('errorList');
  var closeErrorModalBtn = document.getElementById('closeErrorModalBtn');
  var errorModalOkBtn = document.getElementById('errorModalOkBtn');
  var resetBtn = document.getElementById('resetBtn');
  var successModal = document.getElementById('successModal');
  var closeModalBtn = document.getElementById('closeModalBtn');
  var refNumber = document.getElementById('refNumber');
  var successSummary = document.getElementById('successSummary');
  var headerTotal = document.getElementById('headerTotal');
  var jumpList = document.getElementById('jumpList');
  var currencySelect = document.getElementById('currency');
  var bankNameSelect = document.getElementById('bankName');
  var bankNameManual = document.getElementById('bankNameManual');
  var bankNameForeignHint = document.getElementById('bankNameForeignHint');
  var payeeInput = document.getElementById('payee');
  var modeOfPaymentSelect = document.getElementById('modeOfPayment');

  // Payee is typed as-per the bank account name convention, which this firm keeps in all
  // caps - transform live rather than just visually (text-transform:uppercase would leave
  // the underlying value mixed-case, which is what actually gets saved to SharePoint).
  payeeInput.addEventListener('input', function(){
    var pos = payeeInput.selectionStart;
    payeeInput.value = payeeInput.value.toUpperCase();
    payeeInput.setSelectionRange(pos, pos);
  });

  // ---------- Custom dropdown UI for <select> fields (visuals only - the native
  // <select> stays in the DOM as the real data model, so every existing .value
  // read/write, .hidden/.required toggle and dispatched 'change' event above
  // keeps working untouched). ----------
  function enhanceSelect(selectEl){
    var wrap = document.createElement('div');
    wrap.className = 'custom-select-wrap';
    selectEl.parentNode.insertBefore(wrap, selectEl);
    wrap.appendChild(selectEl);

    var trigger = document.createElement('button');
    trigger.type = 'button';
    trigger.className = 'cst-trigger';
    var label = document.createElement('span');
    label.className = 'cst-label';
    var caret = document.createElement('i');
    caret.className = 'fa-solid fa-chevron-down cst-caret';
    trigger.appendChild(label);
    trigger.appendChild(caret);
    wrap.appendChild(trigger);

    var panel = document.createElement('div');
    panel.className = 'cst-panel';
    panel.hidden = true;
    wrap.appendChild(panel);

    function syncLabel(){
      var opt = selectEl.options[selectEl.selectedIndex];
      label.textContent = opt ? opt.textContent : '';
      label.classList.toggle('cst-placeholder', !!opt && opt.value === '');
    }

    function closePanel(){ panel.hidden = true; panel.innerHTML = ''; trigger.classList.remove('open'); }

    function openPanel(){
      panel.innerHTML = Array.prototype.map.call(selectEl.options, function(opt, i){
        var cls = 'cst-option' + (i === selectEl.selectedIndex ? ' selected' : '');
        return '<div class="' + cls + '" data-idx="' + i + '">' + escapeHtml(opt.textContent) + '</div>';
      }).join('');
      panel.hidden = false;
      trigger.classList.add('open');
    }

    trigger.addEventListener('click', function(){
      if (selectEl.disabled) return;
      if (panel.hidden) openPanel(); else closePanel();
    });

    panel.addEventListener('mousedown', function(e){
      var row = e.target.closest('.cst-option');
      if (!row) return;
      e.preventDefault();
      var idx = parseInt(row.getAttribute('data-idx'), 10);
      if (selectEl.selectedIndex !== idx){
        selectEl.selectedIndex = idx;
        selectEl.dispatchEvent(new Event('change', { bubbles: true }));
      }
      closePanel();
    });

    trigger.addEventListener('keydown', function(e){
      if (e.key === 'Escape') closePanel();
    });
    trigger.addEventListener('blur', function(){ setTimeout(closePanel, 150); });
    selectEl.addEventListener('change', syncLabel);

    syncLabel();
  }

  // ---------- Searchable variant (Bank Name): same hidden-<select>-as-data-model approach
  // as enhanceSelect above, but the visible control is a real text input so typing "c"
  // filters the panel down to matches like "CIMB Bank Berhad" instead of just opening the
  // full static list. ----------
  function enhanceSelectSearchable(selectEl){
    var wrap = document.createElement('div');
    wrap.className = 'custom-select-wrap';
    selectEl.parentNode.insertBefore(wrap, selectEl);
    wrap.appendChild(selectEl);

    var trigger = document.createElement('input');
    trigger.type = 'text';
    trigger.autocomplete = 'off';
    trigger.spellcheck = false;
    trigger.className = 'cst-trigger cst-search-input';
    trigger.placeholder = 'Type to search...';
    wrap.appendChild(trigger);

    var caret = document.createElement('i');
    caret.className = 'fa-solid fa-chevron-down cst-caret cst-search-caret';
    wrap.appendChild(caret);

    var panel = document.createElement('div');
    panel.className = 'cst-panel';
    panel.hidden = true;
    wrap.appendChild(panel);

    function syncLabel(){
      var opt = selectEl.options[selectEl.selectedIndex];
      trigger.value = (opt && opt.value !== '') ? opt.textContent : '';
    }

    function closePanel(){ panel.hidden = true; panel.innerHTML = ''; trigger.classList.remove('open'); caret.classList.remove('open'); }

    function renderPanel(filterText){
      var lc = (filterText || '').toLowerCase();
      var matches = [];
      Array.prototype.forEach.call(selectEl.options, function(opt, i){
        if (opt.value !== '' && opt.textContent.toLowerCase().indexOf(lc) !== -1) matches.push(i);
      });
      if (!matches.length){
        panel.innerHTML = '<div class="cst-option cst-option-empty">No matches found</div>';
      } else {
        panel.innerHTML = matches.map(function(i){
          var cls = 'cst-option' + (i === selectEl.selectedIndex ? ' selected' : '');
          return '<div class="' + cls + '" data-idx="' + i + '">' + escapeHtml(selectEl.options[i].textContent) + '</div>';
        }).join('');
      }
      panel.hidden = false;
      trigger.classList.add('open');
      caret.classList.add('open');
    }

    trigger.addEventListener('focus', function(){
      if (selectEl.disabled) return;
      renderPanel('');
      trigger.select();
    });

    trigger.addEventListener('input', function(){ renderPanel(trigger.value); });

    panel.addEventListener('mousedown', function(e){
      var row = e.target.closest('.cst-option[data-idx]');
      if (!row) return;
      e.preventDefault();
      var idx = parseInt(row.getAttribute('data-idx'), 10);
      if (selectEl.selectedIndex !== idx){
        selectEl.selectedIndex = idx;
        selectEl.dispatchEvent(new Event('change', { bubbles: true }));
      }
      closePanel();
    });

    trigger.addEventListener('keydown', function(e){
      if (e.key === 'Escape') closePanel();
    });
    // Snap back to the actual selected option's text if the user typed something and
    // clicked away without picking a suggestion - same "must resolve to a real value"
    // rule used by the Lawyer/Partner people-pickers.
    trigger.addEventListener('blur', function(){ setTimeout(function(){ closePanel(); syncLabel(); }, 150); });
    selectEl.addEventListener('change', syncLabel);

    syncLabel();
    return trigger;
  }

  Array.prototype.forEach.call(document.querySelectorAll('#voucherForm select:not(#bankName)'), enhanceSelect);
  var bankNameSearchInput = enhanceSelectSearchable(bankNameSelect);

  var files = [];
  var rowCounter = 0;
  var TRACKER_STEPS = 5;

  function updateTracker(){
    var matterApplicable = !matterSection.hidden;
    var steps = {};
    steps[1] = nominalType.value !== '' &&
               (nominalType.value !== 'staff' || staffSubtype.value !== '') &&
               (matterApplicable ? matterNumber.value.trim() !== '' : true);
    // A disabled field (Staff Claims never need Mode of Payment/Bank Name/Bank Account Number
    // at all; FPX/JomPAY/Cheque/Bank Draft disable one or more of them too) is legitimately
    // blank and satisfied, not missing - without this check the tracker got stuck reporting
    // step 2 as incomplete even once everything past it, including Attachments, was filled in
    // (reported 2026-10-21).
    var modeOfPaymentEl = document.getElementById('modeOfPayment');
    var bankNameEl = activeBankNameField();
    var bankAccountNumberEl = document.getElementById('bankAccountNumber');
    steps[2] = !!(document.getElementById('payee').value.trim() &&
                  (modeOfPaymentEl.disabled || modeOfPaymentEl.value) &&
                  (bankNameEl.disabled || bankNameEl.value.trim()) &&
                  (bankAccountNumberEl.disabled || bankAccountNumberEl.value.trim()));
    steps[3] = !!((lawyerInChargeField.hidden || lawyerInChargeInput.value.trim()) &&
                  document.getElementById('partnerInCharge').value.trim() &&
                  (seniorPartnerField.hidden || seniorPartnerInput.value.trim()) &&
                  (seniorPartner2Field.hidden || seniorPartner2Input.value.trim()));
    var rows = Array.prototype.slice.call(lineItemsBody.querySelectorAll('tr'));
    steps[4] = rows.some(function(tr){
      return tr.querySelector('.desc-input').value.trim() && parseFloat(tr.querySelector('.amount-input').value) > 0;
    });
    steps[5] = files.length > 0;

    var current = TRACKER_STEPS + 1;
    for (var i = 1; i <= TRACKER_STEPS; i++){
      if (!steps[i]){ current = i; break; }
    }

    for (var i = 1; i <= TRACKER_STEPS; i++){
      var item = jumpList.querySelector('.jump-item[data-step="' + i + '"]');
      if (!item) continue;
      item.classList.remove('done','current');
      if (i < current) item.classList.add('done');
      else if (i === current) item.classList.add('current');
    }
  }

  function todayStr(){
    var d = new Date();
    return d.toISOString().slice(0,10);
  }

  function parseAmount(str){
    if (typeof str === 'number') return str;
    return parseFloat(String(str || '').replace(/,/g, '')) || 0;
  }

  function formatAmount(value){
    var n = parseAmount(value);
    return n.toLocaleString('en-MY', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }

  var DESC_MAX_LENGTH = 200;

  function descCounterHtml(len){
    var atLimit = len >= DESC_MAX_LENGTH;
    return '<div class="char-count' + (atLimit ? ' char-count-limit' : '') + '">' +
      (atLimit ? 'Maximum ' + DESC_MAX_LENGTH + ' characters reached' : len + '/' + DESC_MAX_LENGTH) +
      '</div>';
  }

  function createRow(data){
    data = data || {};
    rowCounter++;
    var tr = document.createElement('tr');
    tr.dataset.rowId = rowCounter;
    tr.innerHTML =
      '<td><textarea class="desc-input" maxlength="200" placeholder="Payment Description" rows="2">' + (data.description ? escapeHtml(data.description) : '') + '</textarea>' +
      descCounterHtml(data.description ? data.description.length : 0) + '</td>' +
      '<td><input type="text" class="invoice-input" placeholder="Invoice/Ref no." value="' + (data.invoice ? escapeHtml(data.invoice) : '') + '"></td>' +
      '<td class="amount-cell"><input type="text" inputmode="decimal" class="amount-input" placeholder="0.00" value="' + (data.amount ? formatAmount(data.amount) : '') + '"></td>' +
      '<td class="remove-cell"><button type="button" class="row-remove" title="Remove row"><i class="fa-solid fa-trash"></i></button></td>';
    lineItemsBody.appendChild(tr);
  }

  function escapeHtml(str){
    var div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  function ensureAtLeastOneRow(){
    if (lineItemsBody.children.length === 0) createRow();
  }

  function updateLineItemLimitUI(){
    var atLimit = lineItemsBody.children.length >= MAX_LINE_ITEMS;
    addRowBtn.disabled = atLimit;
    lineItemLimitWarning.hidden = !atLimit;
  }

  addRowBtn.addEventListener('click', function(){
    if (lineItemsBody.children.length >= MAX_LINE_ITEMS) return;
    createRow();
    updateLineItemLimitUI();
    recalc();
  });

  lineItemsBody.addEventListener('click', function(e){
    if (e.target.closest('.row-remove')){
      var tr = e.target.closest('tr');
      tr.parentNode.removeChild(tr);
      ensureAtLeastOneRow();
      updateLineItemLimitUI();
      recalc();
    }
  });

  lineItemsBody.addEventListener('input', function(e){
    if (e.target.classList.contains('desc-input')){
      var counter = e.target.nextElementSibling;
      if (counter && counter.classList.contains('char-count')) counter.outerHTML = descCounterHtml(e.target.value.length);
    }
    recalc();
  });

  lineItemsBody.addEventListener('blur', function(e){
    if (e.target.classList.contains('amount-input')){
      e.target.value = formatAmount(e.target.value);
    }
  }, true);

  function recalc(){
    var rows = Array.prototype.slice.call(lineItemsBody.querySelectorAll('tr'));
    var total = 0;
    var hasCapBreach = false;
    var isStaff = nominalType.value === 'staff';

    rows.forEach(function(tr){
      var amountInput = tr.querySelector('.amount-input');
      var amount = parseAmount(amountInput.value);
      total += amount;

      amountInput.classList.remove('invalid');
      if (isStaff && amount > 10000){
        hasCapBreach = true;
        amountInput.classList.add('invalid');
      }
    });

    totalAmountField.value = formatAmount(total);
    staffCapWarning.hidden = !hasCapBreach;

    headerTotal.textContent = currencySelect.value + ' ' + total.toLocaleString('en-MY', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

    updateSeniorPartnerAvailability(total);
    updateTracker();
    return { total: total, hasCapBreach: hasCapBreach };
  }

  // ---------- Senior Partner / Lawyer-In-Charge routing ----------
  // Matter Related >= RM10,000: LIC + PIC (existing baseline) + 1 Senior Partner.
  // Office Related: NO Lawyer-In-Charge/HOD (removed per instruction) - just PIC + 1 Senior
  // Partner, and >= RM10,000: a 2nd Senior Partner too.
  // Staff Claim: unaffected (capped at RM10,000, LIC + PIC baseline only - no Senior Partner).
  var SENIOR_PARTNER_THRESHOLD = 10000;
  var lawyerInChargeField = document.getElementById('lawyerInChargeField');
  var lawyerInChargeInput = document.getElementById('lawyerInCharge');
  var seniorPartnerField = document.getElementById('seniorPartnerField');
  var seniorPartner2Field = document.getElementById('seniorPartner2Field');
  var seniorPartnerInput = document.getElementById('seniorPartner');
  var seniorPartner2Input = document.getElementById('seniorPartner2');
  var partnerInChargeLabel = document.getElementById('partnerInChargeLabel');

  // Office Related has no separate Lawyer/HOD step (see above), so the same Partner-In-Charge
  // picker/field does double duty as the department head's sign-off for Office requests - it
  // reads as "HOD" there instead, even though it's the same underlying person field and column.
  function partnerInChargeLabelText(){
    if (nominalType.value === 'office') return 'HOD';
    // Staff Claim (Office category): second sign-off is a Senior Partner, saved to SeniorPartner1.
    if (nominalType.value === 'staff' && staffSubtype.value === 'office') return 'Senior Partner 1';
    return 'Partner-In-Charge';
  }
  // Staff Claim under the Office category is signed off first by the department head, not a
  // lawyer - same field, labelled "HOD", and saved to HeadOfDepartment (see spSubmitRequest).
  function isStaffOfficeClaim(){
    return nominalType.value === 'staff' && staffSubtype.value === 'office';
  }
  function lawyerInChargeLabelText(){
    return isStaffOfficeClaim() ? 'HOD' : 'Lawyer-In-Charge';
  }

  function updateSeniorPartnerAvailability(total){
    var isOffice = nominalType.value === 'office';
    var isHighValue = total >= SENIOR_PARTNER_THRESHOLD;
    var needSP1 = isOffice || (nominalType.value === 'matter' && isHighValue);
    var needSP2 = isOffice && isHighValue;
    var needLawyer = !isOffice;

    partnerInChargeLabel.textContent = partnerInChargeLabelText() + ' *';
    document.getElementById('lawyerInChargeLabel').textContent = lawyerInChargeLabelText() + ' *';

    lawyerInChargeField.hidden = !needLawyer;
    lawyerInChargeInput.required = needLawyer;
    // req() in validate() checks el.disabled (not just el.hidden) to decide whether a field
    // is currently required - hiding only the wrapping .field div leaves the <input> itself
    // not .hidden, so it must also be .disabled or validate() would still demand a value.
    lawyerInChargeInput.disabled = !needLawyer;
    if (!needLawyer){ lawyerInChargeInput.value = ''; document.getElementById('lawyerInChargeEmail').value = ''; }

    seniorPartnerField.hidden = !needSP1;
    seniorPartnerInput.required = needSP1;
    if (!needSP1){ seniorPartnerInput.value = ''; document.getElementById('seniorPartnerEmail').value = ''; }

    seniorPartner2Field.hidden = !needSP2;
    seniorPartner2Input.required = needSP2;
    if (!needSP2){ seniorPartner2Input.value = ''; document.getElementById('seniorPartner2Email').value = ''; }
  }

  // Switching the request away from a matter-applicable type must clear whatever matter
  // data was typed in (or copied in via Copy From An Existing Request) - otherwise it just
  // sits there hidden but still gets submitted, since collectData()/spSubmitRequest read
  // these fields unconditionally rather than checking matterSection.hidden themselves.
  function updateMatterVisibility(showMatter){
    matterSection.hidden = !showMatter;
    matterNumber.required = showMatter;
    if (!showMatter){
      matterNumber.value = '';
      clientName.value = '';
      matterDescription.value = '';
      matterNumberError.hidden = true;
    }
  }

  nominalType.addEventListener('change', function(){
    var type = nominalType.value;
    staffSubtypeField.hidden = type !== 'staff';
    updateMatterVisibility(type === 'matter' || (type === 'staff' && staffSubtype.value === 'matter'));
    updateBankNameAvailability();
    recalc();
  });

  staffSubtype.addEventListener('change', function(){
    updateMatterVisibility(nominalType.value === 'staff' && staffSubtype.value === 'matter');
    recalc();
  });

  var matterLookupTimer = null;
  var matterLookupSeq = 0;

  function runMatterLookup(){
    var key = matterNumber.value.trim();
    matterNumberError.hidden = true;
    if (!key || typeof window.lookupActiveMatter !== 'function') return;
    var seq = ++matterLookupSeq;
    window.lookupActiveMatter(key).then(function(match){
      if (seq !== matterLookupSeq) return; // superseded by a newer lookup, ignore stale result
      if (!match){
        // Purely informational - matter numbers not (yet) in Active Matters can still be
        // entered manually, per the existing "you may edit them if needed" hint below.
        matterNumberError.hidden = false;
        return;
      }
      if (match.client) clientName.value = match.client;
      if (match.description) matterDescription.value = match.description;
    }).catch(function(err){
      console.error('Active Matters lookup failed:', err);
    });
  }

  // Fire shortly after typing stops so the fields fill in without needing to tab/click
  // away first; blur still triggers an immediate lookup (e.g. on tab-out or paste+tab).
  matterNumber.addEventListener('input', function(){
    clearTimeout(matterLookupTimer);
    matterLookupTimer = setTimeout(runMatterLookup, 400);
  });

  matterNumber.addEventListener('blur', function(){
    clearTimeout(matterLookupTimer);
    runMatterLookup();
  });

  // Two separate reasons the manual bank-name field can be needed, with two different looks:
  // - Foreign currency: the dropdown (a Malaysia-only bank list) doesn't apply at all, so it's
  //   hidden outright and only the manual field shows.
  // - "Others" picked from the dropdown (still MYR, but the bank just isn't in the list): the
  //   dropdown stays visible (showing "Others") and the manual field appears alongside it.
  // Either way the typed value is treated as "foreign" for SharePoint purposes - it's free
  // text going into BankNameForeign, not a value from the BankName Choice list.
  function isBankNameManualMode(){
    return currencySelect.value.toUpperCase().indexOf('MYR') === -1 || bankNameSelect.value === 'Others';
  }

  function updateBankNameMode(){
    var isForeignCurrency = currencySelect.value.toUpperCase().indexOf('MYR') === -1;
    var isOthers = !isForeignCurrency && bankNameSelect.value === 'Others';
    var needManual = isForeignCurrency || isOthers;

    bankNameSelect.hidden = isForeignCurrency;
    bankNameSelect.required = !isForeignCurrency;
    bankNameManual.hidden = !needManual;
    bankNameManual.required = needManual;
    bankNameForeignHint.hidden = !needManual;
    bankNameForeignHint.textContent = isForeignCurrency
      ? 'Foreign currency selected - please type the bank name manually.'
      : 'Bank not listed - please type the bank name manually.';
    if (isForeignCurrency && !bankNameManual.value) bankNameManual.value = bankNameSelect.value;
    else if (isOthers && bankNameManual.value === bankNameSelect.value) bankNameManual.value = '';
  }

  function activeBankNameField(){
    return isBankNameManualMode() ? bankNameManual : bankNameSelect;
  }

  var bankAccountNumberInput = document.getElementById('bankAccountNumber');
  var bankAccountNumberLabel = document.getElementById('bankAccountNumberLabel');

  // Bank Draft/Cheque/FPX/JomPAY aren't paid into a specific bank account the same way a
  // transfer is, so Bank Name doesn't apply. FPX also has no concept of an account number
  // at all (it's an online banking redirect, not a destination account), so that field is
  // disabled too; JomPAY pays into a biller code rather than an account number, so that
  // field stays active but is relabelled rather than disabled.
  function updateBankNameAvailability(){
    var mode = modeOfPaymentSelect.value.toLowerCase();
    var isFPX = mode.indexOf('fpx') !== -1;
    var isJomPay = mode.indexOf('jompay') !== -1;
    // Staff Claims (either sub-category, Office or Matter) don't need Mode of Payment/Bank
    // Name/Bank Account Number spelled out on the request - only Matter Related and Office
    // Related (the two top-level types, not the Staff Claim subtype of the same names) do.
    var paymentFieldsNeeded = nominalType.value !== 'staff';
    var disableBankName = !paymentFieldsNeeded || isFPX || isJomPay || mode.indexOf('bank draft') !== -1 || mode.indexOf('cheque') !== -1;

    modeOfPaymentSelect.disabled = !paymentFieldsNeeded;
    // Disabling only blocks interaction - it doesn't clear the value, and collectData() reads
    // these fields' .value unconditionally (it doesn't check .disabled), so a mode/bank name
    // chosen before switching to a type/mode that hides it would otherwise still get saved to
    // SharePoint. Dispatching 'change' here re-enters this same function once (with the value
    // already cleared, so it can't loop) - that's what refreshes the custom dropdown's label.
    if (!paymentFieldsNeeded && modeOfPaymentSelect.value){
      modeOfPaymentSelect.value = '';
      modeOfPaymentSelect.dispatchEvent(new Event('change', { bubbles: true }));
    }

    bankNameSelect.disabled = disableBankName;
    bankNameSearchInput.disabled = disableBankName;
    bankNameManual.disabled = disableBankName;
    if (disableBankName){
      if (bankNameSelect.value){
        bankNameSelect.value = '';
        bankNameSelect.dispatchEvent(new Event('change', { bubbles: true }));
      }
      bankNameManual.value = '';
    }

    bankAccountNumberInput.disabled = isFPX || !paymentFieldsNeeded;
    if (isFPX || !paymentFieldsNeeded) bankAccountNumberInput.value = '';
    bankAccountNumberLabel.textContent = isJomPay ? 'Bank Account Number/Biller Code *' : 'Bank Account Number *';
  }
  modeOfPaymentSelect.addEventListener('change', function(){ updateBankNameAvailability(); recalc(); });
  updateBankNameAvailability();

  currencySelect.addEventListener('change', function(){ updateBankNameMode(); recalc(); });
  bankNameSelect.addEventListener('change', updateBankNameMode);
  form.addEventListener('input', updateTracker);
  form.addEventListener('change', updateTracker);

  // Attachments
  function renderFileList(){
    fileList.innerHTML = '';
    files.forEach(function(f, idx){
      var li = document.createElement('li');
      var sizeKb = (f.size / 1024).toFixed(1);
      li.innerHTML = '<span><i class="fa-solid fa-paperclip"></i> ' + escapeHtml(f.name) + ' (' + sizeKb + ' KB)</span>';
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.innerHTML = '<i class="fa-solid fa-trash"></i>';
      btn.title = 'Remove file';
      btn.addEventListener('click', function(){
        files.splice(idx, 1);
        renderFileList();
      });
      li.appendChild(btn);
      fileList.appendChild(li);
    });
    updateTracker();
  }

  var MAX_ATTACHMENT_SIZE = 5 * 1024 * 1024;

  function addFiles(fileListObj){
    var rejected = [];
    Array.prototype.forEach.call(fileListObj, function(f){
      if (f.size > MAX_ATTACHMENT_SIZE) rejected.push(f.name);
      else files.push(f);
    });
    if (rejected.length){
      attachmentError.textContent = (rejected.length === 1 ? '"' + rejected[0] + '" exceeds' : rejected.length + ' files exceed') +
        ' the 5MB size limit and ' + (rejected.length === 1 ? 'was' : 'were') + ' not added.';
      attachmentError.hidden = false;
    } else {
      attachmentError.hidden = true;
    }
    renderFileList();
  }

  dropzone.addEventListener('click', function(){ attachmentInput.click(); });
  attachmentInput.addEventListener('change', function(){ addFiles(attachmentInput.files); attachmentInput.value=''; });
  ['dragenter','dragover'].forEach(function(evt){
    dropzone.addEventListener(evt, function(e){ e.preventDefault(); dropzone.classList.add('drag-over'); });
  });
  ['dragleave','drop'].forEach(function(evt){
    dropzone.addEventListener(evt, function(e){ e.preventDefault(); dropzone.classList.remove('drag-over'); });
  });
  dropzone.addEventListener('drop', function(e){
    if (e.dataTransfer && e.dataTransfer.files) addFiles(e.dataTransfer.files);
  });

  // Validation & submit
  function clearInvalidStates(){
    form.querySelectorAll('.invalid').forEach(function(el){ el.classList.remove('invalid'); });
  }

  // Does the actual checking and marks/clears .invalid on fields - called both by validate()
  // (on submit, which also opens the error modal) and live on every form edit (which just
  // keeps .invalid and an already-open modal's contents in sync, without popping it open).
  function runValidation(){
    var errors = [];
    clearInvalidStates();

    function req(el, msg){
      if (!el.hidden && !el.disabled && !el.value.trim()){
        el.classList.add('invalid');
        errors.push(msg);
      }
    }

    if (!nominalType.value){ nominalType.classList.add('invalid'); errors.push('Select a payment nominal type.'); }
    if (nominalType.value === 'staff' && !staffSubtype.value){ errors.push('Select a staff claim category.'); }

    var showMatter = !matterSection.hidden;
    if (showMatter) req(matterNumber, 'Matter number is required.');

    req(payeeInput, 'Payee is required.');
    var payeeLetterCount = (payeeInput.value.match(/[A-Za-z]/g) || []).length;
    if (payeeInput.value.trim() && payeeLetterCount < 2){
      payeeInput.classList.add('invalid');
      errors.push('Please type as per bank account name.');
    }
    req(modeOfPaymentSelect, 'Mode Of Payment is required.');
    req(activeBankNameField(), 'Bank Name is required.');
    req(document.getElementById('bankAccountNumber'), 'Bank account number is required.');
    req(lawyerInChargeInput, lawyerInChargeLabelText() + ' is required.');
    req(document.getElementById('partnerInCharge'), partnerInChargeLabelText() + ' is required.');
    // LawyerInCharge/PartnerInCharge are SharePoint Person columns, so free-typed text that
    // doesn't match a real directory entry (no email resolved) can't actually be saved there.
    function reqResolvedPerson(inputId, emailId, label){
      var el = document.getElementById(inputId);
      if (el.value.trim() && !document.getElementById(emailId).value){
        el.classList.add('invalid');
        errors.push('Please pick the ' + label + ' from the suggestions list.');
      }
    }
    reqResolvedPerson('lawyerInCharge', 'lawyerInChargeEmail', lawyerInChargeLabelText());
    reqResolvedPerson('partnerInCharge', 'partnerInChargeEmail', partnerInChargeLabelText());

    // Lawyer/HOD and Partner-In-Charge are two independent sign-offs - the same person can't
    // hold both for one request. Only fires once both have actually resolved to a real
    // person (an unresolved pick is already caught above), and is naturally a no-op for
    // Office Related, where the Lawyer/HOD field doesn't apply and stays empty.
    var lawyerEmailVal = document.getElementById('lawyerInChargeEmail').value;
    var partnerEmailVal = document.getElementById('partnerInChargeEmail').value;
    if (lawyerEmailVal && partnerEmailVal && lawyerEmailVal.toLowerCase() === partnerEmailVal.toLowerCase()){
      lawyerInChargeInput.classList.add('invalid');
      document.getElementById('partnerInCharge').classList.add('invalid');
      errors.push(lawyerInChargeLabelText() + ' and ' + partnerInChargeLabelText() + ' cannot be the same person.');
    }

    if (!seniorPartnerField.hidden){
      req(seniorPartnerInput, 'Senior Partner 1 is required.');
      reqResolvedPerson('seniorPartner', 'seniorPartnerEmail', 'Senior Partner 1');

      // The picker itself already excludes whoever is currently Partner-In-Charge from
      // Senior Partner 1's own suggestions, but that only guards picking a NEW duplicate -
      // this catches the reverse order too (Partner-In-Charge changed after Senior Partner 1
      // was already set to that same person).
      var seniorPartnerEmailVal = document.getElementById('seniorPartnerEmail').value;
      if (partnerEmailVal && seniorPartnerEmailVal && partnerEmailVal.toLowerCase() === seniorPartnerEmailVal.toLowerCase()){
        document.getElementById('partnerInCharge').classList.add('invalid');
        seniorPartnerInput.classList.add('invalid');
        errors.push(partnerInChargeLabelText() + ' and Senior Partner 1 cannot be the same person.');
      }
    }
    if (!seniorPartner2Field.hidden){
      req(seniorPartner2Input, 'Senior Partner 2 is required.');
      reqResolvedPerson('seniorPartner2', 'seniorPartner2Email', 'Senior Partner 2');
    }

    var rows = Array.prototype.slice.call(lineItemsBody.querySelectorAll('tr'));
    var anyLineItem = rows.some(function(tr){
      return tr.querySelector('.desc-input').value.trim() && parseAmount(tr.querySelector('.amount-input').value) > 0;
    });
    if (!anyLineItem){
      errors.push('Add at least one payment line item with a description and amount.');
    }

    var invoiceMissing = false;
    rows.forEach(function(tr){
      var hasContent = tr.querySelector('.desc-input').value.trim() || parseAmount(tr.querySelector('.amount-input').value) > 0;
      var invoiceEl = tr.querySelector('.invoice-input');
      if (hasContent && !invoiceEl.value.trim()){
        invoiceEl.classList.add('invalid');
        invoiceMissing = true;
      }
    });
    if (invoiceMissing) errors.push('Invoice number is required for every payment line item.');

    if (!files.length) errors.push('At least one attachment is required.');
    dropzone.classList.toggle('invalid', !files.length);

    var calc = recalc();
    if (calc.hasCapBreach) errors.push('One or more staff claim amounts exceed RM10,000.00.');
    if (calc.total <= 0) errors.push('Total amount must be greater than zero.');

    return errors;
  }

  function showErrorModal(messages){
    errorList.innerHTML = messages.map(function(m){ return '<li>' + m + '</li>'; }).join('');
    errorModal.hidden = false;
  }
  function hideErrorModal(){ errorModal.hidden = true; }
  closeErrorModalBtn.addEventListener('click', hideErrorModal);
  errorModalOkBtn.addEventListener('click', hideErrorModal);
  errorModal.addEventListener('click', function(e){ if (e.target === errorModal) hideErrorModal(); });

  // Don't mark anything red until the user has actually tried to submit once - otherwise the
  // untouched/empty fields on a brand new form would all show as invalid immediately (every
  // field here is required-by-default on a blank form), including from the synthetic 'change'
  // events this page's own setup code fires while populating dropdowns on load.
  var hasAttemptedSubmit = false;

  function validate(){
    hasAttemptedSubmit = true;
    var errors = runValidation();
    if (errors.length) showErrorModal(errors);
    else hideErrorModal();
    return errors.length === 0;
  }

  // Keep the red field highlighting - and an already-open error modal's contents - in sync
  // as the user fixes things, instead of only re-checking on the next submit attempt. Doesn't
  // open the modal on its own; only the Submit button (validate()) does that, and only once
  // that's happened at least once does editing fields start live-updating .invalid states.
  form.addEventListener('input', function(){
    if (!hasAttemptedSubmit) return;
    var errors = runValidation();
    if (!errorModal.hidden){
      if (errors.length) showErrorModal(errors);
      else hideErrorModal();
    }
  });
  form.addEventListener('change', function(){
    if (!hasAttemptedSubmit) return;
    var errors = runValidation();
    if (!errorModal.hidden){
      if (errors.length) showErrorModal(errors);
      else hideErrorModal();
    }
  });

  function collectData(){
    var rows = Array.prototype.slice.call(lineItemsBody.querySelectorAll('tr')).map(function(tr){
      return {
        description: tr.querySelector('.desc-input').value,
        invoice: tr.querySelector('.invoice-input').value,
        amount: parseAmount(tr.querySelector('.amount-input').value)
      };
    });
    return {
      nominalType: nominalType.value,
      staffSubtype: staffSubtype.value,
      matterNumber: matterNumber.value,
      clientName: clientName.value,
      matterDescription: matterDescription.value,
      payee: payeeInput.value,
      // Re-check .disabled here rather than trust it was already cleared elsewhere - these
      // get disabled (and should read as blank) whenever Mode of Payment doesn't need
      // specifying (Matter/Office Related) or FPX/JomPAY hides a given field, and a path
      // like applyFormData's direct .value assignment doesn't go through that clearing logic.
      modeOfPayment: document.getElementById('modeOfPayment').disabled ? '' : document.getElementById('modeOfPayment').value,
      bankName: activeBankNameField().disabled ? '' : activeBankNameField().value,
      // Which SharePoint column this goes to (BankName vs BankNameForeign) depends on WHY the
      // manual field was used - foreign currency, or "Others" picked for an unlisted local
      // bank - not just on currency, now that "Others" lets a manually-typed name happen
      // under MYR too (see isBankNameManualMode/updateBankNameMode).
      bankNameIsForeign: isBankNameManualMode(),
      bankAccountNumber: document.getElementById('bankAccountNumber').disabled ? '' : document.getElementById('bankAccountNumber').value,
      lawyerInCharge: document.getElementById('lawyerInCharge').value,
      lawyerInChargeEmail: document.getElementById('lawyerInChargeEmail').value,
      partnerInCharge: document.getElementById('partnerInCharge').value,
      partnerInChargeEmail: document.getElementById('partnerInChargeEmail').value,
      seniorPartner: seniorPartnerField.hidden ? '' : seniorPartnerInput.value,
      seniorPartnerEmail: seniorPartnerField.hidden ? '' : document.getElementById('seniorPartnerEmail').value,
      seniorPartner2: seniorPartner2Field.hidden ? '' : seniorPartner2Input.value,
      seniorPartner2Email: seniorPartner2Field.hidden ? '' : document.getElementById('seniorPartner2Email').value,
      lineItems: rows,
      currency: document.getElementById('currency').value,
      totalAmount: totalAmountField.value,
      fileNames: files.map(function(f){ return f.name; })
    };
  }

  // Shared by the Reset button and by a successful submit (below) - pulled out so both go
  // through the exact same cleanup rather than the two drifting apart over time.
  function resetForm(){
    form.reset();
    // form.reset() puts the real <select>s back to their blank default but doesn't fire
    // 'change' - the visible custom dropdown (cst-trigger/cst-search-input, a separate
    // element layered over the real <select>, see enhanceSelect/enhanceSelectSearchable)
    // only refreshes its own label off that event, so without this it would keep showing
    // whatever was last chosen even though the real value underneath is already blank.
    nominalType.dispatchEvent(new Event('change'));
    staffSubtype.dispatchEvent(new Event('change'));
    modeOfPaymentSelect.dispatchEvent(new Event('change'));
    currencySelect.dispatchEvent(new Event('change'));
    bankNameSelect.dispatchEvent(new Event('change'));
    matterSection.hidden = true;
    staffSubtypeField.hidden = true;
    clientName.value = '';
    matterDescription.value = '';
    matterNumberError.hidden = true;
    lineItemsBody.innerHTML = '';
    createRow();
    updateLineItemLimitUI();
    files = [];
    renderFileList();
    attachmentError.hidden = true;
    dropzone.classList.remove('invalid');
    bankNameManual.value = '';
    updateBankNameMode();
    recalc();
    hasAttemptedSubmit = false;
    clearInvalidStates();
    hideErrorModal();
  }

  resetBtn.addEventListener('click', function(){
    if (!confirm('Reset the form? Unsaved changes will be lost.')) return;
    resetForm();
  });

  form.addEventListener('submit', function(e){
    e.preventDefault();
    if (!validate()) return;
    var data = collectData();

    if (typeof window.spSubmitRequest !== 'function'){
      showErrorModal(['Not connected to SharePoint yet - please make sure you are signed in, then try again.']);
      return;
    }

    var originalSubmitHtml = submitBtn.innerHTML;
    submitBtn.disabled = true;
    submitBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Submitting...';

    window.spSubmitRequest(data, files).then(function(created){
      submitBtn.disabled = false;
      submitBtn.innerHTML = originalSubmitHtml;
      refNumber.textContent = created.id;
      successSummary.textContent = data.payee + ' - ' + data.currency + ' ' + data.totalAmount + ' submitted for approval.';
      successModal.hidden = false;
      resetForm();
      // The success modal is a fixed overlay on top of whichever view is active, so switching
      // to View Requests now (while it's still showing) means closing the modal lands them
      // straight there instead of back on the just-reset, now-empty Submit form. The nav
      // item's own click handler already reloads the list, so no need to call that here too.
      var viewRequestsNavItem = document.querySelector('.nav-item[data-view="requests"]');
      if (viewRequestsNavItem) viewRequestsNavItem.click();
    }).catch(function(err){
      submitBtn.disabled = false;
      submitBtn.innerHTML = originalSubmitHtml;
      showErrorModal(['Could not submit to SharePoint: ' + escapeHtml((err && err.message) || 'Unknown error')]);
    });
  });

  closeModalBtn.addEventListener('click', function(){ successModal.hidden = true; });
  document.getElementById('closeModalXBtn').addEventListener('click', function(){ successModal.hidden = true; });

  // Clicking the dimmed backdrop (not the card itself) closes whichever modal it belongs to.
  Array.prototype.forEach.call(document.querySelectorAll('.modal'), function(modal){
    modal.addEventListener('click', function(e){
      if (e.target === modal) modal.hidden = true;
    });
  });

  // ---------- View Requests: status list + details modal ----------
  var TYPE_LABELS = { matter: 'Matter Related', office: 'Office Related', staff: 'Staff Claims' };
  // Sourced directly from Master's own "Status" Choice column (Approved/Rejected/Pending/
  // TIMED OUT/Completed) via classifyApprovalStatus - not derived from the individual
  // Lawyer/Partner/Accounts stage statuses (those are shown separately in the details modal).
  var STATUS_META = {
    'pending': { label: 'Pending', cls: 'pending', icon: 'fa-clock' },
    'timed-out': { label: 'Timed Out', cls: 'pending', icon: 'fa-triangle-exclamation' },
    'approved': { label: 'Approved', cls: 'approved', icon: 'fa-circle-check' },
    'completed': { label: 'Completed', cls: 'approved', icon: 'fa-check-double' },
    'rejected': { label: 'Rejected', cls: 'rejected', icon: 'fa-circle-xmark' }
  };
  var PENDING_STATUSES = ['pending', 'timed-out'];

  // Populated from the real "EVoucher System" SharePoint list by loadRequestsFromSharePoint()
  // below - no hardcoded/demo requests here.
  var SUBMITTED_REQUESTS = [];

  var requestsPendingBody = document.getElementById('requestsPendingBody');
  var requestsPendingEmpty = document.getElementById('requestsPendingEmpty');
  var requestsCompletedBody = document.getElementById('requestsCompletedBody');
  var requestsCompletedEmpty = document.getElementById('requestsCompletedEmpty');
  var accountsPendingBody = document.getElementById('accountsPendingBody');
  var accountsPendingEmpty = document.getElementById('accountsPendingEmpty');
  var accountsCountBadge = document.getElementById('accountsCountBadge');

  var REQUESTS_PAGE_SIZE = 10;
  var pendingPage = 1, completedPage = 1, accountsPage = 1;
  var pendingPagination = document.getElementById('pendingPagination');
  var pendingPageInfo = document.getElementById('pendingPageInfo');
  var pendingPrevBtn = document.getElementById('pendingPrevBtn');
  var pendingNextBtn = document.getElementById('pendingNextBtn');
  var completedPagination = document.getElementById('completedPagination');
  var completedPageInfo = document.getElementById('completedPageInfo');
  var completedPrevBtn = document.getElementById('completedPrevBtn');
  var completedNextBtn = document.getElementById('completedNextBtn');
  var accountsPagination = document.getElementById('accountsPagination');
  var accountsPageInfo = document.getElementById('accountsPageInfo');
  var accountsPrevBtn = document.getElementById('accountsPrevBtn');
  var accountsNextBtn = document.getElementById('accountsNextBtn');

  // Slices a full list of matched indices down to the current page, clamping the page number
  // in case the underlying data shrank (e.g. a search narrowed the results) since it was set.
  function paginateIndices(indices, page){
    var totalPages = Math.max(1, Math.ceil(indices.length / REQUESTS_PAGE_SIZE));
    var clampedPage = Math.min(Math.max(1, page), totalPages);
    var start = (clampedPage - 1) * REQUESTS_PAGE_SIZE;
    return { pageIndices: indices.slice(start, start + REQUESTS_PAGE_SIZE), page: clampedPage, totalPages: totalPages };
  }

  function updatePaginationControls(container, infoEl, prevBtn, nextBtn, page, totalPages){
    container.hidden = totalPages <= 1;
    infoEl.textContent = 'Page ' + page + ' of ' + totalPages;
    prevBtn.disabled = page <= 1;
    nextBtn.disabled = page >= totalPages;
  }

  pendingPrevBtn.addEventListener('click', function(){ pendingPage--; renderRequestsList(); });
  pendingNextBtn.addEventListener('click', function(){ pendingPage++; renderRequestsList(); });
  completedPrevBtn.addEventListener('click', function(){ completedPage--; renderRequestsList(); });
  completedNextBtn.addEventListener('click', function(){ completedPage++; renderRequestsList(); });
  accountsPrevBtn.addEventListener('click', function(){ accountsPage--; renderRequestsList(); });
  accountsNextBtn.addEventListener('click', function(){ accountsPage++; renderRequestsList(); });

  var requestDetailsModal = document.getElementById('requestDetailsModal');
  var requestDetailsBody = document.getElementById('requestDetailsBody');
  var closeRequestDetailsBtn = document.getElementById('closeRequestDetailsBtn');
  var resubmitRequestBtn = document.getElementById('resubmitRequestBtn');
  var rdMainActions = document.getElementById('rdMainActions');
  var accountsCompleteBtn = document.getElementById('accountsCompleteBtn');
  var accountsRejectBtn = document.getElementById('accountsRejectBtn');
  var accountsRemarksBox = document.getElementById('accountsRemarksBox');
  var accountsRemarksInput = document.getElementById('accountsRemarksInput');
  var accountsRemarksError = document.getElementById('accountsRemarksError');
  var currentDetailsIdx = -1;

  function requestRowHtml(reqItem, idx){
    var meta = STATUS_META[reqItem.status];
    return '<tr>' +
      '<td data-label="ID"><span class="ref-chip">' + escapeHtml(reqItem.ref) + '</span></td>' +
      '<td data-label="Type"><span class="type-pill ' + escapeHtml(reqItem.type) + '">' + escapeHtml(TYPE_LABELS[reqItem.type] || reqItem.type) + '</span></td>' +
      '<td data-label="Matter No">' + escapeHtml((reqItem.formData && reqItem.formData.matterNumber) || '-') + '</td>' +
      '<td data-label="Created By">' + escapeHtml(reqItem.createdBy || '-') + '</td>' +
      '<td data-label="Payee">' + escapeHtml(reqItem.payee) + '</td>' +
      '<td data-label="Amount">' + escapeHtml(reqItem.currency) + ' ' + escapeHtml(reqItem.amount) + '</td>' +
      '<td data-label="Date">' + escapeHtml(reqItem.date) + '</td>' +
      '<td data-label="Status"><span class="status-badge ' + meta.cls + '"><i class="fa-solid ' + meta.icon + '"></i> ' + meta.label + '</span></td>' +
      '<td><button type="button" class="btn btn-outline btn-sm btn-view-row view-details-btn" data-idx="' + idx + '"><i class="fa-solid fa-eye"></i> View</button></td>' +
      '</tr>';
  }

  function accountsRowHtml(reqItem, idx){
    return '<tr>' +
      '<td data-label="ID"><span class="ref-chip">' + escapeHtml(reqItem.ref) + '</span></td>' +
      '<td data-label="Type"><span class="type-pill ' + escapeHtml(reqItem.type) + '">' + escapeHtml(TYPE_LABELS[reqItem.type] || reqItem.type) + '</span></td>' +
      '<td data-label="Payee">' + escapeHtml(reqItem.payee) + '</td>' +
      '<td data-label="Amount">' + escapeHtml(reqItem.currency) + ' ' + escapeHtml(reqItem.amount) + '</td>' +
      '<td data-label="Date">' + escapeHtml(reqItem.date) + '</td>' +
      '<td><button type="button" class="btn btn-outline btn-sm btn-view-row accounts-review-btn" data-idx="' + idx + '"><i class="fa-solid fa-eye"></i> Review</button></td>' +
      '</tr>';
  }

  var statPendingCount = document.getElementById('statPendingCount');
  var statApprovedCount = document.getElementById('statApprovedCount');
  var statRejectedCount = document.getElementById('statRejectedCount');
  var pendingCountBadge = document.getElementById('pendingCountBadge');
  var completedCountBadge = document.getElementById('completedCountBadge');

  // Clicking a stat card filters the two tables down to that bucket - clicking the same one
  // again (or the clear link) goes back to showing everything. Only affects Pending/Completed
  // & Rejected, not the separate Accounts Approval table.
  var requestsStatusFilter = null;
  var STAT_FILTER_LABELS = { pending: 'Pending', approved: 'Approved', rejected: 'Rejected' };
  var statCards = Array.prototype.slice.call(document.querySelectorAll('.stat-card[data-filter]'));
  var statFilterHint = document.getElementById('statFilterHint');
  var statFilterHintText = document.getElementById('statFilterHintText');
  var statFilterClearBtn = document.getElementById('statFilterClearBtn');

  function matchesStatusFilter(reqItem){
    if (!requestsStatusFilter) return true;
    if (requestsStatusFilter === 'pending') return PENDING_STATUSES.indexOf(reqItem.status) !== -1;
    if (requestsStatusFilter === 'approved') return reqItem.status === 'approved' || reqItem.status === 'completed';
    if (requestsStatusFilter === 'rejected') return reqItem.status === 'rejected';
    return true;
  }

  function setStatusFilter(filter){
    requestsStatusFilter = (requestsStatusFilter === filter) ? null : filter;
    statCards.forEach(function(card){
      var isActive = card.getAttribute('data-filter') === requestsStatusFilter;
      card.classList.toggle('active', isActive);
      card.setAttribute('aria-pressed', isActive ? 'true' : 'false');
    });
    statFilterHint.hidden = !requestsStatusFilter;
    if (requestsStatusFilter) statFilterHintText.textContent = 'Showing only ' + STAT_FILTER_LABELS[requestsStatusFilter] + ' requests.';
    pendingPage = 1; completedPage = 1;
    renderRequestsList();
  }

  statCards.forEach(function(card){
    card.addEventListener('click', function(){ setStatusFilter(card.getAttribute('data-filter')); });
    card.addEventListener('keydown', function(e){
      if (e.key === 'Enter' || e.key === ' '){ e.preventDefault(); setStatusFilter(card.getAttribute('data-filter')); }
    });
  });
  statFilterClearBtn.addEventListener('click', function(){ setStatusFilter(requestsStatusFilter); });

  var requestsSearchInput = document.getElementById('requestsSearchInput');
  var requestsSearchClear = document.getElementById('requestsSearchClear');
  var requestsSearchQuery = '';

  // Matches on every column shown in the table (ID, type, payee, amount, date, status) - not
  // just the columns visible in the current viewport width.
  function reqItemMatchesSearch(reqItem){
    if (!requestsSearchQuery) return true;
    var meta = STATUS_META[reqItem.status];
    var matterNumber = (reqItem.formData && reqItem.formData.matterNumber) || '';
    var haystack = [
      String(reqItem.ref),
      TYPE_LABELS[reqItem.type] || reqItem.type,
      String(matterNumber),
      meta ? meta.label : reqItem.status,
      reqItem.currency + ' ' + reqItem.amount,
      reqItem.payee,
      reqItem.date,
      reqItem.createdBy || ''
    ].join(' ').toLowerCase();
    return haystack.indexOf(requestsSearchQuery) !== -1;
  }

  requestsSearchInput.addEventListener('input', function(){
    requestsSearchQuery = requestsSearchInput.value.trim().toLowerCase();
    requestsSearchClear.hidden = !requestsSearchInput.value;
    pendingPage = 1; completedPage = 1;
    renderRequestsList();
  });
  requestsSearchClear.addEventListener('click', function(){
    requestsSearchInput.value = '';
    requestsSearchQuery = '';
    requestsSearchClear.hidden = true;
    pendingPage = 1; completedPage = 1;
    renderRequestsList();
  });

  function renderRequestsList(){
    // Stat cards always reflect the true overall totals; the section count badges next to
    // each table heading reflect what's actually visible under the current search (across all
    // pages, not just the page currently showing).
    var pendingCount = 0, approvedCount = 0, rejectedCount = 0;
    var pendingIndices = [], completedIndices = [], accountsIndices = [];
    SUBMITTED_REQUESTS.forEach(function(reqItem, idx){
      var matches = reqItemMatchesSearch(reqItem) && matchesStatusFilter(reqItem);
      if (PENDING_STATUSES.indexOf(reqItem.status) !== -1){
        pendingCount++;
        if (matches) pendingIndices.push(idx);
      } else {
        if (reqItem.status === 'approved' || reqItem.status === 'completed') approvedCount++;
        else if (reqItem.status === 'rejected') rejectedCount++;
        if (matches) completedIndices.push(idx);
      }
      if (reqItem.readyForAccounts) accountsIndices.push(idx);
    });

    var pendingResult = paginateIndices(pendingIndices, pendingPage);
    pendingPage = pendingResult.page;
    requestsPendingBody.innerHTML = pendingResult.pageIndices.map(function(idx){ return requestRowHtml(SUBMITTED_REQUESTS[idx], idx); }).join('');
    requestsPendingEmpty.hidden = pendingIndices.length !== 0;
    updatePaginationControls(pendingPagination, pendingPageInfo, pendingPrevBtn, pendingNextBtn, pendingResult.page, pendingResult.totalPages);

    var completedResult = paginateIndices(completedIndices, completedPage);
    completedPage = completedResult.page;
    requestsCompletedBody.innerHTML = completedResult.pageIndices.map(function(idx){ return requestRowHtml(SUBMITTED_REQUESTS[idx], idx); }).join('');
    requestsCompletedEmpty.hidden = completedIndices.length !== 0;
    updatePaginationControls(completedPagination, completedPageInfo, completedPrevBtn, completedNextBtn, completedResult.page, completedResult.totalPages);

    var accountsResult = paginateIndices(accountsIndices, accountsPage);
    accountsPage = accountsResult.page;
    accountsPendingBody.innerHTML = accountsResult.pageIndices.map(function(idx){ return accountsRowHtml(SUBMITTED_REQUESTS[idx], idx); }).join('');
    accountsPendingEmpty.hidden = accountsIndices.length !== 0;
    updatePaginationControls(accountsPagination, accountsPageInfo, accountsPrevBtn, accountsNextBtn, accountsResult.page, accountsResult.totalPages);

    accountsCountBadge.textContent = accountsIndices.length;
    statPendingCount.textContent = pendingCount;
    statApprovedCount.textContent = approvedCount;
    statRejectedCount.textContent = rejectedCount;
    pendingCountBadge.textContent = pendingIndices.length;
    completedCountBadge.textContent = completedIndices.length;
  }

  var requestsLoadError = document.getElementById('requestsLoadError');
  var requestsLoadErrorText = document.getElementById('requestsLoadErrorText');

  var accountsLoadError = document.getElementById('accountsLoadError');
  var accountsLoadErrorText = document.getElementById('accountsLoadErrorText');

  function loadRequestsFromSharePoint(){
    if (typeof window.spFetchRequests !== 'function') return;
    return window.spFetchRequests().then(function(items){
      requestsLoadError.hidden = true;
      accountsLoadError.hidden = true;
      SUBMITTED_REQUESTS = items;
      renderRequestsList();
    }).catch(function(err){
      console.warn('Could not load requests from SharePoint.', err);
      requestsLoadErrorText.textContent = 'Could not load requests from SharePoint: ' + err.message;
      requestsLoadError.hidden = false;
      accountsLoadErrorText.textContent = 'Could not load requests from SharePoint: ' + err.message;
      accountsLoadError.hidden = false;
    });
  }

  window.eVoucherSignInHandlers.push(function(){ loadRequestsFromSharePoint(); });

  function openRequestDetails(idx, fromAccounts){
    var reqItem = SUBMITTED_REQUESTS[idx];
    if (!reqItem) return;
    currentDetailsIdx = idx;
    var meta = STATUS_META[reqItem.status];

    var PLACEHOLDER = 'Not set';
    function val(v){ return (v === undefined || v === null || v === '') ? PLACEHOLDER : v; }

    function rowsHtml(rows){
      return rows.map(function(r){
        var isPlaceholder = r[1] === PLACEHOLDER;
        // r[2] (isHtml) means r[1] is already-safe markup (a status badge) - don't re-escape it.
        var valueHtml = r[2] ? r[1] : escapeHtml(r[1]);
        return '<div class="matrix-row"><span class="label">' + escapeHtml(r[0]) + '</span><span class="value' + (isPlaceholder ? ' value-muted' : '') + '">' + valueHtml + '</span></div>';
      }).join('');
    }

    // Individual stage statuses (Approved/Rejected/Pending/TIMED OUT/Not Applicable) shown
    // as their own colored badge, reusing the same classifyApprovalStatus buckets/colors as
    // the main status pill - but keeping the exact wording SharePoint has, not a generic label.
    function statusBadgeHtml(status, displayText){
      var bucket = window.classifyApprovalStatus(status);
      var badgeMeta = STATUS_META[bucket] || STATUS_META.pending;
      return '<span class="status-badge ' + badgeMeta.cls + '"><i class="fa-solid ' + badgeMeta.icon + '"></i> ' + escapeHtml(displayText || status) + '</span>';
    }

    // Each approver gets its own card (name, status, and - if they left one - their remarks)
    // rather than a flat label/value list, so a remark reads as clearly belonging to the
    // specific stage that wrote it instead of being lumped into one combined box at the end.
    function approverCardHtml(roleLabel, name, status, displayStatusText, remarks){
      var displayName = val(name);
      var isNamePlaceholder = displayName === PLACEHOLDER;
      var statusHtml = status
        ? statusBadgeHtml(status, displayStatusText)
        : '<span class="approval-status-muted">' + PLACEHOLDER + '</span>';
      var remarksHtml = remarks
        ? '<div class="approval-remarks"><i class="fa-solid fa-comment-dots"></i> ' + escapeHtml(remarks) + '</div>'
        : '';
      return '<div class="approval-card">' +
          '<div class="approval-card-top">' +
            '<span class="approval-role">' + escapeHtml(roleLabel) + '</span>' +
            statusHtml +
          '</div>' +
          '<div class="approval-card-name' + (isNamePlaceholder ? ' value-muted' : '') + '">' + escapeHtml(displayName) + '</div>' +
          remarksHtml +
        '</div>';
    }

    // The Lawyer stage is a verification step, not an approval one - "Approved" reads as
    // "Verified" here for display only; the colour/classification (still driven by the raw
    // status text) is unchanged.
    function lawyerStatusDisplay(status){
      return (status || '').toLowerCase() === 'approved' ? 'Verified' : status;
    }

    var typePillHtml = '<span class="type-pill ' + escapeHtml(reqItem.type) + '">' + escapeHtml(TYPE_LABELS[reqItem.type] || reqItem.type) + '</span>';
    var isStaffType = reqItem.type === 'staff';
    var staffSubtype = (reqItem.formData && reqItem.formData.staffSubtype) || 'matter';
    var overviewRows = [
      ['Request Type', typePillHtml, true],
      ['Created By', val(reqItem.createdBy)],
      ['Payee', reqItem.payee],
      ['Amount', reqItem.currency + ' ' + reqItem.amount],
      ['Date Submitted', reqItem.date]
    ];
    // Staff Claim category (Matter vs Office) isn't its own SharePoint column - it's folded
    // into the RequestType Choice text itself (see inferTypeFromText/requestTypeForSharePoint),
    // so it's otherwise invisible here unless called out as its own row.
    if (isStaffType){
      var staffSubtypePillHtml = staffSubtype === 'office'
        ? '<span class="type-pill staff-office">Office</span>'
        : '<span class="type-pill staff-matter">Matter</span>';
      overviewRows.splice(1, 0, ['Staff Claim Category', staffSubtypePillHtml, true]);
    }
    // Only shown when the request actually has matter data - a Staff Claim filed under the
    // Office category, or an Office Related request, never captured these.
    var hasMatterData = reqItem.type === 'matter' || (isStaffType && staffSubtype === 'matter');
    var matterRows = [
      ['Matter Number', val(reqItem.formData && reqItem.formData.matterNumber)],
      ['Client Name', val(reqItem.formData && reqItem.formData.clientName)],
      ['Matter Description', val(reqItem.formData && reqItem.formData.matterDescription)]
    ];
    // Payment/Approval always render every field now (not just the ones with a value) -
    // missing data shows a placeholder instead of silently disappearing, so it's clear
    // whether something genuinely wasn't captured.
    var paymentRows = [
      ['Bank Name', val(reqItem.bankName)],
      ['Bank Account Number', val(reqItem.bankAccountNumber)]
    ];
    var lineItems = (reqItem.formData && reqItem.formData.lineItems) || [];
    function fmtAmount(n){
      return reqItem.currency + ' ' + (parseFloat(n) || 0).toLocaleString('en-MY', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }
    // Every stage always renders, straight from its own SharePoint column - the first approval
    // is Lawyer-In-Charge (Matter/Staff) or Head of Department (Office), so one of those two
    // simply shows Not set.
    // A stage with no approver assigned doesn't apply to this request, so it always reads
    // "Not Applicable" whatever its status column holds (e.g. a default "New"). Display only -
    // SharePoint isn't changed. Accounts is excluded: it's assigned later, when Accounts acts.
    function stageStatus(name, status){ return name ? status : 'Not Applicable'; }
    var approvalCardsHtml =
      approverCardHtml('Lawyer-In-Charge', reqItem.lawyerInCharge, stageStatus(reqItem.lawyerInCharge, reqItem.lawyerStatus), reqItem.lawyerInCharge ? lawyerStatusDisplay(reqItem.lawyerStatus) : undefined, reqItem.lawyerRemarks) +
      approverCardHtml('Head of Department', reqItem.headOfDepartment, stageStatus(reqItem.headOfDepartment, reqItem.headOfDepartmentStatus), undefined, reqItem.headOfDepartmentRemarks) +
      approverCardHtml('Partner-In-Charge', reqItem.partnerInCharge, stageStatus(reqItem.partnerInCharge, reqItem.partnerStatus), undefined, reqItem.partnerRemarks) +
      approverCardHtml('Senior Partner 1', reqItem.seniorPartner, stageStatus(reqItem.seniorPartner, reqItem.seniorPartnerStatus), undefined, reqItem.seniorPartnerRemarks) +
      approverCardHtml('Senior Partner 2', reqItem.seniorPartner2, stageStatus(reqItem.seniorPartner2, reqItem.seniorPartner2Status), undefined, reqItem.seniorPartner2Remarks) +
      // AccountsStatus's Choice value is "Complete" - shown as "Completed" to match the overall status.
      approverCardHtml('Accounts', reqItem.accountsInCharge, reqItem.accountsStatus,
        (reqItem.accountsStatus || '').toLowerCase() === 'complete' ? 'Completed' : undefined, reqItem.accountsRemarks);

    var html = '<div class="rd-hero">' +
        '<span class="ref-chip">ID : ' + escapeHtml(reqItem.ref) + '</span>' +
        '<span class="status-badge ' + meta.cls + '"><i class="fa-solid ' + meta.icon + '"></i> ' + meta.label + '</span>' +
      '</div>';
    html += '<div class="rd-section"><div class="rd-section-title">Overview</div>' + rowsHtml(overviewRows) + '</div>';
    if (hasMatterData){
      html += '<div class="rd-section"><div class="rd-section-title">Matter Details</div>' + rowsHtml(matterRows) + '</div>';
    }
    html += '<div class="rd-section"><div class="rd-section-title">Payment</div>' + rowsHtml(paymentRows) +
      (isStaffType ? '<div class="rd-inline-note"><i class="fa-solid fa-circle-info"></i> Not required for Staff Claims.</div>' : '') +
      '</div>';
    if (lineItems.length){
      var total = lineItems.reduce(function(sum, li){ return sum + (parseFloat(li.amount) || 0); }, 0);
      html += '<div class="rd-section"><div class="rd-section-title">Line Items</div>' +
        '<table class="rd-table"><thead><tr><th>Description</th><th>Invoice No.</th><th>Amount</th></tr></thead><tbody>' +
        lineItems.map(function(li){
          return '<tr><td>' + escapeHtml(li.description || '') + '</td><td>' + escapeHtml(li.invoice || '') + '</td><td>' + escapeHtml(fmtAmount(li.amount)) + '</td></tr>';
        }).join('') +
        (lineItems.length > 1 ? '<tr class="rd-table-total"><td colspan="2">Total</td><td>' + escapeHtml(fmtAmount(total)) + '</td></tr>' : '') +
        '</tbody></table></div>';
    }
    var attachments = reqItem.attachments || [];
    html += '<div class="rd-section"><div class="rd-section-title">Attachments</div>' +
      (attachments.length
        ? '<div class="rd-attachments">' + attachments.map(function(a){
            return '<a class="rd-attachment" href="' + escapeHtml(a.url) + '" target="_blank" rel="noopener">' +
              '<i class="fa-solid fa-paperclip"></i> ' + escapeHtml(a.name) + '</a>';
          }).join('') + '</div>'
        : '<div class="rd-no-attachments">' + PLACEHOLDER + '</div>') +
      '</div>';
    html += '<div class="rd-section rd-section-approval"><div class="rd-section-title">Approval</div>' + approvalCardsHtml + '</div>';

    requestDetailsBody.innerHTML = html;
    resubmitRequestBtn.hidden = !(reqItem.status === 'rejected' && reqItem.formData);

    var showAccountsActions = !!fromAccounts && reqItem.readyForAccounts;
    accountsCompleteBtn.hidden = !showAccountsActions;
    accountsRejectBtn.hidden = !showAccountsActions;
    accountsRemarksBox.hidden = !showAccountsActions;
    accountsRemarksInput.value = '';
    accountsRemarksInput.classList.remove('invalid');
    accountsRemarksError.hidden = true;
    rdMainActions.hidden = false;

    requestDetailsModal.hidden = false;
  }

  requestsPendingBody.addEventListener('click', function(e){
    var btn = e.target.closest('.view-details-btn');
    if (btn) openRequestDetails(parseInt(btn.getAttribute('data-idx'), 10));
  });
  requestsCompletedBody.addEventListener('click', function(e){
    var btn = e.target.closest('.view-details-btn');
    if (btn) openRequestDetails(parseInt(btn.getAttribute('data-idx'), 10));
  });
  accountsPendingBody.addEventListener('click', function(e){
    var btn = e.target.closest('.accounts-review-btn');
    if (btn) openRequestDetails(parseInt(btn.getAttribute('data-idx'), 10), true);
  });

  closeRequestDetailsBtn.addEventListener('click', function(){ requestDetailsModal.hidden = true; });

  function applyFormData(data){
    if (!data) return;
    nominalType.value = data.nominalType || '';
    nominalType.dispatchEvent(new Event('change'));
    staffSubtype.value = data.staffSubtype || 'matter';
    staffSubtype.dispatchEvent(new Event('change'));
    // Only restore matter fields if they actually apply to THIS data's own type/subtype -
    // otherwise a historical record that has stale matter data left over from before it was
    // switched away from Matter Related (the exact bug updateMatterVisibility now prevents
    // going forward) would have that stale data copied right back in via Copy From An
    // Existing Request, undoing the clear the dispatched 'change' above just did.
    var dataShowsMatter = data.nominalType === 'matter' || (data.nominalType === 'staff' && data.staffSubtype === 'matter');
    matterNumber.value = dataShowsMatter ? (data.matterNumber || '') : '';
    clientName.value = dataShowsMatter ? (data.clientName || '') : '';
    matterDescription.value = dataShowsMatter ? (data.matterDescription || '') : '';
    payeeInput.value = (data.payee || '').toUpperCase();
    modeOfPaymentSelect.value = data.modeOfPayment || '';
    modeOfPaymentSelect.dispatchEvent(new Event('change'));
    currencySelect.value = data.currency || 'MYR';
    currencySelect.dispatchEvent(new Event('change'));
    // If the copied data's bank name was free-typed (genuinely foreign currency, or "Others"
    // picked for an MYR bank not in the list), reflect that split rather than just dumping
    // the text into whichever field activeBankNameField() happens to point at right now -
    // otherwise an "Others" bank copied back in would silently land in the BankName Choice
    // field instead of BankNameForeign, which SharePoint would reject as not a valid choice.
    var isMyrNow = currencySelect.value.toUpperCase().indexOf('MYR') !== -1;
    if (data.bankNameIsForeign && isMyrNow && bankNameSelect.value !== 'Others'){
      bankNameSelect.value = 'Others';
      bankNameSelect.dispatchEvent(new Event('change'));
    } else if (!data.bankNameIsForeign && isMyrNow && bankNameSelect.value === 'Others'){
      bankNameSelect.value = '';
      bankNameSelect.dispatchEvent(new Event('change'));
    }
    // The dispatches above already ran updateBankNameAvailability for this data's own
    // nominalType/modeOfPayment, so .disabled here already reflects whether these fields
    // actually apply - only restore a value where they do, same reasoning as the matter
    // fields above (don't let a stale value sit in what's now a disabled field).
    var bankNameFieldEl = activeBankNameField();
    bankNameFieldEl.value = bankNameFieldEl.disabled ? '' : (data.bankName || '');
    var bankAccountNumberFieldEl = document.getElementById('bankAccountNumber');
    bankAccountNumberFieldEl.value = bankAccountNumberFieldEl.disabled ? '' : (data.bankAccountNumber || '');
    document.getElementById('lawyerInCharge').value = data.lawyerInCharge || '';
    document.getElementById('lawyerInChargeEmail').value = data.lawyerInChargeEmail || '';
    document.getElementById('partnerInCharge').value = data.partnerInCharge || '';
    document.getElementById('partnerInChargeEmail').value = data.partnerInChargeEmail || '';

    lineItemsBody.innerHTML = '';
    var items = (data.lineItems && data.lineItems.length) ? data.lineItems.slice(0, MAX_LINE_ITEMS) : [{}];
    items.forEach(function(r){ createRow(r); });
    updateLineItemLimitUI();
    recalc();
    // After recalc() so the Senior Partner field(s) are already shown/hidden correctly -
    // otherwise updateSeniorPartnerAvailability would immediately clear whatever's set here.
    seniorPartnerInput.value = data.seniorPartner || '';
    document.getElementById('seniorPartnerEmail').value = data.seniorPartnerEmail || '';
    seniorPartner2Input.value = data.seniorPartner2 || '';
    document.getElementById('seniorPartner2Email').value = data.seniorPartner2Email || '';
  }

  // ---------- Copy From An Existing Request ----------
  // Open to any ID regardless of status (unlike Edit & Resubmit, which stays restricted to
  // Rejected items) - but never carries over attachments or each line item's amount, per
  // instruction, so the submitter still re-confirms the money being paid and re-attaches
  // whatever supporting documents actually apply to this new request.
  copyFromIdBtn.addEventListener('click', function(){
    var id = copyFromIdInput.value.trim();
    copyFromIdError.hidden = true;
    if (!id) return;
    if (typeof window.spFetchRequestById !== 'function'){
      copyFromIdError.textContent = 'Not connected to SharePoint yet - please make sure you are signed in, then try again.';
      copyFromIdError.hidden = false;
      return;
    }
    var originalHtml = copyFromIdBtn.innerHTML;
    copyFromIdBtn.disabled = true;
    copyFromIdBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Loading...';
    window.spFetchRequestById(id).then(function(reqItem){
      if (!reqItem){
        copyFromIdError.textContent = 'ID ' + id + ' was not found.';
        copyFromIdError.hidden = false;
        return;
      }
      var cloned = JSON.parse(JSON.stringify(reqItem.formData || {}));
      cloned.lineItems = (cloned.lineItems || []).map(function(li){
        return { description: li.description, invoice: li.invoice, amount: 0 };
      });
      applyFormData(cloned);
      copyFromIdInput.value = '';
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }).catch(function(err){
      copyFromIdError.textContent = 'Could not load ID ' + id + ': ' + ((err && err.message) || 'Unknown error');
      copyFromIdError.hidden = false;
    }).then(function(){
      copyFromIdBtn.disabled = false;
      copyFromIdBtn.innerHTML = originalHtml;
    });
  });

  resubmitRequestBtn.addEventListener('click', function(){
    var reqItem = SUBMITTED_REQUESTS[currentDetailsIdx];
    if (!reqItem || !reqItem.formData) return;
    applyFormData(reqItem.formData);
    // Edit & Resubmit already loads this exact request's data - surfacing its own ID in the
    // Copy From field too just saves having to go look it up again if they want to re-pull it.
    copyFromIdInput.value = reqItem.ref;
    copyFromIdError.hidden = true;
    requestDetailsModal.hidden = true;
    document.querySelector('.nav-item[data-view="submit"]').click();
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });

  // ---------- Accounts Approval actions (Mark Complete / Reject) ----------
  function submitAccountsDecision(decision, remarks){
    var reqItem = SUBMITTED_REQUESTS[currentDetailsIdx];
    if (!reqItem || typeof window.spSubmitAccountsDecision !== 'function') return;
    accountsCompleteBtn.disabled = true;
    accountsRejectBtn.disabled = true;
    accountsRemarksInput.disabled = true;
    var originalCompleteHtml = accountsCompleteBtn.innerHTML;
    accountsCompleteBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Saving...';
    var emailDetails = {
      submitterName: reqItem.createdBy || '',
      requestType: TYPE_LABELS[reqItem.type] || reqItem.type || '',
      payee: reqItem.payee || '',
      modeOfPayment: (reqItem.formData && reqItem.formData.modeOfPayment) || '',
      totalAmount: (reqItem.currency ? reqItem.currency + ' ' : '') + reqItem.amount
    };
    var detailItemIds = ((reqItem.formData && reqItem.formData.lineItems) || []).map(function(li){ return li.detailItemId; }).filter(Boolean);
    window.spSubmitAccountsDecision(reqItem.ref, decision, remarks, reqItem.submitterEmail, emailDetails, detailItemIds).then(function(){
      requestDetailsModal.hidden = true;
      loadRequestsFromSharePoint();
    }).catch(function(err){
      alert('Could not save the Accounts decision: ' + ((err && err.message) || 'Unknown error'));
    }).then(function(){
      accountsCompleteBtn.disabled = false;
      accountsRejectBtn.disabled = false;
      accountsRemarksInput.disabled = false;
      accountsCompleteBtn.innerHTML = originalCompleteHtml;
    });
  }

  function clearAccountsRemarksError(){
    accountsRemarksInput.classList.remove('invalid');
    accountsRemarksError.hidden = true;
  }
  accountsRemarksInput.addEventListener('input', clearAccountsRemarksError);

  accountsCompleteBtn.addEventListener('click', function(){
    clearAccountsRemarksError();
    if (!confirm('Mark this request as Complete? The submitter will be emailed.')) return;
    submitAccountsDecision('Complete', accountsRemarksInput.value.trim());
  });
  accountsRejectBtn.addEventListener('click', function(){
    var remarks = accountsRemarksInput.value.trim();
    if (!remarks){
      accountsRemarksInput.classList.add('invalid');
      accountsRemarksError.hidden = false;
      accountsRemarksInput.focus();
      return;
    }
    clearAccountsRemarksError();
    if (!confirm('Reject this request? The submitter will be emailed with your remarks.')) return;
    submitAccountsDecision('Rejected', remarks);
  });

  // ---------- Sidebar navigation / view switching ----------
  var navItems = Array.prototype.slice.call(document.querySelectorAll('.nav-item'));
  var views = {
    submit: document.getElementById('view-submit'),
    requests: document.getElementById('view-requests'),
    accounts: document.getElementById('view-accounts')
  };
  var topbarTitle = document.getElementById('topbarTitle');
  var topbarSubtitle = document.getElementById('topbarSubtitle');
  var VIEW_META = {
    submit: { title: 'Submit Payment Request', subtitle: 'Payment nominal request and approval routing' },
    requests: { title: 'View Requests', subtitle: 'Browse previously submitted e-voucher requests' },
    accounts: { title: 'Accounts Approval', subtitle: 'Final review for requests that have cleared all required approvals' }
  };

  navItems.forEach(function(btn){
    btn.addEventListener('click', function(){
      var key = btn.getAttribute('data-view');
      navItems.forEach(function(b){ b.classList.toggle('active', b === btn); });
      Object.keys(views).forEach(function(k){ views[k].hidden = k !== key; });
      var meta = VIEW_META[key];
      topbarTitle.textContent = meta.title;
      topbarSubtitle.textContent = meta.subtitle;
      if (key === 'requests' || key === 'accounts') loadRequestsFromSharePoint();
    });
  });

  // ---------- Sidebar collapse (more room for long payment descriptions etc.) ----------
  var sidebarCollapseBtn = document.getElementById('sidebarCollapseBtn');
  var SIDEBAR_COLLAPSE_KEY = 'evoucherSidebarCollapsed';

  function setSidebarCollapsed(collapsed){
    document.body.classList.toggle('sidebar-collapsed', collapsed);
    sidebarCollapseBtn.title = collapsed ? 'Expand sidebar' : 'Collapse sidebar';
    sidebarCollapseBtn.setAttribute('aria-label', sidebarCollapseBtn.title);
    try { localStorage.setItem(SIDEBAR_COLLAPSE_KEY, collapsed ? '1' : '0'); } catch (e){ /* storage may be unavailable - just skip persisting */ }
  }

  sidebarCollapseBtn.addEventListener('click', function(){
    setSidebarCollapsed(!document.body.classList.contains('sidebar-collapsed'));
  });

  (function(){
    try {
      if (localStorage.getItem(SIDEBAR_COLLAPSE_KEY) === '1') setSidebarCollapsed(true);
    } catch (e){ /* ignore - default to expanded */ }
  })();

  Array.prototype.slice.call(jumpList.querySelectorAll('.jump-item')).forEach(function(btn){
    btn.addEventListener('click', function(){
      var target = document.getElementById(btn.getAttribute('data-target'));
      if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  });

  // init
  createRow();
  updateLineItemLimitUI();
  updateBankNameMode();
  recalc();
  renderRequestsList();
})();
</script>

<script>
(function(){
  'use strict';

  var msalConfig = {
    auth: {
      clientId: 'cf1a4824-bb0d-46d0-958e-2ce76d9384ee',
      authority: 'https://login.microsoftonline.com/4db80bd6-18af-4cbe-80e2-915a7955b40c',
      redirectUri: window.location.origin + window.location.pathname
    },
    cache: {
      // localStorage (not sessionStorage) so the signed-in session survives a page
      // reload reliably - sessionStorage was found to not consistently persist across
      // refresh here, forcing a full interactive sign-in redirect on every reload.
      cacheLocation: 'localStorage',
      // Recommended by Microsoft for browsers with strict tracking-prevention (Edge,
      // Safari) that can otherwise lose track of state across the sign-in redirect.
      storeAuthStateInCookie: true
    }
  };
  var msalInstance = new msal.PublicClientApplication(msalConfig);

  // Adjust to match what your tenant admin has actually granted consent for.
  // GroupMember.Read.All is needed for the Lawyer/Partner picker's group membership
  // lookup (Graph /groups/{id}/members). GroupMember.Read.All alone only confirms WHO is a
  // member though - it does not grant permission to read their displayName/mail/UPN, which
  // come back silently nulled-out without User.ReadBasic.All alongside it. Mail.Send is
  // needed for the Accounts Approval email notification (sent from the approver's own
  // mailbox via /me/sendMail - see sendAccountsDecisionEmail).
  var LOGIN_SCOPES = ['User.Read', 'Sites.ReadWrite.All', 'GroupMember.Read.All', 'User.ReadBasic.All', 'Mail.Send'];

  var authGateSpinner = document.getElementById('authGateSpinner');
  var authGateStatus = document.getElementById('authGateStatus');
  var authGateError = document.getElementById('authGateError');
  var signOutBtn = document.getElementById('signOutBtn');
  var profileAvatar = document.getElementById('profileAvatar');
  var profileName = document.getElementById('profileName');
  var profileEmail = document.getElementById('profileEmail');

  function initials(name){
    var parts = (name || '').trim().split(/\s+/);
    if (!parts[0]) return '??';
    return (parts[0][0] + (parts[1] ? parts[1][0] : '')).toUpperCase();
  }

  function runSignInHandlers(account){
    (window.eVoucherSignInHandlers || []).forEach(function(fn){
      try { fn(account); } catch (err) { console.error('Sign-in handler failed:', err); }
    });
  }

  function showApp(account){
    document.body.classList.remove('pre-auth');
    var name = account.name || account.username;
    profileName.textContent = name;
    profileEmail.textContent = account.username;
    profileAvatar.textContent = initials(name);
    // Exposed so the Accounts Approval flow (a separate <script> block/closure) knows who
    // to resolve as the approver when writing AccountsLookupId.
    window.__currentUserEmail = account.username;
    window.__currentUserName = name;
    // When an account is already cached, MSAL can resolve almost instantly - fast enough
    // to get here before the browser has finished parsing later <script> blocks (which is
    // where the people-picker's own setup registers itself). Waiting for DOMContentLoaded
    // guarantees every script block has registered its handler first, no matter how fast
    // sign-in resolves.
    if (document.readyState === 'loading'){
      document.addEventListener('DOMContentLoaded', function(){ runSignInHandlers(account); }, { once: true });
    } else {
      runSignInHandlers(account);
    }
  }

  function showSignInError(err){
    authGateSpinner.hidden = true;
    authGateStatus.hidden = true;
    authGateError.textContent = 'Sign-in failed: ' + ((err && (err.errorCode || err.message)) || 'Unknown error');
    authGateError.hidden = false;
  }

  function trySilentThenInteractive(){
    var accounts = msalInstance.getAllAccounts();
    if (accounts.length > 0){
      msalInstance.setActiveAccount(accounts[0]);
      showApp(accounts[0]);
      return;
    }
    msalInstance.ssoSilent({ scopes: LOGIN_SCOPES }).then(function(result){
      msalInstance.setActiveAccount(result.account);
      showApp(result.account);
    }).catch(function(){
      // No existing session to reuse silently - sign the user in automatically, no click needed.
      authGateStatus.textContent = 'Redirecting to Microsoft sign-in...';
      msalInstance.loginRedirect({ scopes: LOGIN_SCOPES }).catch(showSignInError);
    });
  }

  signOutBtn.addEventListener('click', function(){
    var account = msalInstance.getActiveAccount();
    msalInstance.logoutRedirect({ account: account });
  });

  msalInstance.handleRedirectPromise().then(function(response){
    if (response && response.account){
      msalInstance.setActiveAccount(response.account);
      showApp(response.account);
    } else {
      trySilentThenInteractive();
    }
  }).catch(showSignInError);

  // Reusable helper for the future SharePoint/Graph list integration.
  window.getGraphToken = function(scopes){
    var account = msalInstance.getActiveAccount();
    if (!account) return Promise.reject(new Error('Not signed in'));
    var request = { scopes: scopes || LOGIN_SCOPES, account: account };
    return msalInstance.acquireTokenSilent(request).catch(function(){
      return msalInstance.acquireTokenPopup(request);
    });
  };
})();
</script>

<!-- ================================================================
     SharePoint / Graph data integration.
     Site:    https://stwdkl.sharepoint.com/sites/PowerPlatform
     Lists:   "E-Voucher Master" (one item per request) + "E-Voucher Details" (one item
              per line item). Replaces the old single-list "E-Voucher System"
              (PaymentDesc1-5/InvoiceNo1-5/Amount1-5 flattened onto one item) - full column
              dumps for both pulled 2026-09-19, see chat history.

     Master <-> Details relationship: Details."MasterID" is a plain Number column holding
     the parent Master item's numeric Id - NOT a real SharePoint Lookup column. So linking
     them is just "write MasterID = createdMaster.id" on write, and "group Details rows by
     MasterID client-side" on read (see spSubmitRequest/spFetchRequests below) - no
     @odata.bind or lookup-list semantics involved.

     Master columns of interest: MatterNo (Number), ClientName/MatterDescription/Payee/
     BankNo/BankNameForeign (Text), ModeOfPayment/Currency/RequestType/BankName (Choice),
     TotalAmount (Number), LawyerInCharge/PartnerInCharge/SeniorPartner1/SeniorPartner2/
     Accounts (Person/Group), LawyerStatus/PartnerStatus/SeniorPartner1Status/
     SeniorPartner2Status/AccountsStatus/Status (Choice), LawyerRemarks/PartnerRemarks/
     SeniorPartner1Remarks/SeniorPartner2Remarks/AccountsRemarks (Text),
     LawyerApprovalDate/PartnerApprovalDate/SeniorPartner1Date/SeniorPartner2Date/
     AccountsDate (dateTime). Status (Approved/Rejected/Pending/TIMED OUT/Completed) is the
     request's single authoritative overall status - read directly via
     classifyApprovalStatus(f.Status), NOT re-derived from the individual Lawyer/Partner/
     SeniorPartner/Accounts stage statuses (those are only shown for extra context in the
     details modal).

     Senior Partner routing rule (2026-09-26, updated 2026-10-14): Matter Related >=
     RM10,000 needs 1 Senior Partner (on top of the existing LIC+PIC baseline); Office
     Related has NO Lawyer-In-Charge/HOD step at all (removed 2026-10-14) - just PIC + 1
     Senior Partner regardless of amount, and a 2nd ("Senior Partner 2") if also >=
     RM10,000; Staff Claim is unaffected (already capped at RM10,000, LIC+PIC baseline
     only). See updateSeniorPartnerAvailability in the form's own script block (despite the
     name, it now also toggles Lawyer-In-Charge's visibility/required state) and the
     approval flow, which decides when AccountsStatus becomes "Pending" (the page's
     readyForAccounts only reads that column - 2026-10-24).
     Senior Partner/Senior
     Partner 2 use the SAME security group as Lawyer-In-Charge/Partner-In-Charge
     (APPROVERS_GROUP_ID) - no separate group. NOTE: the first Senior Partner column is
     named "SeniorPartner1" in SharePoint (confirmed via live column dump 2026-09-27) -
     the form/JS internally calls it "seniorPartner" (no digit) throughout, but every
     Graph-facing field reference uses SeniorPartner1/SeniorPartner1Status/
     SeniorPartner1Remarks to match the actual column name.
     This is a 3-stage approval flow (Lawyer -> Partner -> Accounts); the submitter only
     ever picks Lawyer-In-Charge/Partner in charge - Accounts is assigned by a separate
     process, so the form has no field for it.

     Details columns of interest: PaymentDescription/InvoiceNo (Text), Amount (Number),
     MasterID (Number, see above), plus its own mirrored MatterNo (Number)/RType (Text).
     Export (Y/N) and Status (P/C/A/R) also exist on Details but are intentionally left
     unset by spSubmitRequest - like Master's own Status/LawyerStatus/PartnerStatus, they
     look like they belong to a later accounting/approval workflow, not the submitter.

     Accounts Approval (2026-10-10): a built-in final-stage review screen, gated by
     checkCurrentUserIsApprover (checks the signed-in account's email against
     APPROVERS_GROUP_ID - the SAME group used for Lawyer/Partner/Senior Partner selection,
     reused as a stand-in "for now" per instruction, NOT a dedicated Accounts/Finance
     group). A request appears there whenever its AccountsStatus is exactly "Pending" in
     SharePoint (see readyForAccounts in spFetchRequests - the approval flow sets that once
     the earlier stages are done; changed 2026-10-24). "Mark Complete"/"Reject"
     (see window.spSubmitAccountsDecision) PATCH the Master item's fields sub-resource
     directly - note this uses PATCH .../items/{id}/fields with a flat field object, NOT the
     POST-with-{fields:...}-wrapper used for item creation elsewhere in this file - setting
     AccountsStatus/AccountsDate/AccountsLookupId/AccountsRemarks and mirroring the decision
     into Master's own overall Status column, then emails the submitter (resolved from the
     item's Author/CreatedBy field, same LookupId-resolution pattern as Lawyer/Partner) via
     Graph /me/sendMail from the approver's own mailbox (needs the new Mail.Send scope -
     first use will likely need a fresh consent prompt/admin approval, same as every other
     scope added so far). Untested live as of writing - watch for an alert() on a failed
     Complete/Reject action, since that's the most likely thing to not match Graph's exact
     expected request shape.

     Copy From An Existing Request (2026-10-10): a new field on the Submit form (separate
     from the existing Edit & Resubmit button, which stays restricted to Rejected items) -
     open to ANY ID regardless of status, per instruction. Reuses spFetchRequests wholesale
     (window.spFetchRequestById) rather than a separate fetch path. Copies every field
     applyFormData already restores EXCEPT attachments (never touched - applyFormData never
     manipulates the local `files` array, so this was already true for free) and EXCEPT each
     line item's amount (explicitly zeroed before calling applyFormData).

     KNOWN GAPS / OPEN QUESTIONS - not yet resolved:
     - Fixed 2026-10-14: switching Request Type away from Matter Related (or copying from an
       existing request via Copy From An Existing Request) used to leave MatterNo/
       ClientName/MatterDescription populated-but-hidden, and collectData()/spSubmitRequest
       read them unconditionally - so a request submitted as Office Related could still
       silently carry stale Matter data into SharePoint. Now cleared whenever matterSection
       hides (see updateMatterVisibility), and applyFormData only restores those three
       fields when the SOURCE record's own type was actually matter-applicable (so copying
       a historical Office Related item that happens to have leftover matter data from
       before this fix doesn't propagate it forward into the new submission either). This
       does NOT retroactively clean any already-dirty Master items already sitting in
       SharePoint from before this fix - that would need a one-off manual/bulk data cleanup,
       not something done automatically here.
     - RequestType's live Choice values are "Matter, Office, Client" - confirmed "Client" is
       just this list's wording for what the app calls "Staff Claims" internally (same
       category, not a new one). inferTypeFromText/applyRequestTypeChoices/
       requestTypeForSharePoint all match on "client" as well as "staff" now.
     - ModeOfPayment's live 5th choice was literally "Choice 5" (an un-renamed placeholder
       in the SharePoint list) - to be renamed to "Telegraphic Transfer (TT)" in SharePoint
       directly (no frontend change needed once that's done).
     - Currency's live choices were missing "RMB" (present in the form's built-in fallback)
       - to be added to the SharePoint Choice column directly.
     - LawyerStatus choices: Approved/Rejected/TIMED OUT/Pending. PartnerStatus adds "Not
       Applicable" (treated as non-blocking/approved-equivalent by classifyApprovalStatus,
       since it means that stage doesn't apply to this request). "TIMED OUT" is its own
       bucket now (shown as "Timed Out", grouped with Pending on the list page) - flag if it
       should instead read as rejected/needs-resubmission.
     - LawyerInCharge/PartnerInCharge/Accounts are Person/Group columns. WRITE: Graph's
       list-items API won't accept plain display-name text for those - fixed by resolving
       the picker's email through the classic REST /_api/web/ensureuser endpoint (see
       ensureSpUser) into the site's numeric user Id, then writing "<Field>LookupId".
       Requires the picker's hidden *Email field to actually hold an email (i.e. the user
       picked a real suggestion, not free-typed text) - the submit-time validation enforces
       that. READ: confirmed directly against live data that Graph's $expand=fields NEVER
       resolves these into a name/object/array - it only ever returns "<Field>LookupId":
       "7" (the same numeric user Id, as a string). Resolved back to a display name/email
       via the same classic REST getuserbyid endpoint (see getSpUserById), batched once per
       fetch across all distinct ids and cached across fetches (a small, recurring set of
       lawyers/partners/accounts staff).
     - CC was removed from the form entirely - there was never a CC column on either
       SharePoint list to write it to, so it was collected but never actually saved.
     - Lawyer-In-Charge/Partner in charge picker is scoped to one security group
       (APPROVERS_GROUP_ID = 78d49110-d3fa-44ce-abfc-c6a3b199c0e1, see searchPeople/
       fetchGroupMembers below) instead of an org-wide /me/people search - only that
       group's members are selectable/suggested.
     - MatterNo's SharePoint column is typed as Number (on both Master and Details), but
       matter numbers aren't guaranteed to be purely numeric - the frontend sends whatever
       was typed as-is rather than assuming/forcing a numeric format; SharePoint will
       reject it visibly if the column genuinely can't hold a given value, rather than this
       silently dropping it.
     - Attachments: confirmed native SharePoint attachments, uploaded against the Master
       item only (not per Details row). Graph API v1.0 does not reliably support list-item
       attachments, so this uses the classic SharePoint REST endpoint instead, which needs
       its OWN resource permission (see uploadAttachmentsForItem) - separate from the Graph
       permissions already granted.
     - Matter number -> client name/description autofill: wired up to the real
       "Active Matters" list (see lookupActiveMatter below) - unrelated to the Master/
       Details split above. FILEID is the matter number column; client name comes from the
       list's default "Title" column; short description is matched by flexible keyword. The
       OData filter sends the value unquoted only when it looks purely numeric, quoted
       otherwise, since FILEID's exact column type there isn't confirmed.
     ================================================================ -->
<script>
(function(){
  'use strict';

  var SP_HOSTNAME = 'stwdkl.sharepoint.com';
  var SP_SITE_PATH = '/sites/PowerPlatform';
  // "E-Voucher System" (single flattened list, PaymentDesc1-5/InvoiceNo1-5/Amount1-5) has
  // been replaced by this Master/Details pair: one Master item per request, with one
  // Details item per line item linked back via a plain "MasterID" number field (NOT a
  // real SharePoint Lookup column - just the parent's item Id stored as a number).
  var SP_MASTER_LIST_NAME = 'E-Voucher Master';
  var SP_DETAILS_LIST_NAME = 'E-Voucher Details';
  var SP_MATTERS_LIST_NAME = 'Active Matters';
  var GRAPH_BASE = 'https://graph.microsoft.com/v1.0';

  var spSiteId = null;
  var spListIdCache = {};

  function graphRequest(path, options){
    options = options || {};
    return window.getGraphToken(['Sites.ReadWrite.All']).then(function(token){
      var headers = { 'Authorization': 'Bearer ' + token.accessToken };
      if (options.body) headers['Content-Type'] = 'application/json';
      for (var k in (options.headers || {})) headers[k] = options.headers[k];
      return fetch(GRAPH_BASE + path, {
        method: options.method || 'GET',
        headers: headers,
        body: options.body
      });
    }).then(function(res){
      if (!res.ok){
        return res.text().then(function(t){ throw new Error('Graph ' + res.status + ': ' + t); });
      }
      return res.status === 204 ? null : res.json();
    });
  }

  function getSpSiteId(){
    if (spSiteId) return Promise.resolve(spSiteId);
    return graphRequest('/sites/' + SP_HOSTNAME + ':' + SP_SITE_PATH).then(function(site){
      spSiteId = site.id;
      return spSiteId;
    });
  }

  function getSpListId(listName){
    if (spListIdCache[listName]) return Promise.resolve(spListIdCache[listName]);
    return getSpSiteId().then(function(siteId){
      return graphRequest('/sites/' + siteId + '/lists?$filter=' + encodeURIComponent("displayName eq '" + listName + "'"));
    }).then(function(result){
      if (!result.value || !result.value.length) throw new Error('SharePoint list "' + listName + '" not found at ' + SP_SITE_PATH);
      spListIdCache[listName] = result.value[0].id;
      return spListIdCache[listName];
    });
  }

  // ---------- Status / type text helpers (work off live/free text, no hardcoded exact values needed) ----------
  // Used both for Master's own overall "Status" column (Approved/Rejected/Pending/TIMED
  // OUT/Completed) and for the individual LawyerStatus/PartnerStatus/AccountsStatus values
  // shown per-stage in the details modal.
  function classifyApprovalStatus(text){
    var lc = (text || '').toLowerCase();
    if (lc.indexOf('reject') !== -1 || lc.indexOf('declin') !== -1) return 'rejected';
    if (lc.indexOf('complet') !== -1) return 'completed';
    // "Not Applicable" (a real PartnerStatus choice, e.g. requests below a threshold that
    // don't need partner sign-off) is a non-issue, same as an actual approval. "Verified" is
    // the Lawyer stage's own choice text for the same outcome (that stage verifies, it
    // doesn't approve - see lawyerStatusDisplay) - without this it fell through to the
    // default 'pending' bucket and rendered orange even once verification was done.
    if (lc.indexOf('approv') !== -1 || lc.indexOf('not applicable') !== -1 || lc.indexOf('verif') !== -1) return 'approved';
    if (lc.indexOf('timed out') !== -1 || lc.indexOf('timeout') !== -1) return 'timed-out';
    return 'pending';
  }
  // Exposed on window so the modal's statusBadgeHtml (a separate <script> block/closure) can
  // classify individual Lawyer/Partner/Accounts stage statuses the same way.
  window.classifyApprovalStatus = classifyApprovalStatus;

  // staffClaimCategory is the dedicated "StaffClaimCategory" Choice column (values "Matter"/
  // "Office") - the real source of truth once populated, since RequestType's own text often
  // can't distinguish the two at all (the plain "Client" wording carries no such detail).
  // Falls back to guessing from RequestType's text only for older records from before that
  // column existed.
  function inferTypeFromText(text, staffClaimCategory){
    var lc = (text || '').toLowerCase();
    // The live RequestType Choice column uses "Client" for what this app calls "Staff
    // Claims" internally (confirmed same category, just relabelled in SharePoint) - match
    // on either wording so this keeps working if it's ever renamed back.
    var hasStaff = lc.indexOf('staff') !== -1 || lc.indexOf('client') !== -1;
    var hasOffice = lc.indexOf('office') !== -1;
    if (hasStaff){
      var subtype = staffClaimCategory ? (staffClaimCategory.toLowerCase() === 'office' ? 'office' : 'matter') : (hasOffice ? 'office' : 'matter');
      return { nominalType: 'staff', staffSubtype: subtype };
    }
    if (hasOffice) return { nominalType: 'office', staffSubtype: 'matter' };
    return { nominalType: 'matter', staffSubtype: 'matter' };
  }

  // Graph returns Person/Group column values wrapped in an array even for single-value
  // fields (e.g. LawyerInCharge -> [{LookupId, LookupValue, Email}]), not a plain object -
  // unwrap that first, or .LookupValue etc. always come back undefined off the array itself.
  function escapeHtmlLocal(str){
    var d = document.createElement('div');
    d.textContent = str || '';
    return d.innerHTML;
  }

  // ---------- Dynamic choice-column population (dropdowns mirror whatever SharePoint actually has) ----------
  // Internal codes (matter/office/staff) are kept as the dropdown's option values everywhere else in the app;
  // only the visible label text and the value actually sent to SharePoint change here.
  var TYPE_SP_TEXT = { matter: null, office: null, 'staff-matter': null, 'staff-office': null };

  function applyRequestTypeChoices(choices){
    var matterChoice, officeChoice, staffGenericChoice, staffMatterChoice, staffOfficeChoice;
    choices.forEach(function(c){
      var lc = c.toLowerCase();
      // "Client" is this list's actual wording for the staff-claims category (confirmed
      // same category, see inferTypeFromText above) - match either wording.
      var hasStaff = lc.indexOf('staff') !== -1 || lc.indexOf('client') !== -1;
      var hasOffice = lc.indexOf('office') !== -1;
      var hasMatter = lc.indexOf('matter') !== -1;
      if (hasStaff && hasOffice) staffOfficeChoice = c;
      else if (hasStaff && hasMatter) staffMatterChoice = c;
      else if (hasStaff) staffGenericChoice = c;
      else if (hasOffice) officeChoice = c;
      else if (hasMatter) matterChoice = c;
    });
    TYPE_SP_TEXT.matter = matterChoice || TYPE_SP_TEXT.matter;
    TYPE_SP_TEXT.office = officeChoice || TYPE_SP_TEXT.office;
    TYPE_SP_TEXT['staff-matter'] = staffMatterChoice || staffGenericChoice || TYPE_SP_TEXT['staff-matter'];
    TYPE_SP_TEXT['staff-office'] = staffOfficeChoice || staffGenericChoice || TYPE_SP_TEXT['staff-office'];

    var nominalTypeEl = document.getElementById('nominalType');
    Array.prototype.forEach.call(nominalTypeEl.querySelectorAll('option'), function(opt){
      if (opt.value === 'matter' && TYPE_SP_TEXT.matter) opt.textContent = TYPE_SP_TEXT.matter;
      else if (opt.value === 'office' && TYPE_SP_TEXT.office) opt.textContent = TYPE_SP_TEXT.office;
      else if (opt.value === 'staff' && (staffGenericChoice || staffMatterChoice)) opt.textContent = (staffGenericChoice || staffMatterChoice);
    });
    // Value doesn't change here, only option text - re-fire 'change' so the custom
    // dropdown's trigger label (which mirrors option text) picks up the relabel.
    nominalTypeEl.dispatchEvent(new Event('change', { bubbles: true }));
  }

  function requestTypeForSharePoint(data){
    if (data.nominalType === 'staff'){
      // 'Client' is the live RequestType Choice value for this category - only used if
      // loadDynamicChoices hasn't populated TYPE_SP_TEXT yet (e.g. it failed at sign-in).
      return (data.staffSubtype === 'office' ? TYPE_SP_TEXT['staff-office'] : TYPE_SP_TEXT['staff-matter']) || 'Client';
    }
    return TYPE_SP_TEXT[data.nominalType] || (data.nominalType === 'office' ? 'Office Related' : 'Matter Related');
  }

  function populateOptions(selectEl, choices, includeBlank, blankLabel){
    var current = selectEl.value;
    var html = includeBlank ? ('<option value="">' + (blankLabel || 'Select...') + '</option>') : '';
    html += choices.map(function(c){
      return '<option value="' + escapeHtmlLocal(c) + '">' + escapeHtmlLocal(c) + '</option>';
    }).join('');
    selectEl.innerHTML = html;
    if (choices.indexOf(current) !== -1){
      selectEl.value = current;
    } else if (!includeBlank){
      var myrChoice = choices.filter(function(c){ return c.toUpperCase().indexOf('MYR') !== -1; })[0];
      if (myrChoice) selectEl.value = myrChoice;
    }
    selectEl.dispatchEvent(new Event('change', { bubbles: true }));
  }

  function loadDynamicChoices(){
    getSpListId(SP_MASTER_LIST_NAME).then(function(listId){
      return getSpSiteId().then(function(siteId){
        return graphRequest('/sites/' + siteId + '/lists/' + listId + '/columns');
      });
    }).then(function(result){
      var columns = (result && result.value) || [];
      columns.forEach(function(col){
        if (!col.choice || !col.choice.choices || !col.choice.choices.length) return;
        if (col.name === 'RequestType'){
          applyRequestTypeChoices(col.choice.choices);
        } else if (col.name === 'ModeOfPayment'){
          populateOptions(document.getElementById('modeOfPayment'), col.choice.choices, true, 'Select mode');
        } else if (col.name === 'Currency'){
          populateOptions(document.getElementById('currency'), col.choice.choices, false);
        } else if (col.name === 'BankName'){
          // "Others" isn't a real SharePoint choice (there's nowhere to put a free-typed
          // overseas/unlisted bank name as a Choice value) - it's purely a trigger in this
          // form's own UI for switching to the manual bankNameManual field, so it has to be
          // re-added here every time or the live SharePoint list would silently replace it.
          var bankChoices = col.choice.choices.slice();
          if (bankChoices.indexOf('Others') === -1) bankChoices.push('Others');
          populateOptions(document.getElementById('bankName'), bankChoices, true, 'Select bank');
        }
      });
    }).catch(function(err){
      console.warn('Could not load SharePoint choice columns - keeping built-in defaults.', err);
    });
  }

  // ---------- Organization people-picker (Lawyer-In-Charge / HOD, Partner in charge) ----------
  // Scoped to this one security group (its members are the eligible lawyers/partners/HODs)
  // rather than an org-wide search - the whole membership is fetched once and cached, then
  // filtered client-side per keystroke, since /groups/{id}/members has no fuzzy "relevance"
  // search the way /me/people does.
  var APPROVERS_GROUP_ID = '78d49110-d3fa-44ce-abfc-c6a3b199c0e1';
  var groupMembersPromise = null;

  function fetchGroupMembers(){
    if (groupMembersPromise) return groupMembersPromise;
    groupMembersPromise = window.getGraphToken(['GroupMember.Read.All', 'User.ReadBasic.All']).then(function(token){
      var headers = { 'Authorization': 'Bearer ' + token.accessToken };
      function fetchPage(url, acc){
        return fetch(url, { headers: headers }).then(function(res){
          if (!res.ok) return res.text().then(function(t){ throw new Error('Group members fetch failed (' + res.status + '): ' + t); });
          return res.json();
        }).then(function(result){
          var all = acc.concat(result.value || []);
          return result['@odata.nextLink'] ? fetchPage(result['@odata.nextLink'], all) : all;
        });
      }
      // /groups/{id}/members returns a mixed bag of object types (users, sometimes nested
      // groups/devices) - casting to /microsoft.graph.user both filters to actual people
      // and is required for $select to accept user-only properties like mail/UPN without
      // erroring.
      return fetchPage(GRAPH_BASE + '/groups/' + APPROVERS_GROUP_ID + '/members/microsoft.graph.user?$select=id,displayName,mail,userPrincipalName&$top=999', []);
    }).catch(function(err){
      groupMembersPromise = null; // don't cache a failure - let the next attempt retry
      throw err;
    });
    return groupMembersPromise;
  }

  // No query -> the group's own member list (so clicking the field alone already shows a
  // dropdown of people, per the "click to choose OR type to search" requirement).
  function searchPeople(query){
    return fetchGroupMembers().then(function(members){
      var list = members;
      // A lawyer/partner can't verify or approve their own claim, so the person submitting
      // this request should never even show up as a pickable option in any of the four
      // approver fields (Lawyer/HOD, Partner-In-Charge, Senior Partner 1/2) in the first
      // place - they all share this same search, so excluding here covers all of them.
      // Exception: the shared vouchers@ mailbox submits on others' behalf, so it may pick itself.
      var selfEmail = (window.__currentUserEmail || '').toLowerCase();
      if (selfEmail && selfEmail !== 'vouchers@stwd.com.my'){
        list = list.filter(function(p){ return (personEmail(p) || '').toLowerCase() !== selfEmail; });
      }
      if (query){
        var q = query.toLowerCase();
        // Filter the already self-excluded list, not the original members - filtering from
        // members here would silently undo the self-exclusion above the moment any query
        // text was typed, letting the submitter reappear as soon as they searched for anything.
        list = list.filter(function(p){
          return (p.displayName || '').toLowerCase().indexOf(q) !== -1 ||
                 (p.mail || '').toLowerCase().indexOf(q) !== -1 ||
                 (p.userPrincipalName || '').toLowerCase().indexOf(q) !== -1;
        });
      }
      return list.slice(0, 10);
    });
  }

  function personEmail(p){
    return (p.scoredEmailAddresses && p.scoredEmailAddresses[0] && p.scoredEmailAddresses[0].address) || p.userPrincipalName || p.mail || '';
  }

  function dedupePeople(people){
    var seen = {};
    return people.filter(function(p){
      var key = p.id || personEmail(p) || p.displayName;
      if (!key || seen[key]) return false;
      seen[key] = true;
      return true;
    });
  }

  var openPeoplePickers = [];

  // config: { inputId, suggestionsId, hiddenEmailId, excludeEmailId }
  function setupPeoplePicker(config){
    var input = document.getElementById(config.inputId);
    var box = document.getElementById(config.suggestionsId);
    var picker = input.closest('.people-picker');
    var hiddenEmail = config.hiddenEmailId ? document.getElementById(config.hiddenEmailId) : null;
    var debounceTimer = null;
    var currentResults = [];

    function showBox(){ box.hidden = false; picker.classList.add('open'); }
    function hideBox(){ box.hidden = true; box.innerHTML = ''; picker.classList.remove('open'); }
    openPeoplePickers.push(hideBox);

    function renderResults(people){
      people = dedupePeople(people);
      currentResults = people;
      if (!people.length){
        box.innerHTML = '<div class="p-status">No matches found</div>';
        showBox();
        return;
      }
      box.innerHTML = people.map(function(p, i){
        return '<div class="people-suggestion" data-idx="' + i + '">' +
          '<span class="p-name">' + escapeHtmlLocal(p.displayName || '') + '</span></div>';
      }).join('');
      showBox();
    }

    function runSearch(query){
      searchPeople(query).then(function(people){
        // Some pickers exclude whoever is CURRENTLY picked in another field (e.g. Senior
        // Partner 1 can't be the same person as Partner-In-Charge) - read that other field's
        // live value each time rather than a fixed email, so it stays correct as that other
        // field changes.
        if (config.excludeEmailId){
          var excludeEmailEl = document.getElementById(config.excludeEmailId);
          var excludeEmail = ((excludeEmailEl && excludeEmailEl.value) || '').toLowerCase();
          if (excludeEmail) people = people.filter(function(p){ return (personEmail(p) || '').toLowerCase() !== excludeEmail; });
        }
        return people;
      }).then(renderResults).catch(function(){
        box.innerHTML = '<div class="p-status">Search unavailable right now - you can still type a name manually.</div>';
        showBox();
      });
    }

    function selectPerson(p){
      input.value = p.displayName || '';
      hideBox();
      // Fire 'input' BEFORE setting hiddenEmail, not after - the input listener above
      // unconditionally clears hiddenEmail on every keystroke (so free-typed text can't
      // masquerade as a resolved pick), and dispatchEvent runs that listener synchronously.
      // Setting hiddenEmail afterwards used to get wiped out immediately by that same
      // listener, so a genuine click on a suggestion still left hiddenEmail empty.
      input.dispatchEvent(new Event('input', { bubbles: true }));
      // That dispatch just re-ran the input listener below, which (re-)armed its own debounced
      // runSearch() for whatever's now in the field - i.e. the name just picked. Left alone,
      // that search would resolve ~300ms later, match the very person just selected, and pop
      // the suggestion box back open right after it was closed. Cancel it here, after the
      // dispatch has synchronously set it.
      clearTimeout(debounceTimer);
      if (hiddenEmail) hiddenEmail.value = personEmail(p);
      input.dispatchEvent(new Event('change', { bubbles: true }));
    }

    input.addEventListener('focus', function(){
      openPeoplePickers.forEach(function(hide){ if (hide !== hideBox) hide(); });
      // Always open on the full list, not filtered by whatever name is already sitting in
      // the field - re-searching by the current value here meant re-focusing a field that
      // already had someone picked only ever showed that same person back (nothing else
      // could match), making it look like there was no way to pick someone different.
      // Selecting the text too means the next keystroke replaces it outright, same pattern
      // as the Bank Name searchable dropdown.
      runSearch('');
      input.select();
    });

    input.addEventListener('input', function(){
      if (hiddenEmail) hiddenEmail.value = '';
      var query = input.value.trim();
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(function(){ runSearch(query); }, 300);
    });

    box.addEventListener('mousedown', function(e){
      var row = e.target.closest('.people-suggestion');
      if (!row) return;
      var idx = parseInt(row.getAttribute('data-idx'), 10);
      if (currentResults[idx]) selectPerson(currentResults[idx]);
    });

    input.addEventListener('blur', function(){ setTimeout(hideBox, 150); });
  }

  // ---------- Create (Submit Payment Request) ----------
  function getSpRestToken(){
    // Native SharePoint attachments aren't reliably supported via Graph v1.0, so this uses the
    // classic SharePoint REST API instead - which needs its own resource permission (e.g. "AllSites.Write"
    // under the SharePoint API, separate from the Graph permissions already granted) plus admin consent.
    return window.getGraphToken(['https://' + SP_HOSTNAME + '/AllSites.Write']);
  }

  // Graph's $expand=fields never resolves Person/Group columns into a name/email - it only
  // ever returns "<Field>LookupId": "7" (confirmed directly against the live data). That
  // numeric id is the site's own User Information List id, resolved here via the classic
  // REST getuserbyid endpoint and cached, since the same handful of lawyers/partners/
  // accounts staff recur across every request.
  var spUserCache = {};

  function getSpUserById(id){
    if (!id) return Promise.resolve(null);
    if (spUserCache[id]) return spUserCache[id];
    var promise = getSpRestToken().then(function(token){
      return fetch('https://' + SP_HOSTNAME + SP_SITE_PATH + '/_api/web/getuserbyid(' + encodeURIComponent(id) + ')', {
        headers: {
          'Authorization': 'Bearer ' + token.accessToken,
          'Accept': 'application/json;odata=nometadata'
        }
      });
    }).then(function(res){
      return res.ok ? res.json() : null;
    }).then(function(user){
      return user ? { displayName: user.Title || '', email: user.Email || '' } : null;
    }).catch(function(err){
      console.warn('Could not resolve SharePoint user id ' + id, err);
      return null;
    });
    spUserCache[id] = promise;
    return promise;
  }

  // Reads the "Active Matters" list, keyed on FILEID (= matter number), to auto-fill
  // client name / matter description when a recognised matter number is entered.
  // Column names come from a truncated SharePoint view header, so values are picked
  // by flexible keyword match rather than an exact internal name.
  function pickListField(item, pattern){
    var keys = Object.keys(item || {});
    for (var i = 0; i < keys.length; i++){
      if (pattern.test(keys[i]) && item[keys[i]]) return item[keys[i]];
    }
    return '';
  }

  function lookupActiveMatter(fileId){
    var raw = String(fileId).trim();
    // Real matter numbers are plain numbers (e.g. 22670667, confirmed via the sibling
    // MatterNo column being a Number field) - if FILEID is also a Number column, an OData
    // filter needs the value unquoted (a quoted numeric literal is rejected as a type
    // mismatch). Fall back to a quoted string literal only for non-numeric input.
    var filterValue = /^\d+$/.test(raw) ? raw : "'" + raw.replace(/'/g, "''") + "'";
    var url = 'https://' + SP_HOSTNAME + SP_SITE_PATH + "/_api/web/lists/getbytitle('" +
      encodeURIComponent(SP_MATTERS_LIST_NAME) + "')/items?$top=1&$filter=" +
      encodeURIComponent("FILEID eq " + filterValue);
    return getSpRestToken().then(function(token){
      return fetch(url, {
        headers: {
          'Authorization': 'Bearer ' + token.accessToken,
          'Accept': 'application/json;odata=nometadata'
        }
      });
    }).then(function(res){
      if (!res.ok) return res.text().then(function(t){ throw new Error('Active Matters lookup failed (' + res.status + '): ' + t); });
      return res.json();
    }).then(function(result){
      var item = result.value && result.value[0];
      if (!item) return null;
      var match = {
        // Client name is the list's default "Title" column (renamed for display only -
        // the underlying/REST field name stays "Title"), so check that before falling
        // back to a /client/i keyword match in case the column naming ever changes.
        client: item.Title || pickListField(item, /client/i),
        description: pickListField(item, /shortdes|description/i)
      };
      if (!match.client){
        console.warn('Active Matters: no Title/client column found for FILEID ' + fileId + '. Raw record:', item);
      }
      return match;
    });
  }
  window.lookupActiveMatter = lookupActiveMatter;

  function uploadAttachmentsForItem(itemId, filesToUpload){
    if (!filesToUpload || !filesToUpload.length) return Promise.resolve();
    return getSpRestToken().then(function(token){
      var restBase = 'https://' + SP_HOSTNAME + SP_SITE_PATH + "/_api/web/lists/getbytitle('" +
        encodeURIComponent(SP_MASTER_LIST_NAME) + "')/items(" + itemId + ')/AttachmentFiles/add(FileName=\'';
      var uploads = Array.prototype.map.call(filesToUpload, function(file){
        return file.arrayBuffer().then(function(buf){
          return fetch(restBase + encodeURIComponent(file.name) + "')", {
            method: 'POST',
            headers: {
              'Authorization': 'Bearer ' + token.accessToken,
              'Accept': 'application/json;odata=verbose'
            },
            body: buf
          }).then(function(res){
            if (!res.ok) throw new Error('Attachment upload failed for ' + file.name + ' (' + res.status + ')');
          });
        });
      });
      return Promise.all(uploads);
    });
  }

  // Attachments were only ever uploaded (uploadAttachmentsForItem) - nothing ever read them
  // back, so they never showed anywhere they're viewed (View Requests, Accounts Approval -
  // both share openRequestDetails). Graph's $expand=fields doesn't surface native SharePoint
  // attachments at all, so this reads them back the same way they're written: classic REST,
  // here using $expand=AttachmentFiles to pull every Master item's attachments in one request
  // rather than one call per row.
  function fetchAllAttachments(){
    var url = 'https://' + SP_HOSTNAME + SP_SITE_PATH + "/_api/web/lists/getbytitle('" +
      encodeURIComponent(SP_MASTER_LIST_NAME) + "')/items?$select=Id,AttachmentFiles/FileName,AttachmentFiles/ServerRelativeUrl&$expand=AttachmentFiles&$top=500";
    return getSpRestToken().then(function(token){
      return fetch(url, {
        headers: {
          'Authorization': 'Bearer ' + token.accessToken,
          'Accept': 'application/json;odata=nometadata'
        }
      });
    }).then(function(res){
      return res.ok ? res.json() : { value: [] };
    }).then(function(result){
      var byId = {};
      (result.value || []).forEach(function(item){
        if (item.AttachmentFiles && item.AttachmentFiles.length){
          byId[item.Id] = item.AttachmentFiles.map(function(a){
            return { name: a.FileName, url: 'https://' + SP_HOSTNAME + a.ServerRelativeUrl };
          });
        }
      });
      return byId;
    }).catch(function(err){
      console.warn('Could not load attachments.', err);
      return {};
    });
  }

  // LawyerInCharge/PartnerInCharge are Person/Group columns - Graph's list-items API won't
  // accept plain display-name text for those (that was silently not being captured).
  // Resolving the picker's email through the classic REST /_api/web/ensureuser endpoint
  // gives the site's numeric user Id, which is what the "<Field>LookupId" field expects.
  function ensureSpUser(email){
    if (!email) return Promise.resolve(null);
    return getSpRestToken().then(function(token){
      return fetch('https://' + SP_HOSTNAME + SP_SITE_PATH + '/_api/web/ensureuser', {
        method: 'POST',
        headers: {
          'Authorization': 'Bearer ' + token.accessToken,
          'Accept': 'application/json;odata=nometadata',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ logonName: email })
      });
    }).then(function(res){
      if (!res.ok) return res.text().then(function(t){ throw new Error('ensureuser failed for ' + email + ' (' + res.status + '): ' + t); });
      return res.json();
    }).then(function(user){ return user && user.Id; });
  }

  window.spSubmitRequest = function(data, attachmentFiles){
    var requestTypeText = requestTypeForSharePoint(data);
    var fields = {
      RequestType: requestTypeText,
      ClientName: data.clientName || '',
      MatterDescription: data.matterDescription || '',
      Payee: data.payee || '',
      ModeOfPayment: data.modeOfPayment || '',
      TotalAmount: parseFloat(String(data.totalAmount).replace(/,/g, '')) || 0,
      Currency: data.currency || '',
      BankNo: data.bankAccountNumber || ''
    };
    // BankName (Choice, Malaysian bank list) vs BankNameForeign (free text) are separate
    // columns on Master now - which one gets written depends on which field the form was
    // actually showing (same split as updateBankNameMode/activeBankNameField: foreign
    // currency OR "Others" picked for an unlisted local bank both count as "foreign" here).
    if (data.bankNameIsForeign) fields.BankNameForeign = data.bankName || '';
    else fields.BankName = data.bankName || '';
    // MatterNo's SharePoint column is currently typed as Number, but matter numbers aren't
    // guaranteed to be purely numeric - send whatever was entered as-is (SharePoint will
    // reject it visibly if the column truly can't hold it, rather than this silently
    // dropping the value). Only omitted when genuinely blank (Office/Client requests).
    if (data.matterNumber) fields.MatterNo = data.matterNumber;
    // Dedicated Choice column (values "Matter"/"Office") added specifically so a Staff Claim's
    // subtype is actually recorded somewhere, rather than relying on guessing it back out of
    // RequestType's own text (which often can't distinguish the two at all - see
    // inferTypeFromText). Only meaningful for Staff Claims; omitted otherwise.
    if (data.nominalType === 'staff') fields.StaffClaimCategory = data.staffSubtype === 'office' ? 'Office' : 'Matter';

    var createdMaster;
    return Promise.all([
      ensureSpUser(data.lawyerInChargeEmail).catch(function(err){ console.warn('Could not resolve Lawyer-In-Charge as a SharePoint user - it will be left blank.', err); return null; }),
      ensureSpUser(data.partnerInChargeEmail).catch(function(err){ console.warn('Could not resolve Partner In Charge as a SharePoint user - it will be left blank.', err); return null; }),
      ensureSpUser(data.seniorPartnerEmail).catch(function(err){ console.warn('Could not resolve Senior Partner 1 as a SharePoint user - it will be left blank.', err); return null; }),
      ensureSpUser(data.seniorPartner2Email).catch(function(err){ console.warn('Could not resolve Senior Partner 2 as a SharePoint user - it will be left blank.', err); return null; })
    ]).then(function(ids){
      // Staff Claim (Office category): the first approver is the HOD, saved to HeadOfDepartment.
      if (ids[0]){
        if (data.nominalType === 'staff' && data.staffSubtype === 'office') fields.HeadOfDepartmentLookupId = ids[0];
        else fields.LawyerInChargeLookupId = ids[0];
      }
      // Office Related labels this picker "HOD" and stores it in its own HeadOfDepartment
      // Person column; every other type keeps it as PartnerInCharge.
      if (ids[1]){
        if (data.nominalType === 'office') fields.HeadOfDepartmentLookupId = ids[1];
        else if (data.nominalType === 'staff' && data.staffSubtype === 'office') fields.SeniorPartner1LookupId = ids[1];
        else fields.PartnerInChargeLookupId = ids[1];
      }
      if (ids[2]) fields.SeniorPartner1LookupId = ids[2];
      if (ids[3]) fields.SeniorPartner2LookupId = ids[3];
      return getSpListId(SP_MASTER_LIST_NAME);
    }).then(function(masterListId){
      return getSpSiteId().then(function(siteId){
        return graphRequest('/sites/' + siteId + '/lists/' + masterListId + '/items', {
          method: 'POST',
          body: JSON.stringify({ fields: fields })
        });
      });
    }).then(function(created){
      createdMaster = created;
      // One "E-Voucher Details" item per line item, linked back via the plain MasterID
      // number field. MatterNo/RType are mirrored down from the Master row for flat
      // accounting export/reporting; Export/Status are intentionally left unset here for
      // the same reason Master's own Status/LawyerStatus/PartnerStatus are left unset at
      // creation - they're set later by the approval/export workflow, not the submitter.
      var lineItems = (data.lineItems || []).slice(0, 5).filter(function(item){
        return item.description || item.invoice || item.amount;
      });
      return getSpListId(SP_DETAILS_LIST_NAME).then(function(detailsListId){
        return getSpSiteId().then(function(siteId){
          return Promise.all(lineItems.map(function(item){
            var detailFields = {
              PaymentDescription: item.description || '',
              InvoiceNo: item.invoice || '',
              Amount: item.amount || 0,
              // Graph's created-item id comes back as a string ("5") - MasterID is a Number
              // column, so this needs coercing to an actual number or SharePoint rejects it.
              MasterID: parseInt(createdMaster.id, 10),
              // Staff Claims spell out their category here (Master's RequestType text alone
              // can't tell Matter from Office); other types mirror RequestType as-is.
              RType: data.nominalType === 'staff'
                ? (data.staffSubtype === 'office' ? 'Staff Claim Office' : 'Staff Claim Matter')
                : requestTypeText
            };
            if (fields.MatterNo) detailFields.MatterNo = fields.MatterNo;
            return graphRequest('/sites/' + siteId + '/lists/' + detailsListId + '/items', {
              method: 'POST',
              body: JSON.stringify({ fields: detailFields })
            });
          }));
        });
      });
    }).then(function(){
      return uploadAttachmentsForItem(createdMaster.id, attachmentFiles).catch(function(err){
        console.warn('Item was created, but one or more attachments failed to upload.', err);
      });
    }).then(function(){
      return createdMaster;
    });
  };

  // ---------- Read (View Requests) ----------
  // createdDateTime comes back as a UTC ISO timestamp - render it in Malaysia time (not just
  // the date, and not whatever timezone the viewer's own device happens to be set to) so
  // "submitted at 11:58pm" vs "just after midnight" is visible and consistent for every staff
  // member regardless of where they're opening this from.
  function formatDateTime(iso){
    if (!iso) return '';
    var d = new Date(iso);
    if (isNaN(d.getTime())) return iso.slice(0, 10);
    var tz = { timeZone: 'Asia/Kuala_Lumpur' };
    return d.toLocaleDateString('en-MY', Object.assign({ day: '2-digit', month: 'short', year: 'numeric' }, tz)) +
      ', ' + d.toLocaleTimeString('en-MY', Object.assign({ hour: '2-digit', minute: '2-digit' }, tz));
  }

  window.spFetchRequests = function(){
    return Promise.all([
      getSpListId(SP_MASTER_LIST_NAME),
      getSpListId(SP_DETAILS_LIST_NAME)
    ]).then(function(ids){
      return getSpSiteId().then(function(siteId){
        return Promise.all([
          // No $orderby here - Graph rejects ordering by a list-item field ("fields/Created")
          // unless that column is indexed, which silently failed the whole request. Sort
          // newest-first on our side instead, using the item's own createdDateTime.
          graphRequest('/sites/' + siteId + '/lists/' + ids[0] + '/items?$expand=fields&$top=200'),
          // Details has no direct filter-by-MasterID here (that column isn't indexed either) -
          // pull them all in one shot and group client-side instead of one query per Master row.
          graphRequest('/sites/' + siteId + '/lists/' + ids[1] + '/items?$expand=fields&$top=999'),
          fetchAllAttachments()
        ]);
      });
    }).then(function(results){
      var masterRows = (results[0] && results[0].value) || [];
      var detailRows = (results[1] && results[1].value) || [];
      var attachmentsByMasterId = results[2] || {};
      masterRows.sort(function(a, b){ return (b.createdDateTime || '').localeCompare(a.createdDateTime || ''); });

      var detailsByMaster = {};
      detailRows.forEach(function(row){
        var df = row.fields || {};
        var masterId = df.MasterID;
        if (masterId == null) return;
        (detailsByMaster[masterId] = detailsByMaster[masterId] || []).push({
          // Details item id - lets an Accounts decision update these rows' Status directly.
          detailItemId: row.id,
          description: df.PaymentDescription || '',
          invoice: df.InvoiceNo || '',
          amount: parseFloat(df.Amount) || 0
        });
      });

      // LawyerInCharge/PartnerInCharge/SeniorPartner/SeniorPartner2/Accounts only ever come
      // back as "<Field>LookupId" (the SharePoint user's numeric id) - resolve every
      // distinct id that shows up across all rows in one batch (getSpUserById caches each,
      // so repeats are free).
      var neededIds = {};
      masterRows.forEach(function(row){
        var f = row.fields || {};
        [f.LawyerInChargeLookupId, f.PartnerInChargeLookupId, f.HeadOfDepartmentLookupId, f.SeniorPartner1LookupId, f.SeniorPartner2LookupId, f.AccountsLookupId, f.AuthorLookupId].forEach(function(id){
          if (id) neededIds[id] = true;
        });
      });
      return Promise.all(Object.keys(neededIds).map(function(id){
        return getSpUserById(id).then(function(info){ return { id: id, info: info }; });
      })).then(function(resolved){
        var userById = {};
        resolved.forEach(function(r){ if (r.info) userById[r.id] = r.info; });

        return masterRows.map(function(row){
          var f = row.fields || {};
          var typeInfo = inferTypeFromText(f.RequestType, f.StaffClaimCategory);
          var lineItems = detailsByMaster[row.id] || [];
          // Office Related's HOD lives in HeadOfDepartment. Office requests submitted before that
          // column existed stored it in PartnerInCharge instead (new ones never set
          // PartnerInCharge), so that's what tells the two apart for Copy From.
          var hodColumns = typeInfo.nominalType === 'office' && !f.PartnerInChargeLookupId;
          // Master's own Status column is the normal source of truth (see the note near the
          // top of this block), but whatever external process sets it doesn't reliably flip
          // it to Rejected when a request is rejected at the Lawyer stage specifically (the
          // individual LawyerStatus correctly shows Rejected in the details modal, but
          // Status itself was observed staying "Pending" - confirmed 2026-10-15). A
          // rejection at ANY stage is unambiguous, so it overrides whatever Status says
          // rather than waiting on that external process to catch up.
          var anyStageRejected = [f.LawyerStatus, f.HeadOfDepartmentStatus, f.PartnerStatus, f.SeniorPartner1Status, f.SeniorPartner2Status, f.AccountsStatus].some(function(s){
            return classifyApprovalStatus(s) === 'rejected';
          });
          var status = anyStageRejected ? 'rejected' : classifyApprovalStatus(f.Status);          // Prefer BankNameForeign over BankName whenever it actually has a value, rather than
          // deciding purely off Currency - an MYR request can also have its bank name there
          // now, if "Others" was picked for a bank that isn't in the BankName Choice list.
          var bankNameIsForeign = !!f.BankNameForeign;
          var bankNameValue = bankNameIsForeign ? f.BankNameForeign : (f.BankName || '');
          // Staff Claim (Office) keeps its first approver (HOD) in HeadOfDepartment - read it
          // back into the form's first approver field for Copy From.
          var isStaffOfficeRow = typeInfo.nominalType === 'staff' && typeInfo.staffSubtype === 'office';
          var lawyerUser = userById[(isStaffOfficeRow && f.HeadOfDepartmentLookupId) ? f.HeadOfDepartmentLookupId : f.LawyerInChargeLookupId] || {};
          // Staff Claim (Office) keeps its second approver (Senior Partner) in SeniorPartner1.
          var partnerUser = userById[hodColumns ? f.HeadOfDepartmentLookupId
            : (isStaffOfficeRow && f.SeniorPartner1LookupId) ? f.SeniorPartner1LookupId
            : f.PartnerInChargeLookupId] || {};
          var seniorPartnerUser = userById[f.SeniorPartner1LookupId] || {};
          var seniorPartner2User = userById[f.SeniorPartner2LookupId] || {};
          var accountsUser = userById[f.AccountsLookupId] || {};
          var submitterUser = userById[f.AuthorLookupId] || {};
          var lawyerName = lawyerUser.displayName || '';
          var partnerName = partnerUser.displayName || '';
          var seniorPartnerName = seniorPartnerUser.displayName || '';
          var seniorPartner2Name = seniorPartner2User.displayName || '';
          var accountsName = accountsUser.displayName || '';

          // Ready for Accounts purely when SharePoint's AccountsStatus reads exactly "Pending" -
          // the approval flow sets that once the earlier stages are done, so the page doesn't
          // second-guess the routing itself. (Not classifyApprovalStatus: that also treats a
          // blank/"New" status as pending.)
          var readyForAccounts = (f.AccountsStatus || '').trim().toLowerCase() === 'pending';

          return {
            ref: row.id,
            type: typeInfo.nominalType,
            payee: f.Payee || '',
            amount: (parseFloat(f.TotalAmount) || 0).toLocaleString('en-MY', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
            currency: f.Currency || '',
            status: status,
            date: formatDateTime(row.createdDateTime),
            lawyerInCharge: (userById[f.LawyerInChargeLookupId] || {}).displayName || '',
            lawyerStatus: f.LawyerStatus || '',
            // Details-modal cards show each column exactly as stored (Not set when blank).
            headOfDepartment: (userById[f.HeadOfDepartmentLookupId] || {}).displayName || '',
            headOfDepartmentStatus: f.HeadOfDepartmentStatus || '',
            headOfDepartmentRemarks: f.HeadOfDepartmentRemarks || '',
            partnerInCharge: (userById[f.PartnerInChargeLookupId] || {}).displayName || '',
            partnerStatus: f.PartnerStatus || '',
            seniorPartner: seniorPartnerName,
            seniorPartnerStatus: f.SeniorPartner1Status || '',
            seniorPartner2: seniorPartner2Name,
            seniorPartner2Status: f.SeniorPartner2Status || '',
            accountsInCharge: accountsName,
            accountsStatus: f.AccountsStatus || '',
            readyForAccounts: readyForAccounts,
            submitterEmail: submitterUser.email || '',
            createdBy: submitterUser.displayName || '',
            bankName: bankNameValue,
            bankAccountNumber: f.BankNo || '',
            lawyerRemarks: f.LawyerRemarks || '',
            partnerRemarks: f.PartnerRemarks || '',
            seniorPartnerRemarks: f.SeniorPartner1Remarks || '',
            seniorPartner2Remarks: f.SeniorPartner2Remarks || '',
            accountsRemarks: f.AccountsRemarks || '',
            attachments: attachmentsByMasterId[row.id] || [],
            formData: {
              nominalType: typeInfo.nominalType,
              staffSubtype: typeInfo.staffSubtype,
              matterNumber: f.MatterNo || '',
              clientName: f.ClientName || '',
              matterDescription: f.MatterDescription || '',
              payee: f.Payee || '',
              modeOfPayment: f.ModeOfPayment || '',
              bankName: bankNameValue,
              bankNameIsForeign: bankNameIsForeign,
              bankAccountNumber: f.BankNo || '',
              lawyerInCharge: lawyerName,
              lawyerInChargeEmail: lawyerUser.email || '',
              partnerInCharge: partnerName,
              partnerInChargeEmail: partnerUser.email || '',
              seniorPartner: seniorPartnerName,
              seniorPartnerEmail: seniorPartnerUser.email || '',
              seniorPartner2: seniorPartner2Name,
              seniorPartner2Email: seniorPartner2User.email || '',
              currency: f.Currency || '',
              lineItems: lineItems
            }
          };
        });
      });
    });
  };

  // Reuses spFetchRequests wholesale rather than a separate single-item network path -
  // slightly wasteful (fetches every request) but guarantees identical field-mapping logic
  // with zero duplication, and this app's request volume doesn't make that a real cost.
  window.spFetchRequestById = function(id){
    return window.spFetchRequests().then(function(items){
      return items.filter(function(item){ return String(item.ref) === String(id).trim(); })[0] || null;
    });
  };

  // ---------- Accounts Approval ----------
  // Same card layout as the Power Automate approval emails (header band, status pill,
  // Request Details table, Remarks box) so the Accounts outcome reads as part of that series.
  // Table-based with inline styles only - Outlook ignores <style> blocks and most CSS layout.
  function accountsDecisionEmailHtml(itemId, decision, remarks, details){
    var rejected = decision === 'Rejected';
    var statusWord = rejected ? 'Rejected' : 'Completed';
    var main = rejected ? '#c62828' : '#2e7d32';
    var tint = rejected ? '#fdecea' : '#eef6ea';
    var tintBorder = rejected ? '#f5c2bd' : '#cfe5c6';
    var esc = escapeHtmlLocal;
    var font = "font-family:'Segoe UI',Arial,sans-serif;";
    function detailRow(label, value, isLast, emphasise){
      return '<tr>' +
        '<td style="' + font + 'padding:12px 14px;font-size:13px;color:#5f6368;width:40%;' + (isLast ? '' : 'border-bottom:1px solid #e8eaed;') + '">' + label + '</td>' +
        '<td style="' + font + 'padding:12px 14px;' + (emphasise ? 'font-size:16px;font-weight:700;color:' + main + ';' : 'font-size:13px;color:#202124;') + (isLast ? '' : 'border-bottom:1px solid #e8eaed;') + '">' + esc(value || '-') + '</td>' +
        '</tr>';
    }
    var closingLine = rejected
      ? 'Your request has been rejected by Accounts. Please refer to the remarks above.'
      : 'Your request has been completed by Accounts.';
    return '<div style="background:#f3f4f8;padding:24px 0;">' +
      '<table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center" width="460" style="width:460px;max-width:100%;background:#ffffff;border:1px solid #e3e5e8;border-radius:6px;border-collapse:separate;">' +
      '<tr><td style="' + font + 'background:' + main + ';padding:16px 20px;border-radius:6px 6px 0 0;">' +
        '<div style="font-size:11px;letter-spacing:0.5px;color:#f1f3f4;text-transform:uppercase;">E-Voucher Request</div>' +
        '<div style="font-size:19px;font-weight:700;color:#ffffff;margin-top:2px;">' + statusWord + '</div>' +
      '</td></tr>' +
      '<tr><td style="' + font + 'padding:22px 20px 8px;font-size:13px;color:#202124;">' +
        '<p style="margin:0 0 14px;">Dear ' + esc(details.submitterName || 'Sir/Madam') + ',</p>' +
        '<p style="margin:0 0 18px;">Your E-Voucher has been ' +
          '<span style="display:inline-block;background:' + main + ';color:#ffffff;font-size:11px;font-weight:700;padding:3px 9px;border-radius:10px;text-transform:uppercase;">' + statusWord + '</span>' +
          ' by <strong>' + esc(details.approverName || 'Accounts') + '</strong>.</p>' +
        '<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#f7f8f7;border:1px solid #e8eaed;border-left:4px solid ' + main + ';border-collapse:separate;">' +
          '<tr><td colspan="2" style="' + font + 'padding:12px 14px;font-size:13px;font-weight:700;color:' + main + ';border-bottom:1px solid #e8eaed;">Request Details</td></tr>' +
          detailRow('Request ID', String(itemId)) +
          detailRow('Request Type', details.requestType) +
          detailRow('Payee Name', details.payee) +
          detailRow('Mode of Payment', details.modeOfPayment) +
          detailRow('Total Amount', details.totalAmount, true, true) +
        '</table>' +
        (remarks
          ? '<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin-top:14px;background:' + tint + ';border:1px solid ' + tintBorder + ';border-radius:4px;border-collapse:separate;">' +
              '<tr><td style="' + font + 'padding:12px 14px;font-size:12px;color:' + main + ';">' +
                '<div style="font-weight:700;margin-bottom:3px;">Remarks:</div>' + esc(remarks) +
              '</td></tr></table>'
          : '') +
        '<p style="margin:18px 0 12px;">' + closingLine + '</p>' +
        '<p style="margin:0 0 14px;">Thank you.</p>' +
      '</td></tr>' +
      '<tr><td style="' + font + 'background:#f8f9fa;padding:12px 20px;font-size:10px;color:#80868b;text-align:center;border-radius:0 0 6px 6px;">This is an automated message. Please do not reply to this email.</td></tr>' +
      '</table></div>';
  }

  function sendAccountsDecisionEmail(itemId, decision, remarks, submitterEmail, details){
    if (!submitterEmail){
      console.warn('No submitter email resolved for item ' + itemId + ' - skipping notification email.');
      return Promise.resolve();
    }
    details = details || {};
    details.approverName = window.__currentUserName || '';
    var statusWord = decision === 'Rejected' ? 'Rejected' : 'Completed';
    return window.getGraphToken(['Mail.Send']).then(function(token){
      return fetch(GRAPH_BASE + '/me/sendMail', {
        method: 'POST',
        headers: {
          'Authorization': 'Bearer ' + token.accessToken,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          message: {
            subject: statusWord.toUpperCase() + ' - E-Voucher Request - ID: ' + itemId,
            body: { contentType: 'HTML', content: accountsDecisionEmailHtml(itemId, decision, remarks, details) },
            toRecipients: [{ emailAddress: { address: submitterEmail } }]
          }
        })
      });
    }).then(function(res){
      if (!res.ok) return res.text().then(function(t){ throw new Error('sendMail failed (' + res.status + '): ' + t); });
    });
  }

  // decision: 'Complete' or 'Rejected' (matches the AccountsStatus Choice column's actual
  // values). Writes AccountsStatus/AccountsDate/AccountsLookupId/AccountsRemarks (via a
  // Graph PATCH to the item's /fields sub-resource - different from the POST-with-
  // {fields:...}-wrapper used everywhere else in this file for item creation), mirrors the
  // decision into Master's own overall Status column, then emails the submitter.
  window.spSubmitAccountsDecision = function(itemId, decision, remarks, submitterEmail, emailDetails, detailItemIdsForMaster){
    return ensureSpUser(window.__currentUserEmail).catch(function(err){
      console.warn('Could not resolve the signed-in Accounts approver as a SharePoint user - AccountsLookupId will be left blank.', err);
      return null;
    }).then(function(accountsSpUserId){
      var fields = {
        AccountsStatus: decision,
        AccountsDate: new Date().toISOString(),
        Status: decision === 'Rejected' ? 'Rejected' : 'Completed'
      };
      if (accountsSpUserId) fields.AccountsLookupId = accountsSpUserId;
      if (remarks) fields.AccountsRemarks = remarks;
      return getSpListId(SP_MASTER_LIST_NAME).then(function(masterListId){
        return getSpSiteId().then(function(siteId){
          return graphRequest('/sites/' + siteId + '/lists/' + masterListId + '/items/' + itemId + '/fields', {
            method: 'PATCH',
            body: JSON.stringify(fields)
          });
        });
      });
    }).then(function(){
      // Mirror the outcome onto every line item in E-Voucher Details: Status "C" (Complete) or
      // "R" (Rejected). Master is already saved by now, so a failure here is reported but
      // doesn't undo the decision or stop the email.
      var detailItemIds = detailItemIdsForMaster || [];
      if (!detailItemIds.length) return;
      var detailStatus = decision === 'Rejected' ? 'R' : 'C';
      return getSpListId(SP_DETAILS_LIST_NAME).then(function(detailsListId){
        return getSpSiteId().then(function(siteId){
          return Promise.all(detailItemIds.map(function(detailId){
            return graphRequest('/sites/' + siteId + '/lists/' + detailsListId + '/items/' + detailId + '/fields', {
              method: 'PATCH',
              body: JSON.stringify({ Status: detailStatus })
            });
          }));
        });
      }).catch(function(err){
        console.warn('Accounts decision was saved, but E-Voucher Details Status could not be updated.', err);
        alert('The Accounts decision was saved, but the line items\' Status in E-Voucher Details could not be updated to "' +
          detailStatus + '": ' + ((err && err.message) || 'Unknown error'));
      });
    }).then(function(){
      return sendAccountsDecisionEmail(itemId, decision, remarks, submitterEmail, emailDetails).catch(function(err){
        console.warn('Accounts decision was saved, but the notification email failed to send.', err);
      });
    });
  };

  // Checks the signed-in account's email against the same security group used for the
  // Lawyer/Partner/Senior Partner picker (APPROVERS_GROUP_ID) - a stand-in for a dedicated
  // Accounts/Finance group until one exists, per instruction ("for now use the current
  // security group"). Gates visibility of the Accounts Approval nav item/view only - it is
  // NOT itself a security boundary, since SharePoint item-level permissions (set outside
  // this file) are what actually control who can write AccountsStatus etc.
  window.checkCurrentUserIsApprover = function(account){
    var email = (account && account.username || '').toLowerCase();
    if (!email) return Promise.resolve(false);
    return fetchGroupMembers().then(function(members){
      return members.some(function(m){
        return (m.mail || '').toLowerCase() === email || (m.userPrincipalName || '').toLowerCase() === email;
      });
    }).catch(function(err){
      console.warn('Could not check Accounts approver group membership.', err);
      return false;
    });
  };

  window.eVoucherSignInHandlers.push(function(account){
    window.checkCurrentUserIsApprover(account).then(function(isApprover){
      var navItem = document.getElementById('accountsNavItem');
      if (navItem) navItem.hidden = !isApprover;
    });
  });

  window.eVoucherSignInHandlers.push(function(){
    loadDynamicChoices();
    setupPeoplePicker({ inputId: 'lawyerInCharge', hiddenEmailId: 'lawyerInChargeEmail', suggestionsId: 'lawyerInChargeSuggestions' });
    setupPeoplePicker({ inputId: 'partnerInCharge', hiddenEmailId: 'partnerInChargeEmail', suggestionsId: 'partnerInChargeSuggestions' });
    // Same security group as Lawyer/Partner (per instruction) - no separate group ID needed.
    // Partner-In-Charge and Senior Partner 1 can't be the same person, so whoever is
    // currently Partner-In-Charge is excluded from this picker's own suggestions.
    setupPeoplePicker({ inputId: 'seniorPartner', hiddenEmailId: 'seniorPartnerEmail', suggestionsId: 'seniorPartnerSuggestions', excludeEmailId: 'partnerInChargeEmail' });
    setupPeoplePicker({ inputId: 'seniorPartner2', hiddenEmailId: 'seniorPartner2Email', suggestionsId: 'seniorPartner2Suggestions' });
  });
})();
</script>

</body>
</html>
