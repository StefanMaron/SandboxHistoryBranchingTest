namespace Microsoft.DataMigration.GP;

table 40134 "GP SY01100"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; SERIES; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(2; SEQNUMBR; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(3; ACTINDX; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(4; PTGACDSC; Text[31])
        {
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; SERIES, SEQNUMBR)
        {
            Clustered = true;
        }
    }
}

