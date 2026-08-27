permissionset 50118 "BC WEBMCP USER"
{
    Assignable = true;
    Caption = 'BC WebMCP User';
    Permissions =
        tabledata "BC WebMCP Setup" = R,
        table "BC WebMCP Setup" = X,
        table "BC WebMCP Document Buffer" = X,
        codeunit "BC WebMCP Management" = X,
        codeunit "BC WebMCP Interface" = X,
        codeunit "BC WebMCP Customer Provider" = X,
        codeunit "BC WebMCP Vendor Provider" = X,
        codeunit "BC WebMCP Item Provider" = X,
        codeunit "BC WebMCP List Provider" = X,
        codeunit "BC WebMCP Document Provider" = X,
        codeunit "BC WebMCP Data Helper" = X,
        codeunit "BC WebMCP Doc. Serializer" = X,
        page "BC WebMCP FactBox" = X;
}
