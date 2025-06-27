// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.PayablesAgent;

using Microsoft.eServices.EDocument;
using Microsoft.eServices.EDocument.Processing.Import;
using System.Agents;

codeunit 3306 "Payables Agent KPI"
{
    Access = Internal;

    procedure InsertKPIEntry(KPIScenario: Enum "PA KPI Scenario")
    var
        PayablesAgentKPI: Record "Payables Agent KPI";
    begin
        PayablesAgentKPI := GetAggregateKPI(KPIScenario);
        PayablesAgentKPI.Count += 1;
        PayablesAgentKPI.Modify();
        Clear(PayablesAgentKPI);
        PayablesAgentKPI.Count := 1;
        PayablesAgentKPI."KPI Scenario" := KPIScenario;
        PayablesAgentKPI."Is Aggregate" := false;
        PayablesAgentKPI.Insert();
    end;

    procedure GetAggregateKPI(KPIScenario: Enum "PA KPI Scenario") PayablesAgentKPI: Record "Payables Agent KPI"
    begin
        Clear(PayablesAgentKPI);
        PayablesAgentKPI.SetRange("Is Aggregate", true);
        PayablesAgentKPI.SetRange("KPI Scenario", KPIScenario);
        if not PayablesAgentKPI.FindFirst() then begin
            PayablesAgentKPI."Is Aggregate" := true;
            PayablesAgentKPI."KPI Scenario" := KPIScenario;
            PayablesAgentKPI.Insert();
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Import", OnAfterProcessIncomingEDocument, '', false, false)]
    local procedure TrackFinalizedEDocuments(EDocument: Record "E-Document")
    var
        PayablesAgentSetup: Codeunit "Payables Agent Setup";
    begin
        if not PayablesAgentSetup.WasEDocumentCreatedByAgent(EDocument) then
            exit;
        EDocument.CalcFields("Import Processing Status");
        if EDocument."Import Processing Status" <> "Import E-Doc. Proc. Status"::Processed then
            exit;
        if GetCurrentSessionsPayablesAgentTaskId() = 0 then
            InsertKPIEntry("PA KPI Scenario"::"Agent E-Docs Finalized by User")
        else
            InsertKPIEntry("PA KPI Scenario"::"Agent E-Docs Finalized by Agent");
    end;

    local procedure GetCurrentSessionsPayablesAgentTaskId(): BigInteger
    var
        AgentType: Integer;
        AgentALFunctions: DotNet AgentALFunctions;
    begin
        AgentType := AgentALFunctions.GetSessionAgentMetadataProviderType();
        if AgentType < 0 then
            exit(0);
        if "Agent Metadata Provider".FromInteger(AgentType) <> "Agent Metadata Provider"::"Payables Agent" then
            exit(0);
        exit(AgentALFunctions.GetSessionAgentTaskId());
    end;

}