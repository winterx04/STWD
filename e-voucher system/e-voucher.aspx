<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="0">
<title>E-Voucher Request System</title>
<script>
  // Bump this string every time this file is re-uploaded to the document library.
  // Browsers/SharePoint can keep serving an old cached copy of this page after a
  // re-upload; this quietly re-fetches the page in the background (bypassing the
  // HTTP cache) and force-reloads once if the server's copy has a newer version.
  window.__EVOUCHER_VERSION__ = '2026.09.12.9';
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
    fetch(location.pathname + location.search, { cache: 'no-store' }).then(function(res){
      return res.text();
    }).then(function(html){
      var m = html.match(/__EVOUCHER_VERSION__\s*=\s*'([^']+)'/);
      if (m && m[1] && m[1] !== window.__EVOUCHER_VERSION__){
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
    overflow-y:auto;
    z-index:30;
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

  .main{margin-left:var(--sidebar-w);margin-top:var(--topbar-h);min-height:calc(100vh - var(--topbar-h));display:flex;flex-direction:column;}

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
  .submit-layout{display:flex;align-items:flex-start;gap:24px;max-width:1100px;margin:0 auto;}
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
    width:11px;height:11px;flex-shrink:0;border-radius:50%;
    background:var(--border);
    box-sizing:border-box;
    transition:background .2s, border-color .2s;
  }
  .jump-item:not(:last-child) .jump-dot::after{
    content:'';position:absolute;top:11px;left:50%;transform:translateX(-50%);
    width:2px;height:25px;background:var(--border);
    transition:background .2s;
  }
  .jump-item.done .jump-dot{background:var(--primary);}
  .jump-item.done .jump-dot::after{background:var(--primary);}
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
  .view-wrap{max-width:900px;margin:0 auto;}

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
  td .desc-input{min-width:280px;}
  td.amount-cell input{text-align:right;min-width:130px;}
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
  .dropzone p{margin:4px 0;color:var(--text-muted);font-size:14px;}
  .dropzone-icon{display:block;font-size:26px;color:var(--primary);margin-bottom:10px;}

  /* ---------- Custom dropdown (replaces native <select> popup styling) ---------- */
  .custom-select-wrap{position:relative;}
  .custom-select-wrap select{
    position:absolute;inset:0;width:100%;height:100%;
    opacity:0;pointer-events:none;
  }
  .custom-select-wrap:has(select[hidden]) .cst-trigger,
  .custom-select-wrap:has(select[hidden]) .cst-panel{display:none;}
  .custom-select-wrap:has(select.invalid) .cst-trigger{border-color:var(--danger);background:var(--danger-bg);}
  .custom-select-wrap:has(select:disabled) .cst-trigger{opacity:.6;cursor:not-allowed;}
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

  .people-picker{position:relative;}
  .people-picker input[type=text]{padding-right:34px;cursor:text;}
  .people-picker-caret{
    position:absolute;top:0;right:12px;bottom:0;
    display:flex;align-items:center;
    color:var(--text-muted);font-size:12px;
    pointer-events:none;
  }
  .people-picker-multi{
    display:flex;flex-wrap:wrap;align-items:center;gap:6px;
    padding:6px 34px 6px 8px;
    border:1px solid var(--border);border-radius:8px;background:var(--white);
    transition:border-color .15s, box-shadow .15s;
  }
  .people-picker-multi:focus-within{
    border-color:var(--primary);
    box-shadow:0 0 0 3px rgba(224,108,35,0.15);
  }
  .people-picker-multi input[type=text]{
    flex:1;min-width:140px;border:none;padding:6px 4px;box-shadow:none;
  }
  .people-picker-multi input[type=text]:focus{box-shadow:none;}
  .people-chip{
    display:inline-flex;align-items:center;gap:6px;
    background:var(--primary-light);color:var(--primary-dark);
    padding:4px 6px 4px 10px;border-radius:20px;font-size:12.5px;font-weight:600;
    white-space:nowrap;
  }
  .people-chip button{
    background:none;border:none;color:var(--primary-dark);cursor:pointer;
    font-size:11px;line-height:1;width:16px;height:16px;border-radius:50%;
    display:flex;align-items:center;justify-content:center;
  }
  .people-chip button:hover{background:rgba(224,108,35,0.25);}
  .people-suggestions{
    position:absolute;top:100%;left:0;right:0;margin-top:4px;
    background:var(--white);border:1px solid var(--border);border-radius:8px;
    box-shadow:var(--shadow);z-index:20;max-height:220px;overflow-y:auto;
  }
  .people-suggestion{
    padding:8px 12px;cursor:pointer;
    display:flex;flex-direction:column;gap:1px;
  }
  .people-suggestion:hover,.people-suggestion.active{background:var(--bg);}
  .people-suggestion .p-name{font-size:13.5px;font-weight:600;color:var(--text);}
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

  .status-badge{
    display:inline-block;padding:4px 10px;border-radius:20px;
    font-size:11.5px;font-weight:700;white-space:nowrap;
  }
  .status-badge.pending{background:var(--primary-light);color:var(--primary-dark);}
  .status-badge.approved{background:#e3f5ea;color:var(--success);}
  .status-badge.rejected{background:var(--danger-bg);color:var(--danger);}

  .btn-sm{padding:6px 14px;font-size:12.5px;}

  .modal{
    position:fixed;inset:0;background:rgba(1,52,95,0.55);
    display:flex;align-items:center;justify-content:center;
    padding:20px;z-index:50;
  }
  .modal[hidden]{display:none;}
  .modal-card{
    background:var(--white);border-radius:14px;padding:30px;max-width:420px;width:100%;
    text-align:center;box-shadow:0 10px 40px rgba(0,0,0,0.3);
  }
  .modal-card .icon{
    width:56px;height:56px;border-radius:50%;background:#e9f7ee;color:var(--success);
    display:flex;align-items:center;justify-content:center;margin:0 auto 14px;font-size:28px;
  }
  .modal-card h2{margin:0 0 8px;color:var(--navy);}
  .modal-card p{color:var(--text-muted);font-size:14px;margin:4px 0;}
  .modal-card strong{color:var(--navy);}

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
    <img class="brand-full-logo" alt="Sidek Teoh Wong &amp; Dennis" src="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/4gIoSUNDX1BST0ZJTEUAAQEAAAIYYXBwbAQAAABtbnRyUkdCIFhZWiAH5gABAAEAAAAAAABhY3NwQVBQTAAAAABBUFBMAAAAAAAAAAAAAAAAAAAAAAAA9tYAAQAAAADTLWFwcGzs/aOOOIVHw220vU962hgvAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAApkZXNjAAAA/AAAADBjcHJ0AAABLAAAAFB3dHB0AAABfAAAABRyWFlaAAABkAAAABRnWFlaAAABpAAAABRiWFlaAAABuAAAABRyVFJDAAABzAAAACBjaGFkAAAB7AAAACxiVFJDAAABzAAAACBnVFJDAAABzAAAACBtbHVjAAAAAAAAAAEAAAAMZW5VUwAAABQAAAAcAEQAaQBzAHAAbABhAHkAIABQADNtbHVjAAAAAAAAAAEAAAAMZW5VUwAAADQAAAAcAEMAbwBwAHkAcgBpAGcAaAB0ACAAQQBwAHAAbABlACAASQBuAGMALgAsACAAMgAwADIAMlhZWiAAAAAAAAD21QABAAAAANMsWFlaIAAAAAAAAIPfAAA9v////7tYWVogAAAAAAAASr8AALE3AAAKuVhZWiAAAAAAAAAoOAAAEQsAAMi5cGFyYQAAAAAAAwAAAAJmZgAA8qcAAA1ZAAAT0AAACltzZjMyAAAAAAABDEIAAAXe///zJgAAB5MAAP2Q///7ov///aMAAAPcAADAbv/bAEMABgQEBQQEBgUFBQYGBgcJDgkJCAgJEg0NCg4VEhYWFRIUFBcaIRwXGB8ZFBQdJx0fIiMlJSUWHCksKCQrISQlJP/bAEMBBgYGCQgJEQkJESQYFBgkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJP/AABEIAbIIAAMBEQACEQEDEQH/xAAdAAEAAgIDAQEAAAAAAAAAAAAABwgBBgMEBQIJ/8QAXhAAAQMCAwMEDAkHCAcHBAIDAAECAwQFBgcREiExCBNBURQVIjY3YXF0gZOxsjJUcnORobPB0RcYI0JSVpIWMzQ1VWKCwiQ4RFNjZHUmJ0ODhOHwJShGoqPxRZTS/8QAGgEBAAMBAQEAAAAAAAAAAAAAAAMEBQECBv/EACwRAQACAgEEAAcBAQADAQEBAAABAgMRBBIhMTIFExQiM0FRFSM0UmFxQkP/2gAMAwEAAhEDEQA/ALUgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/2Q==">
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
      <i class="fa-solid fa-file-invoice-dollar"></i>
      <span>Submit payment request</span>
    </button>
    <button type="button" class="nav-item" data-view="requests">
      <i class="fa-solid fa-list-check"></i>
      <span>View requests</span>
    </button>
  </nav>

  <!-- <div class="sidebar-footer">Front-end preview &middot; no sign-in required</div> -->
</div>

<div class="main">
  
  <div class="content">

    <section id="view-submit" class="view">
      <div class="submit-layout">
      <div class="submit-main">

        <form id="voucherForm" novalidate>

          <div id="errorSummary" class="alert alert-error" hidden>
            <span>&#9888;</span>
            <div>
              <strong>Please fix the following before submitting:</strong>
              <ul id="errorList"></ul>
            </div>
          </div>

          <section class="card" id="form-section-1">
            <h2><span class="step">1</span><i class="fa-solid fa-file-signature card-icon"></i>Request Type</h2>
            <div class="grid-2">
              <div class="field">
                <label for="nominalType">Payment nominal request for *</label>
                <select id="nominalType" required>
                  <option value="">Select type</option>
                  <option value="matter">E-Voucher on Matter Related</option>
                  <option value="office">E-Voucher on Office Related</option>
                  <option value="staff">E-Voucher on Staff Claims</option>
                </select>
              </div>
              <div class="field" id="staffSubtypeField" hidden>
                <label for="staffSubtype">Staff claim category *</label>
                <select id="staffSubtype">
                  <option value="matter">Matter Related</option>
                  <option value="office">Office Related</option>
                </select>
              </div>
            </div>

            <div id="matterSection" class="matter-fields" hidden>
              <div class="grid-3">
                <div class="field">
                  <label for="matterNumber">Matter number *</label>
                  <input type="text" id="matterNumber" placeholder="e.g. M-2026-1001">
                </div>
                <div class="field">
                  <label for="clientName">Client name</label>
                  <input type="text" id="clientName" readonly>
                </div>
                <div class="field full">
                  <label for="matterDescription">Matter description</label>
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
                <label for="modeOfPayment">Mode of payment *</label>
                <select id="modeOfPayment" required>
                  <option value="">Select mode</option>
                  <option>Bank Draft</option>
                  <option>Cheque</option>
                  <option>InterBank GIRO (IBG)</option>
                  <option>Rentas</option>
                  <option>Telegraphic Transfer (TT)</option>
                </select>
              </div>
              <div class="field">
                <label for="bankName">Bank name *</label>
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
                </select>
                <input type="text" id="bankNameManual" placeholder="Type bank name" hidden>
                <p class="hint" id="bankNameForeignHint" hidden>Foreign currency selected &mdash; please type the bank name manually.</p>
              </div>
              <div class="field">
                <label for="bankAccountNumber">Bank account number *</label>
                <input type="text" id="bankAccountNumber" required>
              </div>
            </div>
          </section>

          <section class="card" id="form-section-3">
            <h2><span class="step">3</span><i class="fa-solid fa-user-check card-icon"></i>Approval Routing</h2>
            <div class="grid-2">
              <div class="field">
                <label for="lawyerInCharge">Lawyer-In-Charge / HOD *</label>
                <div class="people-picker" id="lawyerInChargePicker">
                  <input type="text" id="lawyerInCharge" autocomplete="off" placeholder="Click or type to search..." required>
                  <input type="hidden" id="lawyerInChargeEmail">
                  <i class="fa-solid fa-chevron-down people-picker-caret"></i>
                  <div class="people-suggestions" id="lawyerInChargeSuggestions" hidden></div>
                </div>
              </div>
              <div class="field">
                <label for="partnerInCharge">Partner in charge *</label>
                <div class="people-picker" id="partnerInChargePicker">
                  <input type="text" id="partnerInCharge" autocomplete="off" placeholder="Click or type to search..." required>
                  <input type="hidden" id="partnerInChargeEmail">
                  <i class="fa-solid fa-chevron-down people-picker-caret"></i>
                  <div class="people-suggestions" id="partnerInChargeSuggestions" hidden></div>
                </div>
              </div>
              <div class="field full">
                <label for="ccInput">CC <span class="opt">(optional)</span></label>
                <div class="people-picker people-picker-multi" id="ccPicker">
                  <div class="people-chips" id="ccChips"></div>
                  <input type="text" id="ccInput" autocomplete="off" placeholder="Click or type to search...">
                  <i class="fa-solid fa-chevron-down people-picker-caret"></i>
                  <div class="people-suggestions" id="ccSuggestions" hidden></div>
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
                    <th>Payment description</th>
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
                <label for="totalAmount">Total amount</label>
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
              <p>Invoice, bill, or other supporting documents</p>
            </div>
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
          <div class="tracker-card-label">Jump to section</div>
          <div class="jump-list" id="jumpList">
            <button type="button" class="jump-item" data-step="1" data-target="form-section-1">
              <span class="jump-dot"></span><span class="jump-label">Request Type</span>
            </button>
            <button type="button" class="jump-item" data-step="2" data-target="form-section-2">
              <span class="jump-dot"></span><span class="jump-label">Payee &amp; Payment</span>
            </button>
            <button type="button" class="jump-item" data-step="3" data-target="form-section-3">
              <span class="jump-dot"></span><span class="jump-label">Approval Routing</span>
            </button>
            <button type="button" class="jump-item" data-step="4" data-target="form-section-4">
              <span class="jump-dot"></span><span class="jump-label">Line Items</span>
            </button>
            <button type="button" class="jump-item" data-step="5" data-target="form-section-5">
              <span class="jump-dot"></span><span class="jump-label">Attachment</span>
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
        <div class="card">
          <h2 style="margin-bottom:18px;"><i class="fa-solid fa-hourglass-half card-icon"></i>Pending Requests</h2>
          <div class="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Reference No.</th>
                  <th>Type</th>
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
          <p class="hint" id="requestsPendingEmpty" hidden>No pending requests right now.</p>
        </div>

        <div class="card">
          <h2 style="margin-bottom:18px;"><i class="fa-solid fa-clipboard-check card-icon"></i>Completed &amp; Rejected Requests</h2>
          <div class="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Reference No.</th>
                  <th>Type</th>
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
          <p class="hint" id="requestsCompletedEmpty" hidden>No completed or rejected requests yet.</p>
        </div>
      </div>
    </section>

  </div>
</div>

<div class="modal" id="requestDetailsModal" hidden>
  <div class="modal-card">
    <h2 style="margin-bottom:14px;">Request Details</h2>
    <div id="requestDetailsBody" class="matrix-info" style="text-align:left;"></div>
    <div style="margin-top:18px;display:flex;gap:10px;justify-content:center;">
      <button type="button" class="btn btn-ghost" id="closeRequestDetailsBtn">Close</button>
      <button type="button" class="btn btn-primary" id="resubmitRequestBtn" hidden><i class="fa-solid fa-pen-to-square"></i> Edit &amp; Resubmit</button>
    </div>
  </div>
</div>

<div class="modal" id="successModal" hidden>
  <div class="modal-card">
    <div class="icon">&#10003;</div>
    <h2>Request Submitted</h2>
    <p>Reference No: <strong id="refNumber"></strong></p>
    <p id="successSummary"></p>
    <p class="hint" style="margin-top:14px;">Your request has been recorded in SharePoint and routed for verification and approval.</p>
    <div style="margin-top:18px;">
      <button type="button" class="btn btn-primary" id="closeModalBtn">Close</button>
    </div>
  </div>
</div>

<script>
window.eVoucherSignInHandlers = window.eVoucherSignInHandlers || [];
</script>

<script>
(function(){
  'use strict';

  var MATTER_DB = {
    'M-2026-1001': { client: 'Prestige Land Sdn Bhd', description: 'Sale & Purchase Agreement - Commercial Unit' },
    'M-2026-1002': { client: 'Nova Trading Sdn Bhd', description: 'Corporate Advisory - Share Subscription Agreement' },
    'M-2026-1003': { client: 'Evergreen Holdings Bhd', description: 'Loan Documentation & Facility Agreement' }
  };

  var nominalType = document.getElementById('nominalType');
  var staffSubtypeField = document.getElementById('staffSubtypeField');
  var staffSubtype = document.getElementById('staffSubtype');
  var matterSection = document.getElementById('matterSection');
  var matterNumber = document.getElementById('matterNumber');
  var clientName = document.getElementById('clientName');
  var matterDescription = document.getElementById('matterDescription');
  var lineItemsBody = document.getElementById('lineItemsBody');
  var addRowBtn = document.getElementById('addRowBtn');
  var totalAmountField = document.getElementById('totalAmount');
  var staffCapWarning = document.getElementById('staffCapWarning');
  var lineItemLimitWarning = document.getElementById('lineItemLimitWarning');
  var MAX_LINE_ITEMS = 5;
  var dropzone = document.getElementById('dropzone');
  var attachmentInput = document.getElementById('attachment');
  var fileList = document.getElementById('fileList');
  var form = document.getElementById('voucherForm');
  var errorSummary = document.getElementById('errorSummary');
  var errorList = document.getElementById('errorList');
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

  Array.prototype.forEach.call(document.querySelectorAll('#voucherForm select'), enhanceSelect);

  var files = [];
  var rowCounter = 0;
  var TRACKER_STEPS = 5;

  function updateTracker(){
    var matterApplicable = !matterSection.hidden;
    var steps = {};
    steps[1] = nominalType.value !== '' &&
               (nominalType.value !== 'staff' || staffSubtype.value !== '') &&
               (matterApplicable ? matterNumber.value.trim() !== '' : true);
    steps[2] = !!(document.getElementById('payee').value.trim() &&
                  document.getElementById('modeOfPayment').value &&
                  activeBankNameField().value.trim() &&
                  document.getElementById('bankAccountNumber').value.trim());
    steps[3] = !!(document.getElementById('lawyerInCharge').value.trim() &&
                  document.getElementById('partnerInCharge').value.trim());
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

  function createRow(data){
    data = data || {};
    rowCounter++;
    var tr = document.createElement('tr');
    tr.dataset.rowId = rowCounter;
    tr.innerHTML =
      '<td><input type="text" class="desc-input" maxlength="200" placeholder="Payment description" value="' + (data.description ? escapeHtml(data.description) : '') + '"></td>' +
      '<td><input type="text" class="invoice-input" placeholder="Invoice/Ref no." value="' + (data.invoice ? escapeHtml(data.invoice) : '') + '"></td>' +
      '<td class="amount-cell"><input type="text" inputmode="decimal" class="amount-input" placeholder="0.00" value="' + (data.amount ? formatAmount(data.amount) : '') + '"></td>' +
      '<td><button type="button" class="row-remove" title="Remove row"><i class="fa-solid fa-trash"></i></button></td>';
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

  lineItemsBody.addEventListener('input', function(){ recalc(); });

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

    updateTracker();
    return { total: total, hasCapBreach: hasCapBreach };
  }

  nominalType.addEventListener('change', function(){
    var type = nominalType.value;
    staffSubtypeField.hidden = type !== 'staff';
    var showMatter = type === 'matter' || (type === 'staff' && staffSubtype.value === 'matter');
    matterSection.hidden = !showMatter;
    matterNumber.required = showMatter;
    recalc();
  });

  staffSubtype.addEventListener('change', function(){
    var showMatter = nominalType.value === 'staff' && staffSubtype.value === 'matter';
    matterSection.hidden = !showMatter;
    matterNumber.required = showMatter;
    recalc();
  });

  matterNumber.addEventListener('blur', function(){
    var key = matterNumber.value.trim().toUpperCase();
    if (MATTER_DB[key]){
      clientName.value = MATTER_DB[key].client;
      matterDescription.value = MATTER_DB[key].description;
    }
  });

  function updateBankNameMode(){
    var isForeign = currencySelect.value.toUpperCase().indexOf('MYR') === -1;
    bankNameSelect.hidden = isForeign;
    bankNameSelect.required = !isForeign;
    bankNameManual.hidden = !isForeign;
    bankNameManual.required = isForeign;
    bankNameForeignHint.hidden = !isForeign;
    if (isForeign && !bankNameManual.value) bankNameManual.value = bankNameSelect.value;
    else if (!isForeign && !bankNameSelect.value) { /* leave select as-is */ }
  }

  function activeBankNameField(){
    return currencySelect.value !== 'MYR' ? bankNameManual : bankNameSelect;
  }

  currencySelect.addEventListener('change', function(){ updateBankNameMode(); recalc(); });
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

  function addFiles(fileListObj){
    Array.prototype.forEach.call(fileListObj, function(f){ files.push(f); });
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

  function validate(){
    var errors = [];
    clearInvalidStates();

    function req(el, msg){
      if (!el.hidden && !el.value.trim()){
        el.classList.add('invalid');
        errors.push(msg);
      }
    }

    if (!nominalType.value){ nominalType.classList.add('invalid'); errors.push('Select a payment nominal type.'); }
    if (nominalType.value === 'staff' && !staffSubtype.value){ errors.push('Select a staff claim category.'); }

    var showMatter = !matterSection.hidden;
    if (showMatter) req(matterNumber, 'Matter number is required.');

    req(document.getElementById('payee'), 'Payee is required.');
    req(document.getElementById('modeOfPayment'), 'Mode of payment is required.');
    req(activeBankNameField(), 'Bank name is required.');
    req(document.getElementById('bankAccountNumber'), 'Bank account number is required.');
    req(document.getElementById('lawyerInCharge'), 'Lawyer in charge is required.');
    req(document.getElementById('partnerInCharge'), 'Partner in charge is required.');

    var rows = Array.prototype.slice.call(lineItemsBody.querySelectorAll('tr'));
    var anyLineItem = rows.some(function(tr){
      return tr.querySelector('.desc-input').value.trim() && parseAmount(tr.querySelector('.amount-input').value) > 0;
    });
    if (!anyLineItem){
      errors.push('Add at least one payment line item with a description and amount.');
    }

    var calc = recalc();
    if (calc.hasCapBreach) errors.push('One or more staff claim amounts exceed RM10,000.00.');
    if (calc.total <= 0) errors.push('Total amount must be greater than zero.');

    if (errors.length){
      errorList.innerHTML = errors.map(function(m){ return '<li>' + m + '</li>'; }).join('');
      errorSummary.hidden = false;
      errorSummary.scrollIntoView({ behavior:'smooth', block:'start' });
    } else {
      errorSummary.hidden = true;
    }
    return errors.length === 0;
  }

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
      payee: document.getElementById('payee').value,
      modeOfPayment: document.getElementById('modeOfPayment').value,
      bankName: activeBankNameField().value,
      bankAccountNumber: document.getElementById('bankAccountNumber').value,
      lawyerInCharge: document.getElementById('lawyerInCharge').value,
      partnerInCharge: document.getElementById('partnerInCharge').value,
      ccEmails: (window.getCcSelected ? window.getCcSelected() : []).join(', '),
      lineItems: rows,
      currency: document.getElementById('currency').value,
      totalAmount: totalAmountField.value,
      fileNames: files.map(function(f){ return f.name; })
    };
  }

  resetBtn.addEventListener('click', function(){
    if (!confirm('Reset the form? Unsaved changes will be lost.')) return;
    form.reset();
    matterSection.hidden = true;
    staffSubtypeField.hidden = true;
    clientName.value = '';
    matterDescription.value = '';
    lineItemsBody.innerHTML = '';
    createRow();
    updateLineItemLimitUI();
    files = [];
    renderFileList();
    bankNameManual.value = '';
    updateBankNameMode();
    if (window.clearCcPicker) window.clearCcPicker();
    recalc();
    errorSummary.hidden = true;
  });

  form.addEventListener('submit', function(e){
    e.preventDefault();
    if (!validate()) return;
    var data = collectData();

    if (typeof window.spSubmitRequest !== 'function'){
      errorList.innerHTML = '<li>Not connected to SharePoint yet - please make sure you are signed in, then try again.</li>';
      errorSummary.hidden = false;
      errorSummary.scrollIntoView({ behavior: 'smooth', block: 'start' });
      return;
    }

    var originalSubmitHtml = submitBtn.innerHTML;
    submitBtn.disabled = true;
    submitBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Submitting...';

    window.spSubmitRequest(data, files).then(function(created){
      submitBtn.disabled = false;
      submitBtn.innerHTML = originalSubmitHtml;
      refNumber.textContent = 'EV-' + created.id;
      successSummary.textContent = data.payee + ' - ' + data.currency + ' ' + data.totalAmount + ' submitted for approval.';
      successModal.hidden = false;
      loadRequestsFromSharePoint();
    }).catch(function(err){
      submitBtn.disabled = false;
      submitBtn.innerHTML = originalSubmitHtml;
      errorList.innerHTML = '<li>Could not submit to SharePoint: ' + escapeHtml((err && err.message) || 'Unknown error') + '</li>';
      errorSummary.hidden = false;
      errorSummary.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  });

  closeModalBtn.addEventListener('click', function(){ successModal.hidden = true; });

  // ---------- View Requests: status list + details modal ----------
  var TYPE_LABELS = { matter: 'Matter Related', office: 'Office Related', staff: 'Staff Claims' };
  var STATUS_META = {
    'pending-verification': { label: 'Pending Verification', cls: 'pending', icon: 'fa-clock' },
    'pending-approval': { label: 'Pending Approval', cls: 'pending', icon: 'fa-clock' },
    'approved': { label: 'Approved', cls: 'approved', icon: 'fa-circle-check' },
    'rejected': { label: 'Rejected', cls: 'rejected', icon: 'fa-circle-xmark' }
  };

  var SUBMITTED_REQUESTS = [
    { ref: 'EV-2026-100231', type: 'matter', payee: 'Prestige Land Sdn Bhd', amount: '8,500.00', currency: 'MYR',
      status: 'approved', date: '2026-08-20', lawyerInCharge: 'Victoria Foo Yi Hui', partnerInCharge: 'Low Huan Qi' },
    { ref: 'EV-2026-100249', type: 'matter', payee: 'Evergreen Holdings Bhd', amount: '15,000.00', currency: 'MYR',
      status: 'rejected', date: '2026-08-25', lawyerInCharge: 'Rayhan Kass binti Azriman', partnerInCharge: 'Kee Swee Chuan',
      note: 'Invoice date exceeded the 3-month submission window.',
      formData: {
        nominalType: 'matter', staffSubtype: 'matter', matterNumber: 'M-2026-1003',
        clientName: 'Evergreen Holdings Bhd', matterDescription: 'Loan Documentation & Facility Agreement',
        payee: 'Evergreen Holdings Bhd', modeOfPayment: 'Telegraphic Transfer (TT)',
        bankName: 'HSBC Bank Malaysia Berhad', bankAccountNumber: '1122334455',
        lawyerInCharge: 'Rayhan Kass binti Azriman', partnerInCharge: 'Kee Swee Chuan', ccEmails: '',
        currency: 'MYR', lineItems: [{ description: 'Facility drawdown fee', invoice: 'INV-8841', amount: 15000 }]
      } },
    { ref: 'EV-2026-100255', type: 'office', payee: 'Ban Guan Stationery Sdn Bhd', amount: '1,250.00', currency: 'MYR',
      status: 'pending-verification', date: '2026-08-29' },
    { ref: 'EV-2026-100260', type: 'staff', payee: 'Nurul Izzah binti Hashim', amount: '640.00', currency: 'MYR',
      status: 'pending-approval', date: '2026-09-01', lawyerInCharge: 'Low Huan Qi' }
  ];

  var requestsPendingBody = document.getElementById('requestsPendingBody');
  var requestsPendingEmpty = document.getElementById('requestsPendingEmpty');
  var requestsCompletedBody = document.getElementById('requestsCompletedBody');
  var requestsCompletedEmpty = document.getElementById('requestsCompletedEmpty');
  var requestDetailsModal = document.getElementById('requestDetailsModal');
  var requestDetailsBody = document.getElementById('requestDetailsBody');
  var closeRequestDetailsBtn = document.getElementById('closeRequestDetailsBtn');
  var resubmitRequestBtn = document.getElementById('resubmitRequestBtn');
  var currentDetailsIdx = -1;

  function requestRowHtml(reqItem, idx){
    var meta = STATUS_META[reqItem.status];
    return '<tr>' +
      '<td>' + escapeHtml(reqItem.ref) + '</td>' +
      '<td>' + escapeHtml(TYPE_LABELS[reqItem.type] || reqItem.type) + '</td>' +
      '<td>' + escapeHtml(reqItem.payee) + '</td>' +
      '<td>' + escapeHtml(reqItem.currency) + ' ' + escapeHtml(reqItem.amount) + '</td>' +
      '<td>' + escapeHtml(reqItem.date) + '</td>' +
      '<td><span class="status-badge ' + meta.cls + '"><i class="fa-solid ' + meta.icon + '"></i> ' + meta.label + '</span></td>' +
      '<td><button type="button" class="btn btn-outline btn-sm view-details-btn" data-idx="' + idx + '"><i class="fa-solid fa-eye"></i> View</button></td>' +
      '</tr>';
  }

  function renderRequestsList(){
    var pendingHtml = '', completedHtml = '';
    SUBMITTED_REQUESTS.forEach(function(reqItem, idx){
      if (reqItem.status === 'pending-verification' || reqItem.status === 'pending-approval'){
        pendingHtml += requestRowHtml(reqItem, idx);
      } else {
        completedHtml += requestRowHtml(reqItem, idx);
      }
    });
    requestsPendingBody.innerHTML = pendingHtml;
    requestsPendingEmpty.hidden = pendingHtml !== '';
    requestsCompletedBody.innerHTML = completedHtml;
    requestsCompletedEmpty.hidden = completedHtml !== '';
  }

  function loadRequestsFromSharePoint(){
    if (typeof window.spFetchRequests !== 'function') return;
    return window.spFetchRequests().then(function(items){
      SUBMITTED_REQUESTS = items;
      renderRequestsList();
    }).catch(function(err){
      console.warn('Could not load requests from SharePoint - showing previous/demo data instead.', err);
    });
  }

  window.eVoucherSignInHandlers.push(function(){ loadRequestsFromSharePoint(); });

  function openRequestDetails(idx){
    var reqItem = SUBMITTED_REQUESTS[idx];
    if (!reqItem) return;
    currentDetailsIdx = idx;
    var meta = STATUS_META[reqItem.status];
    var rows = [
      ['Reference No.', reqItem.ref],
      ['Status', meta.label],
      ['Request Type', TYPE_LABELS[reqItem.type] || reqItem.type],
      ['Payee', reqItem.payee],
      ['Amount', reqItem.currency + ' ' + reqItem.amount],
      ['Date Submitted', reqItem.date]
    ];
    if (reqItem.bankName) rows.push(['Bank Name', reqItem.bankName]);
    if (reqItem.bankAccountNumber) rows.push(['Bank Account Number', reqItem.bankAccountNumber]);
    if (reqItem.lawyerInCharge) rows.push(['Lawyer-In-Charge / HOD', reqItem.lawyerInCharge]);
    if (reqItem.partnerInCharge) rows.push(['Partner in Charge', reqItem.partnerInCharge]);
    if (reqItem.note) rows.push(['Note', reqItem.note]);

    requestDetailsBody.innerHTML = rows.map(function(r){
      return '<div class="matrix-row"><span class="label">' + escapeHtml(r[0]) + '</span><span class="value">' + escapeHtml(r[1]) + '</span></div>';
    }).join('');
    resubmitRequestBtn.hidden = !(reqItem.status === 'rejected' && reqItem.formData);
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

  closeRequestDetailsBtn.addEventListener('click', function(){ requestDetailsModal.hidden = true; });

  function applyFormData(data){
    if (!data) return;
    nominalType.value = data.nominalType || '';
    nominalType.dispatchEvent(new Event('change'));
    staffSubtype.value = data.staffSubtype || 'matter';
    staffSubtype.dispatchEvent(new Event('change'));
    matterNumber.value = data.matterNumber || '';
    clientName.value = data.clientName || '';
    matterDescription.value = data.matterDescription || '';
    document.getElementById('payee').value = data.payee || '';
    document.getElementById('modeOfPayment').value = data.modeOfPayment || '';
    currencySelect.value = data.currency || 'MYR';
    currencySelect.dispatchEvent(new Event('change'));
    activeBankNameField().value = data.bankName || '';
    document.getElementById('bankAccountNumber').value = data.bankAccountNumber || '';
    document.getElementById('lawyerInCharge').value = data.lawyerInCharge || '';
    document.getElementById('partnerInCharge').value = data.partnerInCharge || '';
    if (window.clearCcPicker) window.clearCcPicker(); // CC isn't stored in SharePoint yet, so it can't be restored on resubmit

    lineItemsBody.innerHTML = '';
    var items = (data.lineItems && data.lineItems.length) ? data.lineItems.slice(0, MAX_LINE_ITEMS) : [{}];
    items.forEach(function(r){ createRow(r); });
    updateLineItemLimitUI();
    recalc();
  }

  resubmitRequestBtn.addEventListener('click', function(){
    var reqItem = SUBMITTED_REQUESTS[currentDetailsIdx];
    if (!reqItem || !reqItem.formData) return;
    applyFormData(reqItem.formData);
    requestDetailsModal.hidden = true;
    document.querySelector('.nav-item[data-view="submit"]').click();
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });

  // ---------- Sidebar navigation / view switching ----------
  var navItems = Array.prototype.slice.call(document.querySelectorAll('.nav-item'));
  var views = {
    submit: document.getElementById('view-submit'),
    requests: document.getElementById('view-requests')
  };
  var topbarTitle = document.getElementById('topbarTitle');
  var topbarSubtitle = document.getElementById('topbarSubtitle');
  var VIEW_META = {
    submit: { title: 'Submit Payment Request', subtitle: 'Payment nominal request and approval routing' },
    requests: { title: 'View Requests', subtitle: 'Browse previously submitted e-voucher requests' }
  };

  navItems.forEach(function(btn){
    btn.addEventListener('click', function(){
      var key = btn.getAttribute('data-view');
      navItems.forEach(function(b){ b.classList.toggle('active', b === btn); });
      Object.keys(views).forEach(function(k){ views[k].hidden = k !== key; });
      var meta = VIEW_META[key];
      topbarTitle.textContent = meta.title;
      topbarSubtitle.textContent = meta.subtitle;
      if (key === 'requests') loadRequestsFromSharePoint();
    });
  });

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
  // People.Read is needed for the Lawyer/Partner org people-picker (Graph /me/people).
  var LOGIN_SCOPES = ['User.Read', 'Sites.ReadWrite.All', 'People.Read'];

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
     Site:  https://stwdkl.sharepoint.com/sites/PowerPlatform
     List:  "EVoucher System"

     KNOWN GAPS - confirmed with the team, not yet resolved:
     - BankNo: the list has no separate BankName column, so bank name
       is NOT written anywhere yet (only the account number could map
       to BankNo). Intentionally left out of the payload until the
       column is decided/added.
     - LawyerStatus / PartnerStatus: exact Choice values not yet given.
       Left out of the create payload (so the column's own default, if
       any, applies); read back using flexible keyword matching
       (contains "reject"/"approv"/else pending) so it works regardless
       of the exact strings.
     - RequestType: confirmed a Choice column. Options are fetched live
       from the list itself at sign-in (see loadDynamicChoices below),
       so the dropdown always matches whatever choices actually exist -
       no hardcoded guesses.
     - Attachments: confirmed native SharePoint attachments. Graph API
       v1.0 does not reliably support list-item attachments, so this
       uses the classic SharePoint REST endpoint instead, which needs
       its OWN resource permission (see uploadAttachmentsForItem) -
       separate from the Graph permissions already granted.
     - Matter number -> client name/description autofill still uses the
       local MATTER_DB mock, per your note that the real lookup list is
       a separate piece to be wired up later.
     ================================================================ -->
<script>
(function(){
  'use strict';

  var SP_HOSTNAME = 'stwdkl.sharepoint.com';
  var SP_SITE_PATH = '/sites/PowerPlatform';
  var SP_LIST_NAME = 'EVoucher System';
  var GRAPH_BASE = 'https://graph.microsoft.com/v1.0';

  var spSiteId = null;
  var spListId = null;

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

  function getSpListId(){
    if (spListId) return Promise.resolve(spListId);
    return getSpSiteId().then(function(siteId){
      return graphRequest('/sites/' + siteId + '/lists?$filter=' + encodeURIComponent("displayName eq '" + SP_LIST_NAME + "'"));
    }).then(function(result){
      if (!result.value || !result.value.length) throw new Error('SharePoint list "' + SP_LIST_NAME + '" not found at ' + SP_SITE_PATH);
      spListId = result.value[0].id;
      return spListId;
    });
  }

  // ---------- Status / type text helpers (work off live/free text, no hardcoded exact values needed) ----------
  function classifyApprovalStatus(text){
    var lc = (text || '').toLowerCase();
    if (lc.indexOf('reject') !== -1 || lc.indexOf('declin') !== -1) return 'rejected';
    if (lc.indexOf('approv') !== -1) return 'approved';
    return 'pending';
  }

  function deriveOverallStatus(lawyerStatus, partnerStatus){
    var l = classifyApprovalStatus(lawyerStatus);
    var p = classifyApprovalStatus(partnerStatus);
    if (l === 'rejected' || p === 'rejected') return 'rejected';
    if (l === 'approved' && p === 'approved') return 'approved';
    if (l === 'approved') return 'pending-approval';
    return 'pending-verification';
  }

  function inferTypeFromText(text){
    var lc = (text || '').toLowerCase();
    var hasStaff = lc.indexOf('staff') !== -1;
    var hasOffice = lc.indexOf('office') !== -1;
    if (hasStaff) return { nominalType: 'staff', staffSubtype: hasOffice ? 'office' : 'matter' };
    if (hasOffice) return { nominalType: 'office', staffSubtype: 'matter' };
    return { nominalType: 'matter', staffSubtype: 'matter' };
  }

  function personDisplay(val){
    if (!val) return '';
    if (typeof val === 'string') return val;
    return val.LookupValue || val.displayName || val.Title || '';
  }

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
      var hasStaff = lc.indexOf('staff') !== -1;
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
      return (data.staffSubtype === 'office' ? TYPE_SP_TEXT['staff-office'] : TYPE_SP_TEXT['staff-matter']) || 'Staff Claims';
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
    getSpListId().then(function(listId){
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
        }
      });
    }).catch(function(err){
      console.warn('Could not load SharePoint choice columns - keeping built-in defaults.', err);
    });
  }

  // ---------- Organization people-picker (Lawyer-In-Charge / HOD, Partner in charge, CC) ----------
  // No query -> Graph's own relevance-ranked default list (so clicking the field alone already
  // shows a dropdown of people, per the "click to choose OR type to search" requirement).
  function searchPeople(query){
    var url = GRAPH_BASE + '/me/people?$top=10&$select=displayName,scoredEmailAddresses,userPrincipalName';
    if (query) url += '&$search=' + encodeURIComponent('"' + query + '"');
    return window.getGraphToken(['People.Read']).then(function(token){
      return fetch(url, { headers: { 'Authorization': 'Bearer ' + token.accessToken } });
    }).then(function(res){
      if (!res.ok) throw new Error('People search failed: ' + res.status);
      return res.json();
    }).then(function(result){ return result.value || []; });
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

  // config: { inputId, suggestionsId, hiddenEmailId } for single-select,
  // or { inputId, suggestionsId, multi:true, chipsId } for multi-select (returns { getSelected }).
  function setupPeoplePicker(config){
    var input = document.getElementById(config.inputId);
    var box = document.getElementById(config.suggestionsId);
    var hiddenEmail = config.hiddenEmailId ? document.getElementById(config.hiddenEmailId) : null;
    var chipsBox = config.multi ? document.getElementById(config.chipsId) : null;
    var debounceTimer = null;
    var currentResults = [];
    var selected = config.multi ? [] : null;

    function hideBox(){ box.hidden = true; box.innerHTML = ''; }
    openPeoplePickers.push(hideBox);

    function renderResults(people){
      people = dedupePeople(people);
      if (config.multi){
        var selectedEmails = selected.map(personEmail);
        people = people.filter(function(p){ return selectedEmails.indexOf(personEmail(p)) === -1; });
      }
      currentResults = people;
      if (!people.length){
        box.innerHTML = '<div class="p-status">No matches found</div>';
        box.hidden = false;
        return;
      }
      box.innerHTML = people.map(function(p, i){
        return '<div class="people-suggestion" data-idx="' + i + '">' +
          '<span class="p-name">' + escapeHtmlLocal(p.displayName || '') + '</span></div>';
      }).join('');
      box.hidden = false;
    }

    function runSearch(query){
      searchPeople(query).then(renderResults).catch(function(){
        box.innerHTML = '<div class="p-status">Search unavailable right now - you can still type a name manually.</div>';
        box.hidden = false;
      });
    }

    function renderChips(){
      if (!config.multi) return;
      chipsBox.innerHTML = selected.map(function(p, i){
        return '<span class="people-chip">' + escapeHtmlLocal(p.displayName || personEmail(p)) +
          '<button type="button" data-idx="' + i + '" title="Remove">&times;</button></span>';
      }).join('');
    }

    function selectPerson(p){
      if (config.multi){
        selected.push(p);
        renderChips();
        input.value = '';
      } else {
        input.value = p.displayName || '';
        if (hiddenEmail) hiddenEmail.value = personEmail(p);
      }
      hideBox();
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
      if (config.multi) input.focus();
    }

    input.addEventListener('focus', function(){
      openPeoplePickers.forEach(function(hide){ if (hide !== hideBox) hide(); });
      runSearch(input.value.trim());
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

    if (config.multi){
      chipsBox.addEventListener('click', function(e){
        var btn = e.target.closest('button');
        if (!btn) return;
        selected.splice(parseInt(btn.getAttribute('data-idx'), 10), 1);
        renderChips();
      });
    }

    input.addEventListener('blur', function(){ setTimeout(hideBox, 150); });

    if (config.multi){
      return {
        getSelected: function(){ return selected.slice(); },
        clear: function(){ selected = []; renderChips(); }
      };
    }
  }

  // ---------- Create (Submit Payment Request) ----------
  function getSpRestToken(){
    // Native SharePoint attachments aren't reliably supported via Graph v1.0, so this uses the
    // classic SharePoint REST API instead - which needs its own resource permission (e.g. "AllSites.Write"
    // under the SharePoint API, separate from the Graph permissions already granted) plus admin consent.
    return window.getGraphToken(['https://' + SP_HOSTNAME + '/AllSites.Write']);
  }

  function uploadAttachmentsForItem(itemId, filesToUpload){
    if (!filesToUpload || !filesToUpload.length) return Promise.resolve();
    return getSpRestToken().then(function(token){
      var restBase = 'https://' + SP_HOSTNAME + SP_SITE_PATH + "/_api/web/lists/getbytitle('" +
        encodeURIComponent(SP_LIST_NAME) + "')/items(" + itemId + ')/AttachmentFiles/add(FileName=\'';
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

  window.spSubmitRequest = function(data, attachmentFiles){
    var fields = {
      RequestType: requestTypeForSharePoint(data),
      MatterNo: data.matterNumber || '',
      ClientName: data.clientName || '',
      MatterDescription: data.matterDescription || '',
      Payee: data.payee || '',
      ModeOfPayment: data.modeOfPayment || '',
      TotalAmount: parseFloat(String(data.totalAmount).replace(/,/g, '')) || 0,
      Currency: data.currency || '',
      LawyerInCharge: data.lawyerInCharge || '',
      PartnerInCharge: data.partnerInCharge || ''
    };
    (data.lineItems || []).slice(0, 5).forEach(function(item, i){
      var n = i + 1;
      fields['PaymentDesc' + n] = item.description || '';
      fields['InvoiceNo' + n] = item.invoice || '';
      fields['Amount' + n] = item.amount || 0;
    });

    var createdItem;
    return getSpListId().then(function(listId){
      return getSpSiteId().then(function(siteId){
        return graphRequest('/sites/' + siteId + '/lists/' + listId + '/items', {
          method: 'POST',
          body: JSON.stringify({ fields: fields })
        });
      });
    }).then(function(created){
      createdItem = created;
      return uploadAttachmentsForItem(created.id, attachmentFiles).catch(function(err){
        console.warn('Item was created, but one or more attachments failed to upload.', err);
      });
    }).then(function(){
      return createdItem;
    });
  };

  // ---------- Read (View Requests) ----------
  window.spFetchRequests = function(){
    return getSpListId().then(function(listId){
      return getSpSiteId().then(function(siteId){
        return graphRequest('/sites/' + siteId + '/lists/' + listId + '/items?$expand=fields&$top=200&$orderby=fields/Created desc');
      });
    }).then(function(result){
      var rows = (result && result.value) || [];
      return rows.map(function(row){
        var f = row.fields || {};
        var typeInfo = inferTypeFromText(f.RequestType);
        var lineItems = [];
        for (var i = 1; i <= 5; i++){
          var desc = f['PaymentDesc' + i];
          var amt = f['Amount' + i];
          if (desc || amt) lineItems.push({ description: desc || '', invoice: f['InvoiceNo' + i] || '', amount: parseFloat(amt) || 0 });
        }
        var status = deriveOverallStatus(f.LawyerStatus, f.PartnerStatus);
        var noteParts = [];
        if (f.LawyerRemarks) noteParts.push('Lawyer: ' + f.LawyerRemarks);
        if (f.PartnerRemarks) noteParts.push('Partner: ' + f.PartnerRemarks);
        var lawyerName = personDisplay(f.LawyerInCharge);
        var partnerName = personDisplay(f.PartnerInCharge);
        return {
          ref: 'EV-' + row.id,
          type: typeInfo.nominalType,
          payee: f.Payee || '',
          amount: (parseFloat(f.TotalAmount) || 0).toLocaleString('en-MY', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
          currency: f.Currency || '',
          status: status,
          date: (row.createdDateTime || '').slice(0, 10),
          lawyerInCharge: lawyerName,
          partnerInCharge: partnerName,
          note: noteParts.join(' | ') || undefined,
          formData: {
            nominalType: typeInfo.nominalType,
            staffSubtype: typeInfo.staffSubtype,
            matterNumber: f.MatterNo || '',
            clientName: f.ClientName || '',
            matterDescription: f.MatterDescription || '',
            payee: f.Payee || '',
            modeOfPayment: f.ModeOfPayment || '',
            bankName: '',
            bankAccountNumber: '',
            lawyerInCharge: lawyerName,
            partnerInCharge: partnerName,
            ccEmails: '',
            currency: f.Currency || '',
            lineItems: lineItems
          }
        };
      });
    });
  };

  window.eVoucherSignInHandlers.push(function(){
    loadDynamicChoices();
    setupPeoplePicker({ inputId: 'lawyerInCharge', hiddenEmailId: 'lawyerInChargeEmail', suggestionsId: 'lawyerInChargeSuggestions' });
    setupPeoplePicker({ inputId: 'partnerInCharge', hiddenEmailId: 'partnerInChargeEmail', suggestionsId: 'partnerInChargeSuggestions' });
    var ccPicker = setupPeoplePicker({ inputId: 'ccInput', suggestionsId: 'ccSuggestions', multi: true, chipsId: 'ccChips' });
    window.getCcSelected = function(){ return ccPicker.getSelected().map(personEmail).filter(Boolean); };
    window.clearCcPicker = ccPicker.clear;
  });
})();
</script>

</body>
</html>
