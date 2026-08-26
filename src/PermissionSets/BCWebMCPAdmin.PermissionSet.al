permissionset 50119 "BC WEBMCP ADMIN"
{
    Assignable = true;
    Caption = 'BC WebMCP Admin';
    IncludedPermissionSets = "BC WEBMCP USER";
    Permissions =
        tabledata "BC WebMCP Setup" = RIMD,
        page "BC WebMCP Setup" = X;
}
