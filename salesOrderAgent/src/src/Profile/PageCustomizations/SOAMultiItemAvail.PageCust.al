// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.SalesOrderAgent;

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
    }
}