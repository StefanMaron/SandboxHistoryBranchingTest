// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.PayablesAgent;

profile "Payables Agent"
{
    Caption = 'Payables agent (Copilot)';
    Description = 'Default role center for payables agent';
    RoleCenter = "Payables Agent RC";
    Customizations = "PA E-Doc. Error Messages Part",
                     "PA E-Doc. Purchase Draft",
                     "PA EDoc Purchase Draft Subform",
                     "PA Inbound E-Documents",
                     "PA Purchase Invoice";
}
