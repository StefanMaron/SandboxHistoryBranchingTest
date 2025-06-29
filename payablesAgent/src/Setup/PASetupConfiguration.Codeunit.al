// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.PayablesAgent;

using System.Agents;
using Microsoft.eServices.EDocument;
using System.Email;

/// <summary>
/// To be used as a state variable with the all the related records used to configure the agent.
/// </summary>
codeunit 3304 "PA Setup Configuration"
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        TempAgent: Record Agent temporary;
        TempPayablesAgentSetup: Record "Payables Agent Setup" temporary;
        TempEDocumentService: Record "E-Document Service" temporary;
        TempEmailAccount: Record "Email Account" temporary;
        TempAgentAccessControl: Record "Agent Access Control" temporary;
        SkipAgentConfiguration: Boolean;
        SkipEmailVerification: Boolean;

    procedure GetAgent(): Record Agent
    begin
        exit(TempAgent);
    end;

    procedure SetAgent(Agent: Record Agent)
    begin
        TempAgent.Copy(Agent);
    end;

    internal procedure GetSkipAgentConfiguration(): Boolean
    begin
        exit(SkipAgentConfiguration);
    end;

    internal procedure SetSkipAgentConfiguration(LocalSkipAgentConfiguration: Boolean)
    begin
        SkipAgentConfiguration := LocalSkipAgentConfiguration;
    end;

    internal procedure GetSkipEmailVerification(): Boolean
    begin
        exit(SkipEmailVerification);
    end;

    internal procedure SetSkipEmailVerification(LocalSkipEmailVerification: Boolean)
    begin
        SkipEmailVerification := LocalSkipEmailVerification;
    end;

    procedure GetPayablesAgentSetup(): Record "Payables Agent Setup"
    begin
        exit(TempPayablesAgentSetup);
    end;

    procedure SetPayablesAgentSetup(PayablesAgentSetup: Record "Payables Agent Setup")
    begin
        TempPayablesAgentSetup.Copy(PayablesAgentSetup);
    end;

    procedure GetEDocumentService(): Record "E-Document Service"
    begin
        exit(TempEDocumentService);
    end;

    procedure SetEDocumentService(EDocumentService: Record "E-Document Service")
    begin
        TempEDocumentService.Copy(EDocumentService);
    end;

    procedure GetEmailAccount(): Record "Email Account"
    begin
        exit(TempEmailAccount);
    end;

    procedure SetEmailAccount(EmailAccount: Record "Email Account")
    begin
        TempEmailAccount.Copy(EmailAccount);
    end;

    procedure GetAgentAccessControl(var AgentAccessControl: Record "Agent Access Control" temporary)
    begin
        AgentAccessControl.DeleteAll();
        if TempAgentAccessControl.FindSet() then
            repeat
                AgentAccessControl.Copy(TempAgentAccessControl);
                AgentAccessControl.Insert();
            until TempAgentAccessControl.Next() = 0;
    end;

    procedure SetAgentAccessControl(var AgentAccessControl: Record "Agent Access Control" temporary)
    begin
        TempAgentAccessControl.DeleteAll();
        if AgentAccessControl.FindSet() then
            repeat
                TempAgentAccessControl.Copy(AgentAccessControl);
                TempAgentAccessControl.Insert();
            until AgentAccessControl.Next() = 0;
    end;

}