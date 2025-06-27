namespace Microsoft.DataMigration.GP;

table 40124 "GP IV10200"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; ITEMNMBR; Text[31])
        {
            DataClassification = CustomerContent;
        }
        field(2; TRXLOCTN; Text[11])
        {
            DataClassification = CustomerContent;
        }
        field(3; DATERECD; Date)
        {
            DataClassification = CustomerContent;
        }
        field(4; RCTSEQNM; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(5; RCPTSOLD; Boolean)
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
        field(12; RCPTNMBR; Text[21])
        {
            DataClassification = CustomerContent;
        }
        field(15; UNITCOST; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(16; QTYTYPE; Integer)
        {
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; ITEMNMBR, TRXLOCTN, QTYTYPE, DATERECD, RCTSEQNM)
        {
            Clustered = true;
        }
    }
}

