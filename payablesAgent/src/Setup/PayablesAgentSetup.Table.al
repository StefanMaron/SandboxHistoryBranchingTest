// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.PayablesAgent;
using Microsoft.eServices.EDocument;

table 3303 "Payables Agent Setup"
{
    Access = Internal;
    Extensible = false;
    ReplicateData = false;

    fields
    {
        field(1; Id; Integer)
        {
            DataClassification = SystemMetadata;
        }
        field(2; "E-Document Service Code"; Code[20])
        {
            DataClassification = CustomerContent;
            TableRelation = "E-Document Service".Code;
        }
        field(3; "Monitor Outlook"; Boolean)
        {
            DataClassification = SystemMetadata;
        }
        field(4; "Agent User Security Id"; Guid)
        {
            DataClassification = SystemMetadata;
        }
    }
    keys
    {
        key(PK; Id)
        {
            Clustered = true;
        }
    }

    internal procedure GetSetup()
    begin
        if Rec.FindFirst() then
            exit;
        Rec.Insert();
    end;
}