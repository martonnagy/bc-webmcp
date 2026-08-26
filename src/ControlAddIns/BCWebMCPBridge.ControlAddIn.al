controladdin "BC WebMCP Bridge"
{
    Scripts = 'src/ControlAddIns/assets/webmcp-bridge.js';
    StartupScript = 'src/ControlAddIns/assets/startup.js';
    StyleSheets = 'src/ControlAddIns/assets/webmcp.css';

    MinimumHeight = 104;
    RequestedHeight = 136;
    HorizontalShrink = true;
    HorizontalStretch = true;
    VerticalShrink = true;
    VerticalStretch = true;

    event ControlReady();
    event InvokeTool(RequestId: Text; ToolName: Text; ArgumentsJson: Text);

    procedure SetToolDefinitions(ToolDefinitionsJson: Text);
    procedure SetToolRegistrationError(ErrorCode: Text; ErrorMessage: Text);
    procedure CompleteToolCall(RequestId: Text; ResultJson: Text; IsError: Boolean);
}
