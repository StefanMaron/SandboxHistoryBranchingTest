// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

#pragma warning disable AS0007
namespace Microsoft.Agent.SalesOrderAgent;

using System.AI;
using System.Agents;
using System.Azure.KeyVault;
using System.Environment;
using System.Email;
using System.Telemetry;
using System.Security.AccessControl;

codeunit 4587 "SOA Impl"
{
    Access = Internal;
    Permissions = tabledata "Email Inbox" = rd, tabledata User = R;
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        Telemetry: Codeunit "Telemetry";
        AgentTaskTitleLbl: Label 'Email from %1', Comment = '%1 = Sender Name';
        CantCreateTaskErr: Label 'User cannot create tasks.';
        CategoryLbl: Label 'Sales Order Agent', Locked = true;
        TelemetryEmailAddedAsTaskLbl: Label 'Email added as agent task.', Locked = true;
        TelemetryEmailReplySentLbl: Label 'Email reply sent.', Locked = true;
        TelemetryEmailReplyFailedToSendLbl: Label 'Email reply failed to send.', Locked = true;
        TelemetryEmailReplyExternalIdEmptyLbl: Label 'Email reply failed to be sent due to input agent task message containing empty External Id.', Locked = true;
        TelemetryFailedToGetInputAgentTaskMessageLbl: Label 'Failed to get input agent task message.', Locked = true;
        TelemetryNoEmailsFoundLbl: Label 'No emails found.', Locked = true;
        TelemetryEmailsFoundLbl: Label 'Emails found.', Locked = true;
        TelemetrySOASetupRecordNotValidLbl: Label 'SOA Setup record is not valid.', Locked = true;
        TelemetryAgentTaskNotFoundLbl: Label 'Agent task not found.', Locked = true;
        TelemetryAgentTaskMessageExistsLbl: Label 'Agent task message with external message id already exists.', Locked = true;
        TelemetryFailedToGetAgentTaskMessageAttachmentLbl: Label 'Failed to get agent task message attachment.', Locked = true;
        TelemetryAttachmentAddedToEmailLbl: Label 'Attachment added to email.', Locked = true;
        TelemetryAgentScheduledTaskCancelledLbl: Label 'Agent scheduled task cancelled.', Locked = true;
        TelemetryRecoveryScheduledTaskCancelledLbl: Label 'Recovery scheduled task cancelled.', Locked = true;
        TelemetryEmailAddedToExistingTaskLbl: Label 'Email added to existing task.', Locked = true;
        TelemetryAgentScheduledLbl: Label 'Agent scheduled.', Locked = true;
        TelemetryEmailInboxNotFoundLbl: Label 'Email inbox not found.', Locked = true;
        MessageTemplateLbl: Label '<b>Subject:</b> %1<br/><b>Body:</b> %2', Comment = '%1 = Subject, %2 = Body';
        SentMessageTemplateLbl: Label '<b>Sent:</b> %1<br/>', Comment = '%1 = Sender Address';
        ToMessageTemplateLbl: Label '<b>To:</b> %1<br/>', Comment = '%1 = Sender Address';
        FromMessageTemplateLbl: Label '<b>From:</b> %1<br/>', Comment = '%1 = Sender Address';
        EmailSubjectTxt: Label 'Sales order agent reply to task %1', Comment = '%1 = Agent Task id';
        TelemetryProcessingLimitReachedLbl: Label 'Processing limit of emails reached.', Locked = true;
        AnnotationProcessingLimitReachedCodeLbl: Label '1250', Locked = true;
        AnnotationAccessTokenCodeLbl: Label '1251', Locked = true;
        AnnotationAgentTaskFailureCodeLbl: Label '1252', Locked = true;
        AnnotationTooManyEntriesCodeLbl: Label '1253', Locked = true;
        AnnotationProcessingLimitReachedLbl: Label 'You have reached today''s limit of %1 tasks. Thank you for making the most of our AI feature! Feel free to return tomorrow to continue.', Comment = '%1 = Process Limit';
        AnnotationAccessTokenLbl: Label 'The agent can''t currently access the selected mailbox because the mailbox access token is missing. Please reactivate the agent after signing in to Business Central again.';
        AnnotationAgentTaskFailureLbl: Label 'The agent can''t currently access the selected mailbox.';
        TelemetrySOAEmailNotModifiedLbl: Label 'SOA Email record not modified.', Locked = true;
        EmailSeparatorTok: Label '<br/><hr/>', Locked = true;
        EmailXMLWrapperTxt: Label '<div>%1</div>', Locked = true, Comment = '%1 = Email message text';
        ScheduleBillingTask: Boolean;

    internal procedure ScheduleSOAgent(var SOASetup: Record "SOA Setup")
    var
        ScheduledTaskId: Guid;
    begin
        if IsNullGuid(SOASetup.SystemId) then begin
            Telemetry.LogMessage('0000NDU', TelemetrySOASetupRecordNotValidLbl, Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, GetCustomDimensions());
            exit;
        end;

        if not TaskScheduler.CanCreateTask() then
            Error(CantCreateTaskErr);

        RemoveScheduledTask(SOASetup);

        ScheduledTaskId := TaskScheduler.CreateTask(Codeunit::"SOA Dispatcher", Codeunit::"SOA Error Handler", true, CompanyName(), CurrentDateTime() + ScheduleDelay(), SOASetup.RecordId);
        SOASetup."Agent Scheduled Task ID" := ScheduledTaskId;
        ScheduleSOARecovery(SOASetup);

        SOASetup.Modify();
        Telemetry.LogMessage('0000NGM', TelemetryAgentScheduledLbl, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, GetCustomDimensions());
    end;

    /// <summary>
    /// Checks if the agent is active in the current company.
    /// Method must work even for users that have no access to Agent, thus we need to use User table to check if the agent is enabled.
    /// </summary>
    /// <returns>True if active agent exists, false otherwise.</returns>
    procedure ActiveAgentExistInCurrentCompany(): Boolean
    var
        SOASetup: Record "SOA Setup";
        User: Record User;
    begin
        SOASetup.ReadIsolation := IsolationLevel::ReadUncommitted;
        if not SOASetup.FindSet() then
            exit(false);

        // Picking safe option to assume it is enabled if no read permissions are in the system and there is SOA setup.
        User.ReadIsolation := IsolationLevel::ReadUncommitted;
        if not User.ReadPermission() then
            exit(true);

        repeat
            if User.Get(SOASetup."Agent User Security ID") then
                if User.State = User.State::Enabled then
                    exit(true);
        until SOASetup.Next() = 0;

        exit(false);
    end;

    internal procedure GetPreviousText(AgentTaskMessage: Record "Agent Task Message"): Text
    var
        PreviousAgentTaskMessage: Record "Agent Task Message";
        PreviousMessagesText: Text;
    begin
        PreviousAgentTaskMessage.SetRange("Task ID", AgentTaskMessage."Task ID");
        PreviousAgentTaskMessage.SetFilter(SystemCreatedAt, '<%1', AgentTaskMessage.SystemCreatedAt);
        PreviousAgentTaskMessage.ReadIsolation := IsolationLevel::ReadUncommitted;
        PreviousAgentTaskMessage.SetCurrentKey(SystemCreatedAt);
        PreviousAgentTaskMessage.Ascending(false);

        if not PreviousAgentTaskMessage.FindSet() then
            exit('');

        PreviousMessagesText := GetPreviousMessageText(PreviousAgentTaskMessage);
        if PreviousAgentTaskMessage.Next() <> 0 then begin
            repeat
                PreviousMessagesText += EmailSeparatorTok + GetPreviousMessageText(PreviousAgentTaskMessage);
            until PreviousAgentTaskMessage.Next() = 0;

            PreviousMessagesText := StrSubstNo(EmailXMLWrapperTxt, PreviousMessagesText);
        end;

        exit(PreviousMessagesText);
    end;

    local procedure GetPreviousMessageText(var PreviousAgentTaskMessage: Record "Agent Task Message"): Text
    var
        AgentMessage: Codeunit "Agent Message";
        ToAddress: Text;
        HeaderText: Text;
        TextMessage: Text;
    begin
        TextMessage := AgentMessage.GetText(PreviousAgentTaskMessage);
        Clear(HeaderText);
        if PreviousAgentTaskMessage.Type = PreviousAgentTaskMessage.Type::Output then begin
            if GetSentMessageToAddress(PreviousAgentTaskMessage, ToAddress) then
                HeaderText += StrSubstNo(ToMessageTemplateLbl, ToAddress);
            HeaderText += StrSubstNo(SentMessageTemplateLbl, Format(PreviousAgentTaskMessage.SystemModifiedAt));
        end;

        if (PreviousAgentTaskMessage.Type = PreviousAgentTaskMessage.Type::Input) then begin
            if (PreviousAgentTaskMessage.From <> '') then
                HeaderText += StrSubstNo(FromMessageTemplateLbl, PreviousAgentTaskMessage.From);
            HeaderText += StrSubstNo(SentMessageTemplateLbl, Format(GetSentMessageDate(PreviousAgentTaskMessage)));
        end;

        exit(HeaderText + TextMessage);
    end;

    internal procedure GetSentMessageDate(AgentTaskMessage: Record "Agent Task Message"): DateTime
    var
        SOAEmail: Record "SOA Email";
    begin
        SOAEmail.SetRange("Task ID", AgentTaskMessage."Task ID");
        SOAEmail.SetRange("Task Message ID", AgentTaskMessage.ID);
        if not SOAEmail.FindFirst() then
            exit(AgentTaskMessage.SystemCreatedAt);

        exit(SOAEmail."Sent DateTime");
    end;

    internal procedure GetSentMessageToAddress(var OutputAgentTaskMessage: Record "Agent Task Message"; var ToAddress: Text): Boolean
    var
        SentAgentTaskMessage: Record "Agent Task Message";
    begin
        Clear(ToAddress);
        if OutputAgentTaskMessage.Type <> OutputAgentTaskMessage.Type::Output then
            exit(false);

        if not SentAgentTaskMessage.Get(OutputAgentTaskMessage."Task ID", OutputAgentTaskMessage."Input Message ID") then
            exit(false);
        if SentAgentTaskMessage.From = '' then
            exit(false);

        ToAddress := SentAgentTaskMessage.From;
        exit(true);
    end;

    local procedure ScheduleSOARecovery(var SOASetup: Record "SOA Setup")
    var
        ScheduledTaskId: Guid;
    begin
        ScheduledTaskId := TaskScheduler.CreateTask(Codeunit::"SOA Recovery", Codeunit::"SOA Recovery", true, CompanyName(), CurrentDateTime() + ScheduleRecoveryDelay(), SOASetup.RecordId);
        SOASetup."Recovery Scheduled Task ID" := ScheduledTaskId;
    end;

    internal procedure RemoveScheduledTask(var SOASetup: Record "SOA Setup")
    var
        NullGuid: Guid;
    begin
        if TaskScheduler.TaskExists(SOASetup."Agent Scheduled Task ID") then begin
            TaskScheduler.CancelTask(SOASetup."Agent Scheduled Task ID");
            Telemetry.LogMessage('0000NGN', TelemetryAgentScheduledTaskCancelledLbl, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, GetCustomDimensions());
        end;

        if TaskScheduler.TaskExists(SOASetup."Recovery Scheduled Task ID") then begin
            TaskScheduler.CancelTask(SOASetup."Recovery Scheduled Task ID");
            Telemetry.LogMessage('0000NGO', TelemetryRecoveryScheduledTaskCancelledLbl, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, GetCustomDimensions());
        end;

        SOASetup."Agent Scheduled Task ID" := NullGuid;
        SOASetup."Recovery Scheduled Task ID" := NullGuid;
    end;

    local procedure ScheduleDelay(): Integer
    begin
        exit(20 * 1000) // 20 seconds
    end;

    local procedure ScheduleRecoveryDelay(): Integer
    begin
        exit(4 * 60 * 60 * 1000) // 4 hours
    end;

    internal procedure RetrieveEmails(SOASetup: Record "SOA Setup")
    var
        EmailInbox: Record "Email Inbox";
        TempFilters: Record "Email Retrieval Filters" temporary;
        SOAEmail: Record "SOA Email";
        Email: Codeunit "Email";
        SOASetupCU: Codeunit "SOA Setup";
        SOABillingTask: Codeunit "SOA Billing Task";
        Processed: Integer;
        ProcessLimit: Integer;
        CustomDimensions: Dictionary of [Text, Text];
        StartDateTime: DateTime;
    begin
        if not CheckSOASetupStillValid(SOASetup) then
            exit;

        CustomDimensions := GetCustomDimensions();
        ProcessLimit := GetProcessLimitPer24Hours();
        Processed := GetEmailCountProcessedWithin24hrs();

        if Processed >= ProcessLimit then begin
            CustomDimensions.Set('Processed', Format(Processed));
            CustomDimensions.Set('ProcessLimit', Format(ProcessLimit));
            Session.LogMessage('0000O9Y', StrSubstNo(TelemetryProcessingLimitReachedLbl), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
            exit;
        end;

        TempFilters."Unread Emails" := true;
        TempFilters."Load Attachments" := true;
        TempFilters."Max No. of Emails" := GetMaxNoOfEmails();
        TempFilters."Earliest Email" := SOASetup."Last Sync At";
        TempFilters."Last Message Only" := true;
        TempFilters.Insert();
        Email.RetrieveEmails(SOASetup."Email Account ID", SOASetup."Email Connector", EmailInbox, TempFilters);

        if not EmailInbox.FindSet() then begin
            Session.LogMessage('0000NDN', TelemetryNoEmailsFoundLbl, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
            exit;
        end;

        Session.LogMessage('0000NDO', TelemetryEmailsFoundLbl, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);

        //Get latest instructions from KV
        if not CheckSOASetupStillValid(SOASetup) then
            exit;

        SOASetupCU.UpdateInstructions(SOASetup);

        RemoveEmailsOutsideSyncRange(SOASetup, EmailInbox);
        AddEmailInboxToSOAEmails(SOASetup, EmailInbox);
        Commit();

        SOAEmail.SetRange(Processed, false);
        if SOAEmail.FindSet() then;

        StartDateTime := CurrentDateTime();
        repeat
            AddEmailToAgentTask(SOASetup, SOAEmail);
            // Prevent locks from being held for too long
            if CurrentDateTime() - StartDateTime > 25000 then begin
                Commit();
                StartDateTime := CurrentDateTime();
            end;

            Processed += 1;
            if Processed >= ProcessLimit then begin
                CustomDimensions := GetCustomDimensions();
                CustomDimensions.Set('Processed', Format(Processed));
                CustomDimensions.Set('ProcessLimit', Format(ProcessLimit));
                Session.LogMessage('0000O9Z', StrSubstNo(TelemetryProcessingLimitReachedLbl), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
                break;
            end;
        until SOAEmail.Next() = 0;

        if ScheduleBillingTask then
            SOABillingTask.ScheduleBillingTask();
    end;

    internal procedure CheckSOASetupStillValid(var SOASetup: Record "SOA Setup"): Boolean
    var
        CurrentSOASetup: Record "SOA Setup";
    begin
        CurrentSOASetup.ReadIsolation := IsolationLevel::ReadCommitted;
        CurrentSOASetup.SetAutoCalcFields(State);
        if not CurrentSOASetup.Get(SOASetup.RecordId) then
            exit(false);

        if not (CurrentSOASetup.State = CurrentSOASetup.State::Enabled) then
            exit(false);

        if SOASetup."Email Account ID" <> CurrentSOASetup."Email Account ID" then
            exit(false);

        exit(true);
    end;

    internal procedure GetMaxNoOfEmails(): Integer
    begin
        exit(50);
    end;

    internal procedure RemoveEmailsOutsideSyncRange(var SOASetup: Record "SOA Setup"; var EmailInbox: Record "Email Inbox")
    begin
        repeat
            if EmailInbox."Is Read" then
                EmailInbox.Delete(true);
        until EmailInbox.Next() = 0;

        if EmailInbox.FindSet() then;
    end;

    procedure AddEmailInboxToSOAEmails(SOASetup: Record "SOA Setup"; var EmailInbox: Record "Email Inbox")
    var
        SOAEmail: Record "SOA Email";
        Email: Codeunit "Email";
    begin
        repeat
            SOAEmail."Email Inbox ID" := EmailInbox.Id;
            SOAEmail."Sender Name" := EmailInbox."Sender Name";
            SOAEmail."Sender Address" := EmailInbox."Sender Address";
            SOAEmail."Sent DateTime" := EmailInbox."Sent DateTime";
            SOAEmail."Received DateTime" := EmailInbox."Received DateTime";

            if SOAEmail.Insert() then
                Email.MarkAsRead(SOASetup."Email Account ID", SOASetup."Email Connector", EmailInbox."External Message Id");
        until EmailInbox.Next() = 0;
    end;

    local procedure AddEmailToAgentTask(SOASetup: Record "SOA Setup"; var SOAEmail: Record "SOA Email")
    var
        EmailInbox: Record "Email Inbox";
        AgentTask: Codeunit "Agent Task";
    begin
        if not EmailInbox.Get(SOAEmail."Email Inbox ID") then begin
            Session.LogMessage('0000NJT', TelemetryEmailInboxNotFoundLbl, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, GetCustomDimensions());
            SOAEmail.Delete(true);
            exit;
        end;

        if AgentTask.TaskExists(SOASetup."Agent User Security ID", EmailInbox."Conversation Id") then
            AddEmailToExistingAgentTask(EmailInbox, SOAEmail)
        else
            AddEmailToNewAgentTask(SOASetup."Agent User Security ID", EmailInbox, SOAEmail);

        OnAfterProcessEmail(SOAEmail."Email Inbox ID");
    end;

    procedure AddEmailToNewAgentTask(AgentUserSecurityId: Guid; var EmailInbox: Record "Email Inbox"; var SOAEmail: Record "SOA Email")
    var
        AgentTaskRecord: Record "Agent Task";
        AgentTaskMessage: Record "Agent Task Message";
        AgentTask: Codeunit "Agent Task";
        EmailMessage: Codeunit "Email Message";
        SOABilling: Codeunit "SOA Billing";
        MessageText: Text;
    begin
        AgentTaskRecord."Agent User Security ID" := AgentUserSecurityId;
        AgentTaskRecord."External ID" := EmailInbox."Conversation Id";
        AgentTaskRecord.Title := CopyStr(StrSubstNo(AgentTaskTitleLbl, EmailInbox."Sender Name"), 1, MaxStrLen(AgentTaskRecord.Title));

        EmailMessage.Get(EmailInbox."Message Id");
        MessageText := StrSubstNo(MessageTemplateLbl, EmailMessage.GetSubject(), EmailMessage.GetBody());
        AgentTask.CreateTaskMessage(EmailInbox."Sender Address", MessageText, EmailInbox."External Message Id", AgentTaskRecord);

        AgentTaskRecord.SetRange("External ID", EmailInbox."Conversation Id");
        if not AgentTaskRecord.FindFirst() then
            exit;

        AgentTaskMessage.SetRange("Task ID", AgentTaskRecord.ID);
        AgentTaskMessage.ReadIsolation(IsolationLevel::ReadUncommitted);
        if AgentTaskMessage.FindLast() then begin
            SOAEmail.SetAgentMessageFields(AgentTaskMessage);
            SOAEmail.Modify();
            SOABilling.LogEmailRead(AgentTaskMessage.ID, AgentTaskMessage."Task ID");
            ScheduleBillingTask := true;
        end;

        Session.LogMessage('0000NDP', TelemetryEmailAddedAsTaskLbl, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, GetCustomDimensions());
    end;

    procedure AddEmailToExistingAgentTask(EmailInbox: Record "Email Inbox"; var SOAEmail: Record "SOA Email")
    var
        AgentTaskRecord: Record "Agent Task";
        AgentTaskMessage: Record "Agent Task Message";
        AgentTask: Codeunit "Agent Task";
        EmailMessage: Codeunit "Email Message";
        SOABilling: Codeunit "SOA Billing";
        MessageText: Text;
    begin
        AgentTaskRecord.ReadIsolation(IsolationLevel::ReadCommitted);
        AgentTaskRecord.SetRange("External ID", EmailInbox."Conversation Id");
        if not AgentTaskRecord.FindFirst() then begin
            Session.LogMessage('0000NDX', TelemetryAgentTaskNotFoundLbl, Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, GetCustomDimensions());
            exit;
        end;

        AgentTaskMessage.ReadIsolation(IsolationLevel::ReadCommitted);
        AgentTaskMessage.SetRange("Task ID", AgentTaskRecord.ID);
        AgentTaskMessage.SetRange("External ID", EmailInbox."External Message Id");
        if AgentTaskMessage.Count() >= 1 then begin
            Session.LogMessage('0000OFS', TelemetryAgentTaskMessageExistsLbl, Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, GetCustomDimensions());
            exit;
        end;

        EmailMessage.Get(EmailInbox."Message Id");
        MessageText := StrSubstNo(MessageTemplateLbl, EmailMessage.GetSubject(), EmailMessage.GetBody());
        AgentTask.CreateTaskMessage(EmailInbox."Sender Address", MessageText, EmailInbox."External Message Id", AgentTaskRecord);

        if SOAEmail.Get(EmailInbox.Id) then begin
            if not AgentTaskMessage.FindLast() then
                exit;

            SOAEmail.SetAgentMessageFields(AgentTaskMessage);
#pragma warning disable AA0214
            SOAEmail.Modify();
#pragma warning restore AA0214
            SOABilling.LogEmailRead(AgentTaskMessage.ID, AgentTaskMessage."Task ID");
            ScheduleBillingTask := true;
        end;

        Session.LogMessage('0000NGP', TelemetryEmailAddedToExistingTaskLbl, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, GetCustomDimensions());
    end;

    procedure SendEmailReplies(SOASetup: Record "SOA Setup")
    var
        OutputAgentTaskMessage: Record "Agent Task Message";
        InputAgentTaskMessage: Record "Agent Task Message";
        EmailOutbox: Record "Email Outbox";
        AgentMessage: Codeunit "Agent Message";
        CustomDimensions: Dictionary of [Text, Text];
    begin
        OutputAgentTaskMessage.ReadIsolation(IsolationLevel::ReadCommitted);
        OutputAgentTaskMessage.SetRange(Status, OutputAgentTaskMessage.Status::Reviewed);
        OutputAgentTaskMessage.SetRange(Type, OutputAgentTaskMessage.Type::Output);

        if not OutputAgentTaskMessage.FindSet() then
            exit;

        CustomDimensions := GetCustomDimensions();
        repeat
            Clear(EmailOutbox);
            CustomDimensions.Set('AgentTaskID', Format(OutputAgentTaskMessage."Task ID"));
            CustomDimensions.Set('AgentTaskMessageID', OutputAgentTaskMessage."ID");

            if not InputAgentTaskMessage.Get(OutputAgentTaskMessage."Task ID", OutputAgentTaskMessage."Input Message ID") then begin
                Session.LogMessage('0000NDQ', TelemetryFailedToGetInputAgentTaskMessageLbl, Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
                exit;
            end;
            if (InputAgentTaskMessage."External ID" = '') then begin
                Session.LogMessage('0000NDR', TelemetryEmailReplyExternalIdEmptyLbl, Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
                exit;
            end;

            if TryReply(InputAgentTaskMessage, OutputAgentTaskMessage, SOASetup) then begin
                AgentMessage.SetStatusToSent(OutputAgentTaskMessage);
                Session.LogMessage('0000NDS', TelemetryEmailReplySentLbl, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
            end else begin
                CustomDimensions.Set('Error', GetLastErrorText());
                Session.LogMessage('0000OAB', TelemetryEmailReplyFailedToSendLbl, Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
            end;
        until OutputAgentTaskMessage.Next() = 0;
    end;

    local procedure TryReply(InputAgentTaskMessage: Record "Agent Task Message"; OutputAgentTaskMessage: Record "Agent Task Message"; SOASetup: Record "SOA Setup"): Boolean
    var
        AgentMessage: Codeunit "Agent Message";
        Email: Codeunit Email;
        EmailMessage: Codeunit "Email Message";
        Body: Text;
        Subject: Text;
    begin
        Subject := StrSubstNo(EmailSubjectTxt, InputAgentTaskMessage."Task ID");
        Body := AgentMessage.GetText(OutputAgentTaskMessage);
        EmailMessage.CreateReplyAll(Subject, Body, true, InputAgentTaskMessage."External ID");
        AddMessageAttachments(EmailMessage, OutputAgentTaskMessage);

        exit(Email.ReplyAll(EmailMessage, SOASetup."Email Account ID", SOASetup."Email Connector"));
    end;

    local procedure AddMessageAttachments(var EmailMessage: Codeunit "Email Message"; var AgentTaskMessage: Record "Agent Task Message")
    var
        AgentTaskFile: Record "Agent Task File";
        AgentTaskMessageAttachment: Record "Agent Task Message Attachment";
        AgentTaskFileInStream: InStream;
    begin
        AgentTaskMessageAttachment.SetRange("Task ID", AgentTaskMessage."Task ID");
        AgentTaskMessageAttachment.SetRange("Message ID", AgentTaskMessage.ID);
        if not AgentTaskMessageAttachment.FindSet() then
            exit;

        repeat
            if not AgentTaskFile.Get(AgentTaskMessageAttachment."Task ID", AgentTaskMessageAttachment."File ID") then begin
                Telemetry.LogMessage('0000NE7', TelemetryFailedToGetAgentTaskMessageAttachmentLbl, Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, GetCustomDimensions());
                exit;
            end;
            AgentTaskFile.CalcFields(Content);
            //TODO: Refactor to a better interface 
            AgentTaskFile.Content.CreateInStream(AgentTaskFileInStream, TextEncoding::UTF8);
            EmailMessage.AddAttachment(AgentTaskFile."File Name", AgentTaskFile."File MIME Type", AgentTaskFileInStream);
            Telemetry.LogMessage('0000NE8', TelemetryAttachmentAddedToEmailLbl, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, GetCustomDimensions());
        until AgentTaskMessageAttachment.Next() = 0;
    end;

    internal procedure GetNumberOfAttachments(var AgentTaskMessage: Record "Agent Task Message"): Integer
    var
        AgentTaskMessageAttachment: Record "Agent Task Message Attachment";
    begin
        AgentTaskMessageAttachment.SetRange("Task ID", AgentTaskMessage."Task ID");
        AgentTaskMessageAttachment.SetRange("Message ID", AgentTaskMessage.ID);
        AgentTaskMessageAttachment.ReadIsolation := IsolationLevel::ReadUncommitted;
        exit(AgentTaskMessageAttachment.Count());
    end;

    local procedure GetFailedTaskLimit(): Integer
    begin
        exit(5);
    end;

    local procedure GetProcessLimit(): Integer
    var
        AzureKeyVault: Codeunit "Azure Key Vault";
        ProcessLimit: Integer;
        Result: Text;
        ExpiryDateTime: DateTime;
        EmailProcessLimitLbl: Label 'SOAEmailProcessLimit', Locked = true;
        EmailProcessLimitExpiryDateLbl: Label 'SOAEmailProcessLimitExpiryDate', Locked = true;
        FailToGetProcessLimitFromKVLbl: Label 'Failed to get SOA email process limit from key vault.', Locked = true;
    begin
        // If cached value is available and has not expired, return it
        if IsolatedStorage.Get(EmailProcessLimitExpiryDateLbl, Result) then begin
            Evaluate(ExpiryDateTime, Result, 9);
            if ExpiryDateTime > CurrentDateTime() then
                if IsolatedStorage.Get(EmailProcessLimitLbl, Result) then
                    if Evaluate(ProcessLimit, Result) then
                        exit(ProcessLimit);
        end;

        // If not cached or unable to get cached value, get from KV
        if AzureKeyVault.GetAzureKeyVaultSecret(EmailProcessLimitLbl, Result) then begin
            if Evaluate(ProcessLimit, Result) then begin
                if IsolatedStorage.Set(EmailProcessLimitLbl, Format(ProcessLimit)) then;

                ExpiryDateTime := CurrentDateTime() + 3600000; // One hour expiry
                if IsolatedStorage.Set(EmailProcessLimitExpiryDateLbl, Format(ExpiryDateTime, 0, 9)) then;
                exit(ProcessLimit);
            end;
        end else
            Session.LogMessage('0000OQC', FailToGetProcessLimitFromKVLbl, Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'category', CategoryLbl);

        exit(100); // Default if no cache and KV is unavailable
    end;

    local procedure GetProcessLimitPer24Hours(): Integer
    var
        SOAgent: Codeunit "SO Agent";
        Limit: Integer;
    begin
        Limit := GetProcessLimit();
        SOAgent.OnGetEmailProcessLimitPer24Hours(Limit);

        if Limit > GetProcessLimit() then
            exit(GetProcessLimit());
        exit(Limit);
    end;

    local procedure GetEmailCountProcessedWithin24hrs(): Integer
    var
        SOAEmail: Record "SOA Email";
        StartFromDT: DateTime;
    begin
        StartFromDT := CreateDateTime(CalcDate('<-1D>', CurrentDateTime().Date), 0T);

        SOAEmail.SetRange(Processed, true);
        SOAEmail.SetFilter(SystemModifiedAt, '>=%1', StartFromDT);
        exit(SOAEmail.Count());
    end;

    procedure RemoveProcessedEmailsOutsideLast24hrs()
    var
        SOAEmail: Record "SOA Email";
        Limit: DateTime;
    begin
        Limit := CreateDateTime(CalcDate('<-1D>', CurrentDateTime().Date), 0T);

        SOAEmail.SetRange(Processed, true);
        SOAEmail.SetFilter(SystemModifiedAt, '<%1', Limit);
        SOAEmail.SetRange("Agent Task Message Exist", false);
        SOAEmail.ReadIsolation := IsolationLevel::ReadCommitted;

        if not SOAEmail.FindSet() then
            exit;

        repeat
            SOAEmail.Delete(true);
        until SOAEmail.Next() = 0;
        Commit();
    end;

    procedure RemoveTaskLogsOlderThan24hrs()
    var
        SOATask: Record "SOA Task";
        Limit: DateTime;
    begin
        Limit := CreateDateTime(CalcDate('<-1D>', CurrentDateTime().Date), 0T);

        SOATask.SetFilter(SystemCreatedAt, '<%1', Limit);
        if not SOATask.FindSet() then
            exit;

        SOATask.DeleteAll();
        Commit();
    end;

    procedure GetCustomDimensions(): Dictionary of [Text, Text]
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Set('category', GetCategory());
        exit(CustomDimensions);
    end;

    procedure GetCategory(): Text
    begin
        exit(CategoryLbl);
    end;

    procedure RegisterCapability()
    var
        CopilotCapability: Codeunit "Copilot Capability";
        EnvironmentInformation: Codeunit "Environment Information";
        LearnMoreUrlTxt: Label 'https://go.microsoft.com/fwlink/?linkid=2281481', Locked = true;
    begin
        if EnvironmentInformation.IsSaaSInfrastructure() then; //TODO: Add this check back once the feature development is complete
        if not CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::"Sales Order Agent") then
            CopilotCapability.RegisterCapability(Enum::"Copilot Capability"::"Sales Order Agent", Enum::"Copilot Availability"::Preview, LearnMoreUrlTxt);
    end;

    local procedure ShouldAddOverProcessLimitAnnotation(): Boolean
    var
        Processed: Integer;
        ProcessLimit: Integer;
    begin
        ProcessLimit := GetProcessLimitPer24Hours();
        Processed := GetEmailCountProcessedWithin24hrs();

        exit(Processed >= ProcessLimit);
    end;

    local procedure AddOverProcessLimitAnnotation(var Annotations: Record "Agent Annotation")
    begin
        Clear(Annotations);
        Annotations.Code := AnnotationProcessingLimitReachedCodeLbl;
        Annotations.Message := AnnotationProcessingLimitReachedLbl;
        Annotations.Severity := Annotations.Severity::Warning;
        if Annotations.Insert() then;
    end;

    local procedure ShouldAddAccessTokenAnnotation(): Boolean
    var
        SOATask: Record "SOA Task";
        Counter: Integer;
        Failures: Integer;
    begin
#pragma warning disable AA0233
        if SOATask.FindLast() then;
#pragma warning restore AA0233

        repeat
            Counter += 1;
            if not SOATask."Access Token Retrieved" then
                Failures += 1
#pragma warning disable AA0181
        until (SOATask.Next(-1) = 0) or (Counter >= GetFailedTaskLimit());
#pragma warning restore AA0181

        exit(Failures >= GetFailedTaskLimit());
    end;

    local procedure AddAccessTokenAnnotation(var Annotations: Record "Agent Annotation")
    begin
        Clear(Annotations);
        Annotations.Code := AnnotationAccessTokenCodeLbl;
        Annotations.Message := AnnotationAccessTokenLbl;
        Annotations.Severity := Annotations.Severity::Warning;
        if Annotations.Insert() then;
    end;

    local procedure ShouldAddAgentTaskFailureAnnotation(): Boolean
    var
        SOATask: Record "SOA Task";
        Failures: Integer;
        Counter: Integer;
    begin
#pragma warning disable AA0233
        if SOATask.FindLast() then;
#pragma warning restore AA0233

        repeat
            Counter += 1;
            if SOATask.Status = SOATask.Status::"In Progress" then
                Failures += 1
#pragma warning disable AA0181
        until (SOATask.Next(-1) = 0) or (Counter >= GetFailedTaskLimit());
#pragma warning restore AA0181

        if Counter < GetFailedTaskLimit() then
            exit(false);

        exit(Failures >= GetFailedTaskLimit());
    end;

    local procedure AddAgentTaskFailureAnnotation(var Annotations: Record "Agent Annotation")
    begin
        Clear(Annotations);
        Annotations.Code := AnnotationAgentTaskFailureCodeLbl;
        Annotations.Message := AnnotationAgentTaskFailureLbl;
        Annotations.Severity := Annotations.Severity::Warning;
        if Annotations.Insert() then;
    end;

    local procedure AddUnpaidEntriesAnnotation(var Annotations: Record "Agent Annotation")
    var
        SOABilling: Codeunit "SOA Billing";
    begin
        Clear(Annotations);
        Annotations.Code := AnnotationTooManyEntriesCodeLbl;
        Annotations.Message := CopyStr(SOABilling.GetTooManyUnpaidEntriesMessage(), 1, MaxStrLen(Annotations.Message));
        Annotations.Severity := Annotations.Severity::Error;
        if Annotations.Insert() then;
    end;

    [InternalEvent(false, true)]
    local procedure OnAfterProcessEmail(EmailInboxId: BigInteger)
    begin
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"SOA Impl", 'OnAfterProcessEmail', '', false, false)]
    local procedure OnAfterEmailProcessed(EmailInboxId: BigInteger)
    var
        SOAEmail: Record "SOA Email";
        CustomDimensions: Dictionary of [Text, Text];
    begin
        SOAEmail.Get(EmailInboxId);
        SOAEmail.Processed := true;
        if not SOAEmail.Modify() then begin
            CustomDimensions := GetCustomDimensions();
            CustomDimensions.Set('EmailInboxID', Format(EmailInboxId));
            Session.LogMessage('0000OA0', TelemetrySOAEmailNotModifiedLbl, Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"SOA Email", 'OnBeforeDeleteEvent', '', false, false)]
    local procedure OnBeforeDeleteSOAEmailEvent(var Rec: Record "SOA Email"; RunTrigger: Boolean)
    var
        EmailInbox: Record "Email Inbox";
    begin
        EmailInbox.Id := Rec."Email Inbox ID";
        if EmailInbox.Delete(true) then;
    end;

    internal procedure GetAgentAnnotations(AgentUserId: Guid; var Annotations: Record "Agent Annotation")
    var
        SOASetup: Record "SOA Setup";
        SOABilling: Codeunit "SOA Billing";
    begin
        SOASetup.SetRange("Agent User Security ID", AgentUserId);
        if not SOASetup.FindFirst() then
            exit;

        SOASetup.CalcFields(State);
        if SOASetup.State = SOASetup.State::Disabled then
            exit;

        Clear(Annotations);

        if ShouldAddOverProcessLimitAnnotation() then
            AddOverProcessLimitAnnotation(Annotations);
        if ShouldAddAccessTokenAnnotation() then
            AddAccessTokenAnnotation(Annotations)
        else
            if ShouldAddAgentTaskFailureAnnotation() then
                AddAgentTaskFailureAnnotation(Annotations);

        if SOABilling.TooManyUnpaidEntries() then
            AddUnpaidEntriesAnnotation(Annotations);
    end;

}