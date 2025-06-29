// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Agent.SalesOrderAgent.Integration;

using System.Email;

table 4585 "SOA Email"
{
    Access = Internal;
    DataClassification = SystemMetadata;
    InherentEntitlements = RIMDX;
    InherentPermissions = RIMDX;

    fields
    {
        field(1; "Email Inbox ID"; BigInteger)
        {
            TableRelation = "Email Inbox".Id;
        }
        field(2; Processed; Boolean)
        {
        }
    }

    keys
    {
        key(Key1; "Email Inbox ID")
        {
            Clustered = true;
        }
    }
}