// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.PayablesAgent;

page 3303 "Payables Agent RC"
{
    PageType = RoleCenter;
    Caption = 'Payables Agent';
    actions
    {
        area(Processing)
        {
            action(OpenEDocumentToProcess)
            {
                ApplicationArea = All;
                Caption = 'Open E-Document to Process';
                ToolTip = 'Open the E-Document to process.';
                RunObject = codeunit "PA Open Current E-Document";
            }
        }
    }
}