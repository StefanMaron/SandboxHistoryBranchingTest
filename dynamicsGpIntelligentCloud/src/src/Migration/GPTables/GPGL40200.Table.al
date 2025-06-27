namespace Microsoft.DataMigration.GP;

table 40130 "GP GL40200"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; SGMTNUMB; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(2; SGMNTID; Text[67])
        {
            DataClassification = CustomerContent;
        }
        field(3; DSCRIPTN; Text[31])
        {
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; SGMTNUMB, SGMNTID)
        {
            Clustered = true;
        }
    }
}

