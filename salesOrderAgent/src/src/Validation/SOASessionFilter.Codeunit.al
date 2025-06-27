// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

#pragma warning disable AS0007
namespace Microsoft.Agent.SalesOrderAgent;

using Microsoft.Sales.Document;
using Microsoft.Sales.Customer;
using Microsoft.CRM.Contact;
using System.Security.User;

/// <summary>
/// This codeunit is used to filter the documents based on the contact that sent the email.
/// </summary>
codeunit 4306 "SOA Session Filter"
{
    Access = Internal;
    EventSubscriberInstance = Manual;
    InherentEntitlements = X;
    InherentPermissions = X;

    [EventSubscriber(ObjectType::Page, Page::"Sales Order", 'OnOpenPageEvent', '', false, false)]
    local procedure SetFiltersOnOpenSalesOrderPage(var Rec: Record "Sales Header")
    begin
        Rec.FilterGroup(10);
        SetFilterOnSalesHeader(Rec);
        Rec.FilterGroup(0);
    end;

    [EventSubscriber(ObjectType::Page, Page::"Sales Quotes", 'OnOpenPageEvent', '', false, false)]
    local procedure SetFiltersOnOpenSalesQuotesPage(var Rec: Record "Sales Header")
    begin
        Rec.FilterGroup(10);
        SetFilterOnSalesHeader(Rec);
        Rec.FilterGroup(0);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterModifyEvent', '', false, false)]
    local procedure VerifySameCustomer(var Rec: Record "Sales Header")
    var
        BackupSalesHeader: Record "Sales Header";
    begin
        if (Rec."Sell-to Contact No." = '') and (Rec."Sell-to Customer No." = '') then
            exit;

        BackupSalesHeader.Copy(Rec);
        SetFilterOnSalesHeader(BackupSalesHeader);
        if not BackupSalesHeader.Find() then
            Error(DifferentCustomerErr, BackupSalesHeader.GetView());
    end;

    [EventSubscriber(ObjectType::Page, Page::"SOA Multi Items Availability", 'OnAfterInitPage', '', false, false)]
    local procedure OnAfterInitPage(var CustomerNo: Code[20]; var LocationFilter: Text)
    var
        Customer: Record Customer;
        ShipToAddress: Record "Ship-to Address";
        SOASetup: Record "SOA Setup";
        UserSetupMgt: Codeunit "User Setup Management";
        SOAFiltersImpl: Codeunit "SOA Filters Impl.";
        LocationCode: Code[10];
        CustomerFilter: Text;
    begin
        CustomerFilter := SOAFiltersImpl.GetSecurityFiltersForCustomers(SOAFiltersImpl.GetSecurityFiltersForContacts(AgentTaskID));
        if CustomerFilter = '' then
            exit;

        Customer.SetFilter("No.", CustomerFilter);
        if Customer.FindFirst() then begin
            CustomerNo := Customer."No.";
            if SOASetup.FindFirst() then
                if SOASetup."Search Only Available Items" then begin
                    LocationCode := Customer."Location Code";
                    if Customer."Ship-to Code" <> '' then begin
                        ShipToAddress.SetLoadFields("Location Code");
                        if ShipToAddress.Get(Customer."No.", Customer."Ship-to Code") then
                            if ShipToAddress."Location Code" <> '' then
                                LocationCode := ShipToAddress."Location Code";
                    end;
                    LocationFilter := UserSetupMgt.GetLocation(0, LocationCode, Customer."Responsibility Center");
                end;
        end;
    end;

    local procedure SetFilterOnSalesHeader(var Rec: Record "Sales Header")
    var
        SOAFiltersImpl: Codeunit "SOA Filters Impl.";
        SOAImpl: Codeunit "SOA Impl";
        ContactFilter: Text;
        CustomerFilter: Text;
    begin
        ContactFilter := SOAFiltersImpl.GetSecurityFiltersForContacts(AgentTaskID);

        if ContactFilter <> '' then
            CustomerFilter := SOAFiltersImpl.GetSecurityFiltersForCustomers(ContactFilter);

        if (CustomerFilter <> '') and (CustomerFilter <> SOAFiltersImpl.GetExcludeAllFilter()) then begin
            Rec.SetFilter("Sell-to Customer No.", CustomerFilter);
            exit;
        end;

        if ContactFilter <> '' then begin
            Rec.SetFilter("Sell-to Contact No.", ContactFilter);
            exit;
        end;

        Rec.SetFilter("Sell-to Customer No.", SOAFiltersImpl.GetExcludeAllFilter());
        Session.LogMessage('0000O34', FilteringOutAllSalesRecordsTxt, Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, SOAImpl.GetCustomDimensions());
    end;

    [EventSubscriber(ObjectType::Page, Page::"Contact List", 'OnOpenPageEvent', '', false, false)]
    local procedure SetFiltersOnOpenContactPage(var Rec: Record "Contact")
    var
        SOAFiltersImpl: Codeunit "SOA Filters Impl.";
        ContactFilter: Text;
    begin
        ContactFilter := SOAFiltersImpl.GetSecurityFiltersForContacts(AgentTaskID);

        if ContactFilter = '' then
            exit;

        Rec.FilterGroup(10);
        Rec.SetFilter("No.", ContactFilter);
        Rec.FilterGroup(0);
    end;

    [EventSubscriber(ObjectType::Page, Page::"Customer List", 'OnOpenPageEvent', '', false, false)]
    local procedure SetFiltersOnOpenCustomerPage(var Rec: Record "Customer")
    var
        SOAFiltersImpl: Codeunit "SOA Filters Impl.";
        ContactFilter: Text;
        CustomerFilter: Text;
    begin
        ContactFilter := SOAFiltersImpl.GetSecurityFiltersForContacts(AgentTaskID);
        CustomerFilter := SOAFiltersImpl.GetSecurityFiltersForCustomers(ContactFilter);

        if CustomerFilter = '' then
            exit;

        Rec.FilterGroup(10);
        Rec.SetFilter("No.", CustomerFilter);
        Rec.FilterGroup(0);
    end;


    procedure SetAgentTaskID(TaskID: Integer)
    begin
        AgentTaskID := TaskID;
    end;

    var
        AgentTaskID: Integer;
        FilteringOutAllSalesRecordsTxt: Label 'Filtering out all sales header records.';
        DifferentCustomerErr: Label 'Agent cannot crete a quote for a different contact or customer than the one that has sent the request. Filter used: %1', Comment = '%1 - Filter that is used.';
}