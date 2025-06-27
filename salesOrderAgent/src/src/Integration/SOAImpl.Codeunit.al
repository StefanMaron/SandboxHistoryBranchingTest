// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.SalesOrderAgent.Integration;


using Agent.SalesOrderAgent;
using System.AI;
using System.Agents;
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
        TelemetryEmailReplyFailedtoSendLbl: Label 'Email reply failed to send.', Locked = true;
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
        MessageTemplateLbl: Label 'Subject: %1<br/>Body: %2', Locked = true;
        EmailSubjectTxt: Label 'Sales order agent reply to task %1', Comment = '%1 = Agent Task id';
        TelemetryProcessingLimitReachedLbl: Label 'Processing limit of emails reached.', Locked = true;
        AnnotationProcessingLimitReachedCodeLbl: Label '1250', Locked = true;
        AnnotationAccessTokenCodeLbl: Label '1251', Locked = true;
        AnnotationAgentTaskFailureCodeLbl: Label '1252', Locked = true;
        AnnotationProcessingLimitReachedLbl: Label 'You have reached today''s limit of %1 tasks. Thank you for making the most of our AI feature! Feel free to return tomorrow to continue.', Comment = '%1 = Process Limit';
        AnnotationAccessTokenLbl: Label 'The agent can''t currently access the selected mailbox because the mailbox access token is missing. Please reactivate the agent after signing in to Business Central again.';
        AnnotationAgentTaskFailureLbl: Label 'The agent can''t currently access the selected mailbox.';
        AnnotationCodeLbl: Label 'code', Locked = true;
        AnnotationMessageLbl: Label 'message', Locked = true;
        AnnotationSeverityLbl: Label 'severity', Locked = true;
        TelemetrySOAEmailNotModifiedLbl: Label 'SOA Email record not modified.', Locked = true;

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

        // Picking safe option to asume it is enabled if no read permissions are in the system and there is SOA setup.
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

    local procedure ScheduleSOARecovery(var SOASetup: Record "SOA Setup")
    var
        ScheduledTaskId: Guid;
    begin
        ScheduledTaskId := TaskScheduler.CreateTask(Codeunit::"SOA Recovery", Codeunit::"SOA Recovery", true, CompanyName(), CurrentDateTime() + ScheduleRecoveryDelay(), SOASetup.RecordId);
        SOASetup."Recovery Scheduled Task ID" := ScheduledTaskId;
    end;

    local procedure RemoveScheduledTask(var SOASetup: Record "SOA Setup")
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
        Counter: Integer;
        Processed: Integer;
        ProcessLimit: Integer;
        CustomDimensions: Dictionary of [Text, Text];
    begin
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

        RemoveEmailsOutsideSyncRange(SOASetup, EmailInbox);
        AddEmailInboxToSOAEmails(SOASetup, EmailInbox);
        Commit();

        SOAEmail.SetRange(Processed, false);
        if SOAEmail.FindSet() then;

        repeat
            AddEmailToAgentTask(SOASetup, SOAEmail);

            Counter += 1;
            if Counter mod 5 = 0 then
                Commit();

            Processed += 1;
            if Processed >= ProcessLimit then begin
                CustomDimensions := GetCustomDimensions();
                CustomDimensions.Set('Processed', Format(Processed));
                CustomDimensions.Set('ProcessLimit', Format(ProcessLimit));
                Session.LogMessage('0000O9Z', StrSubstNo(TelemetryProcessingLimitReachedLbl), Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
                break;
            end;
        until SOAEmail.Next() = 0;
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

    local procedure AddEmailInboxToSOAEmails(SOASetup: Record "SOA Setup"; var EmailInbox: Record "Email Inbox")
    var
        SOAEmail: Record "SOA Email";
        Email: Codeunit "Email";
    begin
        repeat
            SOAEmail."Email Inbox ID" := EmailInbox.Id;
            if SOAEmail.Insert() then
                Email.MarkAsRead(SOASetup."Email Account ID", SOASetup."Email Connector", EmailInbox."External Message Id");
        until EmailInbox.Next() = 0;
    end;

    local procedure AddEmailToAgentTask(SOASetup: Record "SOA Setup"; SOAEmail: Record "SOA Email")
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
            AddEmailToExistingAgentTask(EmailInbox)
        else
            AddEmailToNewAgentTask(SOASetup."Agent User Security ID", EmailInbox);

        OnAfterProcessEmail(SOAEmail."Email Inbox ID");
    end;

    local procedure AddEmailToNewAgentTask(AgentUserSecurityId: Guid; EmailInbox: Record "Email Inbox")
    var
        AgentTaskRecord: Record "Agent Task";
        AgentTask: Codeunit "Agent Task";
        EmailMessage: Codeunit "Email Message";
        MessageText: Text;
    begin
        AgentTaskRecord."Agent User Security ID" := AgentUserSecurityId;
        AgentTaskRecord."External ID" := EmailInbox."Conversation Id";
        AgentTaskRecord.Title := CopyStr(StrSubstNo(AgentTaskTitleLbl, EmailInbox."Sender Name"), 1, MaxStrLen(AgentTaskRecord.Title));

        EmailMessage.Get(EmailInbox."Message Id");
        MessageText := StrSubstNo(MessageTemplateLbl, EmailMessage.GetSubject(), EmailMessage.GetBody());
        AgentTask.CreateTaskMessage(EmailInbox."Sender Address", MessageText, EmailInbox."External Message Id", AgentTaskRecord);

        Session.LogMessage('0000NDP', TelemetryEmailAddedAsTaskLbl, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, GetCustomDimensions());
    end;

    local procedure AddEmailToExistingAgentTask(EmailInbox: Record "Email Inbox")
    var
        AgentTaskRecord: Record "Agent Task";
        AgentTaskMessage: Record "Agent Task Message";
        AgentTask: Codeunit "Agent Task";
        EmailMessage: Codeunit "Email Message";
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
                Session.LogMessage('0000OAB', TelemetryEmailReplyFailedtoSendLbl, Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
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

    local procedure GetFailedTaskLimit(): Integer
    begin
        exit(5);
    end;

    local procedure GetProcessLimit(): Integer
    begin
        exit(100);
    end;

    local procedure GetProcessLimitPer24Hours(): Integer
    var
        SOAEvent: Codeunit "SO Agent";
        Limit: Integer;
    begin
        Limit := GetProcessLimit();
        SOAEvent.OnGetEmailProcessLimitPer24Hours(Limit);

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
        if EnvironmentInformation.IsSaaSInfrastructure() then; //ToDo: Add this check back once the feature development is complete
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

    local procedure GetOverProcessLimitAnnotation() Annotation: JsonObject
    begin
        Annotation.Add(AnnotationCodeLbl, AnnotationProcessingLimitReachedCodeLbl);
        Annotation.Add(AnnotationMessageLbl, StrSubstNo(AnnotationProcessingLimitReachedLbl, GetProcessLimitPer24Hours()));
        Annotation.Add(AnnotationSeverityLbl, 'Warning');
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

    local procedure GetAccessTokenAnnotation() Annotation: JsonObject
    begin
        Annotation.Add(AnnotationCodeLbl, AnnotationAccessTokenCodeLbl);
        Annotation.Add(AnnotationMessageLbl, AnnotationAccessTokenLbl);
        Annotation.Add(AnnotationSeverityLbl, 'Warning');
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

    local procedure GetAgentTaskFailureAnnotation() Annotation: JsonObject
    begin
        Annotation.Add(AnnotationCodeLbl, AnnotationAgentTaskFailureCodeLbl);
        Annotation.Add(AnnotationMessageLbl, AnnotationAgentTaskFailureLbl);
        Annotation.Add(AnnotationSeverityLbl, 'Warning');
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

    [EventSubscriber(ObjectType::Table, Database::Agent, 'OnAfterModifyEvent', '', false, false)]
    local procedure OnAfterAgentModified(var Rec: Record Agent; var xRec: Record Agent; RunTrigger: Boolean)
    var
        SOASetup: Record "SOA Setup";
    begin
        if Rec.State = Rec.State::Enabled then begin
            SOASetup.SetRange("Agent User Security ID", Rec."User Security ID");
            if SOASetup.FindFirst() then
                if SOASetup."Email Monitoring" and SOASetup."Incoming Monitoring" then
                    ScheduleSOAgent(SOASetup);
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

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"System Action Triggers", 'GetAgentAnnotations', '', false, false)]
    local procedure GetAgentAnnotations(AgentUserId: Guid; var Annotations: JsonArray)
    var
        SOASetup: Record "SOA Setup";
    begin
        if not SOASetup.FindFirst() then
            exit;

        SOASetup.CalcFields(State);
        if SOASetup.State = SOASetup.State::Disabled then
            exit;

        if ShouldAddOverProcessLimitAnnotation() then
            Annotations.Add(GetOverProcessLimitAnnotation());
        if ShouldAddAccessTokenAnnotation() then
            Annotations.Add(GetAccessTokenAnnotation())
        else
            if ShouldAddAgentTaskFailureAnnotation() then
                Annotations.Add(GetAgentTaskFailureAnnotation());
    end;
}