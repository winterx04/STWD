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
  window.__EVOUCHER_VERSION__ = '2026.09.13.11';
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
  .view-wrap{max-width:1180px;margin:0 auto;}

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
    transition:transform .15s;
  }
  .people-picker.open .people-picker-caret{transform:rotate(180deg);}
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
  .stat-card{
    background:var(--white);border:1px solid var(--border);border-radius:var(--radius);
    box-shadow:var(--shadow);padding:18px 20px;display:flex;align-items:center;gap:14px;
  }
  .stat-card .stat-icon{
    width:46px;height:46px;border-radius:12px;flex-shrink:0;
    display:flex;align-items:center;justify-content:center;font-size:18px;
  }
  .stat-card.pending .stat-icon{background:var(--primary-light);color:var(--primary-dark);}
  .stat-card.approved .stat-icon{background:#e3f5ea;color:var(--success);}
  .stat-card.rejected .stat-icon{background:var(--danger-bg);color:var(--danger);}
  .stat-card .stat-num{font-size:24px;font-weight:800;color:var(--navy);line-height:1.1;}
  .stat-card .stat-text{font-size:12.5px;color:var(--text-muted);margin-top:3px;font-weight:600;}

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
  .type-pill{display:inline-block;padding:4px 10px;border-radius:20px;font-size:11.5px;font-weight:700;white-space:nowrap;}
  .type-pill.matter{background:#e7effb;color:#1c5d99;}
  .type-pill.office{background:#f1ecfb;color:#6a3fb5;}
  .type-pill.staff{background:#fff4e0;color:#a3690a;}

  .btn-view-row{border-radius:20px;}
  .btn-view-row:hover{background:var(--navy);color:var(--white);}

  .empty-state{
    text-align:center;padding:40px 20px;color:var(--text-muted);font-size:13.5px;
  }
  .empty-state i{display:block;font-size:26px;color:var(--border);margin-bottom:10px;}

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

  .modal-card-details{max-width:540px;text-align:left;}
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
  .rd-note{
    display:flex;gap:10px;align-items:flex-start;
    background:var(--primary-light);color:var(--primary-dark);
    border-radius:10px;padding:12px 14px;font-size:13.5px;font-weight:600;margin-bottom:14px;
  }
  .rd-note i{margin-top:2px;}
  .rd-actions{margin-top:8px;display:flex;gap:10px;justify-content:flex-end;}
  @media (max-width:480px){.rd-actions{justify-content:stretch;}.rd-actions .btn{flex:1;}}

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
                  <input type="text" id="matterNumber" placeholder="Enter matter number">
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
        <div class="alert alert-error" id="requestsLoadError" hidden>
          <i class="fa-solid fa-triangle-exclamation"></i>
          <span id="requestsLoadErrorText"></span>
        </div>
        <div class="stats-row">
          <div class="stat-card pending">
            <div class="stat-icon"><i class="fa-solid fa-hourglass-half"></i></div>
            <div>
              <div class="stat-num" id="statPendingCount">0</div>
              <div class="stat-text">Pending</div>
            </div>
          </div>
          <div class="stat-card approved">
            <div class="stat-icon"><i class="fa-solid fa-circle-check"></i></div>
            <div>
              <div class="stat-num" id="statApprovedCount">0</div>
              <div class="stat-text">Approved</div>
            </div>
          </div>
          <div class="stat-card rejected">
            <div class="stat-icon"><i class="fa-solid fa-circle-xmark"></i></div>
            <div>
              <div class="stat-num" id="statRejectedCount">0</div>
              <div class="stat-text">Rejected</div>
            </div>
          </div>
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
        </div>
      </div>
    </section>

  </div>
</div>

<div class="modal" id="requestDetailsModal" hidden>
  <div class="modal-card modal-card-details">
    <h2>Request Details</h2>
    <div id="requestDetailsBody" class="matrix-info"></div>
    <div class="rd-actions">
      <button type="button" class="btn btn-outline" id="closeRequestDetailsBtn">Close</button>
      <button type="button" class="btn btn-primary" id="resubmitRequestBtn" hidden><i class="fa-solid fa-pen-to-square"></i> Edit &amp; Resubmit</button>
    </div>
  </div>
</div>

<div class="modal" id="successModal" hidden>
  <div class="modal-card">
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

  var matterLookupTimer = null;
  var matterLookupSeq = 0;

  function runMatterLookup(){
    var key = matterNumber.value.trim();
    if (!key || typeof window.lookupActiveMatter !== 'function') return;
    var seq = ++matterLookupSeq;
    window.lookupActiveMatter(key).then(function(match){
      if (seq !== matterLookupSeq) return; // superseded by a newer lookup, ignore stale result
      if (!match) return;
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
    // LawyerInCharge/PartnerInCharge are SharePoint Person columns, so free-typed text that
    // doesn't match a real directory entry (no email resolved) can't actually be saved there.
    (function(){
      var lawyerEl = document.getElementById('lawyerInCharge');
      if (lawyerEl.value.trim() && !document.getElementById('lawyerInChargeEmail').value){
        lawyerEl.classList.add('invalid');
        errors.push('Please pick the Lawyer-In-Charge / HOD from the suggestions list.');
      }
      var partnerEl = document.getElementById('partnerInCharge');
      if (partnerEl.value.trim() && !document.getElementById('partnerInChargeEmail').value){
        partnerEl.classList.add('invalid');
        errors.push('Please pick the Partner in charge from the suggestions list.');
      }
    })();

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
      lawyerInChargeEmail: document.getElementById('lawyerInChargeEmail').value,
      partnerInCharge: document.getElementById('partnerInCharge').value,
      partnerInChargeEmail: document.getElementById('partnerInChargeEmail').value,
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
      refNumber.textContent = created.id;
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

  // Populated from the real "EVoucher System" SharePoint list by loadRequestsFromSharePoint()
  // below - no hardcoded/demo requests here.
  var SUBMITTED_REQUESTS = [];

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
      '<td data-label="ID"><span class="ref-chip">' + escapeHtml(reqItem.ref) + '</span></td>' +
      '<td data-label="Type"><span class="type-pill ' + escapeHtml(reqItem.type) + '">' + escapeHtml(TYPE_LABELS[reqItem.type] || reqItem.type) + '</span></td>' +
      '<td data-label="Payee">' + escapeHtml(reqItem.payee) + '</td>' +
      '<td data-label="Amount">' + escapeHtml(reqItem.currency) + ' ' + escapeHtml(reqItem.amount) + '</td>' +
      '<td data-label="Date">' + escapeHtml(reqItem.date) + '</td>' +
      '<td data-label="Status"><span class="status-badge ' + meta.cls + '"><i class="fa-solid ' + meta.icon + '"></i> ' + meta.label + '</span></td>' +
      '<td><button type="button" class="btn btn-outline btn-sm btn-view-row view-details-btn" data-idx="' + idx + '"><i class="fa-solid fa-eye"></i> View</button></td>' +
      '</tr>';
  }

  var statPendingCount = document.getElementById('statPendingCount');
  var statApprovedCount = document.getElementById('statApprovedCount');
  var statRejectedCount = document.getElementById('statRejectedCount');
  var pendingCountBadge = document.getElementById('pendingCountBadge');
  var completedCountBadge = document.getElementById('completedCountBadge');

  function renderRequestsList(){
    var pendingHtml = '', completedHtml = '';
    var pendingCount = 0, approvedCount = 0, rejectedCount = 0;
    SUBMITTED_REQUESTS.forEach(function(reqItem, idx){
      if (reqItem.status === 'pending-verification' || reqItem.status === 'pending-approval'){
        pendingHtml += requestRowHtml(reqItem, idx);
        pendingCount++;
      } else {
        completedHtml += requestRowHtml(reqItem, idx);
        if (reqItem.status === 'approved') approvedCount++;
        else if (reqItem.status === 'rejected') rejectedCount++;
      }
    });
    requestsPendingBody.innerHTML = pendingHtml;
    requestsPendingEmpty.hidden = pendingHtml !== '';
    requestsCompletedBody.innerHTML = completedHtml;
    requestsCompletedEmpty.hidden = completedHtml !== '';
    statPendingCount.textContent = pendingCount;
    statApprovedCount.textContent = approvedCount;
    statRejectedCount.textContent = rejectedCount;
    pendingCountBadge.textContent = pendingCount;
    completedCountBadge.textContent = approvedCount + rejectedCount;
  }

  var requestsLoadError = document.getElementById('requestsLoadError');
  var requestsLoadErrorText = document.getElementById('requestsLoadErrorText');

  function loadRequestsFromSharePoint(){
    if (typeof window.spFetchRequests !== 'function') return;
    return window.spFetchRequests().then(function(items){
      requestsLoadError.hidden = true;
      SUBMITTED_REQUESTS = items;
      renderRequestsList();
    }).catch(function(err){
      console.warn('Could not load requests from SharePoint.', err);
      requestsLoadErrorText.textContent = 'Could not load requests from SharePoint: ' + err.message;
      requestsLoadError.hidden = false;
    });
  }

  window.eVoucherSignInHandlers.push(function(){ loadRequestsFromSharePoint(); });

  function openRequestDetails(idx){
    var reqItem = SUBMITTED_REQUESTS[idx];
    if (!reqItem) return;
    currentDetailsIdx = idx;
    var meta = STATUS_META[reqItem.status];

    function rowsHtml(rows){
      return rows.map(function(r){
        return '<div class="matrix-row"><span class="label">' + escapeHtml(r[0]) + '</span><span class="value">' + escapeHtml(r[1]) + '</span></div>';
      }).join('');
    }

    var overviewRows = [
      ['Request Type', TYPE_LABELS[reqItem.type] || reqItem.type],
      ['Payee', reqItem.payee],
      ['Amount', reqItem.currency + ' ' + reqItem.amount],
      ['Date Submitted', reqItem.date]
    ];
    var paymentRows = [];
    if (reqItem.bankName) paymentRows.push(['Bank Name', reqItem.bankName]);
    if (reqItem.bankAccountNumber) paymentRows.push(['Bank Account Number', reqItem.bankAccountNumber]);
    var approvalRows = [];
    if (reqItem.lawyerInCharge) approvalRows.push(['Lawyer-In-Charge / HOD', reqItem.lawyerInCharge]);
    if (reqItem.partnerInCharge) approvalRows.push(['Partner in Charge', reqItem.partnerInCharge]);

    var html = '<div class="rd-hero">' +
        '<span class="ref-chip">ID ' + escapeHtml(reqItem.ref) + '</span>' +
        '<span class="status-badge ' + meta.cls + '"><i class="fa-solid ' + meta.icon + '"></i> ' + meta.label + '</span>' +
      '</div>';
    html += '<div class="rd-section"><div class="rd-section-title">Overview</div>' + rowsHtml(overviewRows) + '</div>';
    if (paymentRows.length) html += '<div class="rd-section"><div class="rd-section-title">Payment</div>' + rowsHtml(paymentRows) + '</div>';
    if (approvalRows.length) html += '<div class="rd-section"><div class="rd-section-title">Approval</div>' + rowsHtml(approvalRows) + '</div>';
    if (reqItem.note) html += '<div class="rd-note"><i class="fa-solid fa-circle-info"></i> ' + escapeHtml(reqItem.note) + '</div>';

    requestDetailsBody.innerHTML = html;
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
    document.getElementById('lawyerInChargeEmail').value = data.lawyerInChargeEmail || '';
    document.getElementById('partnerInCharge').value = data.partnerInCharge || '';
    document.getElementById('partnerInChargeEmail').value = data.partnerInChargeEmail || '';
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
     List:  "E-Voucher System"

     Full column dump pulled 2026-09-13 (56 columns incl. built-ins) - see chat history.
     Confirmed relevant ones: MatterNo (Number), ClientName/MatterDescription/Payee/BankNo
     (Text), ModeOfPayment/Currency/RequestType (Choice), PaymentDesc/InvoiceNo/Amount 1-5
     (Text/Number), TotalAmount (Number), LawyerInCharge/PartnerInCharge (Person/Group),
     LawyerStatus/PartnerStatus (Choice), LawyerRemarks/PartnerRemarks (Text).

     KNOWN GAPS / OPEN QUESTIONS - not yet resolved:
     - BankNo wired up (write + read) as the bank account number - confirmed a plain Text
       column. There is still no separate BankName column, so the bank name the user
       picks/types is NOT written anywhere.
     - RequestType's live Choice values are "Matter, Office, Client" - confirmed "Client" is
       just this list's wording for what the app calls "Staff Claims" internally (same
       category, not a new one). inferTypeFromText/applyRequestTypeChoices/
       requestTypeForSharePoint all match on "client" as well as "staff" now.
     - ModeOfPayment's live 5th choice was literally "Choice 5" (an un-renamed placeholder
       in the SharePoint list) - to be renamed to "Telegraphic Transfer (TT)" in SharePoint
       directly (no frontend change needed once that's done).
     - Currency's live choices were missing "RMB" (present in the form's built-in fallback)
       - to be added to the SharePoint Choice column directly.
     - LawyerStatus choices: Approved/Rejected/TIMED OUT/Pending. PartnerStatus choices:
       Approved/Rejected/TIMED OUT/Not Applicable/Pending. classifyApprovalStatus treats
       "Not Applicable" as non-blocking (same as approved), since it means partner sign-off
       doesn't apply to that request. "TIMED OUT" still falls into the generic "pending"
       bucket - flag if that should instead read as rejected/needs-resubmission.
     - LawyerInCharge/PartnerInCharge are Person/Group columns. Graph's list-items API
       won't accept plain display-name text for those (that's why they weren't being
       captured) - fixed by resolving the picker's email through the classic REST
       /_api/web/ensureuser endpoint (see ensureSpUser) into the site's numeric user Id,
       then writing "<Field>LookupId". Requires the picker's hidden *Email field to
       actually hold an email (i.e. the user picked a real suggestion, not free-typed text)
       - the submit-time validation now enforces that.
     - CC: there is no CC column in this list at all (confirmed from the full column dump),
       so CC recipients still cannot be written anywhere - this needs a product decision on
       what column to add (e.g. a multi-value Person/Group field, or a plain text field of
       comma-separated emails) before it can be wired up.
     - MatterNo's SharePoint column is typed as Number, but matter numbers aren't guaranteed
       to be purely numeric - the frontend sends whatever was typed as-is rather than
       assuming/forcing a numeric format; SharePoint will reject it visibly if the column
       genuinely can't hold a given value, rather than this silently dropping it.
     - Attachments: confirmed native SharePoint attachments. Graph API v1.0 does not
       reliably support list-item attachments, so this uses the classic SharePoint REST
       endpoint instead, which needs its OWN resource permission (see
       uploadAttachmentsForItem) - separate from the Graph permissions already granted.
     - Matter number -> client name/description autofill: wired up to the real
       "Active Matters" list (see lookupActiveMatter below). FILEID is the matter number
       column; client name comes from the list's default "Title" column; short description
       is matched by flexible keyword. The OData filter sends the value unquoted only when
       it looks purely numeric, quoted otherwise, since FILEID's exact column type there
       isn't confirmed.
     ================================================================ -->
<script>
(function(){
  'use strict';

  var SP_HOSTNAME = 'stwdkl.sharepoint.com';
  var SP_SITE_PATH = '/sites/PowerPlatform';
  var SP_LIST_NAME = 'E-Voucher System';
  var SP_MATTERS_LIST_NAME = 'Active Matters';
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
    // "Not Applicable" (a real PartnerStatus choice, e.g. requests below a threshold that
    // don't need partner sign-off) should not block overall approval - treat as a non-issue,
    // same as an actual approval, for deriveOverallStatus's purposes.
    if (lc.indexOf('approv') !== -1 || lc.indexOf('not applicable') !== -1) return 'approved';
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
    // The live RequestType Choice column uses "Client" for what this app calls "Staff
    // Claims" internally (confirmed same category, just relabelled in SharePoint) - match
    // on either wording so this keeps working if it's ever renamed back.
    var hasStaff = lc.indexOf('staff') !== -1 || lc.indexOf('client') !== -1;
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

  function personFieldEmail(val){
    if (!val || typeof val === 'string') return '';
    return val.Email || val.email || '';
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
    var picker = input.closest('.people-picker');
    var hiddenEmail = config.hiddenEmailId ? document.getElementById(config.hiddenEmailId) : null;
    var chipsBox = config.multi ? document.getElementById(config.chipsId) : null;
    var debounceTimer = null;
    var currentResults = [];
    var selected = config.multi ? [] : null;

    function showBox(){ box.hidden = false; picker.classList.add('open'); }
    function hideBox(){ box.hidden = true; box.innerHTML = ''; picker.classList.remove('open'); }
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
      searchPeople(query).then(renderResults).catch(function(){
        box.innerHTML = '<div class="p-status">Search unavailable right now - you can still type a name manually.</div>';
        showBox();
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
    var fields = {
      RequestType: requestTypeForSharePoint(data),
      ClientName: data.clientName || '',
      MatterDescription: data.matterDescription || '',
      Payee: data.payee || '',
      ModeOfPayment: data.modeOfPayment || '',
      TotalAmount: parseFloat(String(data.totalAmount).replace(/,/g, '')) || 0,
      Currency: data.currency || '',
      BankNo: data.bankAccountNumber || ''
    };
    // MatterNo's SharePoint column is currently typed as Number, but matter numbers aren't
    // guaranteed to be purely numeric - send whatever was entered as-is (SharePoint will
    // reject it visibly if the column truly can't hold it, rather than this silently
    // dropping the value). Only omitted when genuinely blank (Office/Client requests).
    if (data.matterNumber) fields.MatterNo = data.matterNumber;
    (data.lineItems || []).slice(0, 5).forEach(function(item, i){
      var n = i + 1;
      fields['PaymentDesc' + n] = item.description || '';
      fields['InvoiceNo' + n] = item.invoice || '';
      fields['Amount' + n] = item.amount || 0;
    });

    var createdItem;
    return Promise.all([
      ensureSpUser(data.lawyerInChargeEmail).catch(function(err){ console.warn('Could not resolve Lawyer-In-Charge as a SharePoint user - it will be left blank.', err); return null; }),
      ensureSpUser(data.partnerInChargeEmail).catch(function(err){ console.warn('Could not resolve Partner In Charge as a SharePoint user - it will be left blank.', err); return null; })
    ]).then(function(ids){
      if (ids[0]) fields.LawyerInChargeLookupId = ids[0];
      if (ids[1]) fields.PartnerInChargeLookupId = ids[1];
      return getSpListId();
    }).then(function(listId){
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
        // No $orderby here - Graph rejects ordering by a list-item field ("fields/Created")
        // unless that column is indexed, which silently failed the whole request. Sort
        // newest-first on our side instead, using the item's own createdDateTime.
        return graphRequest('/sites/' + siteId + '/lists/' + listId + '/items?$expand=fields&$top=200');
      });
    }).then(function(result){
      var rows = (result && result.value) || [];
      rows.sort(function(a, b){ return (b.createdDateTime || '').localeCompare(a.createdDateTime || ''); });
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
        var lawyerEmail = personFieldEmail(f.LawyerInCharge);
        var partnerEmail = personFieldEmail(f.PartnerInCharge);
        return {
          ref: row.id,
          type: typeInfo.nominalType,
          payee: f.Payee || '',
          amount: (parseFloat(f.TotalAmount) || 0).toLocaleString('en-MY', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
          currency: f.Currency || '',
          status: status,
          date: (row.createdDateTime || '').slice(0, 10),
          lawyerInCharge: lawyerName,
          partnerInCharge: partnerName,
          bankAccountNumber: f.BankNo || '',
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
            bankAccountNumber: f.BankNo || '',
            lawyerInCharge: lawyerName,
            lawyerInChargeEmail: lawyerEmail,
            partnerInCharge: partnerName,
            partnerInChargeEmail: partnerEmail,
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
