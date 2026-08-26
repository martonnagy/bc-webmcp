tableextension 50111 "Vendor WebMCP" extends Vendor
{
    fields
    {
        field(50100; "Last Accessed by WebMCP"; DateTime)
        {
            Caption = 'Last Accessed by WebMCP';
            DataClassification = SystemMetadata;
            Editable = false;
        }
    }
}
