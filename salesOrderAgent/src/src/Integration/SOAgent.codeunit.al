// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.SalesOrderAgent.Integration;

codeunit 4583 "SO Agent"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    /// <summary>
    /// Limit cannot be greater than 100
    /// </summary>
    /// <param name="Limit">Limit of the number of emails that can be processed in 24 hours</param>
    [IntegrationEvent(false, false)]
    internal procedure OnGetEmailProcessLimitPer24Hours(var limit: Integer)
    begin
    end;
}