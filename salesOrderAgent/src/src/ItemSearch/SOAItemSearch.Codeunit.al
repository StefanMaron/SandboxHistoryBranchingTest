// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Agent.SalesOrderAgent.ItemSearch;

using Agent.SalesOrderAgent;
using Microsoft.Inventory.Availability;
using Microsoft.Inventory.Item;
using Microsoft.Sales.Document;
using System;
using System.AI;
using System.Environment.Configuration;

codeunit 4591 "SOA Item Search"
{
    Access = Internal;
    EventSubscriberInstance = Manual;
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        ItemSearchNotReadyErr: Label 'Item search is not ready';
        NotificationMsg: Label 'The available inventory for item %1 is lower than the entered quantity at this location.', Comment = '%1=Item Description';

    [TryFunction]
    procedure GetItemFilters(var ItemFilter: Text; SearchPrimaryKeyWords: List of [Text])
    var
        Item: Record Item;
        ALCopilotCapability: DotNet ALCopilotCapability;
        ALSearch: DotNet ALSearch;
        ALSearchOptions: DotNet ALSearchOptions;
        ALSearchQuery: DotNet ALSearchQuery;
        ALSearchResult: DotNet ALSearchResult;
        QueryResults: DotNet GenericList1;
        ALSearchQueryResult: DotNet ALSearchQueryResult;
        ALSearchMode: DotNet ALSearchMode;
        Keyword: Text;
        ItemNoFilter: Text;
    begin
        // If we can get the item uniquely by it's key fields i.e. No., then we don't need to perform extensive search when there is ItemNoFilter.
        if SearchPrimaryKeyWords.Count = 1 then begin
            ItemNoFilter := SearchPrimaryKeyWords.Get(1);
            if (ItemNoFilter <> '') and (StrLen(ItemNoFilter) <= MaxStrLen(Item."No.")) then begin
                Clear(Item);
                Item.SetLoadFields(SystemId);
                Item.ReadIsolation := IsolationLevel::ReadCommitted;
                Item.SetRange("No.", ItemNoFilter);
                Item.SetRange(Blocked, false);
                Item.SetRange("Sales Blocked", false);

                // Search only using key fields
                if Item.FindFirst() then begin
                    ItemFilter := Item.SystemId;
                    exit;
                end;
            end;
        end;

        CheckIsItemSearchReady();
        InitializeSearchOptionsObject(ALSearchOptions, ALCopilotCapability, '', 0, false, true);

        ALSearchQuery := ALSearchQuery.SearchQuery(SearchPrimaryKeyWords.Get(1));
        ALSearchQuery.Top(50);

        foreach Keyword in SearchPrimaryKeyWords do
            ALSearchQuery.AddRequiredTerm(Keyword.ToLower());

        ALSearchQuery.Mode := ALSearchMode::All;
        ALSearchOptions.AddSearchQuery(ALSearchQuery);

        // Search
        ALSearchResult := ALSearch.FindItems(ALSearchOptions, ALCopilotCapability);

        // Process results
        QueryResults := ALSearchResult.GetResultsForQuery(SearchPrimaryKeyWords.Get(1));

        foreach ALSearchQueryResult in QueryResults do
            ItemFilter += ALSearchQueryResult.SystemId + '|';

        ItemFilter := ItemFilter.TrimEnd('|');
    end;

    internal procedure InitializeSearchOptionsObject(var ALSearchOptions: DotNet ALSearchOptions; var ALCopilotCapability: DotNet ALCopilotCapability; SearchQuery: Text; MaximumQueryResultsToRank: Integer; IncludeSynonyms: Boolean; UseContextAwareRanking: Boolean)
    var
        Item: Record Item;
        SearchFilter: DotNet SearchFilter;
        ALSearchRankingContext: DotNet ALSearchRankingContext;
        CurrentModuleInfo: ModuleInfo;
        CapabilityName: Text;
    begin
        ALSearchOptions := ALSearchOptions.SearchOptions();
        ALSearchOptions.IncludeSynonyms := IncludeSynonyms;
        ALSearchOptions.UseContextAwareRanking := UseContextAwareRanking;

        // Add Search Filters
        SearchFilter := SearchFilter.SearchFilter();
        SearchFilter.FieldNo := Item.FieldNo(Blocked);
        SearchFilter.Expression := Text.StrSubstNo('<> %1', true);
        ALSearchOptions.AddSearchFilter(SearchFilter);

        SearchFilter := SearchFilter.SearchFilter();
        SearchFilter.FieldNo := Item.FieldNo("Sales Blocked");
        SearchFilter.Expression := Text.StrSubstNo('<> %1', true);
        ALSearchOptions.AddSearchFilter(SearchFilter);

        //Add Search Ranking Context
        if UseContextAwareRanking then begin
            ALSearchRankingContext := ALSearchRankingContext.SearchRankingContext();
            if SearchQuery <> '' then
                ALSearchRankingContext.UserMessage := SearchQuery;
            if MaximumQueryResultsToRank > 0 then
                ALSearchRankingContext.MaximumQueryResultsToRank := MaximumQueryResultsToRank;
            ALSearchRankingContext.RerankEvenIfOneResult := true;
            ALSearchOptions.RankingContext := ALSearchRankingContext;
        end;

        // Setup capability information
        NavApp.GetCurrentModuleInfo(CurrentModuleInfo);
        CapabilityName := Enum::"Copilot Capability".Names().Get(Enum::"Copilot Capability".Ordinals().IndexOf(Enum::"Copilot Capability"::"Sales Order Agent".AsInteger()));
        ALCopilotCapability := ALCopilotCapability.ALCopilotCapability(CurrentModuleInfo.Publisher(), CurrentModuleInfo.Id(), Format(CurrentModuleInfo.AppVersion()), CapabilityName);
    end;

    local procedure CheckIsItemSearchReady()
    var
        ALSearch: DotNet ALSearch;
        WaitingTime, SleepTime, TimeOutPeriod : Integer;
    begin
        WaitingTime := 0;
        SleepTime := 3000;
        TimeOutPeriod := 300000;
        while (not ALSearch.IsItemSearchReady()) and (WaitingTime <= TimeOutPeriod) do begin
            WaitingTime += SleepTime;
            Sleep(SleepTime);
        end;
        if not ALSearch.IsItemSearchReady() then
            Error(ItemSearchNotReadyErr);
    end;

    internal procedure EnableItemSearch()
    var
        ALSearch: DotNet ALSearch;
    begin
        if not ALSearch.IsItemSearchReady() then
            ALSearch.EnableItemSearch();
    end;

    [EventSubscriber(ObjectType::Page, Page::"Item List", 'OnBeforeFindRecord', '', false, false)]
    local procedure FindRecordItemFromList(var Rec: Record Item; Which: Text; var CrossColumnSearchFilter: Text; var Found: Boolean; var IsHandled: Boolean)
    begin
        FindRecordItem(Rec, Which, CrossColumnSearchFilter, Found, 0, IsHandled, false);
    end;

    [EventSubscriber(ObjectType::Page, Page::"Item Lookup", 'OnBeforeFindRecord', '', false, false)]
    local procedure FindRecordItemFromLookup(var Rec: Record Item; Which: Text; var CrossColumnSearchFilter: Text; var Found: Boolean; var IsHandled: Boolean)
    begin
        FindRecordItem(Rec, Which, CrossColumnSearchFilter, Found, 0, IsHandled, false);
    end;

    [EventSubscriber(ObjectType::Page, Page::"SOA Multi Items Availability", 'OnBeforeFindRecord', '', false, false)]
    local procedure FindRecordItemFromMultiItemsAvailability(var Rec: Record Item; Which: Text; var CrossColumnSearchFilter: Text; var Found: Boolean; RequiredQuantity: Decimal; var IsHandled: Boolean)
    begin
        FindRecordItem(Rec, Which, CrossColumnSearchFilter, Found, RequiredQuantity, IsHandled, true);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnAfterCheckItemAvailable', '', false, false)]
    local procedure OnAfterCheckItemAvailable(var SalesLine: Record "Sales Line"; CalledByFieldNo: Integer; HideValidationDialog: Boolean)
    var
        Item: Record Item;
        SOASetup: Record "SOA Setup";
        NotificationLifecycleMgt: Codeunit "Notification Lifecycle Mgt.";
        QuoteAvailabilityCheckNotification: Notification;
    begin
        if (SalesLine."Document Type" = SalesLine."Document Type"::Quote) and (SalesLine.Type = SalesLine.Type::Item) and (SalesLine."No." <> '') then
            if SOASetup.FindFirst() and SOASetup."Search Only Available Items" and Item.Get(SalesLine."No.") then begin
                Item.SetRange("Drop Shipment Filter", false);
                Item.SetRange("Variant Filter", '');
                Item.SetFilter("Date Filter", '..%1', SalesLine."Shipment Date");
                Item.SetFilter("Location Filter", '%1', SalesLine."Location Code");

                NotificationLifecycleMgt.RecallNotificationsForRecordWithAdditionalContext(SalesLine.RecordId, GetQuoteItemAvailabilityNotificationId(), true);
                if (SalesLine.Quantity > 0) and (not IsRequiredQuantityAvailable(Item, SalesLine.Quantity)) then begin
                    QuoteAvailabilityCheckNotification.Id(CreateGuid());
                    QuoteAvailabilityCheckNotification.Message(StrSubstNo(NotificationMsg, Item.Description));
                    QuoteAvailabilityCheckNotification.Scope(NotificationScope::LocalScope);
                    NotificationLifecycleMgt.SendNotificationWithAdditionalContext(QuoteAvailabilityCheckNotification, SalesLine.RecordId, GetQuoteItemAvailabilityNotificationId());
                end;
            end;
    end;

    local procedure GetQuoteItemAvailabilityNotificationId(): Guid
    begin
        exit('61dfb790-bf0c-47be-b95c-8e51afecd066');
    end;

    local procedure FindRecordItem(var Rec: Record Item; Which: Text; var CrossColumnSearchFilter: Text; var Found: Boolean; RequiredQuantity: Decimal; var IsHandled: Boolean; CheckAvalibility: Boolean)
    var
        SOASetup: Record "SOA Setup";
        Item: Record Item;
        BroaderItemSearch: Codeunit "SOA Broader Item Search";
        SearchKeyWords: List of [Text];
        SearchKeyWordsTrimmed: List of [Text];
        SearchFilter: Text;
        SplitedSearchKeywords: Text;
        SearchKeyword: Text;
        ItemFilter: Text;
        TrimmedItemFilter: Text;
        KeyWord: Text;
        OriginalFilterGroup: Integer;
        ItemSystemId: Guid;
    begin
        OriginalFilterGroup := Rec.FilterGroup();
        Rec.FilterGroup(-1);
        SearchFilter := Rec.GetFilter("No."); //Get current search filter
        Rec.FilterGroup(OriginalFilterGroup);

        if SearchFilter = CrossColumnSearchFilter then //If the search filter is the same as the last one, then we don't need to search again
            exit;
        CrossColumnSearchFilter := SearchFilter;

        SearchKeyWords := SearchFilter.Split('&&'); //Split and trim the search keywords
        foreach KeyWord in SearchKeyWords do begin
            SearchKeyword := KeyWord.TrimStart('&').TrimEnd('*').Trim();
            if SearchKeyword <> '' then
                SearchKeyWordsTrimmed.Add(SearchKeyword);
            if SearchKeyword <> '' then
                SplitedSearchKeywords += SearchKeyword + ',';
        end;

        if SearchKeyWordsTrimmed.Count() = 0 then
            exit;
        if not GetItemFilters(ItemFilter, SearchKeyWordsTrimmed) then   //Search for the items using the entity search
            exit;

        if (ItemFilter = '') and (SplitedSearchKeywords <> '') then
            BroaderItemSearch.BroaderItemSearch(ItemFilter, SplitedSearchKeywords.TrimEnd(','));

        if SOASetup.FindFirst() then
            if ItemFilter <> '' then begin
                foreach ItemSystemId in ItemFilter.Split('|') do begin
                    if Item.GetBySystemId(ItemSystemId) then
                        Item.CopyFilters(Rec);

                    if SOASetup."Search Only Available Items" and CheckAvalibility then begin
                        if IsRequiredQuantityAvailable(Item, RequiredQuantity) then
                            TrimmedItemFilter += ItemSystemId + '|'
                    end else
                        TrimmedItemFilter += ItemSystemId + '|';

                    if TrimmedItemFilter.Split('|').Count() - 1 = 10 then
                        break;
                end;
                ItemFilter := TrimmedItemFilter.TrimEnd('|');
            end;

        if ItemFilter <> '' then begin //IsHandled only if the search is successful
            Item.CopyFilters(Rec);

            Rec.Reset();
            Rec.SetFilter(SystemId, ItemFilter);

            Item.CopyFilter("Drop Shipment Filter", Rec."Drop Shipment Filter");
            Item.CopyFilter("Date Filter", Rec."Date Filter");
            Item.CopyFilter("Location Filter", Rec."Location Filter");
            Item.CopyFilter("Variant Filter", Rec."Variant Filter");
            Found := Rec.Find(Which);
        end;
        IsHandled := true;
    end;

    local procedure IsRequiredQuantityAvailable(var Item: Record Item; RequiredQuantity: Decimal): Boolean
    var
        Item2: Record Item;
        ItemAvailFormsMgt: Codeunit "Item Availability Forms Mgt";
        ExpectedInventory, DummyQtyAvailable, PlannedOrderReleases, GrossRequirement, PlannedOrderRcpt, ScheduledRcpt, ProjAvailableBalance, AvailableInventory : Decimal;
    begin
        Item2.Copy(Item);
        ItemAvailFormsMgt.CalcAvailQuantities(Item2, true, GrossRequirement, PlannedOrderRcpt, ScheduledRcpt,
            PlannedOrderReleases, ProjAvailableBalance, ExpectedInventory, DummyQtyAvailable, AvailableInventory);
        exit((ProjAvailableBalance > 0) and (ProjAvailableBalance >= RequiredQuantity));
    end;
}