// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.SalesOrderAgent;

using Microsoft.Finance.GeneralLedger.Setup;
using System.Agents;
using System.Reflection;

page 4402 "SOA KPI"
{
    PageType = CardPart;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = Agent;
    Permissions = tabledata "General Ledger Setup" = R;
    Caption = 'Sales Order Agent';
    InherentEntitlements = X;
    InherentPermissions = X;

    layout
    {
        area(Content)
        {
            cuegroup(Summary)
            {
                ShowCaption = false;
                field(ReceivedEmails; SOAgentKPI."Received Emails")
                {
                    ApplicationArea = All;
                    Caption = 'Received emails';
                    ToolTip = 'Specifies the total number of emails that the agent has received.';
                }
                field(Quotes; SOAgentKPI."Total Quotes Created")
                {
                    ApplicationArea = All;
                    Caption = 'Quotes created';
                    ToolTip = 'Specifies the total number of quotes that the agent has created. Both active and inactive quotes are included.';

                    trigger OnDrillDown()
                    var
                        SOAKPIEntry: Record "SOA KPI Entry";
                    begin
                        SOAKPIEntry.SetRange("Created by User ID", Rec."User Security ID");
                        SOAKPIEntry.SetRange("Record Type", SOAKPIEntry."Record Type"::"Sales Quote");
                        Page.Run(Page::"SOA KPI Entries", SOAKPIEntry);
                    end;
                }
                field(Orders; SOAgentKPI."Total Orders Created")
                {
                    ApplicationArea = All;
                    Caption = 'Orders created';
                    ToolTip = 'Specifies the total number of orders that the agent has created. Both active and inactive orders are included.';

                    trigger OnDrillDown()
                    var
                        SOAKPIEntry: Record "SOA KPI Entry";
                    begin
                        SOAKPIEntry.SetRange("Created by User ID", Rec."User Security ID");
                        SOAKPIEntry.SetRange("Record Type", SOAKPIEntry."Record Type"::"Sales Order");
                        Page.Run(Page::"SOA KPI Entries", SOAKPIEntry);
                    end;
                }
                field(TimeSavedEmailsHour; TimeSavedEmails)
                {
                    ApplicationArea = All;
                    Caption = 'Time saved on emails';
                    AutoFormatType = 11;
                    AutoFormatExpression = EmailTimeAutoFormatExpression;
                    ToolTip = 'Specifies the total time saved by the agent on emails. The time saved is calculated based on the assumption that the agent saves 3 minutes per email.';
                }
                field(TimeSavedQuotesMin; TimeSavedQuotes)
                {
                    ApplicationArea = All;
                    Caption = 'Time saved on quotes';
                    AutoFormatType = 11;
                    AutoFormatExpression = QuoteTimeAutoFormatExpression;
                    ToolTip = 'Specifies the total time saved by the agent on quotes. The time saved is calculated based on the assumption that the agent saves 6 minutes per quote.';
                }
                field(TotalAmountOrders; TotalAmountOrders)
                {
                    ApplicationArea = All;
                    AutoFormatExpression = TotalAmountOrdersFormat;
                    AutoFormatType = 11;
                    Caption = 'Amount incl. Tax';
                    ToolTip = 'Specifies the total amount of all orders that the agent has created. Both active and inactive orders are included.';
                }
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        CalculateTotals();
    end;

    local procedure CalculateTotals()
    begin
        SOAgentKPI.GetSafe();
        SOAgentKPI.UpdateEmailKPIs(Rec."User Security ID");
        GetAmount(SOAgentKPI."Total Amount Orders", TotalAmountOrders, TotalAmountOrdersFormat);
        TimeSavedEmails := GetTimeSavedEmails(EmailTimeAutoFormatExpression);
        TimeSavedQuotes := GetTimeSavedQuotes(QuoteTimeAutoFormatExpression);
    end;

    local procedure GetAmount(CurrentAmount: Decimal; var NewAmount: Decimal; var NewAmountFormat: Text)
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
        TypeHelper: Codeunit "Type Helper";
        AmountAbbreviation: Text;
        CurrencySymbol: Text[10];
        DecimalPlaces: Integer;
    begin
        ShortenAmount(CurrentAmount, NewAmount, AmountAbbreviation, DecimalPlaces);

        GeneralLedgerSetup.ReadIsolation := IsolationLevel::ReadUncommitted;
        CurrencySymbol := '';
        if GeneralLedgerSetup.Get() then
            CurrencySymbol := GeneralLedgerSetup.GetCurrencySymbol();

        NewAmountFormat := TypeHelper.GetAmountFormatWithUserLocale(CurrencySymbol, DecimalPlaces);

        if NewAmountFormat.EndsWith(CurrencySymbol) then
            NewAmountFormat := NewAmountFormat.TrimEnd(CurrencySymbol) + ' ' + AmountAbbreviation + ' ' + CurrencySymbol
        else
            NewAmountFormat += ' ' + AmountAbbreviation;
    end;

    local procedure ShortenAmount(CurrentAmount: Decimal; var NewAmount: Decimal; var AmountAbbreviation: Text; var DecimalPlaces: Integer)
    begin
        // From 1 until 99999 increment of 1
        if CurrentAmount < 100000 then begin
            AmountAbbreviation := '';
            NewAmount := Round(CurrentAmount, 1);
            DecimalPlaces := 0;
            exit;
        end;

        // From 0.1M until 9.9M increment of 0.1
        if CurrentAmount < 10000000 then begin
            AmountAbbreviation := MillionAbbreviationLbl;
            NewAmount := Round(CurrentAmount / 1000000, 0.1);
            DecimalPlaces := 1;
            exit;
        end;

        // From 10M to 99 M increment of 1
        if CurrentAmount < 100000000 then begin
            AmountAbbreviation := MillionAbbreviationLbl;
            NewAmount := Round(CurrentAmount / 1000000, 1);
            DecimalPlaces := 0;
            exit;
        end;

        // From 0.1B increment of 0.1
        AmountAbbreviation := BillionAbbreviationLbl;
        NewAmount := Round(CurrentAmount / 1000000000, 0.1);
        DecimalPlaces := 1;
    end;

    local procedure GetTimeSavedEmails(var ControlAutoFormatExpression: Text): Decimal
    begin
        exit(ConvertDurationToText(SOAgentKPI."Total Emails" * 3, ControlAutoFormatExpression)); // Estimate is - 3 minutes per email
    end;

    local procedure GetTimeSavedQuotes(var ControlAutoFormatExpression: Text): Decimal
    begin
        exit(ConvertDurationToText(SOAgentKPI."Total Quotes Created" * 6, ControlAutoFormatExpression)); // Estimate is - 6 minutes per quote
    end;

    local procedure ConvertDurationToText(MinutesSaved: Integer; var ControlAutoFormatExpression: Text): Decimal
    var
        HoursSaved: Decimal;
    begin
        ControlAutoFormatExpression := StrSubstNo(AutoFormatExpressionLbl, MinutesUnitLbl);

        if MinutesSaved < 60 then
            exit(MinutesSaved);

        ControlAutoFormatExpression := StrSubstNo(AutoFormatExpressionLbl, HoursUnitLbl);

        // Under 100 hours we track with 0.1 increment, over 100 hours we track with 0.5 increment.
        // This is to show more progress in the beginning. With larger numbers it feels odd to track with small increments.
        if MinutesSaved < 6000 then
            HoursSaved := Round(MinutesSaved / 60, 0.1)
        else
            HoursSaved := Round(MinutesSaved / 60, 0.5);

        exit(HoursSaved);
    end;

    var
        SOAgentKPI: Record "SOA KPI";
        TimeSavedEmails: Decimal;
        TimeSavedQuotes: Decimal;
        EmailTimeAutoFormatExpression: Text;
        QuoteTimeAutoFormatExpression: Text;
        TotalAmountOrdersFormat: Text;
        TotalAmountOrders: Decimal;
        AutoFormatExpressionLbl: Label '<Precision,0:1><Standard Format,0> %1', Locked = true, Comment = '%1 - is the unit hr or min';
        HoursUnitLbl: Label 'hr', Comment = 'hr represents hours, it will be shown like 23.7 hr', MaxLength = 3;
        MinutesUnitLbl: Label 'min', Comment = 'min represents minutes, it will be shown like 23 min', MaxLength = 3;
        MillionAbbreviationLbl: Label 'M', Comment = 'M is a short for million, use a local language abbreviation.', MaxLength = 5;
        BillionAbbreviationLbl: Label 'B', Comment = 'B is a short for billion, use a local language abbreviation.', MaxLength = 5;
}