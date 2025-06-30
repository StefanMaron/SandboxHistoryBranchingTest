// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.PayablesAgent;

using Microsoft.eServices.EDocument;

codeunit 3308 "PA Open Current E-Document"
{
    trigger OnRun()
    var
        EDocument: Record "E-Document";
        PayablesAgent: Codeunit "Payables Agent";
        EDocumentHelper: Codeunit "E-Document Helper";
    begin
        EDocument := PayablesAgent.GetCurrentSessionsEDocument();
        if EDocument."Entry No" = 0 then begin
            Page.Run(Page::"Inbound E-Documents");
            exit;
        end;
        EDocumentHelper.OpenDraftPage(EDocument);
    end;
}