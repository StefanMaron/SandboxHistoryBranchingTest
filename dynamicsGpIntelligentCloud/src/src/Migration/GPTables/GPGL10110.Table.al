namespace Microsoft.DataMigration.GP;

table 40119 "GP GL10110"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; ACTINDX; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(2; YEAR1; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(3; PERIODID; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(4; Ledger_ID; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(5; PERDBLNC; Decimal)
        {
            DataClassification = CustomerContent;
        }
#pragma warning disable AS0086        
        field(6; ACTNUMBR_1; Text[20])
        {
            DataClassification = CustomerContent;
        }
        field(7; ACTNUMBR_2; Text[20])
        {
            DataClassification = CustomerContent;
        }
        field(8; ACTNUMBR_3; Text[20])
        {
            DataClassification = CustomerContent;
        }
        field(9; ACTNUMBR_4; Text[20])
        {
            DataClassification = CustomerContent;
        }
        field(10; ACTNUMBR_5; Text[20])
        {
            DataClassification = CustomerContent;
        }
        field(40; ACTNUMBR_6; Text[20])
        {
            DataClassification = CustomerContent;
        }
        field(41; ACTNUMBR_7; Text[20])
        {
            DataClassification = CustomerContent;
        }
        field(42; ACTNUMBR_8; Text[20])
        {
            DataClassification = CustomerContent;
        }
#pragma warning restore AS0086         
        field(12; DEBITAMT; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(13; CRDTAMNT; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(60; GL00100ACCTYPE1Exist; Boolean)
        {
            FieldClass = FlowField;
            CalcFormula = exist("GP GL00100" where(ACCTTYPE = const(1), ACTINDX = field(ACTINDX)));
        }
    }
    keys
    {
        key(Key1; ACTINDX, YEAR1, PERIODID, Ledger_ID)
        {
            Clustered = true;
        }
        key(Key2; YEAR1, PERIODID, ACTNUMBR_1, ACTNUMBR_2, ACTNUMBR_3, ACTNUMBR_4, ACTNUMBR_5, ACTNUMBR_6, ACTNUMBR_7, ACTNUMBR_8)
        {
        }
    }
}

