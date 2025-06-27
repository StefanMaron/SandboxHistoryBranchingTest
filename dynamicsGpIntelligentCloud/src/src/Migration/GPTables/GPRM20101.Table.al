namespace Microsoft.DataMigration.GP;

table 40132 "GP RM20101"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; CUSTNMBR; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(2; CPRCSTNM; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(3; DOCNUMBR; Text[21])
        {
            DataClassification = CustomerContent;
        }
        field(4; CHEKNMBR; Text[21])
        {
            DataClassification = CustomerContent;
        }
        field(5; BACHNUMB; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(6; BCHSOURC; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(7; TRXSORCE; Text[13])
        {
            DataClassification = CustomerContent;
        }
        field(8; RMDTYPAL; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(9; CSHRCTYP; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(10; CBKIDCRD; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(11; CBKIDCSH; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(12; CBKIDCHK; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(13; DUEDATE; Date)
        {
            DataClassification = CustomerContent;
        }
        field(14; DOCDATE; Date)
        {
            DataClassification = CustomerContent;
        }
        field(15; POSTDATE; Date)
        {
            DataClassification = CustomerContent;
        }
        field(16; PSTUSRID; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(17; GLPOSTDT; DateTime)
        {
            DataClassification = CustomerContent;
        }
        field(18; LSTEDTDT; DateTime)
        {
            DataClassification = CustomerContent;
        }
        field(19; LSTUSRED; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(20; ORTRXAMT; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(21; CURTRXAM; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(22; SLSAMNT; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(23; COSTAMNT; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(24; FRTAMNT; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(25; MISCAMNT; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(26; TAXAMNT; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(27; COMDLRAM; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(28; CASHAMNT; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(29; DISTKNAM; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(30; DISAVAMT; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(31; DISAVTKN; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(32; DISCRTND; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(33; DISCDATE; Date)
        {
            DataClassification = CustomerContent;
        }
        field(34; DSCDLRAM; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(35; DSCPCTAM; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(36; WROFAMNT; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(37; TRXDSCRN; Text[31])
        {
            DataClassification = CustomerContent;
        }
        field(38; CSPORNBR; Text[21])
        {
            DataClassification = CustomerContent;
        }
        field(39; SLPRSNID; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(40; SLSTERCD; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(41; DINVPDOF; Date)
        {
            DataClassification = CustomerContent;
        }
        field(42; PPSAMDED; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(43; GSTDSAMT; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(44; DELETE1; Boolean)
        {
            DataClassification = CustomerContent;
        }
        field(45; AGNGBUKT; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(46; VOIDSTTS; Integer)
        {
            DataClassification = CustomerContent;
        }
        field(47; VOIDDATE; Date)
        {
            DataClassification = CustomerContent;
        }
        field(48; TAXSCHID; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(49; CURNCYID; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(50; PYMTRMID; Text[21])
        {
            DataClassification = CustomerContent;
        }
        field(51; SHIPMTHD; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(52; TRDISAMT; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(53; SLSCHDID; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(54; FRTSCHID; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(55; MSCSCHID; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(56; NOTEINDX; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(57; Tax_Date; Date)
        {
            DataClassification = CustomerContent;
        }
        field(58; APLYWITH; Boolean)
        {
            DataClassification = CustomerContent;
        }
        field(59; SALEDATE; Date)
        {
            DataClassification = CustomerContent;
        }
        field(60; CORRCTN; Boolean)
        {
            DataClassification = CustomerContent;
        }
        field(61; SIMPLIFD; Boolean)
        {
            DataClassification = CustomerContent;
        }
        field(62; Electronic; Boolean)
        {
            DataClassification = CustomerContent;
        }
        field(63; ECTRX; Boolean)
        {
            DataClassification = CustomerContent;
        }
        field(64; BKTSLSAM; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(65; BKTFRTAM; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(66; BKTMSCAM; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(67; BackoutTradeDisc; Decimal)
        {
            DataClassification = CustomerContent;
        }
        field(68; Factoring; Boolean)
        {
            DataClassification = CustomerContent;
        }
        field(69; DIRECTDEBIT; Boolean)
        {
            DataClassification = CustomerContent;
        }
        field(70; ADRSCODE; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(71; EFTFLAG; Boolean)
        {
            DataClassification = CustomerContent;
        }
        field(72; DEX_ROW_TS; DateTime)
        {
            DataClassification = CustomerContent;
        }
        field(73; DEX_ROW_ID; Integer)
        {
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; CUSTNMBR, RMDTYPAL, DOCNUMBR)
        {
            Clustered = true;
        }
    }
}

