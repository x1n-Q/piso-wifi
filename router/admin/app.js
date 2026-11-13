(() => {
  const $ = selector => document.querySelector(selector);
  const money = n => `₱${Number(n || 0).toLocaleString()}`;
  const when = stamp => stamp > 0 ? new Date(stamp * 1000).toLocaleString() : "—";
  const duration = seconds => {
    let n = Math.max(0, Number(seconds || 0));
    const days = Math.floor(n / 86400); n %= 86400;
    const hours = Math.floor(n / 3600); const minutes = Math.floor((n % 3600) / 60);
    return days ? `${days}d ${hours}h` : `${hours}h ${minutes}m`;
  };
  const safe = value => String(value ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;"}[c]));
  let noticeTimer;
  const notify = (message, error = false) => {
    const node = $("#notice"); node.textContent = message; node.className = error ? "show error" : "show";
    clearTimeout(noticeTimer); noticeTimer = setTimeout(() => node.className = "", 3500);
  };
  const api = async (action = "summary", options = {}) => {
    const response = await fetch(`/cgi-bin/piso-admin-api?action=${action}`, {cache:"no-store", ...options});
    const data = await response.json();
    if (!response.ok || !data.ok) throw new Error(data.message || "Request failed");
    return data;
  };
  const render = data => {
    $("#today").textContent = money(data.earnings.today); $("#total").textContent = money(data.earnings.total);
    $("#connected").textContent = data.connected; $("#alertCount").textContent = data.alert_count;
    $("#controller").textContent = data.controller_online ? "● Coin controller online" : "○ Coin controller offline";
    $("#controller").style.color = data.controller_online ? "var(--green)" : "var(--amber)";

    $("#sessions").innerHTML = data.sessions.map(s => `<tr><td><span class="tag ${safe(s.status)}">${safe(s.status)}</span></td><td>${safe(s.mac || s.ip || "Unknown")}</td><td>${safe(s.source || "coin")}${s.voucher ? `<br><small>${safe(s.voucher)}</small>`:""}</td><td>${duration(s.remaining)}</td><td>${money(s.paid)}</td></tr>`).join("");
    $("#emptySessions").hidden = data.sessions.length > 0;
    $("#vouchers").innerHTML = data.vouchers.map(v => `<tr><td><strong>${safe(v.code)}</strong></td><td>${v.plan === 60 ? "2 months" : "1 month"} · ${money(v.price)}</td><td><span class="tag ${safe(v.status)}">${safe(v.status)}</span></td><td>${safe(v.mac || "Not used")}</td><td>${when(v.expires)}</td></tr>`).join("");
    $("#emptyVouchers").hidden = data.vouchers.length > 0;
    $("#alerts").innerHTML = data.alerts.slice().reverse().map(a => `<article class="alert"><time>${when(a.at)}</time><div><strong>${safe(a.type)}</strong><span>Device ${safe(a.mac || "unknown")} · IP ${safe(a.ip || "unknown")} · ${safe(a.detail)}</span></div></article>`).join("");
    $("#emptyAlerts").hidden = data.alerts.length > 0;
  };
  const refresh = async () => { try { render(await api()); } catch (e) { notify(e.message, true); } };
  $("#refresh").addEventListener("click", refresh);
  document.querySelectorAll("[data-plan]").forEach(button => button.addEventListener("click", async () => {
    button.disabled = true;
    try {
      const body = new URLSearchParams({plan:button.dataset.plan});
      const data = await api("create_voucher", {method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded"},body});
      $("#newCode").textContent = data.code; $("#createdVoucher").hidden = false;
      notify(`${data.plan === 60 ? "2-month" : "1-month"} voucher created`); await refresh();
    } catch (e) { notify(e.message, true); } finally { button.disabled = false; }
  }));
  $("#copyCode").addEventListener("click", async () => {
    try { await navigator.clipboard.writeText($("#newCode").textContent); notify("Voucher code copied"); }
    catch (_) { notify("Select and copy the voucher code manually", true); }
  });
  refresh(); setInterval(refresh, 15000);
})();
