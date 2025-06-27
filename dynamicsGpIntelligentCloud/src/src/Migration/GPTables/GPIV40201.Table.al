namespace Microsoft.DataMigration.GP;

table 40125 "GP IV40201"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; UOMSCHDL; Text[11])
        {
            DataClassification = CustomerContent;
        }
        field(4; BASEUOFM; Text[9])
        {
            DataClassification = CustomerContent;
        }

    }
    keys
    {
        key(Key1; UOMSCHDL)
        {
            Clustered = true;
        }
    }
}

