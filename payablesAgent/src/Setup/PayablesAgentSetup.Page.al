// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.PayablesAgent;

using System.AI;
using Microsoft.EServices.EDocumentConnector.Microsoft365;
using System.Agents;
using System.Email;
using Microsoft.eServices.EDocument;

page 3304 "Payables Agent Setup"
{
    PageType = ConfigurationDialog;
    Extensible = false;
    ApplicationArea = All;
    IsPreview = true;
    Caption = 'Configure Payables Agent';
    SourceTable = Agent;
    SourceTableTemporary = true;
    InherentEntitlements = X;
    InherentPermissions = X;

    layout
    {
        area(Content)
        {
            group(StartCard)
            {
                group(Header)
                {
                    field(Badge; BadgeTxt)
                    {
                        ShowCaption = false;
                        Editable = false;
                        ToolTip = 'The badge of the payables agent.';
                    }
                    field(Type; 'by Microsoft')
                    {
                        ShowCaption = false;
                        Editable = false;
                        ToolTip = 'Specifies the type of the agent.';
                    }
                    field(Name; Rec."Display Name")
                    {
                        ShowCaption = false;
                        Editable = false;
                        ToolTip = 'The display name of the agent.';
                    }
                    field(State; Rec.State)
                    {
                        Caption = 'Active';
                        ToolTip = 'Specifies the state of the agent.';
                        OptionCaption = 'Active,Inactive';

                        trigger OnValidate()
                        begin
                            if Rec.State = Rec.State::Enabled then
                                TempPayablesAgentSetup."Monitor Outlook" := true
                            else
                                TempPayablesAgentSetup."Monitor Outlook" := false;
                            SetupChanged := true;
                            CurrPage.Update();
                        end;
                    }
                    field(UserSettingsLink; 'Manage user access')
                    {
                        Caption = 'Coworkers can use this agent.';
                        ApplicationArea = All;
                        ToolTip = 'Specifies the user access control settings for the payables agent.';

                        trigger OnDrillDown()
                        begin
                            if Page.RunModal(Page::"Select Agent Access Control", TempAgentAccessControl) = Action::LookupOK then
                                SetupChanged := true;
                        end;
                    }
                }
                field(Summary; AgentSummaryLbl)
                {
                    Caption = 'Summary';
                    MultiLine = true;
                    Editable = false;
                    ToolTip = 'Specifies the summary of the agent.';
                }
            }
            group(MonitorIncomingGroup)
            {
                Caption = 'Monitor incoming information';
                field(MonitorIncomingEmails; TempPayablesAgentSetup."Monitor Outlook")
                {
                    ShowCaption = false;
                    Caption = 'Monitor emails';
                    ToolTip = 'Specifies whether the agent should monitor incoming emails for PDF document attachments for processing.';

                    trigger OnValidate()
                    begin
                        if TempPayablesAgentSetup."Monitor Outlook" then
                            Rec.State := Rec.State::Enabled;
                        SetupChanged := true;
                        CurrPage.Update();
                    end;
                }
                group(MonitorEmailSettings)
                {
                    ShowCaption = false;
                    field(Mailbox; TempEmailAccount."Email Address")
                    {
                        Caption = 'Email account';
                        ToolTip = 'Specifies the Microsoft 365 mailbox from which to download PDF document attachments.';
                        Editable = false;
                        ShowMandatory = true;

                        trigger OnAssistEdit()
                        var
                            OutlookIntegration: Codeunit "Outlook Integration Impl.";
                        begin
                            if OutlookIntegration.SelectEmailAccountV3(TempEmailAccount) then
                                SetupChanged := true;
                        end;
                    }
                }
                field(Tip; SharedMailboxTipLbl)
                {
                    Caption = '';
                    ShowCaption = false;
                    MultiLine = true;
                    Editable = false;
                    ToolTip = 'Specifies the tip to use a dedicated shared mailbox.';
                }
                group(BillingInformationFirstSetup)
                {
                    InstructionalText = 'By enabling the Payables Agent, you understand your organization may be billed for its use in the future.';
                    Caption = 'Important';
                    field(LearnMoreBilling; LearnMoreTxt)
                    {
                        ShowCaption = false;
                        Editable = false;
                        trigger OnDrillDown()
                        begin
                            Hyperlink(LearnMoreBillingDocumentationLinkTxt);
                        end;
                    }
                }
            }
        }
    }
    actions
    {
        area(SystemActions)
        {
            systemaction(OK)
            {
                Caption = 'Update';
                Enabled = SetupChanged;
                ToolTip = 'Apply the changes to the agent setup.';
            }

            systemaction(Cancel)
            {
                Caption = 'Cancel';
                ToolTip = 'Discard the changes to the agent setup.';
            }
        }
    }

    trigger OnOpenPage()
    var
        AzureOpenAI: Codeunit "Azure OpenAI";
    begin
        if not AzureOpenAI.IsEnabled("Copilot Capability"::"Payables Agent") then
            Error(EnableCapabilityFirstErr);

        BadgeTxt := PayablesAgent.GetInitials();
        PayablesAgentSetup.LoadSetupConfiguration(PASetupConfiguration);
        TempPayablesAgentSetup := PASetupConfiguration.GetPayablesAgentSetup();
        TempEDocumentService := PASetupConfiguration.GetEDocumentService();
        TempEmailAccount := PASetupConfiguration.GetEmailAccount();
        PASetupConfiguration.GetAgentAccessControl(TempAgentAccessControl);
        Rec := PASetupConfiguration.GetAgent();
        if Rec.Insert() then;
    end;

    trigger OnModifyRecord(): Boolean
    begin
        SetupChanged := true;
        exit(true);
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if CloseAction = CloseAction::Cancel then
            exit(true);

        PASetupConfiguration.SetAgent(Rec);
        PASetupConfiguration.SetPayablesAgentSetup(TempPayablesAgentSetup);
        PASetupConfiguration.SetEDocumentService(TempEDocumentService);
        PASetupConfiguration.SetEmailAccount(TempEmailAccount);
        PASetupConfiguration.SetAgentAccessControl(TempAgentAccessControl);
        PayablesAgentSetup.ApplyPayablesAgentSetup(PASetupConfiguration);
        exit(true);
    end;



    var
        TempPayablesAgentSetup: Record "Payables Agent Setup" temporary;
        TempEDocumentService: Record "E-Document Service" temporary;
        TempEmailAccount: Record "Email Account" temporary;
        TempAgentAccessControl: Record "Agent Access Control" temporary;
        PayablesAgentSetup: Codeunit "Payables Agent Setup";
        PASetupConfiguration: Codeunit "PA Setup Configuration";
        PayablesAgent: Codeunit "Payables Agent";
        BadgeTxt: Text[4];
        SetupChanged: Boolean;
        LearnMoreTxt: Label 'Learn more';
        LearnMoreBillingDocumentationLinkTxt: Label 'https://go.microsoft.com/fwlink/?linkid=2298603';
        AgentSummaryLbl: Label 'Monitors incoming emails for sales invoices, matches senders to registered vendors, and creates invoices to reflect in the appropriate G/L accounts. This agent uses generative AI - review its actions for accuracy.';
        EnableCapabilityFirstErr: Label 'The payables agent capability is not configured. Please activate the copilot capability.';
        SharedMailboxTipLbl: label 'The agent reads all PDF attachments from the specified mailbox. Therefore, we recommend using a dedicated shared mailbox for receiving payables documents.';
}
