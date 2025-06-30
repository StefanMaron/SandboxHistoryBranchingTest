// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace System.Agents;

using System.Environment;
using Microsoft.Finance.GeneralLedger.Setup;
using Agent.SalesOrderAgent;
using System.Environment.Configuration;

codeunit 4592 "SOA Events"
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"System Action Triggers", GetAgentTaskContext, '', true, true)]
    local procedure OnGetAgentTaskContext(var Context: JsonObject)
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
    begin
        GeneralLedgerSetup.Get();
        Context.Add(CurrencyCodeTaskContextLbl, GeneralLedgerSetup."LCY Code");
        Context.Add(CurrencySymbolTaskContextLbl, GeneralLedgerSetup.GetCurrencySymbol());
    end;

    [EventSubscriber(ObjectType::Report, Report::"Copy Company", 'OnAfterCreatedNewCompanyByCopyCompany', '', false, false)]
    local procedure HandleOnAfterCreatedNewCompanyByCopyCompany(NewCompanyName: Text[30])
    var
        SOASetup: Record "SOA Setup";
    begin
        // Clear any setup information when copying a company
        SOASetup.ChangeCompany(NewCompanyName);
        SOASetup.DeleteAll();
    end;

    var
        CurrencyCodeTaskContextLbl: Label 'currencyCode', Locked = true;
        CurrencySymbolTaskContextLbl: Label 'currencySymbol', Locked = true;
}