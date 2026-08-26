#if TEST
codeunit 50200 "BC WebMCP Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure SetupIsInitializedWithExpectedDefaults()
    var
        Setup: Record "BC WebMCP Setup";
        Management: Codeunit "BC WebMCP Management";
    begin
        Setup.DeleteAll();
        Management.EnsureSetup();
        AssertTrue(Setup.Get(), 'Setup was not created.');
        AssertEqual(10, Setup."Default Ledger Entry Count", 'Unexpected default ledger count.');
        AssertEqual(100, Setup."Maximum Ledger Entry Count", 'Unexpected maximum ledger count.');
        AssertEqual(10, Setup."Default Document Count", 'Unexpected default document count.');
        AssertEqual(20, Setup."Maximum Document Count", 'Unexpected maximum document count.');
    end;

    [Test]
    procedure CountUsesDefaultWhenOmitted()
    var
        Management: Codeunit "BC WebMCP Management";
        Arguments: JsonObject;
        AppliedCount: Integer;
        RequestedCount: Integer;
        UsedDefault: Boolean;
        ErrorMessage: Text;
    begin
        AssertTrue(Management.ResolveCount(Arguments, 10, 100, AppliedCount, RequestedCount, UsedDefault, ErrorMessage), ErrorMessage);
        AssertEqual(10, AppliedCount, 'The default count was not applied.');
        AssertTrue(UsedDefault, 'usedDefault should be true.');
    end;

    [Test]
    procedure CountIsCappedAtMaximum()
    var
        Management: Codeunit "BC WebMCP Management";
        Arguments: JsonObject;
        AppliedCount: Integer;
        RequestedCount: Integer;
        UsedDefault: Boolean;
        ErrorMessage: Text;
    begin
        Arguments.Add('count', 250);
        AssertTrue(Management.ResolveCount(Arguments, 10, 100, AppliedCount, RequestedCount, UsedDefault, ErrorMessage), ErrorMessage);
        AssertEqual(250, RequestedCount, 'The requested count was not retained.');
        AssertEqual(100, AppliedCount, 'The configured maximum was not applied.');
        AssertFalse(UsedDefault, 'usedDefault should be false.');
    end;

    [Test]
    procedure NonPositiveCountIsRejected()
    var
        Management: Codeunit "BC WebMCP Management";
        Arguments: JsonObject;
        AppliedCount: Integer;
        RequestedCount: Integer;
        UsedDefault: Boolean;
        ErrorMessage: Text;
    begin
        Arguments.Add('count', 0);
        AssertFalse(Management.ResolveCount(Arguments, 10, 100, AppliedCount, RequestedCount, UsedDefault, ErrorMessage), 'A zero count should be rejected.');
    end;

    [Test]
    procedure TimestampToolUpdatesOnlyTimestampField()
    var
        Customer: Record Customer;
        Management: Codeunit "BC WebMCP Management";
        ResultJson: Text;
        OriginalName: Text[100];
        IsError: Boolean;
    begin
        Customer.Init();
        Customer."No." := CopyStr('WEBMCP-' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(Customer."No."));
        Customer.Name := 'WebMCP test customer';
        Customer.Insert();
        OriginalName := Customer.Name;

        Management.ExecuteTool(Customer.RecordId(), Management.GetSetLastAccessedToolName(), '{}', ResultJson, IsError);

        AssertFalse(IsError, ResultJson);
        Customer.Get(Customer."No.");
        AssertTrue(Customer."Last Accessed by WebMCP" <> 0DT, 'The timestamp was not updated.');
        AssertTextEqual(OriginalName, Customer.Name, 'An unrelated field was changed.');
    end;

    [Test]
    procedure CustomerDefinitionsContainSixBuiltInTools()
    var
        Customer: Record Customer;
        Management: Codeunit "BC WebMCP Management";
        Definitions: JsonArray;
        DefinitionsJson: Text;
        ErrorCode: Text;
        ErrorMessage: Text;
    begin
        Customer.Init();
        Customer."No." := CopyStr('WEBMCP-' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(Customer."No."));
        Customer.Insert();

        AssertTrue(Management.GetToolDefinitions(Customer.RecordId(), DefinitionsJson, ErrorCode, ErrorMessage), ErrorCode + ': ' + ErrorMessage);
        AssertTrue(Definitions.ReadFrom(DefinitionsJson), 'Tool definitions were not valid JSON.');
        AssertEqual(6, Definitions.Count(), 'The Customer context should expose six built-in tools.');
    end;

    [Test]
    procedure MissingContextReturnsStructuredError()
    var
        ContextRecordId: RecordId;
        Management: Codeunit "BC WebMCP Management";
        ResultJson: Text;
        IsError: Boolean;
    begin
        Management.ExecuteTool(ContextRecordId, Management.GetPrimaryKeyToolName(), '{}', ResultJson, IsError);
        AssertTrue(IsError, 'A missing context should fail.');
        AssertTrue(StrPos(ResultJson, 'NO_CURRENT_RECORD') <> 0, ResultJson);
    end;

    [Test]
    procedure PublicEventsAddAndExecuteToolForNewTable()
    var
        Currency: Record Currency;
        Management: Codeunit "BC WebMCP Management";
        Definitions: JsonArray;
        DefinitionsJson: Text;
        ResultJson: Text;
        ErrorCode: Text;
        ErrorMessage: Text;
        IsError: Boolean;
    begin
        Currency.Init();
        Currency.Code := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(Currency.Code));
        Currency.Insert();

        AssertTrue(Management.GetToolDefinitions(Currency.RecordId(), DefinitionsJson, ErrorCode, ErrorMessage), ErrorCode + ': ' + ErrorMessage);
        AssertTrue(Definitions.ReadFrom(DefinitionsJson), 'Tool definitions were not valid JSON.');
        AssertEqual(2, Definitions.Count(), 'The generic and test tools should both be registered.');

        Management.ExecuteTool(Currency.RecordId(), 'test_get_currency', '{}', ResultJson, IsError);
        AssertFalse(IsError, ResultJson);
        AssertTrue(StrPos(ResultJson, Currency.Code) <> 0, 'The custom tool did not return its current record.');
    end;

    local procedure AssertTrue(Value: Boolean; Message: Text)
    begin
        if not Value then
            Error(Message);
    end;

    local procedure AssertFalse(Value: Boolean; Message: Text)
    begin
        AssertTrue(not Value, Message);
    end;

    local procedure AssertEqual(Expected: Integer; Actual: Integer; Message: Text)
    begin
        if Expected <> Actual then
            Error('%1 Expected %2, actual %3.', Message, Expected, Actual);
    end;

    local procedure AssertTextEqual(Expected: Text; Actual: Text; Message: Text)
    begin
        if Expected <> Actual then
            Error('%1 Expected %2, actual %3.', Message, Expected, Actual);
    end;
}

codeunit 50201 "BC WebMCP Test Subscriber"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BC WebMCP Interface", 'OnDiscoverTools', '', false, false)]
    local procedure OnDiscoverTools(TableId: Integer; var ToolDefinitions: JsonArray)
    var
        WebMCPInterface: Codeunit "BC WebMCP Interface";
        InputSchema: JsonObject;
        Properties: JsonObject;
        Annotations: JsonObject;
    begin
        if TableId <> Database::Currency then
            exit;
        InputSchema.Add('type', 'object');
        InputSchema.Add('properties', Properties);
        InputSchema.Add('additionalProperties', false);
        Annotations.Add('readOnlyHint', true);
        WebMCPInterface.AddToolDefinition(ToolDefinitions, 'test_get_currency', 'Get test currency', 'Returns the current test currency.', InputSchema, Annotations);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BC WebMCP Interface", 'OnExecuteTool', '', false, false)]
    local procedure OnExecuteTool(ContextRecordId: RecordId; ToolName: Text; Arguments: JsonObject; var ResultJson: Text; var ErrorCode: Text; var ErrorMessage: Text; var IsError: Boolean; var Handled: Boolean)
    var
        Currency: Record Currency;
        RecordReference: RecordRef;
        Result: JsonObject;
    begin
        if Handled or (ToolName <> 'test_get_currency') or (ContextRecordId.TableNo() <> Database::Currency) then
            exit;
        Handled := true;
        if not RecordReference.Get(ContextRecordId) then begin
            ErrorCode := 'RECORD_NOT_FOUND';
            ErrorMessage := 'The Currency no longer exists.';
            IsError := true;
            exit;
        end;
        RecordReference.SetTable(Currency);
        Result.Add('code', Currency.Code);
        Result.WriteTo(ResultJson);
    end;
}
#endif
