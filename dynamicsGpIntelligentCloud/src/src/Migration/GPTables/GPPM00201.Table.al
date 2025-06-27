namespace Microsoft.DataMigration.GP;

table 40128 "GP PM00201"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; VENDORID; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(3; CURRBLNC; Decimal)
        {
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; VENDORID)
        {
            Clustered = true;
        }
    }
}

