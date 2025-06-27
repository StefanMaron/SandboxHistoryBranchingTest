namespace Microsoft.DataMigration.GP;

table 40127 "GP GL00100"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; ACTINDX; Integer)
        {
            DataClassification = CustomerContent;
        }
#pragma warning disable AS0086 
        field(2; ACTNUMBR_1; Text[20])
        {
            DataClassification = CustomerContent;
        }
        field(3; ACTNUMBR_2; Text[20])
        {
            DataClassification = CustomerContent;
        }
        field(4; ACTNUMBR_3; Text[20])
        {
            DataClassification = CustomerContent;
        }
        field(5; ACTNUMBR_4; Text[20])
        {
            DataClassification = CustomerContent;
        }
        field(6; ACTNUMBR_5; Text[20])
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
        field(8; MNACSGMT; Text[67])
        {
            DataClassification = CustomerContent;
        }
        field(9; ACCTTYPE; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(10; ACTDESCR; Text[51])
        {
            DataClassification = CustomerContent;
        }
        field(11; PSTNGTYP; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(12; ACCATNUM; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(13; ACTIVE; Boolean)
        {
            DataClassification = CustomerContent;
        }
        field(14; TPCLBLNC; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(33; ACCTENTR; Boolean)
        {
            DataClassification = CustomerContent;
        }
        field(36; Clear_Balance; Boolean)
        {
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; ACTINDX)
        {
            Clustered = true;
        }
    }
}

