(() => {
  "use strict";

  if (!window.BCWebMCP || typeof window.BCWebMCP.initialize !== "function") {
    const host = document.getElementById("controlAddIn") || document.body;
    host.textContent = "BC WebMCP startup failed: bridge script unavailable.";
    return;
  }

  window.BCWebMCP.initialize();
})();
