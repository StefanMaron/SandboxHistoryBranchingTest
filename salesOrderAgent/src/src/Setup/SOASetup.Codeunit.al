// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

#pragma warning disable AS0007
namespace Microsoft.Agent.SalesOrderAgent;

using System.Agents;
using System.Azure.Identity;
using System.Azure.KeyVault;
using System.Email;
using System.Environment;
using System.Environment.Configuration;
using System.Reflection;
using System.Security.AccessControl;
using System.Telemetry;
using Microsoft.CRM.Contact;
using Microsoft.Finance.Currency;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;

#pragma warning disable AS0049
codeunit 4400 "SOA Setup"
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;
    Permissions = tabledata "Email Inbox" = rd;
#pragma warning restore AS0049

    /// <summary>
    /// Used for testing OnPrem
    /// </summary>
    [Scope('OnPrem')]
    procedure CreateDefaultAgentNoEmail()
    var
        TempAgentAccessControl: Record "Agent Access Control" temporary;
        TempSOASetup: Record "SOA Setup" temporary;
        TempAgent: Record Agent temporary;
        TempEmailAccount: Record "Email Account" temporary;
    begin
        GetAgent(TempAgent);
        TempAgent.State := TempAgent.State::Enabled;
        GetDefaultSOASetup(TempSOASetup, TempAgent);
        TempSOASetup."Email Monitoring" := false;

        GetDefaultAgentAccessControl(TempAgent."User Security ID", TempAgentAccessControl);
        UpdateAgent(TempAgent, TempAgentAccessControl, TempSOASetup, TempEmailAccount, true, true);
    end;

    internal procedure CreateAgent(var TempAgent: Record Agent; var TempAgentAccessControl: Record "Agent Access Control" temporary; var TempSOASetup: Record "SOA Setup" temporary; var TempEmailAccount: Record "Email Account" temporary)
    var
        AllProfile: Record "All Profile";
        TempAggregatePermissionSet: Record "Aggregate Permission Set" temporary;
        Agent: Codeunit Agent;
        InstructionsSecret: SecretText;
    begin
        PrepareInstructions(InstructionsSecret, TempSOASetup);

        TempSOASetup."Agent User Security ID" := Agent.Create("Agent Metadata Provider"::"SO Agent", TempAgent."User Name", TempAgent."Display Name", TempAgentAccessControl);
        Agent.SetInstructions(TempSOASetup."Agent User Security ID", InstructionsSecret);

        GetProfile(AllProfile);
        GetPermissionSets(TempAggregatePermissionSet);
        Agent.SetProfile(TempSOASetup."Agent User Security ID", AllProfile);
        Agent.AssignPermissionSet(TempSOASetup."Agent User Security ID", TempAggregatePermissionSet);

        if TempAgent.State = TempAgent.State::Enabled then
            UpdateSOASetupActivationDT(TempSOASetup);
        UpdateSOASetup(TempSOASetup);

        if TempAgent.State = TempAgent.State::Enabled then begin
            EnableItemSearch();
            Agent.Activate(TempSOASetup."Agent User Security ID");
            if TempSOASetup."Email Monitoring" and TempSOASetup."Incoming Monitoring" and not IsNullGuid(TempSOASetup."Email Account ID") then
                SOAImpl.ScheduleSOAgent(TempSOASetup)
        end
        else
            Agent.Deactivate(TempSOASetup."Agent User Security ID");
    end;

    internal procedure GetInitials(): Text[4]
    begin
        exit(SalesOrderAgentInitialLbl);
    end;

    internal procedure GetAgentType(): Text
    begin
        exit(SalesOrderAgentTypeLbl);
    end;

    internal procedure GetAgentSummary(): Text
    begin
        exit(SOASummaryLbl);
    end;

    internal procedure AllowCreateNewSOAgent(): Boolean
    var
        SOASetup: Record "SOA Setup";
    begin
        SOASetup.Init();
        SOASetup.SetAutoCalcFields(SOASetup.Exists);
        SOASetup.SetRange(SOASetup.Exists, true);
        exit(SOASetup.IsEmpty());
    end;

    internal procedure UpdateAgent(var TempAgent: Record Agent; var TempAgentAccessControl: Record "Agent Access Control" temporary; var TempSOASetup: Record "SOA Setup" temporary; var TempEmailAccount: Record "Email Account" temporary; AccessUpdated: Boolean; Schedule: Boolean)
    var
        Agent: Codeunit Agent;
        AzureADGraphUser: Codeunit "Azure AD Graph User";
    begin
        if AzureADGraphUser.IsUserDelegatedAdmin() or AzureADGraphUser.IsUserDelegatedHelpdesk() then
            Error(DelegateAdminErr);

        if IsNullGuid(TempAgent."User Security ID") then begin
            CreateAgent(TempAgent, TempAgentAccessControl, TempSOASetup, TempEmailAccount);
            exit;
        end;

        if TempAgent.State = TempAgent.State::Enabled then
            UpdateSOASetupActivationDT(TempSOASetup);
        UpdateInstructions(TempSOASetup);

        Agent.SetDisplayName(TempAgent."User Security ID", TempAgent."Display Name");
        if TempAgent.State = TempAgent.State::Enabled then begin
            Agent.Activate(TempAgent."User Security ID");
            EnableItemSearch();
            if TempSOASetup."Email Monitoring" and TempSOASetup."Incoming Monitoring" and not IsNullGuid(TempSOASetup."Email Account ID") and Schedule then
                SOAImpl.ScheduleSOAgent(TempSOASetup);
        end
        else begin
            Agent.Deactivate(TempAgent."User Security ID");
            SOAImpl.RemoveScheduledTask(TempSOASetup);
        end;
        UpdateSOASetup(TempSOASetup);

        if AccessUpdated then
            Agent.UpdateAccess(TempAgent."User Security ID", TempAgentAccessControl);
    end;

    local procedure UpdateSOASetup(var TempSOASetup: Record "SOA Setup" temporary)
    var
        SOASetup: Record "SOA Setup";
    begin
        SOASetup.SetRange("Agent User Security ID", TempSOASetup."Agent User Security ID");
        if SOASetup.FindFirst() then begin
            SOASetup."Incoming Monitoring" := TempSOASetup."Incoming Monitoring";
            SOASetup."Email Monitoring" := TempSOASetup."Email Monitoring";
            if SOASetup."Email Monitoring" then begin
                SOASetup."Email Account ID" := TempSOASetup."Email Account ID";
                SOASetup."Email Connector" := TempSOASetup."Email Connector";
                SOASetup."Email Address" := TempSOASetup."Email Address";
            end;

            SOASetup."Activated At" := TempSOASetup."Activated At";
            SOASetup."Earliest Sync At" := TempSOASetup."Earliest Sync At";
            SOASetup."Last Sync At" := TempSOASetup."Last Sync At";
            SOASetup."Sales Doc. Configuration" := TempSOASetup."Sales Doc. Configuration";
            SOASetup."Quote Review" := TempSOASetup."Quote Review";
            SOASetup."Order Review" := TempSOASetup."Order Review";
            SOASetup."Create Order from Quote" := TempSOASetup."Create Order from Quote";
            SOASetup."Search Only Available Items" := TempSOASetup."Search Only Available Items";
            SOASetup."Agent Scheduled Task ID" := TempSOASetup."Agent Scheduled Task ID";
            SOASetup."Recovery Scheduled Task ID" := TempSOASetup."Recovery Scheduled Task ID";

            SOASetup.Modify();
        end
        else begin
            SOASetup.Copy(TempSOASetup);
            SOASetup.Insert();
            TempSOASetup := SOASetup;
            TempSOASetup.Insert();
        end;
    end;

    local procedure SetDefaultSalesDocConfig(var SOASetup: Record "SOA Setup"; SalesDocConfigValue: Boolean)
    begin
        SOASetup."Sales Doc. Configuration" := SalesDocConfigValue;
        SOASetup."Quote Review" := false;
        SOASetup."Order Review" := false;
        SOASetup."Create Order from Quote" := true;
        SOASetup."Search Only Available Items" := true;
    end;

    internal procedure UpdateInstructions(var TempSOASetup: Record "SOA Setup" temporary)
    var
        AgentCU: Codeunit Agent;
        InstructionsSecret: SecretText;
    begin
        PrepareInstructions(InstructionsSecret, TempSOASetup);
        AgentCU.SetInstructions(TempSOASetup."Agent User Security ID", InstructionsSecret);
    end;

    internal procedure UpdateSOASetupActivationDT(var TempSOASetup: Record "SOA Setup" temporary)
    begin
        TempSOASetup."Activated At" := CurrentDateTime();
    end;

    local procedure EnableItemSearch()
    var
        ItemSearch: Codeunit "SOA Item Search";
    begin
        ItemSearch.EnableItemSearch();
    end;

    internal procedure GetDefaultAgentAccessControl(AgentUserSecurityID: Guid; var TempAgentAccessControl: Record "Agent Access Control" temporary)
    var
        Agents: Codeunit Agent;
    begin
        if IsNullGuid(AgentUserSecurityID) then
            exit;
        Agents.GetUserAccess(AgentUserSecurityID, TempAgentAccessControl);
    end;

    internal procedure GetAgent(var TempSOAgent: Record Agent temporary)
    var
        Agents: Record Agent;
    begin
        if IsNullGuid(TempSOAgent."User Security ID") then begin
            Agents.SetRange("User Name", GetSOAUsername());
            Agents.SetRange("Display Name", SalesOrderAgentDisplayNameLbl);
            if Agents.FindFirst() then begin
                TempSOAgent := Agents;
                TempSOAgent.Insert();
                exit;
            end
            else
                SetAgentDefaults(TempSOAgent);
        end else begin
            Agents.Get(TempSOAgent."User Security ID");
            TempSOAgent.TransferFields(Agents, true);
        end;
    end;

    internal procedure GetDefaultSOASetup(var TempSOASetup: Record "SOA Setup" temporary; var TempSOAgent: Record Agent temporary)
    var
        SOASetup: Record "SOA Setup";
    begin
        if IsNullGuid(TempSOASetup."Agent User Security ID") then
            if SOASetup.FindFirst() then begin
                TempSOASetup := SOASetup;
                TempSOASetup.Insert();
            end
            else
                SetSOASetupDefaults(TempSOASetup, TempSOAgent."User Security ID")
        else begin
            SOASetup.SetRange("Agent User Security ID", TempSOASetup."Agent User Security ID");
            if SOASetup.FindFirst() then begin
                TempSOASetup := SOASetup;
                TempSOASetup.Insert();
            end
            else
                SetSOASetupDefaults(TempSOASetup, TempSOAgent."User Security ID");
        end;
    end;

    internal procedure GetEmailAccount(var SOASetup: Record "SOA Setup"; var TempEmailAccount: Record "Email Account" temporary)
    var
        TempAllEmailAccounts: Record "Email Account" temporary;
        EmailAccount: Codeunit "Email Account";
    begin
        EmailAccount.GetAllAccounts(false, TempAllEmailAccounts);
        TempAllEmailAccounts.SetRange("Account Id", SOASetup."Email Account ID");
        TempAllEmailAccounts.SetRange(Connector, SOASetup."Email Connector");
        if TempAllEmailAccounts.FindFirst() then
            TempEmailAccount.Copy(TempAllEmailAccounts);
    end;

    internal procedure GetDefaultEmailAccount(var TempEmailAccount: Record "Email Account" temporary)
    var
        EmailAccount: Codeunit "Email Account";
    begin
        EmailAccount.GetAllAccounts(false, TempEmailAccount);
        if TempEmailAccount.FindFirst() then;
    end;

    internal procedure GetAgentTaskUserInterventionSuggestions(AgentUserId: Guid; AgentTaskId: BigInteger; PageId: Integer; RecordId: RecordId; var AgentTaskUserInterventionSuggestion: Record "Agent Task User Int Suggestion")
    begin
        Clear(AgentTaskUserInterventionSuggestion);

        if (PageId = Page::"Sales Quote") then begin
            AgentTaskUserInterventionSuggestion.Init();
            AgentTaskUserInterventionSuggestion.Summary := StrSubstNo(SOAInterventionSuggestionSummaryLbl, SOAInterventionSuggestionQuoteLbl);
            AgentTaskUserInterventionSuggestion.Description := StrSubstNo(SOAInterventionSuggestionDescriptionLbl, SOAInterventionSuggestionQuoteLbl);
            AgentTaskUserInterventionSuggestion.Instructions := StrSubstNo(SOAInterventionSuggestionInstructionsLbl, SOAInterventionSuggestionQuoteLbl);
            AgentTaskUserInterventionSuggestion.Insert();
        end;

        if (PageId = Page::"Sales Order") then begin
            AgentTaskUserInterventionSuggestion.Init();
            AgentTaskUserInterventionSuggestion.Summary := StrSubstNo(SOAInterventionSuggestionSummaryLbl, SOAInterventionSuggestionOrderLbl);
            AgentTaskUserInterventionSuggestion.Description := StrSubstNo(SOAInterventionSuggestionDescriptionLbl, SOAInterventionSuggestionOrderLbl);
            AgentTaskUserInterventionSuggestion.Instructions := StrSubstNo(SOAInterventionSuggestionInstructionsLbl, SOAInterventionSuggestionOrderLbl);
            AgentTaskUserInterventionSuggestion.Insert();
        end;
    end;

    internal procedure GetAgentTaskPageContext(AgentUserId: Guid; AgentTaskId: BigInteger; PageId: Integer; RecordId: RecordId; var AgentTaskPageContext: Record "Agent Task Page Context")
    var
        Contact: Record Contact;
        Currency: Record Currency;
        Customer: Record Customer;
        GeneralLedgerSetup: Record "General Ledger Setup";
        SalesHeader: Record "Sales Header";
        SOAFiltersImpl: Codeunit "SOA Filters Impl.";
        CustomerFilter: Text;
        CurrencyCode: Code[10];
    begin
        Clear(AgentTaskPageContext);

        case PageId of
            Page::"Sales Quote",
            Page::"Sales Order":
                if SalesHeader.Get(RecordId) then
                    CurrencyCode := SalesHeader."Currency Code";
            Page::"Contact Card":
                if Contact.Get(RecordId) then begin
                    if Contact.Type = Contact.Type::Person then
                        if Contact.Get(Contact."Company No.") then;
                    CurrencyCode := Contact."Currency Code";
                end;
            Page::"Customer Card":
                if Customer.Get(RecordId) then
                    CurrencyCode := Customer."Currency Code";
            Page::"SOA Multi Items Availability":
                begin
                    CustomerFilter := SOAFiltersImpl.GetSecurityFiltersForCustomers(SOAFiltersImpl.GetSecurityFiltersForContacts(AgentTaskID));
                    if CustomerFilter <> '' then begin
                        Customer.SetFilter("No.", CustomerFilter);
                        if Customer.FindFirst() then
                            CurrencyCode := Customer."Currency Code";
                    end;
                end;
        end;

        if CurrencyCode <> '' then begin
            if Currency.Get(CurrencyCode) then
                SetAgentTaskPageContext(Currency.Code, Currency.GetCurrencySymbol(), AgentTaskPageContext)
        end else
            if GeneralLedgerSetup.Get() then
                SetAgentTaskPageContext(GeneralLedgerSetup."LCY Code", GeneralLedgerSetup.GetCurrencySymbol(), AgentTaskPageContext);
    end;
    
    local procedure SetAgentTaskPageContext(CurrencyCode: Code[10]; CurrencySymbol: Code[10]; var AgentTaskPageContext: Record "Agent Task Page Context")
    begin
        Clear(AgentTaskPageContext);
        AgentTaskPageContext."Currency Code" := CurrencyCode;
        AgentTaskPageContext."Currency Symbol" := CurrencySymbol;
        AgentTaskPageContext.Insert();
    end;

    local procedure SetSOASetupDefaults(var TempSOASetup: Record "SOA Setup" temporary; AgentUserSecurityID: Guid)
    begin
        TempSOASetup.Init();
        TempSOASetup."Incoming Monitoring" := true;
        TempSOASetup."Email Monitoring" := true;
        SetDefaultSalesDocConfig(TempSOASetup, true);
        TempSOASetup."Agent User Security ID" := AgentUserSecurityID;
        TempSOASetup.Insert();
    end;

    local procedure SetAgentDefaults(var TempSOAgent: Record Agent temporary)
    begin
        TempSOAgent.Init();
        TempSOAgent."User Name" := GetSOAUsername();
        TempSOAgent."Display Name" := SalesOrderAgentDisplayNameLbl;
        TempSOAgent.Insert();
    end;

    local procedure GetProfile(var AllProfile: Record "All Profile")
    var
        CurrentModuleInfo: ModuleInfo;
    begin
        NavApp.GetCallerModuleInfo(CurrentModuleInfo);
        AllProfile.Get(AllProfile.Scope::Tenant, CurrentModuleInfo.Id, SalesOrderAgentTok);
    end;

    local procedure GetPermissionSets(var TempAggregatePermissionSet: Record "Aggregate Permission Set" temporary)
    var
        AggregatePermissionSet: Record "Aggregate Permission Set";
        CurrentModuleInfo: ModuleInfo;
    begin
        TempAggregatePermissionSet.Reset();
        TempAggregatePermissionSet.DeleteAll();

        NavApp.GetCallerModuleInfo(CurrentModuleInfo);
        AggregatePermissionSet.SetRange("Role ID", SOAEditTok);
        AggregatePermissionSet.SetRange("App ID", CurrentModuleInfo.Id);
        AggregatePermissionSet.FindFirst();

        TempAggregatePermissionSet.TransferFields(AggregatePermissionSet, true);
        TempAggregatePermissionSet.Insert(true);
    end;

    local procedure GetSOAUsername(): Text[50]
    begin
        exit(SalesOrderAgentNameLbl + ' - ' + CompanyName());
    end;

    local procedure PrepareInstructions(var InstructionsSecret: SecretText; var SOASetup: Record "SOA Setup")
    begin
        GetAzureKeyVaultSecret(InstructionsSecret, 'BCSOAInstructionsV26');
        BuildPromptBasedOnSetup(InstructionsSecret, SOASetup);
        AddCompanyNameToSignature(InstructionsSecret);
    end;

    [NonDebuggable]
    local procedure BuildPromptBasedOnSetup(var InstructionsSecret: SecretText; var SOASetup: Record "SOA Setup")
    var
        PromptInfo: JsonObject;
        PromptHints: JsonToken;
        PromptOrder: JsonToken;
        PromptArray: JsonArray;
        PromptHint: JsonToken;
        InstructionsText: Text;
        HintName: Text;
        Prompt: Text;
        Include: Boolean;
        NextStepNo: Integer;
    begin
        InstructionsText := InstructionsSecret.Unwrap();
        PromptInfo.ReadFrom(InstructionsText);

        if SOASetup.IsEmpty then
            exit;

        PromptInfo.Get('prompt', PromptHints);
        PromptInfo.Get('order', PromptOrder);

        PromptArray := PromptOrder.AsArray();

        foreach PromptHint in PromptArray do begin
            NextStepNo := 0;
            HintName := PromptHint.AsValue().AsText();
            Include := CheckShouldBeIncluded(SOASetup, HintName);

            if Include then
                if PromptHints.AsObject().Get(HintName, PromptHint) then
                    ProcessJToken(SOASetup, Prompt, PromptHint, '', NextStepNo, false);
        end;
        InstructionsSecret := Prompt;
    end;

    [NonDebuggable]
    local procedure ProcessJToken(var SOASetup: Record "SOA Setup"; var Prompt: Text; JToken: JsonToken; ParentStepNo: Text; var NextStepNo: Integer; AddNumbering: Boolean): Boolean
    begin
        case true of
            JToken.IsValue():
                exit(ProcessJTokenAsValue(Prompt, JToken, ParentStepNo, NextStepNo));

            JToken.IsObject():
                exit(ProcessJTokenAsObject(SOASetup, Prompt, JToken.AsObject(), ParentStepNo, NextStepNo));

            JToken.IsArray():
                exit(ProcessJTokenAsArray(SOASetup, Prompt, JToken.AsArray(), ParentStepNo, AddNumbering));
        end;
    end;

    [NonDebuggable]
    local procedure ProcessJTokenAsValue(var Prompt: Text; JToken: JsonToken; ParentStepNo: Text; var NextStepNo: Integer): Boolean
    var
        Value: Text;
        IsPageSpecInstructionTag: Boolean;
    begin
        Value := JToken.AsValue().AsText();
        IsPageSpecInstructionTag := Value.StartsWith('{%') and Value.EndsWith('%}');

        if IsPageSpecInstructionTag and (NextStepNo > 0) then
            NextStepNo -= 1;

        if not IsPageSpecInstructionTag and (NextStepNo > 0) then
            AddValueToPrompt(Prompt, Value, GetNextStepNo(ParentStepNo, NextStepNo))
        else
            AddValueToPrompt(Prompt, Value, '');

        exit(true);
    end;

    [NonDebuggable]
    local procedure ProcessJTokenAsObject(var SOASetup: Record "SOA Setup"; var Prompt: Text; JObject: JsonObject; ParentStepNo: Text; var NextStep: Integer): Boolean
    var
        AttributeJToken: JsonToken;
        Name: Text;
        IncludeStepNo: Boolean;
    begin
        if JObject.Get('name', AttributeJToken) then
            Name := AttributeJToken.AsValue().AsText();

        if not CheckShouldBeIncluded(SOASetup, Name) then
            exit(false);

        if JObject.Get('value', AttributeJToken) then
            ProcessJTokenAsValue(Prompt, AttributeJToken, ParentStepNo, NextStep);

        if JObject.Get('steps_include_numbering', AttributeJToken) then
            IncludeStepNo := AttributeJToken.AsValue().AsBoolean();

        if JObject.Get('steps', AttributeJToken) then
            ProcessJTokenAsArray(SOASetup, Prompt, AttributeJToken.AsArray(), GetNextStepNo(ParentStepNo, NextStep), IncludeStepNo);
        exit(true);
    end;

    [NonDebuggable]
    local procedure ProcessJTokenAsArray(var SOASetup: Record "SOA Setup"; var Prompt: Text; JArray: JsonArray; ParentStepNo: Text; AddNumbering: Boolean): Boolean
    var
        JToken: JsonToken;
        NextStep: Integer;
    begin
        if AddNumbering then
            NextStep := 1;
        foreach JToken in JArray do
            if ProcessJToken(SOASetup, Prompt, JToken, ParentStepNo, NextStep, AddNumbering) then
                if AddNumbering then
                    NextStep += 1;
        exit(true);
    end;

    local procedure GetNextStepNo(ParentStepNo: Text; StepNo: Integer): Text
    begin
        if StepNo = 0 then
            exit('');

        if ParentStepNo <> '' then
            exit(ParentStepNo + '.' + Format(StepNo));

        exit(Format(StepNo));
    end;

    [NonDebuggable]
    local procedure AddValueToPrompt(var Prompt: Text; Value: Text; StepNo: Text)
    var
        PrefixToAdd: Text;
        NewLineChar: Char;
    begin
        NewLineChar := 10;

        if StepNo <> '' then begin
            PrefixToAdd := StepNo + '. ';
            AddSpaceInFront(PrefixToAdd);
        end;

        Prompt += PrefixToAdd + Value + NewLineChar;
    end;

    local procedure AddSpaceInFront(var PrefixToAdd: Text)
    var
        DotsCount: Integer;
        i: Integer;
    begin
        if PrefixToAdd = '' then
            exit;
        DotsCount := StrLen(PrefixToAdd) - StrLen(PrefixToAdd.Replace('.', ''));
        if DotsCount < 2 then
            exit;
        for i := 1 to DotsCount - 1 do
            PrefixToAdd := ' ' + PrefixToAdd;
    end;

    local procedure CheckShouldBeIncluded(var SOASetup: Record "SOA Setup"; ValueName: Text): Boolean
    begin
        case ValueName of
            'create_sales_order':
                exit(SOASetup."Create Order from Quote" or not SOASetup."Sales Doc. Configuration");
            'no_sales_order':
                exit(not SOASetup."Create Order from Quote" and SOASetup."Sales Doc. Configuration");
            'review_quote_before_send':
                exit(SOASetup."Quote Review" and SOASetup."Sales Doc. Configuration");
            'review_order_before_send':
                exit(SOASetup."Order Review" and SOASetup."Sales Doc. Configuration");
            'item_availability':
                exit(SOASetup."Search Only Available Items");
            else
                exit(true);
        end;
    end;

    [NonDebuggable]
    local procedure AddCompanyNameToSignature(var InstructionsSecretValue: SecretText)
    var
        InstructionsText: Text;
    begin
        InstructionsText := InstructionsSecretValue.Unwrap();
        InstructionsText := StrSubstNo(InstructionsText, CompanyName());
        InstructionsSecretValue := InstructionsText;
    end;

    local procedure GetAzureKeyVaultSecret(var SecretValue: SecretText; SecretName: Text)
    var
        AzureKeyVault: Codeunit "Azure Key Vault";
        FeatureTelemetry: Codeunit "Feature Telemetry";
    begin
        if not AzureKeyVault.GetAzureKeyVaultSecret(SecretName, SecretValue) then begin
            FeatureTelemetry.LogError('0000NKG', SalesOrderAgentDisplayNameLbl, 'Get instructions from Key Vault', TelemetryGetInstructionsFailedErr);
            Error(SOASetupFailedErr);
        end;
    end;

    internal procedure ValidateEmailConnectionStatus(var TempSOASetup: Record "SOA Setup" temporary) ConnectionSuccess: Boolean
    var
        SOATestSetup: Codeunit "SOA Test Setup";
    begin
        SOATestSetup.SetTestEmailConnection(true);
        ConnectionSuccess := SOATestSetup.Run(TempSOASetup);
    end;

    internal procedure ValidateEmailConnection(StateChanged: Boolean; var TempSOASetup: Record "SOA Setup" temporary)
    var
        NAVAppSettings: Record "NAV App Setting";
        EnvironmentInformation: Codeunit "Environment Information";
        CurrentModuleInfo: ModuleInfo;
        GeneralError: Boolean;
    begin
        if TempSOASetup."Incoming Monitoring" and TempSOASetup."Email Monitoring" and not IsNullGuid(TempSOASetup."Email Account ID") then begin
            if StateChanged then
                UpdateSyncDateTime(TempSOASetup);

            if ValidateEmailConnectionStatus(TempSOASetup) then
                exit;

            if GuiAllowed() then begin
                GeneralError := true;
                if EnvironmentInformation.IsSandbox() then begin
                    NavApp.GetCurrentModuleInfo(CurrentModuleInfo);
                    NAVAppSettings.ReadIsolation(IsolationLevel::ReadUncommitted);
                    NAVAppSettings.SetRange("App ID", CurrentModuleInfo.Id);
                    if NAVAppSettings.FindFirst() then
                        if NAVAppSettings."Allow HttpClient Requests" = false then begin
                            GeneralError := false;
                            Error(SOAAttemptedConnectionHttpRequestFailedErr);
                        end;
                end;

                if GeneralError then
                    Error(SOAAttemptedConnectionFailedErr);
            end;
        end;
    end;

    internal procedure UpdateSyncDateTime(var TempSetup: Record "SOA Setup" temporary)
    var
        EmailsCount: Integer;
        ConfirmMessage: Text;
    begin
        // First activation
        if TempSetup."Activated At" = 0DT then begin
            TempSetup."Earliest Sync At" := CurrentDateTime();
            TempSetup."Last Sync At" := TempSetup."Earliest Sync At";
            exit;
        end;

        EmailsCount := GetEmailsCount(TempSetup);

        if EmailsCount = 0 then begin
            TempSetup."Earliest Sync At" := CurrentDateTime();
            TempSetup."Last Sync At" := TempSetup."Earliest Sync At";
            exit;
        end;

        if EmailsCount < SOAImpl.GetMaxNoOfEmails() then
            ConfirmMessage := StrSubstNo(NewEmailsSinceDeactivationLbl, Format(EmailsCount), Format(TempSetup."Last Sync At"))
        else
            ConfirmMessage := StrSubstNo(NewEmailsSinceDeactivationLbl, Format(EmailsCount) + '+', Format(TempSetup."Last Sync At"));

        if Confirm(ConfirmMessage, true) then
            TempSetup."Earliest Sync At" := TempSetup."Activated At"
        else
            TempSetup."Earliest Sync At" := CurrentDateTime();
        TempSetup."Last Sync At" := TempSetup."Earliest Sync At";
    end;

    local procedure GetEmailsCount(var TempSetup: Record "SOA Setup" temporary) EmailsCount: Integer
    var
        SOATestSetup: Codeunit "SOA Test Setup";
    begin
        SOATestSetup.SetTestEmailCount(true);
        if SOATestSetup.Run(TempSetup) then;
        EmailsCount := SOATestSetup.GetEmailCount();
    end;

    [EventSubscriber(ObjectType::Report, Report::"Copy Company", 'OnAfterCreatedNewCompanyByCopyCompany', '', false, false)]
    local procedure HandleOnAfterCreatedNewCompanyByCopyCompany(NewCompanyName: Text[30])
    var
        SOASetup: Record "SOA Setup";
        SOAKPIEntry: Record "SOA KPI Entry";
        SOAKPI: Record "SOA KPI";
        SOAEmail: Record "SOA Email";
    begin
        SOASetup.ChangeCompany(NewCompanyName);
        SOASetup.DeleteAll();

        SOAKPIEntry.ChangeCompany(NewCompanyName);
        SOAKPIEntry.DeleteAll();

        SOAKPI.ChangeCompany(NewCompanyName);
        SOAKPI.DeleteAll();

        SOAEmail.ChangeCompany(NewCompanyName);
        SOAEmail.DeleteAll();
    end;

    var
        SOAImpl: Codeunit "SOA Impl";
        SalesOrderAgentNameLbl: Label 'SALES ORDER AGENT', MaxLength = 17;
        SalesOrderAgentDisplayNameLbl: Label 'Sales Order Agent', MaxLength = 80;
        SalesOrderAgentTypeLbl: Label 'By Microsoft';
        SOAEditTok: Label 'SOA - EDIT', Locked = true, MaxLength = 20;
        SalesOrderAgentTok: Label 'Sales Order Agent', Locked = true;
        SalesOrderAgentInitialLbl: Label 'SO', MaxLength = 4;
        SOASummaryLbl: Label 'Monitors incoming emails for sales inquiries, matches senders to registered customers, checks inventory, and creates quotes. When sending quotes, the agent processes replies, and converts accepted quotes into orders.';
        DelegateAdminErr: Label 'Delegated admin and helpdesk users are not allowed to update the agent.';
        TelemetryGetInstructionsFailedErr: label 'There was an error getting instructions from the Key Vault.', Locked = true;
        SOASetupFailedErr: label 'There was an error setting up the Sales Order Copilot. Log a Business Central support request about this.';
        SOAInterventionSuggestionSummaryLbl: Label 'I have updated the %1', Comment = '%1 = Sales Document Type';
        SOAInterventionSuggestionDescriptionLbl: Label 'Used to indicate that a user has done some manual updates to a sales %1 as part of reviewing it before sending it to a customer.', Comment = '%1 = Sales Document Type';
        SOAInterventionSuggestionInstructionsLbl: Label 'I have updated the sales %1. Make sure to download the PDF again before including the %1 information in any outgoing communication.', Comment = '%1 = Sales Document Type';
        SOAInterventionSuggestionQuoteLbl: Label 'quote';
        SOAInterventionSuggestionOrderLbl: Label 'order';
        NewEmailsSinceDeactivationLbl: Label 'New e-mails (%1) have arrived since %2 but haven''t been processed yet. Should Sales Order Agent also process these?', Comment = '%1 - Number of emails, %2 - Date and time of deactivation.';
        SOAAttemptedConnectionFailedErr: Label 'The agent can''t be activated because the connection to the selected Microsoft 365 mailbox failed. Ask your Microsoft 365 administrator to check if the user configuring the agent has permission to access the mailbox.';
        SOAAttemptedConnectionHttpRequestFailedErr: Label 'The agent can''t be activated because its settings don''t allow Http Requests. Ask your administrator to update this setting and try again.';
}