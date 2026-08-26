controladdin "BC WebMCP Bridge"
{
    Scripts = 'src/ControlAddIns/assets/webmcp-bridge.js';
    StartupScript = 'src/ControlAddIns/assets/startup.js';
    StyleSheets = 'src/ControlAddIns/assets/webmcp.css';

    MinimumHeight = 120;
    RequestedHeight = 180;
    HorizontalShrink = true;
    HorizontalStretch = true;
    VerticalShrink = true;
    VerticalStretch = false;

    event InvokeTool(RequestId: Text; ToolName: Text; ArgumentsJson: Text);

    procedure CompleteToolCall(RequestId: Text; ResultJson: Text; IsError: Boolean);
}
