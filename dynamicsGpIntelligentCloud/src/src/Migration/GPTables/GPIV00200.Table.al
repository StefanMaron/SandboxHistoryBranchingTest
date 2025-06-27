namespace Microsoft.DataMigration.GP;

table 40122 "GP IV00200"
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
        field(3; DATERECD; Date)
        {
            DataClassification = CustomerContent;
        }
        field(4; DTSEQNUM; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(5; SERLNMBR; Text[21])
        {
            DataClassification = CustomerContent;
        }
        field(9; RCTSEQNM; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(13; QTYTYPE; Integer)
        {
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; ITEMNMBR, LOCNCODE, QTYTYPE, DATERECD, DTSEQNUM)
        {
            Clustered = true;
        }
    }
}

