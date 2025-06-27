namespace Microsoft.DataMigration.GP;

using System.Email;

table 40135 "GP SY01200"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; Master_Type; Text[3])
        {
            DataClassification = CustomerContent;
        }
        field(2; Master_ID; Text[31])
        {
            DataClassification = CustomerContent;
        }
        field(3; ADRSCODE; Text[15])
        {
            DataClassification = CustomerContent;
        }
        field(4; INET1; Text[201])
        {
            DataClassification = CustomerContent;
        }
        field(5; INET2; Text[201])
        {
            DataClassification = CustomerContent;
        }
        field(16; EmailToAddress; Text[2048])
        {
            DataClassification = CustomerContent;
        }
        field(17; EmailCcAddress; Text[2048])
        {
            DataClassification = CustomerContent;
        }
        field(18; EmailBccAddress; Text[2048])
        {
            DataClassification = CustomerContent;
        }
    }
    keys
    {
        key(Key1; Master_Type, Master_ID, ADRSCODE)
        {
            Clustered = true;
        }
    }

    procedure GetSingleEmailAddress(MaxEmailAddressLength: Integer): Text
    var
        EmailAddressList: List of [Text];
        EmailAddress: Text;
    begin
        BuildEmailAddressList(EmailAddressList);

        foreach EmailAddress in EmailAddressList do
            if StrLen(EmailAddress) <= MaxEmailAddressLength then
                exit(EmailAddress);

        exit('');
    end;

    procedure GetAllEmailAddressesText(MaxResultTextLength: Integer): Text
    var
        EmailAddressList: List of [Text];
    begin
        BuildEmailAddressList(EmailAddressList);
        exit(FlattenEmailAddressList(EmailAddressList, MaxResultTextLength));
    end;

    local procedure BuildEmailAddressList(var EmailAddressList: List of [Text])
    begin
        BuildEmailAddressListFromText(Rec.EmailToAddress, EmailAddressList);
        BuildEmailAddressListFromText(Rec.EmailCcAddress, EmailAddressList);
        BuildEmailAddressListFromText(Rec.EmailBccAddress, EmailAddressList);
        BuildEmailAddressListFromText(Rec.INET1, EmailAddressList);
    end;

    local procedure BuildEmailAddressListFromText(Recipients: Text; var EmailAddressList: List of [Text])
    var
        MailManagement: Codeunit "Mail Management";
        CleanedRecipients: Text;
        TmpEmailAddressList: List of [Text];
        EmailAddress: Text;
        CleanedEmailAddress: Text;
    begin
        CleanedRecipients := DelChr(Recipients.Trim(), '<>', ';');

        if CleanedRecipients = '' then
            exit;

        TmpEmailAddressList := CleanedRecipients.Split(';');
        foreach EmailAddress in TmpEmailAddressList do begin
            CleanedEmailAddress := CleanEmailAddress(EmailAddress);
            if not AlreadyContainsEmailAddress(CleanedEmailAddress, EmailAddressList) then
                if MailManagement.CheckValidEmailAddress(CleanedEmailAddress) then
                    EmailAddressList.Add(CleanedEmailAddress)
                else
                    ClearLastError();
        end;
    end;

    local procedure AlreadyContainsEmailAddress(EmailAddress: Text; EmailAddressList: List of [Text]): Boolean
    var
        NextEmailAddress: Text;
        EmailAddressLCase: Text;
    begin
        EmailAddressLCase := EmailAddress.ToLower();
        foreach NextEmailAddress in EmailAddressList do
            if NextEmailAddress.ToLower() = EmailAddressLCase then
                exit(true);

        exit(false);
    end;

    local procedure FlattenEmailAddressList(EmailAddressList: List of [Text]; MaxResultTextLength: Integer): Text
    var
        EmailTextBuilder: TextBuilder;
        TotalTextLength: Integer;
        ProjectedTextLength: Integer;
        EmailAddress: Text;
        EmailAddressLength: Integer;
        AddSeparator: Boolean;
    begin
        TotalTextLength := 0;

        foreach EmailAddress in EmailAddressList do begin
            EmailAddressLength := StrLen(EmailAddress);
            if EmailAddressLength <= MaxResultTextLength then begin
                ProjectedTextLength := TotalTextLength + EmailAddressLength;
                if AddSeparator then
                    ProjectedTextLength := ProjectedTextLength + 1;

                if ProjectedTextLength <= MaxResultTextLength then begin
                    TotalTextLength := ProjectedTextLength;

                    if AddSeparator then
                        EmailTextBuilder.Append(';');

                    EmailTextBuilder.Append(EmailAddress);
                end;

                AddSeparator := true;
            end;
        end;

        exit(EmailTextBuilder.ToText());
    end;

    local procedure CleanEmailAddress(EmailTxt: Text): Text
    var
        LowerEmailTxt: Text;
    begin
        LowerEmailTxt := EmailTxt.ToLower().TrimEnd();
        if (LowerEmailTxt.Contains('mailto:')) then
            EmailTxt := LowerEmailTxt.Replace('mailto:', '');

        exit(EmailTxt);
    end;
}

