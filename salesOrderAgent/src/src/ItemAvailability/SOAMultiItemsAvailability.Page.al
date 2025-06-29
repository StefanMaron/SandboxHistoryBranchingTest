// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Agent.SalesOrderAgent;

using Microsoft.Assembly.Document;
using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Transfer;
using Microsoft.Manufacturing.Document;
using Microsoft.Projects.Project.Planning;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Microsoft.Foundation.Period;
using Microsoft.Inventory.Location;
using System.Utilities;
using Microsoft.Inventory.Availability;

page 4410 "SOA Multi Items Availability"
{
    ApplicationArea = Basic, Suite;
    Caption = 'Item Availability';
    DeleteAllowed = false;
    InsertAllowed = false;
    PageType = List;
    SourceTable = Item;
    Extensible = false;
    InherentEntitlements = X;
    InherentPermissions = X;

    layout
    {
        area(Content)
        {
            group(Options)
            {
                Caption = 'Options';
                Visible = OptionsVisible;
                field(AnalysisPeriodType; AnalysisPeriodType)
                {
                    Caption = 'View by';
                    ToolTip = 'Specifies by which period amounts are displayed.';

                    trigger OnValidate()
                    begin
                        FindPeriod('');
                    end;
                }
                field(AnalysisAmountType; AnalysisAmountType)
                {
                    Caption = 'View as';
                    ToolTip = 'Specifies how amounts are displayed. Net Change: The net change in the balance for the selected period. Balance at Date: The balance as of the last day in the selected period.';

                    trigger OnValidate()
                    begin
                        FindPeriod('');
                    end;
                }
                field(DateFilter; DateFilter)
                {
                    Caption = 'Date Filter';
                    ToolTip = 'Specifies the dates that will be used to filter the amounts in the window.';

                    trigger OnValidate()
                    begin
                        Rec.SetFilter("Date Filter", DateFilter);
                        FindPeriod('');
                    end;
                }
                field(LocationFilter; LocationFilter)
                {
                    Caption = 'Location Filter';
                    ToolTip = 'Specifies the location(-s) that will be used to filter the amounts in the window.';

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        LocationList: Page "Location List";
                    begin
                        LocationList.LookupMode(true);
                        if LocationList.RunModal() = Action::LookupOK then begin
                            Text := LocationList.GetSelectionFilter();
                            exit(true);
                        end;
                    end;

                    trigger OnValidate()
                    begin
                        LocationFilter := LocationFilter.ToUpper();
                        Rec.SetFilter("Location Filter", LocationFilter);
                        CurrPage.Update(false);
                    end;
                }
                field(QuantityFilter; QuantityFilter)
                {
                    Caption = 'Quantity Filter';
                    ToolTip = 'Specifies the quantity filter that will be used to identify the available quantity.';
                    DecimalPlaces = 0 : 5;
                    trigger OnValidate()
                    begin
                        CurrPage.Update(false);
                    end;
                }
            }
            repeater(Control1)
            {
                Editable = false;
                field("No."; Rec."No.")
                {
                    ToolTip = 'Specifies a number of the item.';
                }
                field(Description; Rec.Description)
                {
                    ToolTip = 'Specifies a description of the item.';
                }
                field(Available; Available)
                {
                    Caption = 'Available';
                    ToolTip = 'Specifies if the required quantity is available.';
                }
                field(GrossRequirement; GrossRequirement)
                {
                    Caption = 'Gross Requirement';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies the sum of the total demand for the item. The gross requirement consists of independent demand (which include sales orders, service orders, transfer orders, and demand forecasts) and dependent demand, which include production order components for planned, firm planned, and released production orders and requisition and planning worksheets lines.';

                    trigger OnDrillDown()
                    begin
                        ShowItemAvailLineList(0);
                    end;
                }
                field(ScheduledRcpt; ScheduledRcpt)
                {
                    Caption = 'Scheduled Receipt';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies the sum of items from replenishment orders. This includes firm planned and released production orders, purchase orders, and transfer orders.';

                    trigger OnDrillDown()
                    begin
                        ShowItemAvailLineList(2);
                    end;
                }
                field(PlannedOrderRcpt; PlannedOrderRcpt)
                {
                    Caption = 'Planned Receipt';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies the quantity on planned production orders plus planning worksheet lines plus requisition worksheet lines.';

                    trigger OnDrillDown()
                    begin
                        ShowItemAvailLineList(1);
                    end;
                }
                field(Inventory; Rec.Inventory)
                {
                    Caption = 'Inventory';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies the inventory level of an item.';

                    trigger OnDrillDown()
                    var
                        Item: Record Item;
                    begin
                        Item.Copy(Rec);
                        ItemAvailFormsMgt.ShowItemLedgerEntries(Item, false);
                    end;
                }
                field(ProjAvailableBalance; ProjAvailableBalance)
                {
                    Caption = 'Available Quantity';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies the item''s availability. This quantity includes all known supply and demand but does not include anticipated demand from demand forecasts or blanket sales orders or suggested supplies from planning or requisition worksheets.';

                    trigger OnDrillDown()
                    begin
                        ShowItemAvailLineList(4);
                    end;
                }
                field(QtyOnPurchOrder; Rec."Qty. on Purch. Order")
                {
                    Caption = 'Qty. on Purch. Order';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies how many units of the item are inbound on purchase orders, meaning listed on outstanding purchase order lines.';
                    Visible = false;

                    trigger OnDrillDown()
                    var
                        Item: Record Item;
                    begin
                        Item.Copy(Rec);
                        PurchAvailabilityMgt.ShowPurchLines(Item);
                    end;
                }
                field(QtyOnSalesOrder; Rec."Qty. on Sales Order")
                {
                    Caption = 'Qty. on Sales Order';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies how many units of the item are allocated to sales orders, meaning listed on outstanding sales orders lines.';
                    Visible = false;

                    trigger OnDrillDown()
                    var
                        Item: Record Item;
                    begin
                        Item.Copy(Rec);
                        SalesAvailabilityMgt.ShowSalesLines(Item);
                    end;
                }
                field(QtyOnJobOrder; Rec."Qty. on Job Order")
                {
                    Caption = 'Qty. on Project Order';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies how many units of the item are allocated to projects, meaning listed on outstanding project planning lines. The field is automatically updated based on the Remaining Qty. field in the Project Planning Lines window.';
                    Visible = false;

                    trigger OnDrillDown()
                    var
                        Item: Record Item;
                    begin
                        Item.Copy(Rec);
                        JobPlanningAvailabilityMgt.ShowJobPlanningLines(Item);
                    end;
                }
                field(TransOrdShipmentQty; Rec."Trans. Ord. Shipment (Qty.)")
                {
                    Caption = 'Trans. Ord. Shipment (Qty.)';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies the quantity of the items that remains to be shipped. The program calculates this quantity as the difference between the Quantity and the Quantity Shipped fields. It automatically updates the field each time you either update the Quantity or Quantity Shipped field.';
                    Visible = false;

                    trigger OnDrillDown()
                    var
                        Item: Record Item;
                    begin
                        Item.Copy(Rec);
                        TransferAvailabilityMgt.ShowTransLines(Item, Item.FieldNo("Trans. Ord. Shipment (Qty.)"));
                    end;
                }
                field(QtyOnAsmComponent; Rec."Qty. on Asm. Component")
                {
                    Caption = 'Qty. on Asm. Comp. Lines';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies how many units of the item are allocated to assembly component orders.';
                    Visible = false;

                    trigger OnDrillDown()
                    var
                        Item: Record Item;
                    begin
                        Item.Copy(Rec);
                        AssemblyAvailabilityMgt.ShowAsmCompLines(Item);
                    end;
                }
                field(QtyOnAssemblyOrder; Rec."Qty. on Assembly Order")
                {
                    Caption = 'Qty. on Assembly Order';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies how many units of the item are allocated to assembly orders, which is how many are listed on outstanding assembly order headers.';
                    Visible = false;

                    trigger OnDrillDown()
                    var
                        Item: Record Item;
                    begin
                        Item.Copy(Rec);
                        AssemblyAvailabilityMgt.ShowAsmOrders(Item);
                    end;
                }
                field(QtyInTransit; Rec."Qty. in Transit")
                {
                    Caption = 'Qty. in Transit';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies the quantity of the items that are currently in transit.';
                    Visible = false;

                    trigger OnDrillDown()
                    var
                        Item: Record Item;
                    begin
                        Item.Copy(Rec);
                        TransferAvailabilityMgt.ShowTransLines(Item, Item.FieldNo("Qty. in Transit"));
                    end;
                }
                field(TransOrdReceiptQty; Rec."Trans. Ord. Receipt (Qty.)")
                {
                    Caption = 'Trans. Ord. Receipt (Qty.)';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies the quantity of the items that remain to be received but are not yet shipped. The program calculates this quantity as the difference between the Quantity and the Quantity Shipped fields. It automatically updates the field each time you either update the Quantity or Quantity Shipped field.';
                    Visible = false;

                    trigger OnDrillDown()
                    var
                        Item: Record Item;
                    begin
                        Item.Copy(Rec);
                        TransferAvailabilityMgt.ShowTransLines(Item, Item.FieldNo("Trans. Ord. Receipt (Qty.)"));
                    end;
                }
                field(ExpectedInventory; ExpectedInventory)
                {
                    Caption = 'Expected Inventory';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies the quantity of the item that is expected to be in inventory at the end of the period entered in the Date Filter field.';
                    Visible = false;
                }
                field(QtyAvailable; QtyAvailable)
                {
                    Caption = 'Available Inventory';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies the quantity of the item that is currently in inventory and not reserved for other demand.';
                    Visible = false;
                }
                field(ScheduledReceiptQty; Rec."Scheduled Receipt (Qty.)")
                {
                    Caption = 'Scheduled Receipt (Qty.)';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies how many units of the item are scheduled for production orders. The program automatically calculates and updates the contents of the field, using the Remaining Quantity field on production order lines.';
                    Visible = false;

                    trigger OnDrillDown()
                    var
                        Item: Record Item;
                    begin
                        Item.Copy(Rec);
                        ProdOrderAvailabilityMgt.ShowSchedReceipt(Item);
                    end;
                }
                field(QtyOnComponentLines; Rec."Qty. on Component Lines")
                {
                    Caption = 'Qty. on Component Lines';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies the sum of items from planned production orders.';
                    Visible = false;

                    trigger OnDrillDown()
                    var
                        Item: Record Item;
                    begin
                        Item.Copy(Rec);
                        ProdOrderAvailabilityMgt.ShowSchedNeed(Item);
                    end;
                }
                field(PlannedOrderReleases; PlannedOrderReleases)
                {
                    Caption = 'Planned Order Releases';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies the sum of items from replenishment order proposals, which include planned production orders and planning or requisition worksheets lines, that are calculated according to the starting date in the planning worksheet and production order or the order date in the requisition worksheet. This sum is not included in the projected available inventory. However, it indicates which quantities should be converted from planned to scheduled receipts.';

                    trigger OnDrillDown()
                    begin
                        ShowItemAvailLineList(3);
                    end;
                }
                field(NetChange; Rec."Net Change")
                {
                    Caption = 'Net Change';
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'Specifies the net change in the inventory of the item during the period entered in the Date Filter field.';
                    Visible = false;

                    trigger OnDrillDown()
                    var
                        Item: Record Item;
                    begin
                        Item.Copy(Rec);
                        ItemAvailFormsMgt.ShowItemLedgerEntries(Item, true);
                    end;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {

            action(PreviousPeriod)
            {
                Caption = 'Previous Period';
                Image = PreviousRecord;
                ToolTip = 'Show the information based on the previous period. If you set the View by field to Day, the date filter changes to the day before.';

                trigger OnAction()
                begin
                    FindPeriod('<=');
                end;
            }
            action(NextPeriod)
            {
                Caption = 'Next Period';
                Image = NextRecord;
                ToolTip = 'Show the information based on the next period. If you set the View by field to Day, the date filter changes to the day after.';

                trigger OnAction()
                begin
                    FindPeriod('>=');
                end;
            }
            group("&Item")
            {
                Caption = '&Item';
                Image = Item;
                group(ItemAvailabilityBy)
                {
                    Caption = '&Item Availability by';
                    Image = ItemAvailability;
                    action("Event")
                    {
                        Caption = 'Event';
                        Image = Event;
                        ToolTip = 'View how the actual and the projected available balance of an item will develop over time according to supply and demand events.';

                        trigger OnAction()
                        var
                            Item: Record Item;
                        begin
                            Item.Copy(Rec);
                            ItemAvailFormsMgt.ShowItemAvailabilityFromItem(Item, "Item Availability Type"::"Event");
                        end;
                    }
                    action(Period)
                    {
                        Caption = 'Period';
                        Image = Period;
                        RunObject = Page "Item Availability by Periods";
                        RunPageLink = "No." = field("No."),
                                      "Global Dimension 1 Filter" = field("Global Dimension 1 Filter"),
                                      "Global Dimension 2 Filter" = field("Global Dimension 2 Filter"),
                                      "Location Filter" = field("Location Filter"),
                                      "Drop Shipment Filter" = field("Drop Shipment Filter"),
                                      "Variant Filter" = field("Variant Filter");
                        ToolTip = 'Show the projected quantity of the item over time according to time periods, such as day, week, or month.';
                    }
                    action(Variant)
                    {
                        Caption = 'Variant';
                        Image = ItemVariant;
                        RunObject = Page "Item Availability by Variant";
                        RunPageLink = "No." = field("No."),
                                      "Global Dimension 1 Filter" = field("Global Dimension 1 Filter"),
                                      "Global Dimension 2 Filter" = field("Global Dimension 2 Filter"),
                                      "Location Filter" = field("Location Filter"),
                                      "Drop Shipment Filter" = field("Drop Shipment Filter"),
                                      "Variant Filter" = field("Variant Filter");
                        ToolTip = 'View or edit the item''s variants. Instead of setting up each color of an item as a separate item, you can set up the various colors as variants of the item.';
                    }
                    action("BOM Level")
                    {
                        Caption = 'BOM Level';
                        Image = BOMLevel;
                        ToolTip = 'View availability figures for items on bills of materials that show how many units of a parent item you can make based on the availability of child items.';

                        trigger OnAction()
                        var
                            Item: Record Item;
                        begin
                            Item.Copy(Rec);
                            ItemAvailFormsMgt.ShowItemAvailabilityFromItem(Item, "Item Availability Type"::BOM);
                        end;
                    }
                }
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(PreviousPeriod_Promoted; PreviousPeriod) { }
                actionref(NextPeriod_Promoted; NextPeriod) { }
            }
        }
    }

    trigger OnInit()
    var
        SOASetup: Record "SOA Setup";
        SOAKPITrackAll: Codeunit "SOA - KPI Track All";
        AgentType, AgentTaskID : Integer;
    begin
        AnalysisPeriodType := AnalysisPeriodType::Day;
        AnalysisAmountType := AnalysisAmountType::"Balance at Date";

        OptionsVisible := true;
        if SOAKPITrackAll.IsOrderTakerAgentSession(AgentType, AgentTaskID) then
            if SOASetup.FindLast() then
                OptionsVisible := SOASetup."Search Only Available Items";
    end;

    trigger OnOpenPage()
    begin
        LocationFilter := Rec.GetFilter("Location Filter");
        Rec.SetRange("Drop Shipment Filter", false);
        Rec.SetRange("Variant Filter", '');

        FindPeriod('');
    end;

    trigger OnFindRecord(Which: Text): Boolean
    var
        Found: Boolean;
        IsHandled: Boolean;
    begin
        IsHandled := false;
        OnBeforeFindRecord(Rec, Which, CrossColumnSearchFilter, Found, QuantityFilter, IsHandled);
        if IsHandled then
            exit(Found);

        exit(Rec.Find(Which));
    end;

    trigger OnAfterGetRecord()
    begin
        CalcAvailQuantities(GrossRequirement, PlannedOrderRcpt, ScheduledRcpt, PlannedOrderReleases, ProjAvailableBalance, ExpectedInventory, QtyAvailable);
    end;

    var
        Calendar: Record Date;
        AssemblyAvailabilityMgt: Codeunit "Assembly Availability Mgt.";
        ItemAvailFormsMgt: Codeunit "Item Availability Forms Mgt";
        JobPlanningAvailabilityMgt: Codeunit "Job Planning Availability Mgt.";
        ProdOrderAvailabilityMgt: Codeunit "Prod. Order Availability Mgt.";
        PurchAvailabilityMgt: Codeunit "Purch. Availability Mgt.";
        SalesAvailabilityMgt: Codeunit "Sales Availability Mgt.";
        TransferAvailabilityMgt: Codeunit "Transfer Availability Mgt.";
        AnalysisAmountType: Enum "Analysis Amount Type";
        AnalysisPeriodType: Enum "Analysis Period Type";
        QuantityFilter, ExpectedInventory, QtyAvailable, PlannedOrderReleases, GrossRequirement, PlannedOrderRcpt, ScheduledRcpt, ProjAvailableBalance : Decimal;
        DateFilter, LocationFilter, CrossColumnSearchFilter : Text;
        Available: Boolean;
        OptionsVisible: Boolean;

    local procedure ShowItemAvailLineList(What: Integer)
    var
        Item: Record Item;
    begin
        Item.Copy(Rec);
        ItemAvailFormsMgt.ShowItemAvailLineList(Item, What);
    end;

    local procedure CalcAvailQuantities(var GrossRequirement2: Decimal; var PlannedOrderRcpt2: Decimal; var ScheduledRcpt2: Decimal; var PlannedOrderReleases2: Decimal; var ProjAvailableBalance2: Decimal; var ExpectedInventory2: Decimal; var AvailableInventory: Decimal)
    var
        Item: Record Item;
        DummyQtyAvailable: Decimal;
    begin
        Item.Copy(Rec);
        if Item.Type = Item.Type::Inventory then begin
            Item.SetFilter("Date Filter", DateFilter);
            Item.SetFilter("Location Filter", LocationFilter);
            Item.SetRange("Drop Shipment Filter", false);
            Item.SetRange("Variant Filter", '');

            ItemAvailFormsMgt.CalcAvailQuantities(Item, AnalysisAmountType = AnalysisAmountType::"Balance at Date", GrossRequirement2, PlannedOrderRcpt2, ScheduledRcpt2,
                PlannedOrderReleases2, ProjAvailableBalance2, ExpectedInventory2, DummyQtyAvailable, AvailableInventory);
            Available := (ProjAvailableBalance2 > 0) and (ProjAvailableBalance2 >= QuantityFilter);
        end else
            Available := true;
    end;

    local procedure FindPeriod(SearchText: Text[3])
    var
        PeriodPageMgt: Codeunit PeriodPageManagement;
    begin
        if Rec.GetFilter("Date Filter") <> '' then begin
            Calendar.SetFilter("Period Start", Rec.GetFilter("Date Filter"));
            if not PeriodPageMgt.FindDate('+', Calendar, AnalysisPeriodType) then
                PeriodPageMgt.FindDate('+', Calendar, "Analysis Period Type"::Day);
            Calendar.SetRange("Period Start");
        end;
        PeriodPageMgt.FindDate(SearchText, Calendar, AnalysisPeriodType);
        if AnalysisAmountType = AnalysisAmountType::"Net Change" then begin
            Rec.SetRange("Date Filter", Calendar."Period Start", Calendar."Period End");
            if Rec.GetRangeMin("Date Filter") = Rec.GetRangeMax("Date Filter") then
                Rec.SetRange("Date Filter", Rec.GetRangeMin("Date Filter"));
        end else
            Rec.SetRange("Date Filter", 0D, Calendar."Period End");
        DateFilter := Rec.GetFilter("Date Filter");
        CurrPage.Update(false);
    end;

    [InternalEvent(false, false)]
    local procedure OnBeforeFindRecord(var Rec: Record Item; Which: Text; var CrossColumnSearchFilter: Text; var Found: Boolean; RequiredQuantity: Decimal; var IsHandled: Boolean)
    begin
    end;
}