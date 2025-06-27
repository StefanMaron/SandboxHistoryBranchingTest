// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

#pragma warning disable AS0007
namespace Microsoft.Agent.SalesOrderAgent;

using System.Agents;

codeunit 4309 "SOA Agent Validation" implements IAgentValidation
{
    Access = Internal;

    procedure GetAgentAnnotations(AgentUserId: Guid; var Annotations: Record "Agent Annotation")
    begin
        SOAImpl.GetAgentAnnotations(AgentUserId, Annotations);
    end;

    procedure GetTaskMessageAnnotations(AgentUserId: Guid; TaskId: BigInteger; TaskMessageId: Guid; var Annotations: Record "Agent Annotation")
    begin
    end;

    var
        SOAImpl: Codeunit "SOA Impl";
}