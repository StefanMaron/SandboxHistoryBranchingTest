// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.PayablesAgent;
using Microsoft.eServices.EDocument.Processing.Import.Purchase;

pagecustomization "PA EDoc Purchase Draft Subform" customizes "E-Doc. Purchase Draft Subform"
{
    ClearActions = true;
    ClearLayout = true;

    layout
    {
        modify("Line Type")
        {
            Visible = true;
        }
        modify("No.")
        {
            Visible = true;
        }
    }
}