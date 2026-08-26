codeunit 50115 "BC WebMCP Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        Management: Codeunit "BC WebMCP Management";
    begin
        Management.EnsureSetup();
    end;
}
