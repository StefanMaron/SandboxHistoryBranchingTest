// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.PayablesAgent;

using Microsoft.eServices.EDocument;
using System.Agents;
using System.Email;
using Microsoft.EServices.EDocumentConnector.Microsoft365;
using System.Azure.Identity;
using Microsoft.eServices.EDocument.Integration.Interfaces;
using Microsoft.eServices.EDocument.Integration;
using System.Reflection;
using System.Security.AccessControl;
using System.Azure.KeyVault;
using Microsoft.eServices.EDocument.Processing.Import;
using System.Environment.Configuration;

codeunit 3307 "Payables Agent Setup"
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    /// <summary>
    /// Retrieves all the records containing setup information for the payables agent.
    /// </summary>
    /// <param name="PASetupConfiguration">State variable where all the setup related information is stored.</param>
    procedure LoadSetupConfiguration(var PASetupConfiguration: Codeunit "PA Setup Configuration")
    var
        Agent: Record Agent;
        EDocumentService: Record "E-Document Service";
        TempEmailAccount: Record "Email Account" temporary;
        PayablesAgentSetup: Record "Payables Agent Setup";
        OutlookSetup: Record "Outlook Setup";
        TempAgentAccessControl: Record "Agent Access Control" temporary;
        AgentCU: Codeunit Agent;
        EmailAccount: Codeunit "Email Account";
    begin
        // Skipping configuring the Agent framework records is valid in tests
        if not PASetupConfiguration.GetSkipAgentConfiguration() then
            if GetAgent(Agent) then
                AgentCU.GetUserAccess(Agent."User Security ID", TempAgentAccessControl);

        PayablesAgentSetup.GetSetup();
        if EDocumentService.Get(PayablesAgentSetup."E-Document Service Code") then;
        if OutlookSetup.Get() then;
        EmailAccount.GetAllAccounts(false, TempEmailAccount);
        if not TempEmailAccount.Get(OutlookSetup."Email Account ID", OutlookSetup."Email Connector") then
            Clear(TempEmailAccount);

        PASetupConfiguration.SetAgent(Agent);
        PASetupConfiguration.SetPayablesAgentSetup(PayablesAgentSetup);
        PASetupConfiguration.SetEDocumentService(EDocumentService);
        PASetupConfiguration.SetEmailAccount(TempEmailAccount);
        PASetupConfiguration.SetAgentAccessControl(TempAgentAccessControl);
    end;

    /// <summary>
    /// Persist the payables agent setup configured across the different records required.
    /// </summary>
    /// <param name="PASetupConfiguration">State variable where all the setup related information is stored.</param>
    procedure ApplyPayablesAgentSetup(var PASetupConfiguration: Codeunit "PA Setup Configuration")
    var
        PayablesAgentSetup: Record "Payables Agent Setup";
        OutlookSetup: Record "Outlook Setup";
        AzureADGraphUser: Codeunit "Azure AD Graph User";
        ConsentManager: Interface IConsentManager;
        ErrorAccountNotConnecting: ErrorInfo;
        OrigEmailAccountId: Guid;
        DelegatedAdminErr: Label 'Delegated admin and helpdesk users are not allowed to update the agent.';
        EmailMonitoringRequiresPrivacyConsentErr: Label 'Email monitoring requires privacy consent.';
        EmailConnectionErr: Label 'Failed to connect to the email mailbox.';
        EmailConnectionMessageErr: Label 'Connection to mailbox failed. Please review the email account configuration for email %1', Comment = '%1 - Email account name';
        EmailConnectionNavigationActionLbl: Label 'Show email accounts';
        ActivateWithoutMailboxNameErr: Label 'To activate the agent with the current settings, a mailbox must be selected first.';
    begin
        if AzureADGraphUser.IsUserDelegatedAdmin() or AzureADGraphUser.IsUserDelegatedHelpdesk() then
            Error(DelegatedAdminErr);

        Session.LogMessage('0000OUW', 'Setting up payables agent', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::All, 'Category', PayablesAgentTelemetryTok);

        // If the agent is to be activated, we check if the privacy consent has been given for the email integration or triger the consent flow
        // This has to happen before any write transactions since the consent runs modally (and will block the session)
        if PASetupConfiguration.GetAgent().State = PASetupConfiguration.GetAgent().State::Enabled then begin
            ConsentManager := "Service Integration"::Outlook;
            if not ConsentManager.ObtainPrivacyConsent() then
                Error(EmailMonitoringRequiresPrivacyConsentErr);
        end;

        if not OutlookSetup.FindFirst() then
            OutlookSetup.Insert();
        OrigEmailAccountId := OutlookSetup."Email Account ID";
        OutlookSetup."Email Account ID" := PASetupConfiguration.GetEmailAccount()."Account Id";
        OutlookSetup."Email Connector" := PASetupConfiguration.GetEmailAccount().Connector;
        if OrigEmailAccountId <> OutlookSetup."Email Account ID" then
            OutlookSetup."Last Sync At" := 0DT;
        OutlookSetup.Modify();

        if PASetupConfiguration.GetAgent().State = PASetupConfiguration.GetAgent().State::Enabled then
            if not PASetupConfiguration.GetSkipEmailVerification() then begin

                if PASetupConfiguration.GetPayablesAgentSetup()."Monitor Outlook" then
                    if IsNullGuid(PASetupConfiguration.GetEmailAccount()."Account Id") then
                        Error(ActivateWithoutMailboxNameErr);

                if not TestEmailConnection(OutlookSetup) then begin
                    ErrorAccountNotConnecting.Title(EmailConnectionErr);
                    ErrorAccountNotConnecting.Message(StrSubstNo(EmailConnectionMessageErr, PASetupConfiguration.GetEmailAccount()."Email Address"));
                    ErrorAccountNotConnecting.PageNo := Page::"Email Accounts";
                    ErrorAccountNotConnecting.AddNavigationAction(EmailConnectionNavigationActionLbl);
                    Error(ErrorAccountNotConnecting);
                end;

            end;

        // We apply the changes to the "Payables Agent Setup" record
        PayablesAgentSetup.GetSetup();
        PayablesAgentSetup.Copy(PASetupConfiguration.GetPayablesAgentSetup());

        if not PASetupConfiguration.GetSkipAgentConfiguration() then // Skipping the agent's configuration is valid in tests
            PayablesAgentSetup."Agent User Security Id" := ApplyAgentSetup(PASetupConfiguration);

        // We apply the changes to the E-Document Service related records
        PayablesAgentSetup."E-Document Service Code" := ApplyEDocumentServiceSetup(PASetupConfiguration);
        PayablesAgentSetup.Modify();
    end;

    procedure WasEDocumentCreatedByAgent(EDocument: Record "E-Document"): Boolean
    begin
        exit(EDocument.GetEDocumentService().Code = PayablesAgentEDocServiceTok);
    end;

    /// <summary>
    /// Retrieves the agent record if configured in the database, or populates the record with default values.
    /// </summary>
    /// <param name="Agent">Record where the Agent is loaded</param>
    /// <returns>True if an Agent was found, false otherwise</returns>
    procedure GetAgent(var Agent: Record Agent): Boolean
    var
        PayablesAgentSetup: Record "Payables Agent Setup";
    begin
        PayablesAgentSetup.GetSetup();
        // We attempt to find the agent by the security id stored in the setup record.
        if Agent.Get(PayablesAgentSetup."Agent User Security Id") then
            exit(true);
        // If the agent could not be found, and there was a user security id configured, we need to clear it, since it is not valid anymore.
        if not IsNullGuid(PayablesAgentSetup."Agent User Security Id") then
            Clear(PayablesAgentSetup."Agent User Security Id");
        // If the agent could not be found from the configured security id, we attempt to find it by the user name.
        Agent.SetRange("User Name", AgentUserName());
        if Agent.FindFirst() then
            PayablesAgentSetup."Agent User Security Id" := Agent."User Security ID";
        PayablesAgentSetup.Modify();
        // If we were unable to find the agent, we set the default values for the record's fields.
        if IsNullGuid(Agent."User Security ID") then begin
            Agent."User Name" := AgentUserName();
            Agent."Display Name" := CopyStr(AgentDisplayNameLbl, 1, MaxStrLen(Agent."Display Name"));
        end;
        exit(not IsNullGuid(Agent."User Security ID"));
    end;

    internal procedure SetAgentInstructions(AgentUserSecurityId: Guid)
    var
        AzureKeyVault: Codeunit "Azure Key Vault";
        Agent: Codeunit Agent;
        Instructions: SecretText;
        PromptSecretNameTok: Label 'BCPAInstructionsV262', Locked = true;
    begin
        if IsNullGuid(AgentUserSecurityId) then
            exit;
        if not AzureKeyVault.GetAzureKeyVaultSecret(PromptSecretNameTok, Instructions) then
            Session.LogMessage('0000OUX', 'Failed to retrieve agent''s instructions', Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::All, 'Category', PayablesAgentTelemetryTok);
        Agent.SetInstructions(AgentUserSecurityId, Instructions);
    end;

    local procedure AgentUserName(): Code[50]
    begin
        exit(CopyStr(AgentUserNameLbl + ' - ' + CompanyName(), 1, 50));
    end;

    local procedure ApplyAgentSetup(var PASetupConfiguration: Codeunit "PA Setup Configuration"): Guid
    var
        AllProfile: Record "All Profile";
        AggregatePermissionSet: Record "Aggregate Permission Set";
        TempModifiedAgent: Record Agent temporary;
        TempModifiedAgentAccessControl: Record "Agent Access Control" temporary;
        Agent: Codeunit Agent;
        CurrentModuleInfo: ModuleInfo;
        NullGuid: Guid;
        ProfileObjectNameTok: Label 'Payables Agent', Locked = true;
        AgentPermissionSetTok: Label 'Payables Ag. - Run', Locked = true;
    begin
        TempModifiedAgent := PASetupConfiguration.GetAgent();
        // If we want to deactivate the agent, we do so and exit
        if TempModifiedAgent.State = TempModifiedAgent.State::Disabled then begin
            if not IsNullGuid(TempModifiedAgent."User Security ID") then
                Agent.Deactivate(TempModifiedAgent."User Security ID");
            exit(NullGuid);
        end;
        PASetupConfiguration.GetAgentAccessControl(TempModifiedAgentAccessControl);
        // If we want to activate it, and the agent does not exist, we need to create it
        if IsNullGuid(TempModifiedAgent."User Security ID") then begin
            TempModifiedAgent."User Security ID" := Agent.Create("Agent Metadata Provider"::"Payables Agent", TempModifiedAgent."User Name", TempModifiedAgent."Display Name", TempModifiedAgentAccessControl);
            NavApp.GetCurrentModuleInfo(CurrentModuleInfo);
            AllProfile.Get(AllProfile.Scope::Tenant, CurrentModuleInfo.Id, ProfileObjectNameTok);
            Agent.SetProfile(TempModifiedAgent."User Security ID", AllProfile);
            AggregatePermissionSet.SetRange("App ID", CurrentModuleInfo.Id);
            AggregatePermissionSet.SetRange("Role ID", AgentPermissionSetTok);
            Agent.AssignPermissionSet(TempModifiedAgent."User Security ID", AggregatePermissionSet);
        end else
            // If it already exists, we update the agent's access control
            Agent.UpdateAccess(TempModifiedAgent."User Security ID", TempModifiedAgentAccessControl);

        SetAgentInstructions(TempModifiedAgent."User Security ID");
        Agent.Activate(TempModifiedAgent."User Security ID");
        exit(TempModifiedAgent."User Security ID");
    end;

    local procedure ApplyEDocumentServiceSetup(var PASetupConfiguration: Codeunit "PA Setup Configuration"): Code[20]
    var
        EDocumentService: Record "E-Document Service";
        OutlookSetup: Record "Outlook Setup";
    begin
        // If we intend to disable the agent, we need to disable the E-Document Service's autoimport as well
        if PASetupConfiguration.GetAgent().State = PASetupConfiguration.GetAgent().State::Disabled then begin
            if EDocumentService.Get(PayablesAgentEDocServiceTok) then begin
                EDocumentService.Validate("Auto Import", false);
                EDocumentService.Modify();
            end;
            exit(PayablesAgentEDocServiceTok);
        end;
        if not EDocumentService.Get(PayablesAgentEDocServiceTok) then begin
            EDocumentService.Code := PayablesAgentEDocServiceTok;
            EDocumentService.Insert(true);
        end;
        // We configure the default E-Document Service settings
        EDocumentService.Validate("Service Integration V2", "Service Integration"::Outlook);
        EDocumentService.Validate("Automatic Import Processing", "E-Doc. Automatic Processing"::No);
        EDocumentService.Validate("Import Process", "E-Document Import Process"::"Version 2.0");
        Clear(EDocumentService."Import Start Time");
        EDocumentService."Import Minutes between runs" := 1;
        EDocumentService.Modify();
        // If monitoring outlook is requested, we set auto-import in the service and configure the Outlook Setup
        if PASetupConfiguration.GetPayablesAgentSetup()."Monitor Outlook" then begin
            EDocumentService.Validate("Auto Import", true);
            OutlookSetup.FindFirst();
            OutlookSetup.Validate(Enabled, true);
            OutlookSetup.Modify();
        end
        else
            EDocumentService.Validate("Auto Import", false);
        EDocumentService.Modify();
        exit(PayablesAgentEDocServiceTok);
    end;

    [TryFunction]
    procedure TestEmailConnection(OutlookSetup: Record "Outlook Setup")
    var
        TempFilters: Record "Email Retrieval Filters" temporary;
        TempEmailInbox: Record "Email Inbox" temporary;
        Email: Codeunit "Email";
    begin
        TempFilters."Unread Emails" := true;
        TempFilters."Earliest Email" := OutlookSetup."Last Sync At";
        TempFilters."Max No. of Emails" := 1;
        Email.RetrieveEmails(OutlookSetup."Email Account ID", OutlookSetup."Email Connector", TempEmailInbox, TempFilters);
    end;

    [EventSubscriber(ObjectType::Report, Report::"Copy Company", 'OnAfterCreatedNewCompanyByCopyCompany', '', false, false)]
    local procedure HandleOnAfterCreatedNewCompanyByCopyCompany(NewCompanyName: Text[30])
    var
        PayablesAgentSetup: Record "Payables Agent Setup";
        PayablesAgentKPI: Record "Payables Agent KPI";
    begin
        PayablesAgentSetup.ChangeCompany(NewCompanyName);
        PayablesAgentSetup.DeleteAll();

        PayablesAgentKPI.ChangeCompany(NewCompanyName);
        PayablesAgentKPI.DeleteAll();
    end;


    var
        AgentUserNameLbl: Label 'Payables Agent', Comment = 'User name of the agent.';
        AgentDisplayNameLbl: Label 'Payables Agent';
        PayablesAgentTelemetryTok: Label 'Payables Agent', Locked = true;
        PayablesAgentEDocServiceTok: Label 'AGENT', Locked = true;
}