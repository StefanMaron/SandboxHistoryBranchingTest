namespace Microsoft.DataMigration.GP;

table 40131 "GP RM00103"
{
    DataClassification = CustomerContent;
    fields
    {
        field(3; CUSTNMBR; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(4; CUSTBLNC; Decimal)
        {
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; CUSTNMBR)
        {
            Clustered = true;
        }
    }
}

