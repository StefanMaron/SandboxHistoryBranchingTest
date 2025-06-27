// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

#pragma warning disable AS0007
namespace Microsoft.Agent.SalesOrderAgent;

using System.Agents;
using System.AI;

codeunit 4401 "SOA Metadata Provider" implements IAgentMetadata, IAgentFactory
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    procedure GetInitials(): Text[4]
    begin
        exit(SOASetupCU.GetInitials());
    end;

    procedure GetFirstTimeSetupPageId(): Integer
    begin
        // The first time setup page ID is the same as the setup page ID.
        exit(Page::"SOA Setup");
    end;

    procedure GetSetupPageId(): Integer
    begin
        // The first time setup page ID is the same as the setup page ID.
        exit(Page::"SOA Setup");
    end;

    procedure GetSummaryPageId(): Integer
    begin
        exit(Page::"SOA KPI");
    end;

    procedure ShowCanCreateAgent(): Boolean
    begin
        exit(SOASetupCU.AllowCreateNewSOAgent());
    end;

    procedure GetCopilotCapability(): Enum "Copilot Capability"
    begin
        exit("Copilot Capability"::"Sales Order Agent");
    end;

    procedure GetAgentTaskUserInterventionSuggestions(AgentUserId: Guid; AgentTaskId: BigInteger; PageId: Integer; RecordId: RecordId; var AgentTaskUserInterventionSuggestion: Record "Agent Task User Int Suggestion")
    begin
        SOASetupCU.GetAgentTaskUserInterventionSuggestions(AgentUserId, AgentTaskId, PageId, RecordId, AgentTaskUserInterventionSuggestion);
    end;

    procedure GetAgentTaskPageContext(AgentUserId: Guid; AgentTaskId: BigInteger; PageId: Integer; RecordId: RecordId; var AgentTaskPageContext: Record "Agent Task Page Context")
    begin
        SOASetupCU.GetAgentTaskPageContext(AgentUserId, AgentTaskId, PageId, RecordId, AgentTaskPageContext);
    end;

    procedure GetAgentTaskMessagePageId(): Integer
    begin
        exit(Page::"SOA Email Message");
    end;

    var
        SOASetupCU: Codeunit "SOA Setup";
}