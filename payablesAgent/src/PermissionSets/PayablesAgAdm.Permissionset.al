// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.PayablesAgent;

permissionset 3304 "Payables Ag. - Adm."
{
    Caption = 'Payables Agent - Administration';
    Assignable = true;
    IncludedPermissionSets = "Payables Ag. - Read";
    Permissions = tabledata "Payables Agent Setup" = IM;
}