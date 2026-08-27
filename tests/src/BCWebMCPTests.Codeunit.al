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
        AssertEqual(20, Setup."Default List Count", 'Unexpected default list count.');
        AssertEqual(100, Setup."Maximum List Count", 'Unexpected maximum list count.');
    end;

    [Test]
    procedure ExistingSetupBackfillsOnlyMissingListDefaults()
    var
        Setup: Record "BC WebMCP Setup";
        Management: Codeunit "BC WebMCP Management";
    begin
        Setup.DeleteAll();
        Setup.Init();
        Setup."Primary Key" := '';
        Setup.Validate("Default Ledger Entry Count", 7);
        Setup.Validate("Maximum Ledger Entry Count", 70);
        Setup.Validate("Default Document Count", 4);
        Setup.Validate("Maximum Document Count", 40);
        Setup.Insert(true);

        Management.EnsureSetup();

        Setup.Get();
        AssertEqual(7, Setup."Default Ledger Entry Count", 'The existing ledger default was changed.');
        AssertEqual(70, Setup."Maximum Ledger Entry Count", 'The existing ledger maximum was changed.');
        AssertEqual(4, Setup."Default Document Count", 'The existing document default was changed.');
        AssertEqual(40, Setup."Maximum Document Count", 'The existing document maximum was changed.');
        AssertEqual(20, Setup."Default List Count", 'The missing list default was not backfilled.');
        AssertEqual(100, Setup."Maximum List Count", 'The missing list maximum was not backfilled.');
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
    procedure CustomerListDefinitionsContainOnlyCurrentListTool()
    var
        Management: Codeunit "BC WebMCP Management";
        Definitions: JsonArray;
        DefinitionsJson: Text;
        ErrorCode: Text;
        ErrorMessage: Text;
    begin
        AssertTrue(Management.GetListToolDefinitions(Database::Customer, DefinitionsJson, ErrorCode, ErrorMessage), ErrorCode + ': ' + ErrorMessage);
        AssertTrue(Definitions.ReadFrom(DefinitionsJson), 'List tool definitions were not valid JSON.');
        AssertEqual(1, Definitions.Count(), 'The Customer list context should expose one tool.');
        AssertTrue(StrPos(DefinitionsJson, Management.GetCurrentListToolName()) <> 0, 'The current-list tool was not registered.');
        AssertTrue(StrPos(DefinitionsJson, 'totalCount') <> 0, 'The definition does not describe total-count metadata.');
        AssertTrue(StrPos(DefinitionsJson, 'isLimited') <> 0, 'The definition does not describe limited-result handling.');
    end;

    [Test]
    procedure CustomerListRespectsFilterOrderAndReportsLimitedResult()
    var
        Customer: Record Customer;
        Management: Codeunit "BC WebMCP Management";
        BaseNo: Code[20];
        ResultJson: Text;
        IsError: Boolean;
    begin
        BaseNo := NewBaseNo();
        InsertCustomer(BaseNo + 'A', 'Alpha');
        InsertCustomer(BaseNo + 'B', 'Charlie');
        InsertCustomer(BaseNo + 'C', 'Bravo');

        Customer.SetFilter("No.", BaseNo + '*');
        Customer.SetCurrentKey(Name);
        Customer.Ascending(false);
        Management.ExecuteListTool(Database::Customer, Customer.GetView(false), Management.GetCurrentListToolName(), '{"count":2}', ResultJson, IsError);

        AssertFalse(IsError, ResultJson);
        AssertJsonInteger(ResultJson, 'requestedCount', 2);
        AssertJsonInteger(ResultJson, 'appliedCount', 2);
        AssertJsonInteger(ResultJson, 'returnedCount', 2);
        AssertJsonInteger(ResultJson, 'totalCount', 3);
        AssertJsonBoolean(ResultJson, 'isLimited', true);
        AssertJsonBoolean(ResultJson, 'hasMore', true);
        AssertTextEqual('Charlie', GetRowText(ResultJson, 0, 'name'), 'The first row did not follow the descending page order.');
        AssertTextEqual('Bravo', GetRowText(ResultJson, 1, 'name'), 'The second row did not follow the descending page order.');
        AssertTrue(StrPos(ResultJson, 'salesLCY') <> 0, 'Customer sales were not included.');
        AssertTrue(StrPos(ResultJson, 'balanceLCY') <> 0, 'Customer balance was not included.');
        Customer.Get(BaseNo + 'A');
        AssertTrue(Customer."Last Accessed by WebMCP" = 0DT, 'Reading a list changed the WebMCP timestamp.');
    end;

    [Test]
    procedure CustomerListReportsCompleteFilteredResult()
    var
        Customer: Record Customer;
        Management: Codeunit "BC WebMCP Management";
        BaseNo: Code[20];
        ResultJson: Text;
        IsError: Boolean;
    begin
        BaseNo := NewBaseNo();
        InsertCustomer(BaseNo + 'A', 'Alpha');
        InsertCustomer(BaseNo + 'B', 'Bravo');
        InsertCustomer(BaseNo + 'C', 'Charlie');

        Customer.SetFilter("No.", BaseNo + 'A|' + BaseNo + 'C');
        Management.ExecuteListTool(Database::Customer, Customer.GetView(false), Management.GetCurrentListToolName(), '{"count":10}', ResultJson, IsError);

        AssertFalse(IsError, ResultJson);
        AssertJsonInteger(ResultJson, 'returnedCount', 2);
        AssertJsonInteger(ResultJson, 'totalCount', 2);
        AssertJsonBoolean(ResultJson, 'isLimited', false);
        AssertJsonBoolean(ResultJson, 'hasMore', false);
    end;

    [Test]
    procedure CustomerListConfiguredMaximumReportsLimitedResult()
    var
        Customer: Record Customer;
        Setup: Record "BC WebMCP Setup";
        Management: Codeunit "BC WebMCP Management";
        BaseNo: Code[20];
        ResultJson: Text;
        IsError: Boolean;
    begin
        Management.GetSetup(Setup);
        Setup.Validate("Default List Count", 2);
        Setup.Validate("Maximum List Count", 2);
        Setup.Modify(true);
        BaseNo := NewBaseNo();
        InsertCustomer(BaseNo + 'A', 'Alpha');
        InsertCustomer(BaseNo + 'B', 'Bravo');
        InsertCustomer(BaseNo + 'C', 'Charlie');

        Customer.SetFilter("No.", BaseNo + '*');
        Management.ExecuteListTool(Database::Customer, Customer.GetView(false), Management.GetCurrentListToolName(), '{"count":10}', ResultJson, IsError);

        AssertFalse(IsError, ResultJson);
        AssertJsonInteger(ResultJson, 'requestedCount', 10);
        AssertJsonInteger(ResultJson, 'appliedCount', 2);
        AssertJsonInteger(ResultJson, 'returnedCount', 2);
        AssertJsonInteger(ResultJson, 'totalCount', 3);
        AssertJsonBoolean(ResultJson, 'isLimited', true);
        AssertJsonBoolean(ResultJson, 'hasMore', true);
    end;

    [Test]
    procedure CustomerListEmptyViewReportsCompleteEmptyResult()
    var
        Customer: Record Customer;
        Management: Codeunit "BC WebMCP Management";
        ResultJson: Text;
        IsError: Boolean;
    begin
        Customer.SetRange("No.", NewBaseNo());
        Management.ExecuteListTool(Database::Customer, Customer.GetView(false), Management.GetCurrentListToolName(), '{}', ResultJson, IsError);

        AssertFalse(IsError, ResultJson);
        AssertJsonInteger(ResultJson, 'returnedCount', 0);
        AssertJsonInteger(ResultJson, 'totalCount', 0);
        AssertJsonBoolean(ResultJson, 'isLimited', false);
        AssertJsonBoolean(ResultJson, 'hasMore', false);
        AssertTrue(StrPos(ResultJson, '"rows":[]') <> 0, 'The empty view did not return an empty rows array.');
    end;

    [Test]
    procedure ItemListIncludesStockAndPriceFacts()
    var
        Item: Record Item;
        Management: Codeunit "BC WebMCP Management";
        ItemNo: Code[20];
        ResultJson: Text;
        IsError: Boolean;
    begin
        ItemNo := NewBaseNo();
        Item.Init();
        Item."No." := ItemNo;
        Item.Description := 'WebMCP list item';
        Item."Unit Price" := 25;
        Item."Unit Cost" := 10;
        Item.Insert();

        Item.SetRange("No.", ItemNo);
        Management.ExecuteListTool(Database::Item, Item.GetView(false), Management.GetCurrentListToolName(), '{}', ResultJson, IsError);

        AssertFalse(IsError, ResultJson);
        AssertJsonInteger(ResultJson, 'totalCount', 1);
        AssertTrue(StrPos(ResultJson, 'inventory') <> 0, 'Item inventory was not included.');
        AssertTrue(StrPos(ResultJson, 'quantityOnSalesOrder') <> 0, 'Item sales-order quantity was not included.');
        AssertTrue(StrPos(ResultJson, 'quantityOnPurchaseOrder') <> 0, 'Item purchase-order quantity was not included.');
        AssertTrue(StrPos(ResultJson, 'unitPrice') <> 0, 'Item unit price was not included.');
        AssertTrue(StrPos(ResultJson, 'unitCost') <> 0, 'Item unit cost was not included.');
    end;

    [Test]
    procedure ListErrorsAreStructured()
    var
        Customer: Record Customer;
        Management: Codeunit "BC WebMCP Management";
        ResultJson: Text;
        IsError: Boolean;
    begin
        Management.ExecuteListTool(0, '', Management.GetCurrentListToolName(), '{}', ResultJson, IsError);
        AssertTrue(IsError, 'Missing list context should fail.');
        AssertTrue(StrPos(ResultJson, 'NO_LIST_CONTEXT') <> 0, ResultJson);

        Management.ExecuteListTool(Database::Currency, '', Management.GetCurrentListToolName(), '{}', ResultJson, IsError);
        AssertTrue(IsError, 'An unsupported list table should fail.');
        AssertTrue(StrPos(ResultJson, 'UNSUPPORTED_LIST_TABLE') <> 0, ResultJson);

        Management.ExecuteListTool(Database::Customer, Customer.GetView(false), Management.GetCurrentListToolName(), '{"unexpected":true}', ResultJson, IsError);
        AssertTrue(IsError, 'An unexpected list argument should fail.');
        AssertTrue(StrPos(ResultJson, 'INVALID_ARGUMENTS') <> 0, ResultJson);

        Management.ExecuteListTool(Database::Customer, Customer.GetView(false), Management.GetCurrentListToolName(), '{"count":"ten"}', ResultJson, IsError);
        AssertTrue(IsError, 'A non-integer list count should fail.');
        AssertTrue(StrPos(ResultJson, 'INVALID_ARGUMENTS') <> 0, ResultJson);

        Management.ExecuteListTool(Database::Customer, 'not a valid view', Management.GetCurrentListToolName(), '{}', ResultJson, IsError);
        AssertTrue(IsError, 'An invalid list view should fail.');
        AssertTrue(StrPos(ResultJson, 'INVALID_LIST_VIEW') <> 0, ResultJson);
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

    local procedure NewBaseNo(): Code[20]
    begin
        exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 18));
    end;

    local procedure InsertCustomer(CustomerNo: Code[20]; CustomerName: Text[100])
    var
        Customer: Record Customer;
    begin
        Customer.Init();
        Customer."No." := CustomerNo;
        Customer.Name := CustomerName;
        Customer.Insert();
    end;

    local procedure AssertJsonInteger(JsonText: Text; PropertyName: Text; Expected: Integer)
    var
        Json: JsonObject;
        Token: JsonToken;
    begin
        AssertTrue(Json.ReadFrom(JsonText), 'The result was not a valid JSON object.');
        AssertTrue(Json.Get(PropertyName, Token), 'The result did not contain ' + PropertyName + '.');
        AssertEqual(Expected, Token.AsValue().AsInteger(), 'Unexpected ' + PropertyName + '.');
    end;

    local procedure AssertJsonBoolean(JsonText: Text; PropertyName: Text; Expected: Boolean)
    var
        Json: JsonObject;
        Token: JsonToken;
    begin
        AssertTrue(Json.ReadFrom(JsonText), 'The result was not a valid JSON object.');
        AssertTrue(Json.Get(PropertyName, Token), 'The result did not contain ' + PropertyName + '.');
        if Token.AsValue().AsBoolean() <> Expected then
            Error('Unexpected %1. Expected %2, actual %3.', PropertyName, Expected, Token.AsValue().AsBoolean());
    end;

    local procedure GetRowText(JsonText: Text; RowIndex: Integer; PropertyName: Text): Text
    var
        Json: JsonObject;
        Rows: JsonArray;
        Row: JsonObject;
        Token: JsonToken;
    begin
        AssertTrue(Json.ReadFrom(JsonText), 'The result was not a valid JSON object.');
        AssertTrue(Json.Get('rows', Token), 'The result did not contain rows.');
        Rows := Token.AsArray();
        AssertTrue(Rows.Get(RowIndex, Token), 'The requested row was not returned.');
        Row := Token.AsObject();
        AssertTrue(Row.Get(PropertyName, Token), 'The row did not contain ' + PropertyName + '.');
        exit(Token.AsValue().AsText());
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
