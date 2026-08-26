codeunit 50106 "BC WebMCP Customer Provider"
{
    Access = Internal;

    procedure Execute(ContextRecordId: RecordId; ToolName: Text; Arguments: JsonObject; var ResultJson: Text; var ErrorCode: Text; var ErrorMessage: Text): Boolean
    var
        Management: Codeunit "BC WebMCP Management";
    begin
        Clear(ErrorCode);
        Clear(ErrorMessage);

        if ToolName = Management.GetRecordInfoToolName() then begin
            GetRecordInfo(ContextRecordId, ResultJson);
            exit(true);
        end;
        if ToolName = Management.GetFinancialInfoToolName() then begin
            GetFinancialInfo(ContextRecordId, ResultJson);
            exit(true);
        end;
        if ToolName = Management.GetLedgerEntriesToolName() then begin
            GetLedgerEntries(ContextRecordId, Arguments, ResultJson, ErrorCode, ErrorMessage);
            exit(true);
        end;
        if ToolName = Management.GetDocumentsToolName() then begin
            GetDocuments(ContextRecordId, Arguments, ResultJson, ErrorCode, ErrorMessage);
            exit(true);
        end;
        if ToolName = Management.GetSetLastAccessedToolName() then begin
            SetLastAccessed(ContextRecordId, ResultJson);
            exit(true);
        end;
        exit(false);
    end;

    local procedure GetRecordInfo(ContextRecordId: RecordId; var ResultJson: Text)
    var
        Customer: Record Customer;
        Management: Codeunit "BC WebMCP Management";
        RecordReference: RecordRef;
        Result: JsonObject;
        Data: JsonObject;
    begin
        RecordReference.Get(ContextRecordId);
        RecordReference.SetTable(Customer);
        Customer.CalcFields(Balance);
        Management.AddRecordContext(RecordReference, Result);
        Data.Add('recordType', 'customer');
        Data.Add('number', Customer."No.");
        Data.Add('name', Customer.Name);
        Data.Add('name2', Customer."Name 2");
        Data.Add('blocked', Format(Customer.Blocked));
        Data.Add('address', Customer.Address);
        Data.Add('address2', Customer."Address 2");
        Data.Add('city', Customer.City);
        Data.Add('postCode', Customer."Post Code");
        Data.Add('countryRegionCode', Customer."Country/Region Code");
        Data.Add('contact', Customer.Contact);
        Data.Add('phoneNo', Customer."Phone No.");
        Data.Add('email', Customer."E-Mail");
        Data.Add('currencyCode', Customer."Currency Code");
        Data.Add('balance', Customer.Balance);
        if Customer."Last Accessed by WebMCP" <> 0DT then
            Data.Add('lastAccessedByWebMCP', Customer."Last Accessed by WebMCP");
        Result.Add('data', Data);
        Result.WriteTo(ResultJson);
    end;

    local procedure GetFinancialInfo(ContextRecordId: RecordId; var ResultJson: Text)
    var
        Customer: Record Customer;
        Management: Codeunit "BC WebMCP Management";
        DataHelper: Codeunit "BC WebMCP Data Helper";
        RecordReference: RecordRef;
        Result: JsonObject;
        Data: JsonObject;
        PostingGroups: JsonObject;
    begin
        RecordReference.Get(ContextRecordId);
        RecordReference.SetTable(Customer);
        Customer.CalcFields(Balance, "Balance (LCY)", "Balance Due", "Balance Due (LCY)");
        Management.AddRecordContext(RecordReference, Result);
        Data.Add('recordType', 'customer');
        Data.Add('currencyCode', Customer."Currency Code");
        Data.Add('balance', Customer.Balance);
        Data.Add('balanceLCY', Customer."Balance (LCY)");
        Data.Add('balanceDue', Customer."Balance Due");
        Data.Add('balanceDueLCY', Customer."Balance Due (LCY)");
        Data.Add('creditLimitLCY', Customer."Credit Limit (LCY)");
        Data.Add('paymentTermsCode', Customer."Payment Terms Code");
        Data.Add('paymentMethodCode', Customer."Payment Method Code");
        PostingGroups.Add('customerPostingGroup', Customer."Customer Posting Group");
        PostingGroups.Add('generalBusinessPostingGroup', Customer."Gen. Bus. Posting Group");
        PostingGroups.Add('vatBusinessPostingGroup', Customer."VAT Bus. Posting Group");
        Data.Add('postingGroups', PostingGroups);
        DataHelper.AddDefaultDimensions(Database::Customer, Customer."No.", Data);
        Result.Add('data', Data);
        Result.WriteTo(ResultJson);
    end;

    local procedure GetLedgerEntries(ContextRecordId: RecordId; Arguments: JsonObject; var ResultJson: Text; var ErrorCode: Text; var ErrorMessage: Text)
    var
        Customer: Record Customer;
        CustomerLedgerEntry: Record "Cust. Ledger Entry";
        Setup: Record "BC WebMCP Setup";
        Management: Codeunit "BC WebMCP Management";
        RecordReference: RecordRef;
        Result: JsonObject;
        Entries: JsonArray;
        Entry: JsonObject;
        AppliedCount: Integer;
        RequestedCount: Integer;
        ReturnedCount: Integer;
        UsedDefault: Boolean;
        HasMore: Boolean;
    begin
        Management.GetSetup(Setup);
        if not Management.ResolveCount(Arguments, Setup."Default Ledger Entry Count", Setup."Maximum Ledger Entry Count", AppliedCount, RequestedCount, UsedDefault, ErrorMessage) then begin
            ErrorCode := 'INVALID_ARGUMENTS';
            exit;
        end;

        RecordReference.Get(ContextRecordId);
        RecordReference.SetTable(Customer);
        CustomerLedgerEntry.SetRange("Customer No.", Customer."No.");
        CustomerLedgerEntry.SetCurrentKey("Entry No.");
        CustomerLedgerEntry.Ascending(false);
        if CustomerLedgerEntry.FindSet() then
            repeat
                if ReturnedCount = AppliedCount then begin
                    HasMore := true;
                    break;
                end;
                CustomerLedgerEntry.CalcFields(Amount, "Remaining Amount", "Amount (LCY)", "Remaining Amt. (LCY)");
                Clear(Entry);
                Entry.Add('entryNo', CustomerLedgerEntry."Entry No.");
                Entry.Add('postingDate', CustomerLedgerEntry."Posting Date");
                Entry.Add('documentDate', CustomerLedgerEntry."Document Date");
                Entry.Add('documentType', Format(CustomerLedgerEntry."Document Type"));
                Entry.Add('documentNo', CustomerLedgerEntry."Document No.");
                Entry.Add('externalDocumentNo', CustomerLedgerEntry."External Document No.");
                Entry.Add('description', CustomerLedgerEntry.Description);
                Entry.Add('currencyCode', CustomerLedgerEntry."Currency Code");
                Entry.Add('amount', CustomerLedgerEntry.Amount);
                Entry.Add('remainingAmount', CustomerLedgerEntry."Remaining Amount");
                Entry.Add('amountLCY', CustomerLedgerEntry."Amount (LCY)");
                Entry.Add('remainingAmountLCY', CustomerLedgerEntry."Remaining Amt. (LCY)");
                Entry.Add('dueDate', CustomerLedgerEntry."Due Date");
                Entry.Add('open', CustomerLedgerEntry.Open);
                Entries.Add(Entry);
                ReturnedCount += 1;
            until CustomerLedgerEntry.Next() = 0;

        Management.AddRecordContext(RecordReference, Result);
        Management.AddCountMetadata(Result, RequestedCount, UsedDefault, AppliedCount, ReturnedCount, HasMore);
        Result.Add('entries', Entries);
        Result.WriteTo(ResultJson);
    end;

    local procedure GetDocuments(ContextRecordId: RecordId; Arguments: JsonObject; var ResultJson: Text; var ErrorCode: Text; var ErrorMessage: Text)
    var
        DocumentProvider: Codeunit "BC WebMCP Document Provider";
    begin
        DocumentProvider.GetDocuments(ContextRecordId, Arguments, ResultJson, ErrorCode, ErrorMessage);
    end;

    local procedure SetLastAccessed(ContextRecordId: RecordId; var ResultJson: Text)
    var
        Customer: Record Customer;
        Management: Codeunit "BC WebMCP Management";
        RecordReference: RecordRef;
        Result: JsonObject;
        Data: JsonObject;
        PreviousValue: DateTime;
        NewValue: DateTime;
    begin
        RecordReference.Get(ContextRecordId);
        RecordReference.SetTable(Customer);
        PreviousValue := Customer."Last Accessed by WebMCP";
        NewValue := CurrentDateTime();
        Customer."Last Accessed by WebMCP" := NewValue;
        Customer.Modify(false);
        RecordReference.GetTable(Customer);
        Management.AddRecordContext(RecordReference, Result);
        Data.Add('previousLastAccessedByWebMCP', PreviousValue);
        Data.Add('lastAccessedByWebMCP', NewValue);
        Result.Add('data', Data);
        Result.WriteTo(ResultJson);
    end;
}
