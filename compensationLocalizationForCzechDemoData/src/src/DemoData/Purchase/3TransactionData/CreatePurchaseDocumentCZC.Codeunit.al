#pragma warning disable AA0247
codeunit 31484 "Create Purchase Document CZC"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    trigger OnRun()
    begin
        CreatePurchaseCreditMemosToPost();
    end;

    local procedure CreatePurchaseCreditMemosToPost()
    var
        PurchaseHeader: Record "Purchase Header";
        ContosoCompensationsCZC: Codeunit "Contoso Compensations CZC";
        ContosoUtilities: Codeunit "Contoso Utilities";
        ContosoPurchase: Codeunit "Contoso Purchase";
        CreateVendor: Codeunit "Create Vendor";
        CreatePaymentTerms: Codeunit "Create Payment Terms";
        CreateItem: Codeunit "Create Item";
        CreatePaymentMethod: Codeunit "Create Payment Method";
    begin
        PurchaseHeader := ContosoCompensationsCZC.InsertPurchaseHeader(Enum::"Purchase Document Type"::"Credit Memo", CreateVendor.EUGraphicDesign(), '', ContosoUtilities.AdjustDate(19020101D), 20230101D, ContosoUtilities.AdjustDate(19020101D), CreatePaymentTerms.PaymentTermsCOD(), '', '', '', 20230101D, CreatePaymentMethod.Cash());
        ContosoPurchase.InsertPurchaseLineWithItem(PurchaseHeader, CreateItem.AthensDesk(), 4, '', 506.6);
    end;

    procedure PostPurchaseCreditMemos()
    var
        PurchaseHeader: Record "Purchase Header";
        CreatePurchaseDocument: Codeunit "Create Purchase Document";
    begin
        PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::"Credit Memo");
        PurchaseHeader.SetFilter("Your Reference", '<>%1', CreatePurchaseDocument.OpenYourReference());
        if PurchaseHeader.FindSet() then
            repeat
                Codeunit.Run(Codeunit::"Purch.-Post", PurchaseHeader);
            until PurchaseHeader.Next() = 0;
    end;
}
