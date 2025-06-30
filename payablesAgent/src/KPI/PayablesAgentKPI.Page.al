// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.PayablesAgent;

using System.Agents;

page 3306 "Payables Agent KPI"
{
    PageType = CardPart;
    ApplicationArea = All;
    SourceTable = Agent;
    InherentEntitlements = X;
    InherentPermissions = X;

    layout
    {
        area(Content)
        {
            cuegroup(Summary)
            {
                ShowCaption = false;
                field(AgentTasksReceived; CountKPI.Get("PA KPI Scenario"::"Agent Tasks Received"))
                {
                    ApplicationArea = All;
                    Caption = 'E-Documents Received';
                    ToolTip = 'Specifies the number of tasks received by the agent.';
                }
                field(AgentEDocsFinalizedByAgent; CountKPI.Get("PA KPI Scenario"::"Agent E-Docs Finalized by Agent"))
                {
                    ApplicationArea = All;
                    Caption = 'Invoices created by the agent';
                    ToolTip = 'Specifies the number of tasks finalized by the agent.';
                }
            }
        }
    }

    trigger OnOpenPage()
    var
        i: Integer;
    begin
        foreach i in PAKPIScenario.Ordinals() do begin
            PAKPIScenario := "PA KPI Scenario".FromInteger(i);
            CountKPI.Set(PAKPIScenario, PayablesAgentKPI.GetAggregateKPI(PAKPIScenario).Count);
        end;
    end;

    var
        PayablesAgentKPI: Codeunit "Payables Agent KPI";
        CountKPI: Dictionary of [Enum "PA KPI Scenario", Integer];
        PAKPIScenario: Enum "PA KPI Scenario";

}