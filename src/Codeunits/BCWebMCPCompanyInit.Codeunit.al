codeunit 50117 "BC WebMCP Company Init."
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Company-Initialize", 'OnCompanyInitialize', '', false, false)]
    local procedure OnCompanyInitialize()
    var
        Management: Codeunit "BC WebMCP Management";
    begin
        Management.EnsureSetup();
    end;
}
