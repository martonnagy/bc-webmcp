codeunit 50121 "BC WebMCP Data Helper"
{
    Access = Internal;

    procedure AddDefaultDimensions(TableId: Integer; RecordNo: Code[20]; var Data: JsonObject)
    var
        DefaultDimension: Record "Default Dimension";
        Dimensions: JsonArray;
        Dimension: JsonObject;
    begin
        DefaultDimension.SetRange("Table ID", TableId);
        DefaultDimension.SetRange("No.", RecordNo);
        if DefaultDimension.FindSet() then
            repeat
                DefaultDimension.CalcFields("Dimension Value Name");
                Clear(Dimension);
                Dimension.Add('dimensionCode', DefaultDimension."Dimension Code");
                Dimension.Add('dimensionValueCode', DefaultDimension."Dimension Value Code");
                Dimension.Add('dimensionValueName', DefaultDimension."Dimension Value Name");
                Dimension.Add('valuePosting', Format(DefaultDimension."Value Posting"));
                Dimension.Add('allowedValuesFilter', DefaultDimension."Allowed Values Filter");
                Dimensions.Add(Dimension);
            until DefaultDimension.Next() = 0;
        Data.Add('defaultDimensions', Dimensions);
    end;
}
