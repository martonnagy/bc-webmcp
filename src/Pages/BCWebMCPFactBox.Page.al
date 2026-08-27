page 50100 "BC WebMCP FactBox"
{
    PageType = CardPart;
    ApplicationArea = All;
    Caption = 'WebMCP';
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            field(LastAccessedByWebMCP; LastAccessed)
            {
                ApplicationArea = All;
                Caption = 'Last Accessed by WebMCP';
                Editable = false;
                ToolTip = 'Specifies when the current record was last explicitly marked as accessed through WebMCP.';
                Visible = LastAccessedVisible;
            }
            field(LastAccessedByWebMCPNever; LastAccessedNever)
            {
                ApplicationArea = All;
                Caption = 'Last Accessed by WebMCP';
                Editable = false;
                ToolTip = 'Specifies that the current record has never been explicitly marked as accessed through WebMCP.';
                Visible = LastAccessedNeverVisible;
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
                    if ListContext then
                        Management.ExecuteListTool(ContextTableId, ContextView, ToolName, ArgumentsJson, ResultJson, IsError)
                    else
                        Management.ExecuteTool(ContextRecordId, ToolName, ArgumentsJson, ResultJson, IsError);
                    CurrPage.WebMCPBridge.CompleteToolCall(RequestId, ResultJson, IsError);

                    if (not ListContext) and (not IsError) and (ToolName = Management.GetSetLastAccessedToolName()) then begin
                        RefreshLastAccessed();
                        CurrPage.Update(false);
                    end;
                end;
            }
        }
    }

    procedure SetContext(NewContextRecordId: RecordId)
    begin
        ListContext := false;
        Clear(ContextTableId);
        Clear(ContextView);
        ContextRecordId := NewContextRecordId;
        RefreshLastAccessed();
        RefreshToolDefinitions();
        CurrPage.Update(false);
    end;

    procedure SetListContext(NewContextTableId: Integer; NewContextView: Text)
    begin
        ListContext := true;
        Clear(ContextRecordId);
        ContextTableId := NewContextTableId;
        ContextView := NewContextView;
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

        if ListContext then begin
            if not Management.GetListToolDefinitions(ContextTableId, ToolDefinitionsJson, ErrorCode, ErrorMessage) then begin
                CurrPage.WebMCPBridge.SetToolRegistrationError(ErrorCode, ErrorMessage);
                exit;
            end;
        end else
            if not Management.GetToolDefinitions(ContextRecordId, ToolDefinitionsJson, ErrorCode, ErrorMessage) then begin
                CurrPage.WebMCPBridge.SetToolRegistrationError(ErrorCode, ErrorMessage);
                exit;
            end;

        CurrPage.WebMCPBridge.SetToolDefinitions(ToolDefinitionsJson);
    end;

    local procedure RefreshLastAccessed()
    var
        Management: Codeunit "BC WebMCP Management";
    begin
        LastAccessed := 0DT;
        LastAccessedVisible := false;
        LastAccessedNeverVisible := true;
        LastAccessedNever := 'Never';

        if ListContext then begin
            LastAccessedNeverVisible := false;
            exit;
        end;

        if Management.GetLastAccessed(ContextRecordId, LastAccessed) then
            if LastAccessed <> 0DT then begin
                LastAccessedVisible := true;
                LastAccessedNeverVisible := false;
            end;
    end;

    var
        ContextRecordId: RecordId;
        ContextTableId: Integer;
        ContextView: Text;
        LastAccessed: DateTime;
        LastAccessedNever: Text;
        LastAccessedVisible: Boolean;
        LastAccessedNeverVisible: Boolean;
        BridgeReady: Boolean;
        ListContext: Boolean;
}
