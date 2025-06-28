// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.PayablesAgent;

permissionset 3305 "Payables Ag. - Read"
{
    Caption = 'Payables Agent - Read';
    Assignable = true;
    Permissions = tabledata "Payables Agent Setup" = R;
}