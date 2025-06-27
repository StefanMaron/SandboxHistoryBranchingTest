namespace Microsoft.DataMigration.GP;

table 40121 "GP IV00105"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; ITEMNMBR; Text[31])
        {
            DataClassification = CustomerContent;
        }
        field(2; CURNCYID; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(5; LISTPRCE; Decimal)
        {
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; ITEMNMBR, CURNCYID)
        {
            Clustered = true;
        }
    }
}

