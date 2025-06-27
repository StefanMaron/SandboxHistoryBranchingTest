namespace Microsoft.DataMigration.GP;

table 40136 "GP SY03300"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; PYMTRMID; Text[21])
        {
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; PYMTRMID)
        {
            Clustered = true;
        }
    }
}

