// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

#pragma warning disable AS0007
namespace Microsoft.Agent.SalesOrderAgent;

using System.Azure.KeyVault;
using System.Telemetry;

codeunit 4598 "SOA Prompts"
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    internal procedure GetAzureKeyVaultSecret(var SecretValue: SecretText; SecretName: Text)
    var
        AzureKeyVault: Codeunit "Azure Key Vault";
        FeatureTelemetry: Codeunit "Feature Telemetry";
    begin
        if not AzureKeyVault.GetAzureKeyVaultSecret(SecretName, SecretValue) then begin
            FeatureTelemetry.LogError('0000MJE', GetFeatureName(), 'Get prompt from Key Vault', TelemetryConstructingPromptFailedErr);
            Error(ConstructingPromptFailedErr);
        end;
    end;

    internal procedure GetBroaderItemSearchPrompt(): SecretText
    var
        BroaderItemSearchPrompt: SecretText;
    begin
        GetAzureKeyVaultSecret(BroaderItemSearchPrompt, 'BCSOABroaderItemSearchPromptV26');
        exit(BroaderItemSearchPrompt);
    end;

    internal procedure GetBroaderItemSearchSystemPrompt(): SecretText
    var
        BroaderItemSearchSystemPrompt: SecretText;
    begin
        GetAzureKeyVaultSecret(BroaderItemSearchSystemPrompt, 'BCSOABroaderItemSearchTaskPromptV26');
        exit(BroaderItemSearchSystemPrompt);
    end;

    local procedure GetFeatureName(): Text
    begin
        exit('Sales Order Agent');
    end;

    var
        ConstructingPromptFailedErr: label 'There was an error with sending the call to Copilot. Log a Business Central support request about this.', Comment = 'Copilot is a Microsoft service name and must not be translated';
        TelemetryConstructingPromptFailedErr: label 'There was an error with constructing the chat completion prompt from the Key Vault.', Locked = true;
}