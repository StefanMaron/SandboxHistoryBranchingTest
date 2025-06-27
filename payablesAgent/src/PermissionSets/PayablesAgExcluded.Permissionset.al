// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.PayablesAgent;
using Microsoft.Purchases.Vendor;


/// <summary>
/// Permissionset that has the permissions to be excluded from the Payables Agent to ensure no unintended access.
/// </summary>
permissionset 3306 "Payables Ag. - Excluded"
{
    Access = Internal;
    Caption = 'Payables Agent - Excluded';
    Permissions =
        tabledata Vendor = M;
}