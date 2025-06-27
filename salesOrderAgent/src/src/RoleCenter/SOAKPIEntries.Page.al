// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.SalesOrderAgent;

using Microsoft.CRM.Contact;
using Microsoft.Sales.Customer;

page 4403 "SOA KPI Entries"
{
    PageType = List;
    Caption = 'Sales Order Agent Entries';
    ApplicationArea = All;
    SourceTable = "SOA KPI Entry";
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    InherentEntitlements = X;
    InherentPermissions = X;

    layout
    {
        area(Content)
        {
            repeater(Main)
            {
                field(Type; Rec."Record Type")
                {
                    Visible = TypeVisible;
                }
                field("No."; Rec."No.")
                {
                    trigger OnDrillDown()
                    begin
                        Rec.OpenCard();
                    end;
                }
                field(Status; Rec.Status)
                {
                }
                field(ContactNo; Rec."Contact No.")
                {
                    Visible = false;
                    trigger OnDrillDown()
                    var
                        Contact: Record "Contact";
                    begin
                        Contact.Get(Rec."Contact No.");
                        Page.Run(Page::"Contact Card", Contact);
                    end;
                }
                field(ContactName; Rec."Contact Name")
                {
                }
                field(CustomerNo; Rec."Customer No.")
                {
                    Visible = false;
                    trigger OnDrillDown()
                    var
                        Customer: Record "Customer";
                    begin
                        Customer.Get(Rec."Customer No.");
                        Page.Run(Page::"Customer Card", Customer);
                    end;
                }
                field(CustomerName; Rec."Customer Name")
                {
                }
                field(Amount; Rec."Amount Including Tax")
                {
                }
                field(SystemModifiedAt; Rec.SystemModifiedAt)
                {
                    Caption = 'Date modified';
                    ToolTip = 'Specifies the date and time when the record was last modified';
                }
            }
        }
    }

    actions
    {
        area(Creation)
        {
            action(View)
            {
                ApplicationArea = All;
                Caption = 'View';
                ToolTip = 'Opens the record if it exists.';
                Image = View;

                trigger OnAction()
                begin
                    Rec.OpenCard();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(View_Promoted; View)
                {
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        TypeVisible := Rec.GetFilter(Rec."Record Type") = '';
        if TypeVisible then
            exit;

        if Rec.GetFilter("Record Type") = Format(Rec."Record Type"::"Sales Order") then
            Caption := 'Sales Orders created by Sales Order Agent';

        if Rec.GetFilter("Record Type") = Format(Rec."Record Type"::"Sales Quote") then
            Caption := 'Sales Quotes created by Sales Order Agent';
    end;

    var
        TypeVisible: Boolean;
}