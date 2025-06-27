namespace Microsoft.DataMigration.GP;

table 40133 "GP SY00300"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; SGMTNUMB; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(2; SGMTNAME; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(6; MNSEGIND; Boolean)
        {
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; SGMTNUMB)
        {
            Clustered = true;
        }
    }
}

