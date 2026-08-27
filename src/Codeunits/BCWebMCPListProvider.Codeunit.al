codeunit 50120 "BC WebMCP List Provider"
{
    Access = Internal;

    procedure Execute(TableId: Integer; PageView: Text; Arguments: JsonObject; var ResultJson: Text; var ErrorCode: Text; var ErrorMessage: Text)
    begin
        Clear(ResultJson);
        Clear(ErrorCode);
        Clear(ErrorMessage);

        case TableId of
            Database::Customer:
                GetCustomers(PageView, Arguments, ResultJson, ErrorCode, ErrorMessage);
            Database::Vendor:
                GetVendors(PageView, Arguments, ResultJson, ErrorCode, ErrorMessage);
            Database::Item:
                GetItems(PageView, Arguments, ResultJson, ErrorCode, ErrorMessage);
            else begin
                ErrorCode := 'UNSUPPORTED_LIST_TABLE';
                ErrorMessage := 'The current Business Central table does not support list reading through WebMCP.';
            end;
        end;
    end;

    local procedure GetCustomers(PageView: Text; Arguments: JsonObject; var ResultJson: Text; var ErrorCode: Text; var ErrorMessage: Text)
    var
        Customer: Record Customer;
        Setup: Record "BC WebMCP Setup";
        Management: Codeunit "BC WebMCP Management";
        Result: JsonObject;
        Rows: JsonArray;
        Row: JsonObject;
        AppliedCount: Integer;
        RequestedCount: Integer;
        ReturnedCount: Integer;
        TotalCount: Integer;
        UsedDefault: Boolean;
    begin
        Management.GetSetup(Setup);
        if not ResolveListCount(Arguments, Setup, AppliedCount, RequestedCount, UsedDefault, ErrorMessage) then begin
            ErrorCode := 'INVALID_ARGUMENTS';
            exit;
        end;

        if not TrySetCustomerView(Customer, PageView) then begin
            ErrorCode := 'INVALID_LIST_VIEW';
            ErrorMessage := 'Business Central could not apply the current Customer list view.';
            exit;
        end;

        TotalCount := Customer.Count();
        if Customer.FindSet() then
            repeat
                if ReturnedCount = AppliedCount then
                    break;
                Customer.CalcFields(Balance, "Balance (LCY)", "Sales (LCY)");
                Clear(Row);
                Row.Add('number', Customer."No.");
                Row.Add('name', Customer.Name);
                Row.Add('blocked', Format(Customer.Blocked));
                Row.Add('currencyCode', Customer."Currency Code");
                Row.Add('salesLCY', Customer."Sales (LCY)");
                Row.Add('balance', Customer.Balance);
                Row.Add('balanceLCY', Customer."Balance (LCY)");
                Rows.Add(Row);
                ReturnedCount += 1;
            until Customer.Next() = 0;

        Management.AddListContext(Database::Customer, Customer.GetView(true), Result);
        Management.AddListCountMetadata(Result, RequestedCount, UsedDefault, AppliedCount, ReturnedCount, TotalCount);
        Result.Add('rows', Rows);
        Result.WriteTo(ResultJson);
    end;

    local procedure GetVendors(PageView: Text; Arguments: JsonObject; var ResultJson: Text; var ErrorCode: Text; var ErrorMessage: Text)
    var
        Vendor: Record Vendor;
        Setup: Record "BC WebMCP Setup";
        Management: Codeunit "BC WebMCP Management";
        Result: JsonObject;
        Rows: JsonArray;
        Row: JsonObject;
        AppliedCount: Integer;
        RequestedCount: Integer;
        ReturnedCount: Integer;
        TotalCount: Integer;
        UsedDefault: Boolean;
    begin
        Management.GetSetup(Setup);
        if not ResolveListCount(Arguments, Setup, AppliedCount, RequestedCount, UsedDefault, ErrorMessage) then begin
            ErrorCode := 'INVALID_ARGUMENTS';
            exit;
        end;

        if not TrySetVendorView(Vendor, PageView) then begin
            ErrorCode := 'INVALID_LIST_VIEW';
            ErrorMessage := 'Business Central could not apply the current Vendor list view.';
            exit;
        end;

        TotalCount := Vendor.Count();
        if Vendor.FindSet() then
            repeat
                if ReturnedCount = AppliedCount then
                    break;
                Vendor.CalcFields(Balance, "Balance (LCY)", "Purchases (LCY)");
                Clear(Row);
                Row.Add('number', Vendor."No.");
                Row.Add('name', Vendor.Name);
                Row.Add('blocked', Format(Vendor.Blocked));
                Row.Add('currencyCode', Vendor."Currency Code");
                Row.Add('purchasesLCY', Vendor."Purchases (LCY)");
                Row.Add('balance', Vendor.Balance);
                Row.Add('balanceLCY', Vendor."Balance (LCY)");
                Rows.Add(Row);
                ReturnedCount += 1;
            until Vendor.Next() = 0;

        Management.AddListContext(Database::Vendor, Vendor.GetView(true), Result);
        Management.AddListCountMetadata(Result, RequestedCount, UsedDefault, AppliedCount, ReturnedCount, TotalCount);
        Result.Add('rows', Rows);
        Result.WriteTo(ResultJson);
    end;

    local procedure GetItems(PageView: Text; Arguments: JsonObject; var ResultJson: Text; var ErrorCode: Text; var ErrorMessage: Text)
    var
        Item: Record Item;
        Setup: Record "BC WebMCP Setup";
        Management: Codeunit "BC WebMCP Management";
        Result: JsonObject;
        Rows: JsonArray;
        Row: JsonObject;
        AppliedCount: Integer;
        RequestedCount: Integer;
        ReturnedCount: Integer;
        TotalCount: Integer;
        UsedDefault: Boolean;
    begin
        Management.GetSetup(Setup);
        if not ResolveListCount(Arguments, Setup, AppliedCount, RequestedCount, UsedDefault, ErrorMessage) then begin
            ErrorCode := 'INVALID_ARGUMENTS';
            exit;
        end;

        if not TrySetItemView(Item, PageView) then begin
            ErrorCode := 'INVALID_LIST_VIEW';
            ErrorMessage := 'Business Central could not apply the current Item list view.';
            exit;
        end;

        TotalCount := Item.Count();
        if Item.FindSet() then
            repeat
                if ReturnedCount = AppliedCount then
                    break;
                Item.CalcFields(Inventory, "Qty. on Sales Order", "Qty. on Purch. Order");
                Clear(Row);
                Row.Add('number', Item."No.");
                Row.Add('description', Item.Description);
                Row.Add('type', Format(Item.Type));
                Row.Add('blocked', Item.Blocked);
                Row.Add('baseUnitOfMeasure', Item."Base Unit of Measure");
                Row.Add('inventory', Item.Inventory);
                Row.Add('quantityOnSalesOrder', Item."Qty. on Sales Order");
                Row.Add('quantityOnPurchaseOrder', Item."Qty. on Purch. Order");
                Row.Add('unitPrice', Item."Unit Price");
                Row.Add('unitCost', Item."Unit Cost");
                Rows.Add(Row);
                ReturnedCount += 1;
            until Item.Next() = 0;

        Management.AddListContext(Database::Item, Item.GetView(true), Result);
        Management.AddListCountMetadata(Result, RequestedCount, UsedDefault, AppliedCount, ReturnedCount, TotalCount);
        Result.Add('rows', Rows);
        Result.WriteTo(ResultJson);
    end;

    local procedure ResolveListCount(Arguments: JsonObject; Setup: Record "BC WebMCP Setup"; var AppliedCount: Integer; var RequestedCount: Integer; var UsedDefault: Boolean; var ErrorMessage: Text): Boolean
    var
        Management: Codeunit "BC WebMCP Management";
        ArgumentKeys: List of [Text];
        CountToken: JsonToken;
    begin
        ArgumentKeys := Arguments.Keys();
        if (ArgumentKeys.Count() > 1) or ((ArgumentKeys.Count() = 1) and (not Arguments.Get('count', CountToken))) then begin
            ErrorMessage := 'Only the optional count argument is supported.';
            exit(false);
        end;

        exit(Management.ResolveCount(Arguments, Setup."Default List Count", Setup."Maximum List Count", AppliedCount, RequestedCount, UsedDefault, ErrorMessage));
    end;

    [TryFunction]
    local procedure TrySetCustomerView(var Customer: Record Customer; PageView: Text)
    begin
        Customer.SetView(PageView);
    end;

    [TryFunction]
    local procedure TrySetVendorView(var Vendor: Record Vendor; PageView: Text)
    begin
        Vendor.SetView(PageView);
    end;

    [TryFunction]
    local procedure TrySetItemView(var Item: Record Item; PageView: Text)
    begin
        Item.SetView(PageView);
    end;
}
