// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;
using Agent.PayablesAgent;

pageextension 3303 "PA Inbound E-Documents" extends "Inbound E-Documents"
{
    trigger OnOpenPage()
    var
        EDocument: Record "E-Document";
        PayablesAgent: Codeunit "Payables Agent";
    begin
        EDocument := PayablesAgent.GetCurrentSessionsEDocument();
        if EDocument."Entry No" = 0 then
            exit;
        Rec.SetRange("Entry No", EDocument."Entry No");
    end;
}