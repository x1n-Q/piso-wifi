(() => {
  const config = window.AZ_TIRES_FIREBASE || {};
  const $ = selector => document.querySelector(selector);
  let idToken = "", ownerEmail = "", ownerPassword = "", refreshing = false, authRefreshTimer = 0;

  const validConfig = () => config.apiKey && config.databaseUrl && config.deviceUid && ![config.apiKey,config.databaseUrl,config.deviceUid].some(value => String(value).includes("REPLACE_WITH"));
  const safe = value => String(value ?? "").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;"}[c]));
  const money = value => `₱${Number(value || 0).toLocaleString()}`;
  const when = value => Number(value) > 0 ? new Date(Number(value)).toLocaleString() : "—";
  const duration = value => { let n=Math.max(0,Number(value||0)),d=Math.floor(n/86400);n%=86400;const h=Math.floor(n/3600),m=Math.floor(n%3600/60);return d?`${d}d ${h}h`:`${h}h ${m}m`; };
  const setText = (selector,value) => { $(selector).textContent=value; };

  const signIn = async () => {
    const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(config.apiKey)}`,{
      method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({email:ownerEmail,password:ownerPassword,returnSecureToken:true})
    });
    const data = await response.json();
    if (!response.ok || !data.idToken) throw new Error(data.error?.message || "Firebase sign-in failed");
    idToken=data.idToken;
    clearTimeout(authRefreshTimer);
    authRefreshTimer=setTimeout(()=>signIn().catch(()=>{}),50*60*1000);
  };

  const db = async (method,path,body,retryAuth=true) => {
    const response = await fetch(`${String(config.databaseUrl).replace(/\/$/,"")}/${path}.json?auth=${encodeURIComponent(idToken)}`,{
      method,headers:{"Content-Type":"application/json"},body:body===undefined?undefined:JSON.stringify(body),cache:"no-store"
    });
    const data = await response.json();
    if (response.status===401 && retryAuth && ownerEmail && ownerPassword) {
      await signIn();
      return db(method,path,body,false);
    }
    if (!response.ok) throw new Error(data?.error || `Firebase ${method} failed`);
    return data;
  };

  const fillSettings = values => {
    if (!values) return;
    Object.entries(values).forEach(([key,value])=>{const input=$(`[name="${key}"]`);if(input&&document.activeElement!==input)input.value=value;});
  };

  const render = device => {
    const data=device?.telemetry||{},earnings=data.earnings||{},now=Date.now(),updated=Number(data.cloud_updated_at||0),online=updated>0&&now-updated<180000;
    setText("#siteName",data.site_name||"AZ Tires Piso WiFi");setText("#today",money(earnings.today));setText("#total",money(earnings.total));
    setText("#connected",data.connected||0);setText("#authenticated",data.authenticated||0);setText("#alertCount",data.alert_count||0);setText("#lastSync",when(updated));
    const cloud=$("#cloudState");cloud.textContent=online?"● Q20 ONLINE":"○ Q20 OFFLINE";cloud.className=`status ${online?"online":"offline"}`;
    setText("#controller",data.controller_online?"● Coin controller online":"○ Coin controller offline");
    const applied=device?.applied;setText("#applyState",applied?`${applied.status}: ${applied.message}`:"No remote change");
    fillSettings(data.remote_config);

    const sessions=data.sessions||[];$("#sessions").innerHTML=sessions.map(s=>`<tr><td><span class="tag ${safe(s.status)}">${safe(s.status)}</span></td><td>${safe(s.mac||s.ip||"Unknown")}</td><td>${safe(s.source||"coin")}${s.voucher?`<br><small>${safe(s.voucher)}</small>`:""}</td><td>${duration(s.remaining)}</td><td>${money(s.paid)}</td></tr>`).join("");$("#emptySessions").hidden=sessions.length>0;
    const vouchers=data.vouchers||[];$("#vouchers").innerHTML=vouchers.map(v=>`<tr><td><strong>${safe(v.code)}</strong></td><td>${v.plan===60?"2 months":"1 month"} · ${money(v.price)}</td><td><span class="tag ${safe(v.status)}">${safe(v.status)}</span></td><td>${safe(v.mac||"Not used")}</td><td>${v.expires?new Date(v.expires*1000).toLocaleString():"—"}</td></tr>`).join("");$("#emptyVouchers").hidden=vouchers.length>0;
    const alerts=data.alerts||[];$("#alerts").innerHTML=alerts.slice().reverse().map(a=>`<article><time>${a.at?new Date(a.at*1000).toLocaleString():"—"}</time><div><strong>${safe(a.type)}</strong><span>Device ${safe(a.mac||"unknown")} · IP ${safe(a.ip||"unknown")} · ${safe(a.detail)}</span></div></article>`).join("");$("#emptyAlerts").hidden=alerts.length>0;
  };

  const refresh = async () => {
    if(refreshing)return;refreshing=true;
    try{render(await db("GET",`devices/${config.deviceUid}`));}catch(error){const cloud=$("#cloudState");cloud.textContent=error.message;cloud.className="status offline";}finally{refreshing=false;}
  };

  $("#loginForm").addEventListener("submit",async event=>{
    event.preventDefault();setText("#loginError","");
    if(!validConfig()){setText("#loginError","Firebase config.js is not configured yet.");return;}
    ownerEmail=$("#email").value.trim();ownerPassword=$("#password").value;
    try{await signIn();$("#loginView").hidden=true;$("#dashboardView").hidden=false;await refresh();setInterval(refresh,30000);}catch(error){setText("#loginError",error.message);}
  });

  $("#settingsForm").addEventListener("submit",async event=>{
    event.preventDefault();const form=new FormData(event.currentTarget),desired={revision:Date.now()};
    for(const [key,value] of form.entries())desired[key]=Number(value);
    setText("#settingsNotice","Sending validated settings to the Q20…");
    try{await db("PUT",`devices/${config.deviceUid}/desired`,desired);setText("#settingsNotice","Saved. The Q20 normally applies this within one minute.");setTimeout(refresh,5000);}catch(error){setText("#settingsNotice",error.message);}
  });
  $("#refresh").addEventListener("click",refresh);$("#logout").addEventListener("click",()=>location.reload());
})();
