codeunit 50116 "BC WebMCP Upgrade"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        Management: Codeunit "BC WebMCP Management";
    begin
        Management.EnsureSetup();
    end;
}
