(() => {
  const qs = new URLSearchParams(location.search);
  const authAction = qs.get("authaction") || "";
  let clientIp = qs.get("clientip") || "";
  if (!clientIp && authAction) {
    try { clientIp = new URL(authAction, location.href).searchParams.get("clientip") || ""; }
    catch (_) { const match = authAction.match(/[?&]clientip=([^&]+)/); if (match) clientIp = decodeURIComponent(match[1]); }
  }
  const clientMac = qs.get("clientmac") || "";
  const token = qs.get("tok") || "";
  const safeOriginUrl = value => {
    try {
      const url = new URL(value || "http://neverssl.com/", location.href);
      return url.protocol === "http:" || url.protocol === "https:" ? url.href : "http://neverssl.com/";
    } catch (_) { return "http://neverssl.com/"; }
  };
  const originUrl = safeOriginUrl(qs.get("redir") || qs.get("originurl"));

  const el = {
    badge: document.querySelector("#statusBadge"), time: document.querySelector("#timeRemaining"),
    device: document.querySelector("#deviceLabel"), notice: document.querySelector("#notice"),
    insert: document.querySelector("#insertCoin"), voucher: document.querySelector("#useVoucher"),
    pause: document.querySelector("#pauseSession"), resume: document.querySelector("#resumeSession"),
    browse: document.querySelector("#browseNow"), coinModal: document.querySelector("#coinModal"),
    coinEyebrow: document.querySelector("#coinModalEyebrow"), coinTitle: document.querySelector("#coinModalTitle"),
    coinMessage: document.querySelector("#coinModalMessage"), countdown: document.querySelector("#coinCountdown"), coinTotal: document.querySelector("#coinTotal"),
    coinDone: document.querySelector("#coinDone"), coinIcon: document.querySelector("#coinIcon"),
    insertTitle: document.querySelector("#insertTitle"), insertHint: document.querySelector("#insertHint"),
    controller: document.querySelector("#controllerState"), voucherModal: document.querySelector("#voucherModal"),
    voucherCode: document.querySelector("#voucherCode"), voucherMessage: document.querySelector("#voucherMessage"),
    activateVoucher: document.querySelector("#activateVoucher")
  };

  let state = {status:"ready", remaining:0};
  let waitingUntil = 0, coinWindowPesos = 0, refreshing = false, controllerOnline = null, controllerRefreshing = false;
  let coinFinishing = false, coinRetryAfter = 0;
  let coinAudio = null, coinBeepTimer = null;

  const unlockCoinSound = () => {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return;
    if (!coinAudio) coinAudio = new AudioContextClass();
    if (coinAudio.state === "suspended") coinAudio.resume().catch(() => {});
  };
  const playCoinBeep = () => {
    if (!coinAudio || coinAudio.state !== "running") return;
    const now = coinAudio.currentTime;
    const oscillator = coinAudio.createOscillator();
    const gain = coinAudio.createGain();
    oscillator.type = "square";
    oscillator.frequency.setValueAtTime(2400,now);
    gain.gain.setValueAtTime(.0001,now);
    gain.gain.exponentialRampToValueAtTime(.09,now + .008);
    gain.gain.setValueAtTime(.09,now + .105);
    gain.gain.exponentialRampToValueAtTime(.0001,now + .13);
    oscillator.connect(gain); gain.connect(coinAudio.destination);
    oscillator.start(now); oscillator.stop(now + .14);
  };
  const startCoinBeeping = () => {
    unlockCoinSound();
    if (coinBeepTimer) return;
    playCoinBeep();
    coinBeepTimer = setInterval(playCoinBeep,500);
  };
  const stopCoinBeeping = () => {
    if (!coinBeepTimer) return;
    clearInterval(coinBeepTimer);
    coinBeepTimer = null;
  };

  const formatTime = seconds => {
    const n = Math.max(0, Number(seconds) || 0), h = Math.floor(n / 3600), m = Math.floor((n % 3600) / 60), s = Math.floor(n % 60);
    if (h >= 100) { const days = Math.floor(h / 24); return `${days}d ${String(h % 24).padStart(2,"0")}h`; }
    return [h,m,s].map(v => String(v).padStart(2,"0")).join(":");
  };
  const formatCountdown = seconds => `${String(Math.floor(Math.max(0,seconds)/60)).padStart(2,"0")}:${String(Math.max(0,seconds)%60).padStart(2,"0")}`;
  const setBadge = status => { el.badge.className = `badge ${status}`; el.badge.textContent = status.toUpperCase(); };
  const openModal = modal => { modal.hidden = false; document.body.classList.add("modal-open"); };
  const closeModal = modal => { modal.hidden = true; if (el.coinModal.hidden && el.voucherModal.hidden) document.body.classList.remove("modal-open"); };
  const expireEmptyCoinWindow = () => {
    stopCoinBeeping();
    waitingUntil = 0; coinWindowPesos = 0; el.coinDone.hidden = true;
    closeModal(el.coinModal);
    el.notice.textContent = "Coin entry closed after 30 seconds. Tap INSERT COIN to try again.";
  };

  const api = async (action, extra = {}) => {
    const params = new URLSearchParams({action,clientip:clientIp,clientmac:clientMac,tok:token,...extra});
    const response = await fetch(`/cgi-bin/api?${params}`, {cache:"no-store"});
    let payload;
    try { payload = await response.json(); } catch (_) { throw new Error("Portal did not return a valid response. Please try again."); }
    if (!response.ok || !payload.ok) throw new Error(payload.message || "Request failed");
    return payload;
  };

  const renderController = () => {
    const status = controllerOnline === true ? "online" : controllerOnline === false ? "offline" : "checking";
    el.controller.className = `hardware-state ${status}`;
    el.insert.classList.toggle("offline", controllerOnline === false);
    if (controllerOnline === true) {
      el.controller.querySelector("span").textContent = "Coin acceptor ONLINE and ready";
      el.insertTitle.textContent = "INSERT COIN"; el.insertHint.textContent = "Tap here first, then insert your coin";
    } else if (controllerOnline === false) {
      el.controller.querySelector("span").textContent = "Coin acceptor OFFLINE · vouchers still work";
      el.insertTitle.textContent = "COIN ACCEPTOR OFFLINE"; el.insertHint.textContent = "Use a voucher or ask the owner";
    } else {
      el.controller.querySelector("span").textContent = "Checking coin acceptor…";
    }
  };

  const render = () => {
    const now = Math.floor(Date.now()/1000), waiting = Math.max(0,waitingUntil-now);
    el.coinTotal.textContent = `₱${coinWindowPesos}`;
    if (waiting > 0 || (waitingUntil && coinWindowPesos > 0)) {
      setBadge("waiting"); el.countdown.textContent = formatCountdown(waiting);
      el.coinDone.hidden = coinWindowPesos <= 0;
      if (coinFinishing) {
        el.notice.textContent = `₱${coinWindowPesos} RECEIVED · STARTING INTERNET…`;
        el.coinEyebrow.textContent = "PAYMENT SAVED";
        el.coinTitle.textContent = `₱${coinWindowPesos} RECEIVED`;
        el.coinMessage.textContent = "Please wait while the router starts your internet session.";
      } else if (waiting === 0 && coinWindowPesos > 0) {
        el.notice.textContent = `₱${coinWindowPesos} RECEIVED · FINISHING PAYMENT…`;
        el.coinEyebrow.textContent = "COIN ENTRY COMPLETE";
        el.coinTitle.textContent = `₱${coinWindowPesos} RECEIVED`;
        el.coinMessage.textContent = "Your coins are saved. Starting your internet session now.";
      } else if (coinWindowPesos > 0) {
        el.notice.textContent = `₱${coinWindowPesos} INSERTED · ADD MORE OR TAP DONE`;
        el.coinEyebrow.textContent = "PAYMENT RECEIVED";
        el.coinTitle.textContent = `₱${coinWindowPesos} INSERTED`;
        el.coinMessage.textContent = "Keep inserting coins. Press the green button only after your LAST coin.";
      } else {
        el.notice.textContent = `INSERT COINS NOW · ${waiting} seconds left`;
        el.coinEyebrow.textContent = "COIN SLOT READY";
        el.coinTitle.textContent = "INSERT YOUR COINS NOW";
        el.coinMessage.textContent = "You can insert several coins. They will add together automatically.";
      }
    } else {
      if (waitingUntil) {
        waitingUntil = 0; coinWindowPesos = 0; el.coinDone.hidden = true;
        el.coinMessage.textContent = "Coin time expired. Close this message and tap INSERT COIN again."; el.countdown.textContent = "00:00";
      }
      setBadge(state.status || "ready");
    }
    el.time.textContent = formatTime(state.remaining);
    el.device.textContent = clientIp ? `This device · ${clientIp}` : "Open from AZ Tires Piso WiFi";
    el.pause.disabled = state.status !== "active"; el.resume.disabled = state.status !== "paused";
    el.browse.hidden = state.status !== "active"; el.browse.href = originUrl;
    document.body.classList.toggle("session-active", state.status === "active" || state.status === "paused");
  };

  const refresh = async () => {
    if (!clientIp || refreshing) return render();
    refreshing = true;
    try {
      const hadWindow = waitingUntil > 0, hadCoins = coinWindowPesos > 0;
      const payload = await api("status"); state = payload.session;
      if (payload.coin_window && (payload.coin_window.active || payload.coin_window.pending)) {
        waitingUntil = Number(payload.coin_window.expires) || 0;
        coinWindowPesos = Number(payload.coin_window.pesos) || 0;
      } else {
        stopCoinBeeping();
        waitingUntil = 0; coinWindowPesos = 0;
        if (hadWindow && !hadCoins) expireEmptyCoinWindow();
      }
      if (state.status === "active") {
        if (!waitingUntil) el.notice.textContent = state.source === "voucher" ? "Voucher active. Tap CONTINUE TO INTERNET." : "Payment accepted. Tap CONTINUE TO INTERNET.";
      } else if (state.status === "paused") el.notice.textContent = "Your internet time is paused safely.";
      else if (!waitingUntil) el.notice.textContent = "Choose INSERT COIN or USE VOUCHER.";
      render();
    } catch (error) { el.notice.textContent = error.message; }
    finally { refreshing = false; }
  };

  const refreshController = async () => {
    if (controllerRefreshing) return controllerOnline;
    controllerRefreshing = true;
    try { controllerOnline = (await api("controller_status")).online === true; } catch (_) { controllerOnline = false; }
    controllerRefreshing = false; renderController(); return controllerOnline;
  };

  const startCoinWindow = async () => {
    unlockCoinSound();
    if (!clientIp) { el.notice.textContent = "Connect to AZ Tires Piso WiFi first."; return; }
    if (controllerOnline !== true) await refreshController();
    if (controllerOnline !== true) {
      el.coinIcon.classList.add("offline"); el.coinEyebrow.textContent = "COIN ACCEPTOR OFFLINE"; el.coinTitle.textContent = "Use a voucher for now";
      el.coinMessage.textContent = "The ESP32 controller is not online, so a real coin cannot be credited yet."; el.countdown.textContent = "OFFLINE"; openModal(el.coinModal); return;
    }
    el.insert.disabled = true;
    try {
      const payload = await api("wait"); waitingUntil = Number(payload.expires) || 0; coinWindowPesos = Number(payload.pesos) || 0;
      el.coinIcon.classList.remove("offline"); el.notice.textContent = "INSERT YOUR COINS NOW."; openModal(el.coinModal); startCoinBeeping(); render();
    } catch (error) { stopCoinBeeping(); el.notice.textContent = error.message; }
    finally { el.insert.disabled = false; }
  };

  const finishCoinWindow = async () => {
    stopCoinBeeping();
    if (coinFinishing) return;
    if (!waitingUntil || !clientIp) { closeModal(el.coinModal); return; }
    coinFinishing = true; el.coinDone.disabled = true; el.coinDone.textContent = "STARTING INTERNET…"; render();
    try {
      const payload = await api("finish_coin"); state = payload.session;
      const paid = coinWindowPesos; waitingUntil = 0; coinWindowPesos = 0;
      coinRetryAfter = 0;
      el.notice.textContent = paid > 0 ? `₱${paid} accepted. Tap CONTINUE TO INTERNET.` : "Coin entry cancelled.";
      closeModal(el.coinModal); render();
    } catch (error) { coinRetryAfter = Date.now() + 3000; el.coinMessage.textContent = `${error.message} Retrying automatically…`; }
    finally { coinFinishing = false; el.coinDone.disabled = false; el.coinDone.textContent = "FINISHED INSERTING — START INTERNET"; render(); }
  };

  const activateVoucher = async () => {
    if (!clientIp) { el.notice.textContent = "Connect to AZ Tires Piso WiFi first."; return; }
    const code = el.voucherCode.value.trim();
    if (!code) { el.voucherMessage.textContent = "Please enter the voucher code."; el.voucherCode.focus(); return; }
    el.activateVoucher.disabled = true; el.activateVoucher.textContent = "CHECKING VOUCHER…";
    try {
      const payload = await api("redeem_voucher", {code}); state = payload.session;
      el.voucherMessage.textContent = "VOUCHER ACTIVATED! This device now has internet."; el.notice.textContent = "Voucher active. Tap CONTINUE TO INTERNET."; render();
      setTimeout(() => closeModal(el.voucherModal),1200);
    } catch (error) { el.voucherMessage.textContent = error.message; }
    finally { el.activateVoucher.disabled = false; el.activateVoucher.textContent = "ACTIVATE VOUCHER"; }
  };

  el.insert.addEventListener("click",startCoinWindow);
  el.voucher.addEventListener("click",() => { el.voucherMessage.textContent = "The voucher will lock to this device when activated."; openModal(el.voucherModal); setTimeout(() => el.voucherCode.focus(),100); });
  el.coinDone.addEventListener("click",finishCoinWindow); el.activateVoucher.addEventListener("click",activateVoucher);
  el.voucherCode.addEventListener("keydown",event => { if (event.key === "Enter") activateVoucher(); });
  document.querySelectorAll("[data-close]").forEach(node => node.addEventListener("click",() => node.dataset.close === "coin" ? finishCoinWindow() : closeModal(el.voucherModal)));
  el.pause.addEventListener("click",async() => { try { state=(await api("pause")).session; el.notice.textContent="Your internet time is paused safely."; render(); } catch(error){el.notice.textContent=error.message;} });
  el.resume.addEventListener("click",async() => { try { state=(await api("resume")).session; el.notice.textContent="Internet time resumed."; render(); } catch(error){el.notice.textContent=error.message;} });

  render(); renderController(); refresh(); refreshController();
  setInterval(() => {
    if(state.status==="active"&&state.remaining>0) state.remaining-=1;
    if(waitingUntil && Math.floor(Date.now()/1000)>=waitingUntil) {
      stopCoinBeeping();
      if(coinWindowPesos>0 && Date.now()>=coinRetryAfter) finishCoinWindow();
      else if(coinWindowPesos===0) expireEmptyCoinWindow();
    }
    render();
  },1000);
  setInterval(() => { if (waitingUntil) refresh(); },300);
  setInterval(() => { if (!waitingUntil) refresh(); },2500);
  setInterval(refreshController,5000);
  window.addEventListener("pagehide",stopCoinBeeping);
})();
