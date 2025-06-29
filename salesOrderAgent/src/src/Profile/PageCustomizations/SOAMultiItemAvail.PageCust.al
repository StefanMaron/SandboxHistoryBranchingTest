// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

#pragma warning disable AS0007
namespace Microsoft.Agent.SalesOrderAgent;

pagecustomization "SOA Multi Item Avail." customizes "SOA Multi Items Availability"
{
    ClearActions = true;
    ClearLayout = true;

    layout
    {
        modify("No.")
        {
            Visible = true;
        }
        modify("Description")
        {
            Visible = true;
        }
        modify(DateFilter)
        {
            Visible = true;
        }
        modify(QuantityFilter)
        {
            Visible = true;
        }
        modify(AvailabilityLevel)
        {
            Visible = true;
        }
        modify(UnitPriceInclDiscount)
        {
            Visible = true;
        }
        modify(CurrencyCode)
        {
            Visible = true;
        }
        modify(LineUOM)
        {
            Visible = true;
        }
        modify(MatchingItem)
        {
            Visible = true;
        }
    }
}