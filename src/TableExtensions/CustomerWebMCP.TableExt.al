tableextension 50110 "Customer WebMCP" extends Customer
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
