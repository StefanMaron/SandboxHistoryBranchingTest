namespace Microsoft.EServices.EDocumentConnector.Microsoft365;

using Microsoft.eServices.EDocument;

pageextension 6386 InboundEDocumentListExt extends "Inbound E-Documents"
{
    ObsoleteReason = 'This page is to be temporarily removed from the app. Later it will be added.';
    ObsoleteTag = '26.2';
    ObsoleteState = Pending;

    actions
    {
        addlast(Processing)
        {
            action(ViewMailMessage)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'View e-mail message';
                ToolTip = 'View the source e-mail message.';
                Image = Email;
                Visible = EmailActionsVisible;

                ObsoleteReason = 'This action is to be temporarily removed from the app. Later it will be added.';
                ObsoleteTag = '26.2';
                ObsoleteState = Pending;

                trigger OnAction()
                var
                    OutlookIntegrationImpl: Codeunit "Outlook Integration Impl.";
                begin
                    if (Rec."Outlook Mail Message Id" <> '') then
                        HyperLink(StrSubstNo(OutlookIntegrationImpl.WebLinkText(), Rec."Outlook Mail Message Id"))
                end;
            }
        }
        addafter(Promoted_ViewFile)
        {
            actionref(Promoted_ViewMailMessage; ViewMailMessage)
            {
                ObsoleteReason = 'This action is to be temporarily removed from the app. Later it will be added.';
                ObsoleteTag = '26.2';
                ObsoleteState = Pending;
            }
        }
    }

    trigger OnOpenPage()
    var
        OutlookIntegrationImpl: Codeunit "Outlook Integration Impl.";
    begin
        OutlookIntegrationImpl.SetConditionalVisibilityFlag(Rec, EmailActionsVisible);
    end;

    var
        EmailActionsVisible: Boolean;
}