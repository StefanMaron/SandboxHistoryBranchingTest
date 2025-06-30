// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.SalesOrderAgent;

using System.Environment.Configuration;
using Agent.SalesOrderAgent.ItemSearch;
using Agent.SalesOrderAgent.Integration;

codeunit 4304 "SOA Session Events"
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;
    SingleInstance = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"System Initialization", OnAfterLogin, '', false, false)]
    local procedure RegisterSubscribersOnAfterLogin()
    begin
        RegisterSubscribers();
    end;

    procedure RegisterSubscribers()
    var
        AgentType: Integer;
        AgentTaskID: Integer;
        TrackChanges: Boolean;
    begin
        // Cover a case when a regular session is updating the work Agent did
        if not GlobalSOAKPITrackAll.IsOrderTakerAgentSession(AgentType, AgentTaskID) then begin
            TrackChanges := GlobalSOAKPITrackAll.TrackChanges();
            if TrackChanges then
                BindUserEvents();
            exit;
        end;

        SetupKPITrackingEvents();
        SetupItemSearchEvents();
        SetupFilteringEvents(AgentTaskID);
    end;

    internal procedure BindUserEvents()
    var
        SOAImpl: Codeunit "SOA Impl";
    begin
        if not BindSubscription(GlobalSOAKPITrackAll) then
            Session.LogMessage('0000O41', FailedToBindSubscriptionErr, Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, SOAImpl.GetCustomDimensions());
    end;

    local procedure SetupKPITrackingEvents()
    begin
        if BindSubscription(GlobalSOAKPITrackAll) then;
        if BindSubscription(GlobalSOAKPITrackAgents) then;
    end;

    local procedure SetupItemSearchEvents()
    begin
        if BindSubscription(GlobalSOAItemSearch) then;
        if BindSubscription(GlobalSOAVariantSearch) then;
    end;

    local procedure SetupFilteringEvents(AgentTaskID: Integer)
    var
        SOAImpl: Codeunit "SOA Impl";
        DisableFilters: Boolean;
    begin
        GlobalSessionFilter.SetAgentTaskID(AgentTaskID);
        OnDisableContactAndCustomerFiltering(DisableFilters);
        if not DisableFilters then
            BindSubscription(GlobalSessionFilter)
        else
            Session.LogMessage('0000O33', ContactFilteringDisabledAgentTxt, Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, SOAImpl.GetCustomDimensions());
    end;

    [InternalEvent(false, false)]
    local procedure OnDisableContactAndCustomerFiltering(var DisableFilters: Boolean)
    begin
    end;

    var
        GlobalSessionFilter: Codeunit "SOA Session Filter";
        GlobalSOAItemSearch: Codeunit "SOA Item Search";
        GlobalSOAVariantSearch: Codeunit "SOA Variant Search";
        GlobalSOAKPITrackAgents: Codeunit "SOA - KPI Track Agents";
        GlobalSOAKPITrackAll: Codeunit "SOA - KPI Track All";
        ContactFilteringDisabledAgentTxt: Label 'Contact and customer filtering is disabled for this agent through an event.', Locked = true;
        FailedToBindSubscriptionErr: Label 'Failed to bind subscription for User and Agent KPI changes.', Locked = true;
}