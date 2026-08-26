page 50100 "BC WebMCP FactBox"
{
    PageType = CardPart;
    ApplicationArea = All;
    Caption = 'BC WebMCP';
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            field(LastAccessedByWebMCP; LastAccessedDisplay)
            {
                ApplicationArea = All;
                Caption = 'Last Accessed by WebMCP';
                Editable = false;
                ToolTip = 'Specifies when the current record was last explicitly marked as accessed through WebMCP.';
            }
            usercontrol(WebMCPBridge; "BC WebMCP Bridge")
            {
                ApplicationArea = All;

                trigger ControlReady()
                begin
                    BridgeReady := true;
                    RefreshToolDefinitions();
                end;

                trigger InvokeTool(RequestId: Text; ToolName: Text; ArgumentsJson: Text)
                var
                    Management: Codeunit "BC WebMCP Management";
                    ResultJson: Text;
                    IsError: Boolean;
                begin
                    Management.ExecuteTool(ContextRecordId, ToolName, ArgumentsJson, ResultJson, IsError);
                    CurrPage.WebMCPBridge.CompleteToolCall(RequestId, ResultJson, IsError);

                    if (not IsError) and (ToolName = Management.GetSetLastAccessedToolName()) then begin
                        RefreshLastAccessed();
                        CurrPage.Update(false);
                    end;
                end;
            }
        }
    }

    procedure SetContext(NewContextRecordId: RecordId)
    begin
        ContextRecordId := NewContextRecordId;
        RefreshLastAccessed();
        RefreshToolDefinitions();
        CurrPage.Update(false);
    end;

    local procedure RefreshToolDefinitions()
    var
        Management: Codeunit "BC WebMCP Management";
        ToolDefinitionsJson: Text;
        ErrorCode: Text;
        ErrorMessage: Text;
    begin
        if not BridgeReady then
            exit;

        if not Management.GetToolDefinitions(ContextRecordId, ToolDefinitionsJson, ErrorCode, ErrorMessage) then begin
            CurrPage.WebMCPBridge.SetToolRegistrationError(ErrorCode, ErrorMessage);
            exit;
        end;

        CurrPage.WebMCPBridge.SetToolDefinitions(ToolDefinitionsJson);
    end;

    local procedure RefreshLastAccessed()
    var
        Management: Codeunit "BC WebMCP Management";
        LastAccessed: DateTime;
    begin
        LastAccessedDisplay := 'Never';
        if Management.GetLastAccessed(ContextRecordId, LastAccessed) then
            if LastAccessed <> 0DT then
                LastAccessedDisplay := Format(LastAccessed, 0, 9);
    end;

    var
        ContextRecordId: RecordId;
        LastAccessedDisplay: Text;
        BridgeReady: Boolean;
}
