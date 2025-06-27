namespace Microsoft.DataMigration.GP;

table 40120 "GP IV00102"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; ITEMNMBR; Text[31])
        {
            DataClassification = CustomerContent;
        }
        field(2; LOCNCODE; Text[11])
        {
            DataClassification = CustomerContent;
        }
        field(4; RCRDTYPE; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(21; QTYONHND; Decimal)
        {
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; ITEMNMBR, RCRDTYPE, LOCNCODE)
        {
            Clustered = true;
        }
    }
}

