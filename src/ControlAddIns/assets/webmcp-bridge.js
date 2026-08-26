(() => {
  "use strict";

  const TIMEOUT_MS = 10_000;
  const pendingCalls = new Map();

  let initialized = false;
  let disposed = false;
  let registrationController;
  let statusElements;
  let lastDefinitionsJson = "";

  function createBridgeError(code, message) {
    const error = new Error(message);
    error.name = code;
    error.code = code;
    return error;
  }

  function createDiagnosticPanel() {
    const host = document.getElementById("controlAddIn") || document.body;
    host.replaceChildren();

    const panel = document.createElement("section");
    panel.className = "bc-webmcp-panel";
    panel.setAttribute("aria-live", "polite");

    const header = document.createElement("div");
    header.className = "bc-webmcp-header";

    const brand = document.createElement("div");
    brand.className = "bc-webmcp-brand";
    const brandMark = document.createElement("span");
    brandMark.className = "bc-webmcp-brand-mark";
    brandMark.setAttribute("aria-hidden", "true");
    const heading = document.createElement("h2");
    heading.textContent = "WebMCP status";
    brand.append(brandMark, heading);

    const availability = document.createElement("span");
    availability.className = "bc-webmcp-badge";
    availability.textContent = "Checking";
    availability.dataset.state = "pending";

    header.append(brand, availability);

    const tools = createToolsStatusRow();
    const latest = createStatusRow("Latest call", "None");

    panel.append(header, tools.row, tools.details, latest.row);
    host.appendChild(panel);

    return {
      panel,
      availability,
      tools: tools.text,
      toolsToggle: tools.toggle,
      toolDetails: tools.details,
      latest: latest.value
    };
  }

  function createToolsStatusRow() {
    const row = document.createElement("div");
    row.className = "bc-webmcp-row";

    const label = document.createElement("span");
    label.className = "bc-webmcp-label";
    label.textContent = "Tools";

    const toggle = document.createElement("button");
    toggle.className = "bc-webmcp-value bc-webmcp-tools-toggle";
    toggle.type = "button";
    toggle.disabled = true;
    toggle.setAttribute("aria-expanded", "false");
    toggle.setAttribute("aria-controls", "bc-webmcp-tool-details");

    const text = document.createElement("span");
    text.className = "bc-webmcp-tools-text";
    text.textContent = "Waiting for Business Central…";

    const infoIcon = document.createElement("span");
    infoIcon.className = "bc-webmcp-info-icon";
    infoIcon.textContent = "ⓘ";
    infoIcon.setAttribute("aria-hidden", "true");

    toggle.append(text, infoIcon);
    row.append(label, toggle);

    const details = document.createElement("div");
    details.id = "bc-webmcp-tool-details";
    details.className = "bc-webmcp-tool-details";
    details.hidden = true;

    toggle.addEventListener("click", () => {
      const shouldExpand = details.hidden;
      details.hidden = !shouldExpand;
      toggle.setAttribute("aria-expanded", String(shouldExpand));
      updateToolsToggleLabel();
    });

    return { row, toggle, text, details };
  }

  function createStatusRow(labelText, valueText) {
    const row = document.createElement("div");
    row.className = "bc-webmcp-row";

    const label = document.createElement("span");
    label.className = "bc-webmcp-label";
    label.textContent = labelText;

    const value = document.createElement("span");
    value.className = "bc-webmcp-value";
    value.textContent = valueText;

    row.append(label, value);
    return { row, value };
  }

  function setElementStatus(element, message, state) {
    if (!element) return;
    element.textContent = message;
    element.dataset.state = state || "neutral";
  }

  function setAvailability(message, state) {
    setElementStatus(statusElements.availability, message, state);
  }

  function setToolsStatus(message, state) {
    setElementStatus(statusElements.tools, message, state);
    if (statusElements?.toolsToggle) {
      statusElements.toolsToggle.dataset.state = state || "neutral";
      updateToolsToggleLabel();
    }
  }

  function setLatestStatus(message, state) {
    setElementStatus(statusElements.latest, message, state);
  }

  function updateToolsToggleLabel() {
    if (!statusElements?.toolsToggle || !statusElements.tools) return;

    const action = statusElements.toolDetails?.hidden ? "Show" : "Hide";
    statusElements.toolsToggle.setAttribute(
      "aria-label",
      `${statusElements.tools.textContent}. ${action} registered tool details.`
    );
  }

  function setRegisteredToolDefinitions(toolDefinitions) {
    const { toolDetails, toolsToggle } = statusElements;
    toolDetails.replaceChildren();
    toolDetails.hidden = true;
    toolsToggle.setAttribute("aria-expanded", "false");
    toolsToggle.disabled = toolDefinitions.length === 0;

    for (const definition of toolDefinitions) {
      const tool = document.createElement("article");
      tool.className = "bc-webmcp-tool";

      const name = document.createElement("h3");
      name.className = "bc-webmcp-tool-name";
      name.textContent = definition.name;

      const description = document.createElement("p");
      description.className = "bc-webmcp-tool-description";
      description.textContent =
        typeof definition.description === "string" && definition.description.trim()
          ? definition.description
          : "No description is available.";

      tool.append(name, description);
      toolDetails.appendChild(tool);
    }

    updateToolsToggleLabel();
  }

  function parseErrorPayload(resultJson) {
    try {
      const value = JSON.parse(resultJson);
      return {
        code: typeof value.code === "string" ? value.code : "AL_ERROR",
        message:
          typeof value.message === "string"
            ? value.message
            : "Business Central returned an error."
      };
    } catch {
      return {
        code: "AL_ERROR",
        message: resultJson || "Business Central returned an error."
      };
    }
  }

  function takePendingCall(requestId) {
    const pending = pendingCalls.get(requestId);
    if (!pending) return undefined;

    pendingCalls.delete(requestId);
    clearTimeout(pending.timeoutId);
    return pending;
  }

  function invokeAL(toolName, argumentsObject) {
    return new Promise((resolve, reject) => {
      if (disposed) {
        reject(createBridgeError("PAGE_CLOSED", "The Business Central page is closing."));
        return;
      }

      const requestId = window.crypto.randomUUID();
      const timeoutId = window.setTimeout(() => {
        const pending = takePendingCall(requestId);
        if (!pending) return;

        const error = createBridgeError(
          "TIMEOUT",
          "The Business Central tool call timed out after 10 seconds."
        );
        setLatestStatus(`${pending.toolName}: ${error.message}`, "error");
        pending.reject(error);
      }, TIMEOUT_MS);

      pendingCalls.set(requestId, { resolve, reject, timeoutId, toolName });
      setLatestStatus(`${toolName}: waiting for Business Central…`, "pending");

      try {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod(
          "InvokeTool",
          [requestId, toolName, JSON.stringify(argumentsObject ?? {})],
          false,
          () => {},
          () => {
            const pending = takePendingCall(requestId);
            if (!pending) return;

            const error = createBridgeError(
              "AL_INVOCATION_FAILED",
              "Business Central rejected the AL invocation."
            );
            setLatestStatus(`${pending.toolName}: ${error.message}`, "error");
            pending.reject(error);
          }
        );
      } catch (cause) {
        const pending = takePendingCall(requestId);
        if (!pending) return;

        const message = cause instanceof Error ? cause.message : String(cause);
        const error = createBridgeError("AL_INVOCATION_FAILED", message);
        setLatestStatus(`${pending.toolName}: ${error.message}`, "error");
        pending.reject(error);
      }
    });
  }

  window.CompleteToolCall = function CompleteToolCall(requestId, resultJson, isError) {
    const pending = takePendingCall(requestId);
    if (!pending) return;

    if (isError) {
      const payload = parseErrorPayload(resultJson);
      const error = createBridgeError(payload.code, payload.message);
      setLatestStatus(`${pending.toolName}: ${payload.message}`, "error");
      pending.reject(error);
      return;
    }

    setLatestStatus(`${pending.toolName}: completed`, "success");
    pending.resolve(resultJson);
  };

  async function registerToolDefinitions(toolDefinitions) {
    registrationController?.abort();
    registrationController = new AbortController();
    setRegisteredToolDefinitions([]);

    if (toolDefinitions.length === 0) {
      setToolsStatus("No tools are available for this context", "neutral");
      return;
    }

    setToolsStatus(`Registering ${toolDefinitions.length} tools…`, "pending");

    await Promise.all(
      toolDefinitions.map((definition) => {
        const toolName = definition.name;
        return document.modelContext.registerTool(
          {
            ...definition,
            execute: async (argumentsObject) => {
              try {
                const resultJson = await invokeAL(toolName, argumentsObject);
                return { content: [{ type: "text", text: resultJson }] };
              } catch (error) {
                const message = error instanceof Error ? error.message : String(error);
                setLatestStatus(`${toolName}: ${message}`, "error");
                throw error;
              }
            }
          },
          { signal: registrationController.signal }
        );
      })
    );

    if (!disposed) {
      setRegisteredToolDefinitions(toolDefinitions);
      setToolsStatus(`${toolDefinitions.length} tools registered`, "success");
    }
  }

  window.SetToolDefinitions = async function SetToolDefinitions(toolDefinitionsJson) {
    if (disposed || toolDefinitionsJson === lastDefinitionsJson) return;

    if (
      !("modelContext" in document) ||
      !document.modelContext ||
      typeof document.modelContext.registerTool !== "function"
    ) {
      setAvailability("Unavailable", "error");
      setRegisteredToolDefinitions([]);
      setToolsStatus("document.modelContext.registerTool is missing", "error");
      return;
    }

    setAvailability("Available", "success");

    try {
      const definitions = JSON.parse(toolDefinitionsJson);
      if (!Array.isArray(definitions)) {
        throw new TypeError("Business Central returned an invalid tool definition list.");
      }

      await registerToolDefinitions(definitions);
      lastDefinitionsJson = toolDefinitionsJson;
    } catch (error) {
      const name = error instanceof Error ? error.name : "REGISTRATION_ERROR";
      const message = error instanceof Error ? error.message : String(error);
      setRegisteredToolDefinitions([]);
      setToolsStatus(`${name}: ${message}`, "error");
      console.error("BC WebMCP registration failed", error);
    }
  };

  window.SetToolRegistrationError = function SetToolRegistrationError(errorCode, errorMessage) {
    setRegisteredToolDefinitions([]);
    setToolsStatus(`${errorCode}: ${errorMessage}`, "error");
  };

  function dispose() {
    if (disposed) return;

    disposed = true;
    registrationController?.abort();

    const error = createBridgeError(
      "PAGE_CLOSED",
      "The Business Central page is closing."
    );

    for (const pending of pendingCalls.values()) {
      clearTimeout(pending.timeoutId);
      pending.reject(error);
    }
    pendingCalls.clear();
  }

  function initialize() {
    if (initialized) return;

    initialized = true;
    statusElements = createDiagnosticPanel();
    window.addEventListener("pagehide", dispose, { once: true });

    if (
      "modelContext" in document &&
      document.modelContext &&
      typeof document.modelContext.registerTool === "function"
    ) {
      setAvailability("Available", "success");
    } else {
      setAvailability("Unavailable", "error");
    }

    Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("ControlReady", []);
  }

  window.BCWebMCP = Object.freeze({ initialize });
})();
