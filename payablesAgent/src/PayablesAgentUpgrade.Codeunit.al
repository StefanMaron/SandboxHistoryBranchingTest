// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

#pragma warning disable AS0007
namespace Microsoft.Agent.SalesOrderAgent;

using System.Upgrade;
using Agent.PayablesAgent;

codeunit 3305 "Payables Agent Upgrade"
{
    Access = Internal;
    Subtype = Upgrade;

    InherentEntitlements = X;
    InherentPermissions = X;

    trigger OnUpgradePerDatabase()
    begin
        // For private preview do not run register capability on upgrade. 
        // Ok, since it will be added when Copilot Capabilities page is opened.
        // Early preview will need to be enabled through the Copilot Capabilities page.
        // RegisterCapability();
    end;

#pragma warning disable AA0228
    local procedure RegisterCapability()
    var
        PayablesAgent: Codeunit "Payables Agent";
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if not UpgradeTag.HasUpgradeTag(GetRegisterPayablesAgentCapabilityTag()) then begin
            PayablesAgent.RegisterCapability();

            UpgradeTag.SetUpgradeTag(GetRegisterPayablesAgentCapabilityTag());
        end;
    end;
#pragma warning restore AA0228

    local procedure GetRegisterPayablesAgentCapabilityTag(): Code[250]
    begin
        exit('MS-575373-PayablesAgentCapability-20250507');
    end;

}