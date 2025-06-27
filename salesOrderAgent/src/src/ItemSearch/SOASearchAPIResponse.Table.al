// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

#pragma warning disable AS0007
namespace Microsoft.Agent.SalesOrderAgent;

table 4591 "SOA Search API Response"
{
    Access = Internal;
    TableType = Temporary;
    InherentEntitlements = X;
    InherentPermissions = X;
    Caption = 'SOA Search API Response';

    fields
    {
        field(1; RecordFoundSystemID; Guid)
        {
            DataClassification = SystemMetadata;
        }
        field(2; Score; Decimal)
        {
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(Key1; RecordFoundSystemID)
        {
            Clustered = true;
        }
    }

}