// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.SalesOrderAgent;

using Microsoft.CRM.Contact;
using Agent.SalesOrderAgent.Integration;
using Microsoft.CRM.BusinessRelation;
using System.Agents;
using Microsoft.Sales.Customer;

codeunit 4305 "SOA Filters Impl."
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;
    Permissions = tabledata "Agent Task Message" = r;

    var
        ExcludeAllFilterTok: Label '<>*', Locked = true;

    procedure FindCustomer(var Contact: Record Contact; var Customer: Record Customer): Boolean
    var
        ContactBusinessRelation: Record "Contact Business Relation";
        ContactBusinessRelationFound: Boolean;
    begin
        if Contact.Type = Contact.Type::Person then
            ContactBusinessRelationFound := ContactBusinessRelation.FindByContact(ContactBusinessRelation."Link to Table"::Customer, Contact."No.");

        if not ContactBusinessRelationFound then
            ContactBusinessRelationFound := ContactBusinessRelation.FindByContact(ContactBusinessRelation."Link to Table"::Customer, Contact."Company No.");

        if not ContactBusinessRelationFound then
            exit(false);

        exit(Customer.Get(ContactBusinessRelation."No."));
    end;

    procedure GetSecurityFiltersForCustomers(ContactsFilter: Text): Text
    var
        Contact: Record Contact;
        Customer: Record Customer;
        SOAImpl: Codeunit "SOA Impl";
        ProcessedCustomers: List of [Text];
        CustomerFilter: Text;
    begin
        Contact.SetFilter("No.", ContactsFilter);

        if not Contact.FindSet() then begin
            Session.LogMessage('0000O31', NoContactsFoundTxt, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, SOAImpl.GetCustomDimensions());
            exit(ExcludeAllFilterTok);
        end;

        repeat
            if FindCustomer(Contact, Customer) then
                if not ProcessedCustomers.Contains(Customer."No.") then begin
                    ProcessedCustomers.Add(Customer."No.");
                    CustomerFilter += '|' + Customer."No.";
                end;
        until Contact.Next() = 0;

        CustomerFilter := CustomerFilter.TrimStart('|');
        if CustomerFilter = '' then
            CustomerFilter := ExcludeAllFilterTok;
        exit(CustomerFilter);
    end;

    procedure GetSecurityFiltersForContacts(AgentTaskID: Integer): Text
    var
        ContactList: List of [Text];
        ContactFilter: Text;
        ContactNo: Text;
    begin
        GetContactsInvolvedInTask(AgentTaskID, ContactList);
        if ContactList.Count() = 0 then
            exit(ExcludeAllFilterTok);

        foreach ContactNo in ContactList do
            ContactFilter += '|' + ContactNo;

        exit(ContactFilter.TrimStart('|'));
    end;

    procedure GetContactsInvolvedInTask(AgentTaskID: Integer; var ContactList: List of [Text])
    var
        AgentTaskMessage: Record "Agent Task Message";
        Contact: Record Contact;
        SOAImpl: Codeunit "SOA Impl";
        From: Text;
        ProcessedFromEmails: List of [Text];
    begin
        AgentTaskMessage.SetRange(Type, AgentTaskMessage.Type::Input);
        AgentTaskMessage.SetRange("Task ID", AgentTaskID);

        if not AgentTaskMessage.FindSet() then begin
            Session.LogMessage('0000O32', NoTaskMessagesFoundTxt, Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, SOAImpl.GetCustomDimensions());
            exit;
        end;

        repeat
            From := GetSafeFromEmailFilter(AgentTaskMessage.From);
            if not ProcessedFromEmails.Contains(From) then begin
                ProcessedFromEmails.Add(From);
                Contact.SetFilter("E-Mail", From);
                Contact.ReadIsolation := IsolationLevel::ReadUncommitted;
                if Contact.FindSet() then
                    repeat
                        if not ContactList.Contains(Contact."No.") then
                            ContactList.Add(Contact."No.");
                    until Contact.Next() = 0;
            end;
        until AgentTaskMessage.Next() = 0;
    end;

    procedure GetExcludeAllFilter(): Text
    begin
        exit(ExcludeAllFilterTok);
    end;

    procedure ShowMissingContactNotification(FromEmail: Text)
    var
        MissingContactNotification: Notification;
    begin
        MissingContactNotification.Id := '1a55c794-3b65-44b7-b0d8-433a5c0c6a7f';
        MissingContactNotification.Message := StrSubstNo(MissingContactNotificationLbl, FromEmail);
        if MissingContactNotification.Recall() then;
        MissingContactNotification.AddAction(CreateContactLbl, Codeunit::"SOA Filters Impl.", 'CreateContactFromEmail');
        MissingContactNotification.AddAction(LearnMoreLbl, Codeunit::"SOA Filters Impl.", 'LearnMoreNotRegisteredEmail');
        MissingContactNotification.SetData('FromEmail', FromEmail);
        MissingContactNotification.Send();
    end;

    procedure CreateContactFromEmail(MissingContactNotification: Notification)
    var
        Contact: Record Contact;
        FromEmail: Text;
    begin
        FromEmail := MissingContactNotification.GetData('FromEmail');
#pragma warning disable AA0139
        // Email cannot be truncated, we need an error
        Contact."E-Mail" := FromEmail;
#pragma warning restore AA0139
        Contact.Insert(true);
        Commit();
        Page.RunModal(Page::"Contact Card", Contact);
    end;

    procedure LearnMoreNotRegisteredEmail(MissingContactNotification: Notification)
    begin
        Hyperlink(SecurityFilteringDocumentationURLTxt);
    end;

    internal procedure GetSafeFromEmailFilter(FromEmail: Text): Text
    begin
        exit('''@' + LowerCase(FromEmail.TrimStart('"').TrimEnd('"').Trim()) + '''');
    end;

    var
        NoContactsFoundTxt: Label 'No contacts found for given email.', Locked = true;
        NoTaskMessagesFoundTxt: Label 'No agent task messages found for given task ID.', Locked = true;
        LearnMoreLbl: Label 'Learn more';
        CreateContactLbl: Label 'Create contact';
        SecurityFilteringDocumentationURLTxt: Label 'https://go.microsoft.com/fwlink/?linkid=2298901', Locked = true;
        MissingContactNotificationLbl: Label 'A contact with email <%1> is not found. Without it, document access and creation are not possible.', Comment = '%1 - email address';
}