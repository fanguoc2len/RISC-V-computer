(function () {
  const data = window.RVPC_DEMO_DATA;

  if (!data) {
    throw new Error("RVPC_DEMO_DATA is missing.");
  }

  const screenEl = document.getElementById("screen");
  const modeBadgeEl = document.getElementById("mode-badge");
  const commandHintEl = document.getElementById("command-hint");
  const shortcutGridEl = document.getElementById("shortcut-grid");
  const autoplayButtonEl = document.getElementById("autoplay-button");
  const resetButtonEl = document.getElementById("reset-button");

  const statusModeEl = document.getElementById("status-mode");
  const statusLedEl = document.getElementById("status-led");
  const statusTimeEl = document.getElementById("status-time");
  const statusPs2El = document.getElementById("status-ps2");
  const statusStatEl = document.getElementById("status-stat");
  const statusBootEl = document.getElementById("status-boot");

  const bootMagicEl = document.getElementById("boot-magic");
  const bootLoadEl = document.getElementById("boot-load");
  const bootSizeEl = document.getElementById("boot-size");
  const bootEntryEl = document.getElementById("boot-entry");
  const bootChecksumEl = document.getElementById("boot-checksum");
  const bootApp0El = document.getElementById("boot-app0");

  const npuDot4El = document.getElementById("npu-dot4");
  const npuVec16El = document.getElementById("npu-vec16");
  const npuR0El = document.getElementById("npu-r0");
  const npuR1El = document.getElementById("npu-r1");
  const npuR2El = document.getElementById("npu-r2");
  const npuR3El = document.getElementById("npu-r3");

  const monitorHelp = "CMDS:h c l b k i m t r n p v x g";
  const appHelp = "APPCMDS:H C I L T N V Q";
  const promptMonitor = "> ";
  const promptApp = "APP> ";
  const maxVisibleLines = 29;

  const ps2ScanMap = {
    a: 0x1c,
    b: 0x32,
    c: 0x21,
    g: 0x34,
    h: 0x33,
    i: 0x43,
    k: 0x42,
    l: 0x4b,
    m: 0x3a,
    n: 0x31,
    p: 0x4d,
    q: 0x15,
    r: 0x2d,
    t: 0x2c,
    v: 0x2a,
    x: 0x22
  };

  const state = {
    mode: "monitor",
    transcript: [],
    bootLoaded: false,
    bootStatus: "00000000",
    monitorLedValue: 0x1,
    visibleLedValue: 0x1,
    appLedValue: 0xA,
    ps2Raw: 0x1c,
    ps2Ascii: "a",
    timeCounter: 0x0003ca26,
    busy: true,
    autoplayRunning: false,
    pendingBootTimer: null
  };

  function currentPrompt() {
    return state.mode === "app" ? promptApp : promptMonitor;
  }

  function hex(value, width) {
    return value.toString(16).toUpperCase().padStart(width, "0");
  }

  function asciiOrQuestion(ch) {
    return ch && ch.length === 1 ? ch : "?";
  }

  function tickTime(step) {
    state.timeCounter = (state.timeCounter + step) >>> 0;
  }

  function rememberKey(key) {
    const lower = key.toLowerCase();
    if (ps2ScanMap[lower] !== undefined) {
      state.ps2Raw = ps2ScanMap[lower];
      state.ps2Ascii = lower;
    }
  }

  function pushLine(text) {
    state.transcript.push(text);
    if (state.transcript.length > 256) {
      state.transcript = state.transcript.slice(-256);
    }
  }

  function pushBlock(text) {
    text.split("\n").forEach((line) => pushLine(line));
  }

  function resetTranscript(lines) {
    state.transcript = lines.slice();
  }

  function showMonitorScreen() {
    resetTranscript([
      "RV32 PC",
      "h=help c=clear l=led b=boot k=ps2 i=info m=mem t=time r=ram n=npu p=pcpi v=vec16 x=mat g=go"
    ]);
  }

  function showAppScreen() {
    resetTranscript([
      "RVOS/32",
      "APP SHELL READY",
      appHelp
    ]);
  }

  function updateChrome() {
    const modeName = state.mode === "app" ? "RVOS/32" : "MONITOR";
    const commands = state.mode === "app" ? data.appCommands.join(" ") : data.monitorCommands.join(" ");

    modeBadgeEl.textContent = modeName;
    statusModeEl.textContent = modeName;
    commandHintEl.textContent = commands;

    statusLedEl.textContent = hex(state.visibleLedValue, 4);
    statusTimeEl.textContent = hex(state.timeCounter, 8);
    statusPs2El.textContent = `${hex(state.ps2Raw, 2)} / ${asciiOrQuestion(state.ps2Ascii)}`;
    statusStatEl.textContent = state.bootStatus;
    statusBootEl.textContent = state.bootLoaded ? "READY" : "AUTOBOOT";

    bootMagicEl.textContent = data.boot.magicText;
    bootLoadEl.textContent = data.boot.loadAddress;
    bootSizeEl.textContent = data.boot.sizeBytes;
    bootEntryEl.textContent = data.boot.entryAddress;
    bootChecksumEl.textContent = data.boot.checksum;
    bootApp0El.textContent = data.boot.firstAppWord;

    npuDot4El.textContent = data.npu.dot4;
    npuVec16El.textContent = data.npu.vec16;
    npuR0El.textContent = data.npu.mat[0];
    npuR1El.textContent = data.npu.mat[1];
    npuR2El.textContent = data.npu.mat[2];
    npuR3El.textContent = data.npu.mat[3];

    autoplayButtonEl.textContent = state.autoplayRunning ? "Showcase Running" : "Run Showcase";
    autoplayButtonEl.disabled = state.autoplayRunning;
  }

  function renderScreen() {
    const visible = state.transcript.slice(-maxVisibleLines);
    const escapedLines = visible.map((line) =>
      String(line)
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
    );
    const promptHtml = state.busy
      ? "[autobooting...]"
      : currentPrompt()
          .replaceAll("&", "&amp;")
          .replaceAll("<", "&lt;")
          .replaceAll(">", "&gt;") + '<span class="cursor">_</span>';
    screenEl.innerHTML = [...escapedLines, promptHtml].join("\n");
  }

  function render() {
    updateChrome();
    renderScreen();
  }

  function doBootComplete() {
    state.bootLoaded = true;
    state.bootStatus = data.boot.statusOk;
    state.busy = false;
    pushLine("BOOT=OK");
    render();
  }

  function resetMachine() {
    if (state.pendingBootTimer) {
      window.clearTimeout(state.pendingBootTimer);
    }

    state.mode = "monitor";
    state.bootLoaded = false;
    state.bootStatus = "00000000";
    state.monitorLedValue = 0x1;
    state.visibleLedValue = 0x1;
    state.appLedValue = 0xA;
    state.ps2Raw = 0x1c;
    state.ps2Ascii = "a";
    state.timeCounter = 0x0003ca26;
    state.busy = true;
    state.autoplayRunning = false;

    showMonitorScreen();
    render();

    state.pendingBootTimer = window.setTimeout(doBootComplete, 600);
  }

  function pushCommandEcho(command) {
    pushLine(`${currentPrompt()}${command}`);
  }

  function handleMonitorCommand(command) {
    switch (command) {
      case "h":
      case "?":
        pushLine(monitorHelp);
        break;
      case "c":
        resetTranscript([]);
        break;
      case "l":
        state.monitorLedValue ^= 0x1;
        state.visibleLedValue = state.monitorLedValue;
        pushLine(`LED=${state.monitorLedValue & 0x1}`);
        break;
      case "b":
        state.bootLoaded = true;
        state.bootStatus = data.boot.statusOk;
        pushLine("BOOT=OK");
        break;
      case "k":
        pushLine(`PS2=OK RAW=${hex(state.ps2Raw, 2)} ASCII=${asciiOrQuestion(state.ps2Ascii)}`);
        break;
      case "i":
        pushLine(
          `BOOTLD=${state.bootLoaded ? "1" : "0"} ENTRY=${state.bootLoaded ? data.boot.entryAddress : "00000000"} STATUS=${state.bootStatus}`
        );
        break;
      case "m":
        pushLine(`BI0=${data.boot.bootInfoMagic} APP0=${data.boot.firstAppWord}`);
        break;
      case "t":
        pushLine(`TIME=${hex(state.timeCounter, 8)}`);
        break;
      case "r":
        pushLine("RAM=OK");
        break;
      case "n":
        pushLine(`NPU=OK RES=${data.npu.dot4}`);
        break;
      case "p":
        pushLine(`PCPI=OK RES=${data.npu.dot4}`);
        break;
      case "v":
        pushLine(`V16=OK MMIO=${data.npu.vec16} PCPI=${data.npu.vec16}`);
        break;
      case "x":
        pushLine(`MAT=OK R0=${data.npu.mat[0]} R1=${data.npu.mat[1]} R2=${data.npu.mat[2]} R3=${data.npu.mat[3]}`);
        break;
      case "g":
        if (!state.bootLoaded) {
          pushLine("GO=ER");
          break;
        }
        state.mode = "app";
        state.appLedValue = 0xA;
        state.visibleLedValue = state.appLedValue;
        showAppScreen();
        break;
      default:
        pushLine("?");
        break;
    }
  }

  function handleAppCommand(command) {
    switch (command) {
      case "h":
        pushLine(appHelp);
        break;
      case "c":
        showAppScreen();
        break;
      case "i":
        pushLine(`APPINFO LD=${data.boot.loadAddress} EN=${data.boot.entryAddress} ST=${state.bootStatus}`);
        break;
      case "l":
        state.appLedValue ^= 0xF;
        state.visibleLedValue = state.appLedValue;
        pushLine(`APPLED=${hex(state.appLedValue, 8)}`);
        break;
      case "t":
        pushLine(`APPTIME=${hex(state.timeCounter, 8)}`);
        break;
      case "n":
        pushLine(`APPNPU=OK RES=${data.npu.dot4}`);
        break;
      case "v":
        pushLine(`APPMAT=OK R0=${data.npu.mat[0]} R1=${data.npu.mat[1]} R2=${data.npu.mat[2]} R3=${data.npu.mat[3]}`);
        break;
      case "q":
        pushLine("APPBYE");
        state.mode = "monitor";
        pushLine("GO=RET");
        break;
      default:
        pushLine("APP?");
        break;
    }
  }

  function sendCommand(rawCommand) {
    if (state.busy) {
      return;
    }

    const printable = String(rawCommand || "").trim();
    if (!printable) {
      return;
    }

    const command = printable[0].toLowerCase();
    rememberKey(command);
    pushCommandEcho(command);
    tickTime(0x271);

    if (state.mode === "app") {
      handleAppCommand(command);
    } else {
      handleMonitorCommand(command);
    }

    render();
  }

  async function runShowcase() {
    if (state.autoplayRunning) {
      return;
    }

    if (state.busy) {
      return;
    }

    state.autoplayRunning = true;
    render();

    const steps = [
      ["h", 700],
      ["l", 700],
      ["b", 700],
      ["k", 700],
      ["i", 700],
      ["m", 700],
      ["t", 700],
      ["r", 700],
      ["n", 700],
      ["p", 700],
      ["v", 700],
      ["x", 900],
      ["g", 1100],
      ["h", 700],
      ["n", 700],
      ["v", 900],
      ["q", 900]
    ];

    for (const [command, delayMs] of steps) {
      sendCommand(command);
      await new Promise((resolve) => window.setTimeout(resolve, delayMs));
    }

    state.autoplayRunning = false;
    render();
  }

  function installKeyboard() {
    window.addEventListener("keydown", (event) => {
      if (event.ctrlKey || event.metaKey || event.altKey) {
        return;
      }

      if (event.key === "Escape") {
        event.preventDefault();
        resetMachine();
        return;
      }

      if (event.key === "F1") {
        event.preventDefault();
        runShowcase();
        return;
      }

      if (event.key.length === 1) {
        event.preventDefault();
        sendCommand(event.key);
      }
    });
  }

  function installShortcuts() {
    const rows = [
      ...data.monitorCommands.map((command) => ({ command, label: command.toUpperCase(), kind: "monitor" })),
      ...data.appCommands.map((command) => ({ command, label: `APP ${command.toUpperCase()}`, kind: "app" }))
    ];

    rows.forEach(({ command, label, kind }) => {
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = label;
      if (kind === "app") {
        button.className = "app-key";
      }
      button.addEventListener("click", () => sendCommand(command));
      shortcutGridEl.appendChild(button);
    });
  }

  resetButtonEl.addEventListener("click", resetMachine);
  autoplayButtonEl.addEventListener("click", runShowcase);

  installKeyboard();
  installShortcuts();
  resetMachine();

  window.setInterval(() => {
    tickTime(0x3F);
    render();
  }, 1000);
})();
