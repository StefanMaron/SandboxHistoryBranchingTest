// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.PayablesAgent;
using System.Agents;
using System.AI;
using Microsoft.eServices.EDocument;
using Microsoft.eServices.EDocument.Processing.Import;
using Microsoft.Utilities;

codeunit 3303 "Payables Agent" implements IAgentMetadata, IAgentFactory
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;
    Subtype = Install;

    trigger OnInstallAppPerDatabase()
    begin
        // For private preview do not run register capability on install. 
        // Ok, since it will be added when Copilot Capabilities page is opened.
        // Early preview will need to be enabled through the Copilot Capabilities page.
        // RegisterCapability();
    end;

    procedure GetSetupPageId(): Integer
    begin
        exit(Page::"Payables Agent Setup");
    end;

    procedure GetSummaryPageId(): Integer
    begin
        exit(Page::"Payables Agent KPI");
    end;

    procedure GetAgentTaskUserInterventionSuggestions(AgentUserId: Guid; AgentTaskId: BigInteger; PageId: Integer; RecordId: RecordId; var AgentTaskUserInterventionSuggestion: Record "Agent Task User Int Suggestion")
    begin
        Clear(AgentTaskUserInterventionSuggestion);
    end;

    procedure GetAgentTaskMessagePageId(): Integer
    begin
        exit(Page::"PA Agent Email Task");
    end;

    procedure GetInitials(): Text[4]
    begin
        exit(PayablesAgentInitialsTok);
    end;

    procedure GetFirstTimeSetupPageId(): Integer
    begin
        exit(Page::"Payables Agent Setup");
    end;

    procedure GetAgentTaskPageContext(AgentUserId: Guid; AgentTaskId: BigInteger; PageId: Integer; RecordId: RecordId; var AgentTaskPageContext: Record "Agent Task Page Context")
    begin
        Clear(AgentTaskPageContext);
    end;

    procedure ShowCanCreateAgent(): Boolean
    begin
        exit(true);
    end;

    procedure GetCopilotCapability(): Enum "Copilot Capability"
    begin
        exit("Copilot Capability"::"Payables Agent");
    end;

    /// <summary>
    /// If the current session is a payables agent session, this procedure will return the e-document being processed by the agent.
    /// </summary>
    /// <returns>The E-Document being processed by the agent, or an empty record if the session is not from a payables agent.</returns>
    procedure GetCurrentSessionsEDocument() EDocument: Record "E-Document"
    var
        AgentTaskMessage: Record "Agent Task Message";
        AgentType, EDocumentEntryNo : Integer;
        AgentTaskId: BigInteger;
        AgentALFunctions: DotNet AgentALFunctions;
    begin
        AgentType := AgentALFunctions.GetSessionAgentMetadataProviderType();
        if "Agent Metadata Provider".FromInteger(AgentType) <> "Agent Metadata Provider"::"Payables Agent" then
            exit;
        AgentTaskId := AgentALFunctions.GetSessionAgentTaskId();
        AgentTaskMessage.SetRange("Task ID", AgentTaskId);
        if not AgentTaskMessage.FindFirst() then
            exit;
        if not Evaluate(EDocumentEntryNo, AgentTaskMessage."External ID") then
            exit;
        if EDocument.Get(EDocumentEntryNo) then;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Copilot AI Capabilities", 'OnRegisterCopilotCapability', '', false, false)]
    local procedure OnRegisterCopilotCapability()
    begin
        RegisterCapability();
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Data Classification Eval. Data", 'OnCreateEvaluationDataOnAfterClassifyTablesToNormal', '', false, false)]
    local procedure ClassifyDataSensitivity()
    var
        DataClassificationEvalData: Codeunit "Data Classification Eval. Data";
    begin
        DataClassificationEvalData.SetTableFieldsToNormal(Database::"Payables Agent Setup");
        DataClassificationEvalData.SetTableFieldsToNormal(Database::"Payables Agent KPI");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Import", OnAfterProcessIncomingEDocument, '', false, false)]
    local procedure CreateAgentTask(EDocument: Record "E-Document"; StartState: Enum "Import E-Doc. Proc. Status")
    var
        Agent: Record Agent;
        AgentTask: Record "Agent Task";
        PayablesAgentSetup: Codeunit "Payables Agent Setup";
        AgentTaskCU: Codeunit "Agent Task";
        PayablesAgentKPI: Codeunit "Payables Agent KPI";
        Message: Text;
        TaskTitleLbl: Label 'Email from %1', Comment = '%1 is the sender''s email address.';
        MessageLbl: Label 'New inbound e-document %1 has been received, create a purchase invoice for it.', Locked = true;
        MessageNoAttachmentLbl: Label 'New inbound e-document %1 with no attachment has been received. Consider deleting it.', Locked = true;
    begin
        if not EDocument.Get(EDocument."Entry No") then
            exit;
        if EDocument.GetEDocumentService().Code <> PayablesAgentEDocServiceTok then
            exit;
        if StartState <> "Import E-Doc. Proc. Status"::Unprocessed then
            exit;
        EDocument.CalcFields("Import Processing Status");
        if EDocument."Import Processing Status" in ["Import E-Doc. Proc. Status"::Processed] then
            exit;
        if EDocument."Read into Draft Impl." = "E-Doc. Read into Draft"::"Blank Draft" then
            Message := StrSubstNo(MessageNoAttachmentLbl, EDocument."Entry No")
        else
            Message := StrSubstNo(MessageLbl, EDocument."Entry No");
        if not PayablesAgentSetup.GetAgent(Agent) then
            exit;
        if Agent.State = Agent.State::Disabled then
            exit;
        PayablesAgentSetup.SetAgentInstructions(Agent."User Security ID");
        AgentTask."Agent User Security ID" := Agent."User Security ID";
        AgentTask."External ID" := Format(EDocument."Entry No");
        AgentTask.Title := CopyStr(StrSubstNo(TaskTitleLbl, EDocument."Source Details"), 1, MaxStrLen(AgentTask.Title));
        AgentTaskCU.CreateTaskMessage(CopyStr(EDocument."Source Details", 1, 250), Message, AgentTask."External ID", AgentTask);
        PayablesAgentKPI.InsertKPIEntry("PA KPI Scenario"::"Agent Tasks Received");
    end;

    internal procedure RegisterCapability()
    var
        EDocumentsSetup: Record "E-Documents Setup";
        CopilotCapability: Codeunit "Copilot Capability";
    begin
        // Only register capability if tenant has new experience enabled
        if not EDocumentsSetup.IsNewEDocumentExperienceActive() then
            exit;

        if CopilotCapability.IsCapabilityRegistered("Copilot Capability"::"Payables Agent") then
            exit;
        CopilotCapability.RegisterCapability("Copilot Capability"::"Payables Agent", "Copilot Availability"::"Early Preview", 'https://go.microsoft.com/fwlink/?linkid=2304779');
    end;

    var
        PayablesAgentInitialsTok: Label 'PA', Comment = 'Initials for payables agent.', MaxLength = 4;
        PayablesAgentEDocServiceTok: Label 'AGENT', Locked = true;
}