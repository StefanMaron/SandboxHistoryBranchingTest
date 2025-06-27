// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

#pragma warning disable AS0007
namespace Microsoft.Agent.SalesOrderAgent;

using System.AI;

codeunit 4597 "SOA Broader Item Search Func" implements "AOAI Function"
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        BroaderItemSearch: Codeunit "SOA Broader Item Search";
        SearchQuery: Text;
        FunctionNameLbl: Label 'split_item_keywords', Locked = true;

    [NonDebuggable]
    procedure GetPrompt(): JsonObject
    var
        Prompt: Codeunit "SOA Prompts";
        PromptJson: JsonObject;
    begin
        PromptJson.ReadFrom((Prompt.GetBroaderItemSearchPrompt().Unwrap()));
        exit(PromptJson);
    end;

    [NonDebuggable]
    procedure Execute(Arguments: JsonObject): Variant
    var
        ItemsResults: JsonToken;
        ItemResultsArray: JsonArray;
        ItemFilter: Text;
    begin
        if Arguments.Get('results', ItemsResults) then begin
            ItemResultsArray := ItemsResults.AsArray();
            if BroaderItemSearch.SearchBroader(ItemResultsArray, SearchQuery, 10, 25, false, true, ItemFilter) then
                exit(ItemFilter);
        end;
    end;

    procedure SetSearchQuery(NewSearchQuery: Text)
    begin
        SearchQuery := NewSearchQuery;
    end;

    procedure GetName(): Text
    begin
        exit(FunctionNameLbl);
    end;
}