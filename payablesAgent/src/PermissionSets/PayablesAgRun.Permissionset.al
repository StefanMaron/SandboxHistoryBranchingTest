// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.PayablesAgent;
using System.Security.AccessControl;
using Microsoft.eServices.EDocument;
using System.Utilities;
using System.Agents;
using Microsoft.Integration.Entity;

/// <summary>
/// The permissionset that the agent will be assigned to when they are created in the system. This permissionset is used to give the agent access to the pages and actions that are needed to perform their tasks.
/// </summary>
permissionset 3303 "Payables Ag. - Run"
{
    Caption = 'Payables Agent - Run';
    Assignable = true;
    IncludedPermissionSets =
        // Basic permissions to access the system
        "D365 Basic - Read",
        "D365 READ",
        "LOCAL",
        // Permissions to be able to interact with e-documents and create purchase documents
        "D365 PURCH DOC, EDIT",
        "E-Doc. Core - Basic",
        "E-Doc. Core - Edit";

    Permissions =
        // Missing permissions to create purchase documents
        tabledata "Error Message" = IMD,
        tabledata "Purch. Inv. Entity Aggregate" = IMD,
        // Other
        tabledata "Agent Task Message" = R; // Needed to add the filter of the e-documents that are available for the current session of the agent

    ExcludedPermissionSets =
        // Permissions that are not needed for the agent to perform their tasks
        "Payables Ag. - Excluded";
}