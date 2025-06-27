namespace Microsoft.DataMigration.GP;

table 40123 "GP IV00300"
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
        field(5; LOTNUMBR; Text[21])
        {
            DataClassification = CustomerContent;
        }
        field(6; QTYRECVD; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(7; QTYSOLD; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(10; RCTSEQNM; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(13; QTYTYPE; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(16; EXPNDATE; Date)
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

