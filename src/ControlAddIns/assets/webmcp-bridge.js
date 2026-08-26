(() => {
  "use strict";

  const TOOL_NAME = "bc_get_current_record_primary_key";
  const TIMEOUT_MS = 10_000;
  const pendingCalls = new Map();

  let initialized = false;
  let disposed = false;
  let registrationController;
  let statusElements;

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

    const heading = document.createElement("h2");
    heading.textContent = "BC WebMCP";
    panel.appendChild(heading);

    const feature = createStatusRow("WebMCP", "Checking…");
    const registration = createStatusRow("Tool", "Not registered");
    const latest = createStatusRow("Latest call", "None");

    panel.append(feature.row, registration.row, latest.row);
    host.appendChild(panel);

    return {
      panel,
      feature: feature.value,
      registration: registration.value,
      latest: latest.value
    };
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

  function setFeatureStatus(message, state) {
    setElementStatus(statusElements.feature, message, state);
  }

  function setRegistrationStatus(message, state) {
    setElementStatus(statusElements.registration, message, state);
  }

  function setLatestStatus(message, state) {
    setElementStatus(statusElements.latest, message, state);
  }

  function setElementStatus(element, message, state) {
    if (!element) return;

    element.textContent = message;
    element.dataset.state = state || "neutral";
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
        setLatestStatus(`${error.name}: ${error.message}`, "error");
        pending.reject(error);
      }, TIMEOUT_MS);

      pendingCalls.set(requestId, { resolve, reject, timeoutId });
      setLatestStatus(`Waiting for Business Central (${requestId})`, "pending");

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
            setLatestStatus(`${error.name}: ${error.message}`, "error");
            pending.reject(error);
          }
        );
      } catch (cause) {
        const pending = takePendingCall(requestId);
        if (!pending) return;

        const message = cause instanceof Error ? cause.message : String(cause);
        const error = createBridgeError("AL_INVOCATION_FAILED", message);
        setLatestStatus(`${error.name}: ${error.message}`, "error");
        pending.reject(error);
      }
    });
  }

  window.CompleteToolCall = function CompleteToolCall(
    requestId,
    resultJson,
    isError
  ) {
    const pending = takePendingCall(requestId);
    if (!pending) return;

    if (isError) {
      const payload = parseErrorPayload(resultJson);
      const error = createBridgeError(payload.code, payload.message);
      setLatestStatus(`${error.name}: ${error.message}`, "error");
      pending.reject(error);
      return;
    }

    setLatestStatus(resultJson, "success");
    pending.resolve(resultJson);
  };

  async function registerTool() {
    if (
      !("modelContext" in document) ||
      !document.modelContext ||
      typeof document.modelContext.registerTool !== "function"
    ) {
      setFeatureStatus("Unavailable", "error");
      setRegistrationStatus(
        "document.modelContext.registerTool is missing",
        "error"
      );
      return;
    }

    setFeatureStatus("Available", "success");
    setRegistrationStatus("Registering…", "pending");
    registrationController = new AbortController();

    try {
      await document.modelContext.registerTool(
        {
          name: TOOL_NAME,
          title: "Get current Business Central record key",
          description:
            "Returns the table identity and primary-key fields of the Business Central record currently displayed on the host page. This operation is read-only.",
          inputSchema: {
            type: "object",
            properties: {},
            additionalProperties: false
          },
          annotations: {
            readOnlyHint: true
          },
          execute: async () => {
            try {
              const resultJson = await invokeAL(TOOL_NAME, {});
              return {
                content: [{ type: "text", text: resultJson }]
              };
            } catch (error) {
              const name = error instanceof Error ? error.name : "TOOL_ERROR";
              const message = error instanceof Error ? error.message : String(error);
              setLatestStatus(`${name}: ${message}`, "error");
              throw error;
            }
          }
        },
        { signal: registrationController.signal }
      );

      if (!disposed) {
        setRegistrationStatus(`Registered: ${TOOL_NAME}`, "success");
      }
    } catch (error) {
      const name = error instanceof Error ? error.name : "REGISTRATION_ERROR";
      const message = error instanceof Error ? error.message : String(error);
      setRegistrationStatus(`${name}: ${message}`, "error");
      console.error("BC WebMCP registration failed", error);
    }
  }

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
    void registerTool();
  }

  window.BCWebMCP = Object.freeze({ initialize });
})();
