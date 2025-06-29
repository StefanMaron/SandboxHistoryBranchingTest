// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.SalesOrderAgent;

using Microsoft.Integration.Entity;

codeunit 4594 "SOA - KPI Track Agents"
{
    InherentEntitlements = X;
    InherentPermissions = X;
    EventSubscriberInstance = Manual;

    [EventSubscriber(ObjectType::Table, Database::"Sales Quote Entity Buffer", 'OnAfterInsertEvent', '', false, false)]
    local procedure InsertSalesQuoteChanged(var Rec: Record "Sales Quote Entity Buffer")
    var
        SOAKPITrackAll: Codeunit "SOA - KPI Track All";
    begin
        SOAKPITrackAll.UpdateSalesQuoteBuffer(Rec, BlankSOAKPIEntry.Status::Active, false);
    end;

    var
        BlankSOAKPIEntry: Record "SOA KPI Entry";
}