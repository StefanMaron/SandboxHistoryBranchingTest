// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.SalesOrderAgent.Integration;

using System.Agents;
using Microsoft.CRM.Contact;
using Agent.SalesOrderAgent;

page 4404 "SOA Email Message"
{
    PageType = Card;
    ApplicationArea = All;
    SourceTable = "Agent Task Message";
    InsertAllowed = false;
    ModifyAllowed = true;
    DeleteAllowed = false;
    Caption = 'Agent Task Message';
    DataCaptionExpression = '';
    Extensible = false;
    InherentEntitlements = X;
    InherentPermissions = X;

    layout
    {
        area(Content)
        {
            group(General)
            {
                field(LastModifiedAt; Rec.SystemModifiedAt)
                {
                    Caption = 'Last modified at';
                    ToolTip = 'Specifies the date and time when the message was last modified.';
                }
                field(CreatedAt; Rec.SystemCreatedAt)
                {
                    Caption = 'Created at';
                    ToolTip = 'Specifies the date and time when the message was created.';
                }
                field(TaskID; Rec."Task Id")
                {
                    Caption = 'Task ID';
                    Visible = false;
                }
                field(MessageID; Rec."ID")
                {
                    Caption = 'ID';
                    Visible = false;
                }
                field(MessageType; Rec.Type)
                {
                    Caption = 'Type';
                }
                field(MessageFrom; Rec.From)
                {
                    Visible = Rec.Type = Rec.Type::Input;
                    Caption = 'From';
                    Editable = false;
                }
                field(Status; Rec.Status)
                {
                    Caption = 'Status';
                    Editable = false;
                }
                field(AttachmentsCount; AttachmentsCount)
                {
                    Caption = 'Attachments';
                    ToolTip = 'Specifies the number of attachments that are associated with the message.';
                    Editable = false;
                }
            }

            group(Message)
            {
                Caption = 'Message';
                Editable = IsMessageEditable;
                field(MessageText; GlobalMessageText)
                {
                    ShowCaption = false;
                    Caption = 'Message';
                    ToolTip = 'Specifies the message text.';
                    MultiLine = true;
                    ExtendedDatatype = RichContent;
                    Editable = IsMessageEditable;

                    trigger OnValidate()
                    var
                        AgentMessage: Codeunit "Agent Message";
                    begin
                        AgentMessage.UpdateText(Rec, GlobalMessageText);
                    end;

                }
            }
        }

    }

    actions
    {
        area(Processing)
        {
            action(DownloadAttachment)
            {
                ApplicationArea = All;
                Caption = 'Download attachments';
                ToolTip = 'Download the attachment.';
                Image = Download;
                Enabled = AttachmentsCount > 0;

                trigger OnAction()
                begin
                    DownloadAttachments();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(DownloadAttachment_Promoted; DownloadAttachment)
                {
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        UpdateControls();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        UpdateControls();
    end;

    local procedure UpdateControls()
    var
        AgentTaskMessageAttachment: Record "Agent Task Message Attachment";
        LastInputMessage: Record "Agent Task Message";
        AgentMessage: Codeunit "Agent Message";
        SOAFiltersImpl: Codeunit "SOA Filters Impl.";
    begin
        GlobalMessageText := AgentMessage.GetText(Rec);
        IsMessageEditable := AgentMessage.IsEditable(Rec);

        AgentTaskMessageAttachment.SetRange("Task ID", Rec."Task ID");
        AgentTaskMessageAttachment.SetRange("Message ID", Rec.ID);

        AttachmentsCount := AgentTaskMessageAttachment.Count();
        if Rec.Type = Rec.Type::Output then
            CurrPage.Caption(OutgoingMessageTxt);
        if Rec.Type = Rec.Type::Input then
            CurrPage.Caption(IncomingMessageTxt);

        LastInputMessage.Copy(Rec);
        if Rec.Type = Rec.Type::Output then
            if not LastInputMessage.Get(Rec."Task ID", Rec."Input Message ID") then
                exit;

        ContactExists := FindContact(GlobalContact, LastInputMessage);
        if not ContactExists then
            SOAFiltersImpl.ShowMissingContactNotification(LastInputMessage.From);
    end;

    local procedure DownloadAttachments()
    var
        AgentMessage: Codeunit "Agent Message";
    begin
        AgentMessage.DownloadAttachments(Rec);
    end;

    local procedure FindContact(var Contact: Record Contact; var AgentTaskMessage: Record "Agent Task Message"): Boolean
    var
        SOAFiltersImpl: Codeunit "SOA Filters Impl.";
    begin
        Contact.SetFilter("E-Mail", SOAFiltersImpl.GetSafeFromEmailFilter(AgentTaskMessage.From));
        if not Contact.FindFirst() then
            exit(false);

        exit(true);
    end;

    var
        GlobalContact: Record "Contact";
        GlobalMessageText: Text;
        IsMessageEditable: Boolean;
        AttachmentsCount: Integer;
        ContactExists: Boolean;
        OutgoingMessageTxt: Label 'Outgoing message';
        IncomingMessageTxt: Label 'Incoming message';
}