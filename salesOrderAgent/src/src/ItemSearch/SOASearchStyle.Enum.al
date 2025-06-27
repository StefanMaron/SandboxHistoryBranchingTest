// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

#pragma warning disable AS0007
namespace Microsoft.Agent.SalesOrderAgent;

enum 4591 "SOA Search Style"
{
    Access = Internal;
    Extensible = false;

    value(0; "Permissive")
    {
        Caption = 'Permissive';
    }
    value(1; "Balanced")
    {
        Caption = 'Balanced';
    }
    value(2; "Precise")
    {
        Caption = 'Precise';
    }
}