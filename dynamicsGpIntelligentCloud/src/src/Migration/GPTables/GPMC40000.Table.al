namespace Microsoft.DataMigration.GP;

table 40126 "GP MC40000"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; FUNLCURR; Text[15])
        {
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; FUNLCURR)
        {
            Clustered = true;
        }
    }
}

