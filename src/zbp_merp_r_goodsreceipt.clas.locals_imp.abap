"! Local behavior handler for Goods Receipt root entity.
CLASS lhc_zmerp_r_goodsreceipt DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      " Validation state areas for UI field highlighting
      c_val_company        TYPE string VALUE 'VALIDATE_COMPANY',
      c_val_partner        TYPE string VALUE 'VALIDATE_PARTNER',
      c_val_warehouse      TYPE string VALUE 'VALIDATE_WAREHOUSE',
      c_val_currency       TYPE string VALUE 'VALIDATE_CURRENCY',
      c_val_po_ref         TYPE string VALUE 'VALIDATE_PO_REF',
      c_val_doc_date       TYPE string VALUE 'VALIDATE_DOC_DATE',
      c_val_post_date      TYPE string VALUE 'VALIDATE_POST_DATE'.

    TYPES: BEGIN OF ty_po_status,
             DocumentUUID TYPE sysuuid_x16,
             Status       TYPE zmerp_po_status,
           END OF ty_po_status,
           tt_po_status TYPE STANDARD TABLE OF ty_po_status WITH EMPTY KEY.

    " --- Access and state ---
    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR GoodsReceipt
        RESULT  result.

    "! Evaluates dynamic instance features for actions based on status.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING
        keys   REQUEST requested_features FOR GoodsReceipt
      RESULT   result.

    "! Pre-checks deletion conditions and status restrictions.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING
        keys FOR DELETE GoodsReceipt.

    " --- Actions ---
    "! Posts the Goods Receipt.
    METHODS postDocument FOR MODIFY
      IMPORTING
        keys   FOR ACTION GoodsReceipt~postDocument
      RESULT   result.

    "! Unposts the Goods Receipt (back to 'New'): stock must not become negative,
    "! purchase order status follows the receipt progress.
    METHODS unpostDocument FOR MODIFY
      IMPORTING
        keys   FOR ACTION GoodsReceipt~unpostDocument
      RESULT   result.

    "! Cancels the Goods Receipt.
    METHODS cancelDocument FOR MODIFY
      IMPORTING
        keys   FOR ACTION GoodsReceipt~cancelDocument
      RESULT   result.

    " --- Determinations on modify ---
    "! Sets default header values on document creation.
    METHODS setHeaderDefaults FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR GoodsReceipt~setHeaderDefaults.

    "! Derives dependent header fields when the company code changes.
    METHODS deriveHeaderOnCompanyCode FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR GoodsReceipt~deriveHeaderOnCompanyCode.

    "! Derives dependent header fields when the document date changes.
    METHODS deriveDatesOnDocumentDate FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR GoodsReceipt~deriveDatesOnDocumentDate.

    "! Keeps the currency of all items in sync with the header currency.
    METHODS syncItemCurrency FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR GoodsReceipt~syncItemCurrency.

    "! Derives header fields and context when the referenced Purchase Order changes.
    METHODS deriveDocFromPurchaseOrder FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR GoodsReceipt~deriveDocFromPurchaseOrder.

    "! Clears the purchase order reference (and by that all items) when company code, business partner
    "! or warehouse no longer match the referenced purchase order.
    METHODS clearPoOnHeaderChange FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR GoodsReceipt~clearPoOnHeaderChange.

    " --- Determinations on save ---
    "! Assigns the document number from the number range on first save.
    METHODS assignDocumentNumber FOR DETERMINE ON SAVE
      IMPORTING
        keys FOR GoodsReceipt~assignDocumentNumber.

    " --- Validations ---
    "! Validates mandatory header fields before saving.
    METHODS validateHeaderFields FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR GoodsReceipt~validateHeaderFields.

    "! Validates document date and posting date consistency.
    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR GoodsReceipt~validateDates.

    "! A document is not saved without a number: runs after assignDocumentNumber
    "! (save determinations come before save validations) and fails the instance if no number was assigned.
    METHODS validateDocumentNumber FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR GoodsReceipt~validateDocumentNumber.

    " --- Clearing of validation messages ---
    "! Clears validation messages for organizational header fields that have been filled in.
    METHODS clearMessagesForHeaderFields FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR GoodsReceipt~clearMessagesForHeaderFields.

    "! Clears date validation messages for fields that have been fixed.
    METHODS clearMessagesForDates FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR GoodsReceipt~clearMessagesForDates.

    " --- Helpers ---
    "! Receipt status of the referenced purchase orders after the given goods receipt items are
    "! posted (iv_sign = 1) or unposted (iv_sign = -1). Only purchase orders touched by the items
    "! and whose status really changes are returned.
    "! @parameter it_items    | Goods receipt items (PoItemReferenceUUID, Quantity)
    "! @parameter it_progress | Receipt progress of the purchase orders (posted receipts only)
    "! @parameter iv_sign     | 1 = items are added to the received quantity, -1 = removed
    "! @parameter rt_status   | Purchase orders with their new status
    METHODS calc_po_receipt_status
      IMPORTING it_items         TYPE zcl_merp_doc_item_logic=>tt_items
                it_progress      TYPE zif_merp_doc_po_sel=>tt_progress
                iv_sign          TYPE i
      RETURNING VALUE(rt_status) TYPE tt_po_status.

    "! Updates the receipt status of the referenced purchase orders (via the PO action setReceiptStatus)
    "! after the given goods receipt items are posted (iv_sign = 1) or unposted (iv_sign = -1).
    "! @parameter it_items    | Goods receipt items (PoItemReferenceUUID, Quantity)
    "! @parameter it_progress | Receipt progress of the purchase orders (posted receipts only)
    "! @parameter iv_sign     | 1 = items are added to the received quantity, -1 = removed
    "! @parameter rv_success  | abap_false if a purchase order could not be updated
    METHODS update_po_receipt_status
      IMPORTING it_items          TYPE zcl_merp_doc_item_logic=>tt_items
                it_progress       TYPE zif_merp_doc_po_sel=>tt_progress
                iv_sign           TYPE i
      RETURNING VALUE(rv_success) TYPE abap_bool.

ENDCLASS.

CLASS lhc_zmerp_r_goodsreceipt IMPLEMENTATION.

  " --- Access and state ---
  METHOD get_global_authorizations.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_features.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    result = VALUE #(
      FOR header IN lt_headers
      LET lv_active = xsdbool( header-%is_draft = if_abap_behv=>mk-off )
          lv_edit   = xsdbool( lv_active = abap_true
                             AND zcl_merp_doc_gr_lifecycle=>can_edit( header-Status ) = abap_true )
          lv_post   = xsdbool( lv_active = abap_true
                             AND zcl_merp_doc_gr_lifecycle=>can_post( header-Status ) = abap_true )
          lv_unpost = xsdbool( lv_active = abap_true
                             AND zcl_merp_doc_gr_lifecycle=>can_unpost( header-Status ) = abap_true )
          lv_cancel = xsdbool( lv_active = abap_true
                             AND zcl_merp_doc_gr_lifecycle=>can_cancel( header-Status ) = abap_true )
          lv_delete = zcl_merp_doc_gr_lifecycle=>can_delete( header-Status ) IN
      ( %tky                   = header-%tky
        %delete                = COND #( WHEN lv_delete = abap_true
                                         THEN if_abap_behv=>fc-o-enabled
                                         ELSE if_abap_behv=>fc-o-disabled )
        %action-Edit           = COND #( WHEN lv_edit = abap_true
                                         THEN if_abap_behv=>fc-o-enabled
                                         ELSE if_abap_behv=>fc-o-disabled )
        %action-postDocument   = COND #( WHEN lv_post = abap_true
                                         THEN if_abap_behv=>fc-o-enabled
                                         ELSE if_abap_behv=>fc-o-disabled )
        %action-unpostDocument = COND #( WHEN lv_unpost = abap_true
                                         THEN if_abap_behv=>fc-o-enabled
                                         ELSE if_abap_behv=>fc-o-disabled )
        %action-cancelDocument = COND #( WHEN lv_cancel = abap_true
                                         THEN if_abap_behv=>fc-o-enabled
                                         ELSE if_abap_behv=>fc-o-disabled )
        " The document number carries the company prefix, so the company is fixed once it is assigned
        %field-CompanyCode     = COND #( WHEN header-DocumentNumber IS INITIAL
                                         THEN if_abap_behv=>fc-f-mandatory
                                         ELSE if_abap_behv=>fc-f-read_only ) )
    ).
  ENDMETHOD.

  METHOD precheck_delete.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_failed_added TYPE abap_bool.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " Usages of all documents in one selection (the selector skips initial keys)
    DATA(lt_usages) = NEW zcl_merp_doc_gr_sel( )->zif_merp_doc_gr_sel~read_usages(
      VALUE #( FOR hdr IN lt_headers ( DocumentUUID = hdr-DocumentUUID ) ) ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_hdr).
      lv_failed_added = abap_false.

      IF zcl_merp_doc_gr_lifecycle=>can_delete( lr_hdr->Status ) = abap_false.
        APPEND VALUE #(
          %tky        = lr_hdr->%tky
          %fail-cause = if_abap_behv=>cause-conflict
        ) TO failed-goodsreceipt.

        APPEND VALUE #(
          %tky            = lr_hdr->%tky
          %element-Status = if_abap_behv=>mk-on
          %msg            = NEW zcx_merp_pur(
                               textid   = zcx_merp_pur=>delete_not_allowed
                               attr1    = CONV #( lr_hdr->DocumentNumber )
                               severity = if_abap_behv_message=>severity-error )
        ) TO reported-goodsreceipt.
        CONTINUE.
      ENDIF.

      " One message per using entity (sorted table: WHERE uses the table key)
      LOOP AT lt_usages REFERENCE INTO DATA(lr_usage) WHERE DocumentUUID = lr_hdr->DocumentUUID.

        IF lv_failed_added = abap_false.
          APPEND VALUE #(
            %tky        = lr_hdr->%tky
            %fail-cause = if_abap_behv=>cause-dependency
          ) TO failed-goodsreceipt.
          lv_failed_added = abap_true.
        ENDIF.

        APPEND VALUE #(
          %tky            = lr_hdr->%tky
          %element-Status = if_abap_behv=>mk-on
          %msg            = NEW zcx_merp_pur(
                               textid   = zcx_merp_pur=>goods_receipt_in_use
                               attr1    = CONV #( lr_hdr->DocumentNumber )
                               attr2    = CONV #( lr_usage->UsedInEntity )
                               severity = if_abap_behv_message=>severity-error )
        ) TO reported-goodsreceipt.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  " --- Actions ---
  METHOD postDocument.
    DATA lt_update       TYPE TABLE FOR UPDATE zmerp_r_goodsreceipt.
    DATA lo_message      TYPE REF TO zcx_merp_pur.
    DATA lo_item_message TYPE REF TO zcx_merp_pur.
    DATA lv_items_valid  TYPE abap_bool.
    DATA ls_po           TYPE zif_merp_doc_po_sel=>ty_header.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
        FIELDS ( Status DocumentNumber CompanyCode WarehouseCode CurrencyCode PoReferenceUUID PostingDate )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers)
      ENTITY GoodsReceipt BY \_Items
        FIELDS ( HeaderUUID ItemNo ItemCode Quantity UnitOfMeasure NetAmount VatAmount GrossAmount PoItemReferenceUUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_items).

    " Lock first, then read (as in SAP): every goods movement locks its order and its stock
    " (a receipt changes the stock value that the moving average of a parallel issue is computed from);
    " a receipt adds goods, so no availability check is needed
    DATA(lt_po_keys) = VALUE zif_merp_doc_po_sel=>tt_document_keys(
      FOR header IN lt_headers WHERE ( PoReferenceUUID IS NOT INITIAL ) ( DocumentUUID = header-PoReferenceUUID ) ).
    SORT lt_po_keys BY DocumentUUID.
    DELETE ADJACENT DUPLICATES FROM lt_po_keys COMPARING DocumentUUID.

    SET LOCKS OF zmerp_r_purchaseorder
      ENTITY PurchaseOrder
      FROM VALUE #( FOR po_key IN lt_po_keys ( DocumentUUID = po_key-DocumentUUID ) )
      FAILED DATA(ls_po_lock_failed).

    DATA(lt_lock_failures) = zcl_merp_stock_control=>lock_stock(
      VALUE #( FOR item IN lt_items
               LET header = VALUE #( lt_headers[ DocumentUUID = item-HeaderUUID ] OPTIONAL ) IN
               ( CompanyCode   = header-CompanyCode
                 WarehouseCode = header-WarehouseCode
                 ItemCode      = item-ItemCode
                 UnitOfMeasure = item-UnitOfMeasure ) ) ).

    " Company currencies and purchase order context of all documents in one selection each
    DATA(lt_companies) = NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_companies(
      VALUE #( FOR header IN lt_headers ( CompanyCode = header-CompanyCode ) ) ).

    DATA(lo_po_selector) = NEW zcl_merp_doc_po_sel( ).
    DATA(lt_po_headers)  = lo_po_selector->zif_merp_doc_po_sel~read_headers( lt_po_keys ).
    DATA(lt_progress)    = lo_po_selector->zif_merp_doc_po_sel~read_progress( lt_po_keys ).

    " Items and open values in the shape of the shared follow-up logic (order item reference mapped, C15).
    " Open quantities and amounts are reduced by each document accepted below, so further documents
    " of the same request on the same purchase order are checked against the remaining values
    " (lt_progress stays unchanged: the purchase order status is derived from it including all documents)
    DATA(lt_doc_items) = CORRESPONDING zcl_merp_doc_item_logic=>tt_items(
      lt_items MAPPING IsDraft                = %is_draft
                       OrderItemReferenceUUID = PoItemReferenceUUID ).

    DATA(lt_open) = CORRESPONDING zcl_merp_doc_order_ref_logic=>tt_order_items(
      lt_progress MAPPING OrderUUID     = PoHeaderUUID
                          OrderItemUUID = PoItemUUID
                          DoneQuantity  = ReceivedQuantity ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      CLEAR lo_message.
      lv_items_valid = abap_true.

      " Purchase order of the document (initial if it does not exist)
      ls_po = VALUE #( lt_po_headers[ DocumentUUID = lr_header->PoReferenceUUID ] OPTIONAL ).

      " 1. Header checks
      IF zcl_merp_doc_gr_lifecycle=>can_post( lr_header->Status ) = abap_false.
        lo_message = NEW #( textid   = zcx_merp_pur=>post_not_allowed
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( lr_header->DocumentNumber ) ).
      ELSEIF NOT line_exists( lt_items[ HeaderUUID = lr_header->DocumentUUID ] ).
        lo_message = NEW #( textid   = zcx_merp_pur=>document_empty_items_invalid
                            severity = if_abap_behv_message=>severity-error ).
      ELSEIF line_exists( ls_po_lock_failed-purchaseorder[ DocumentUUID = lr_header->PoReferenceUUID ] ).
        " The purchase order is edited or posted by another user
        lo_message = NEW #( textid   = zcx_merp_pur=>document_locked
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( ls_po-DocumentNumber ) ).
      ELSEIF NOT line_exists( lt_companies[ CompanyCode  = lr_header->CompanyCode
                                            CurrencyCode = lr_header->CurrencyCode ] ).
        " Stock is valuated in the company currency (no currency conversion yet)
        lo_message = NEW #( textid   = zcx_merp_pur=>currency_not_company
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( lr_header->CurrencyCode )
                            attr2    = CONV #( VALUE #( lt_companies[ CompanyCode = lr_header->CompanyCode ]-CurrencyCode
                                                        OPTIONAL ) ) ).
      ELSEIF zcl_merp_doc_po_lifecycle=>can_receive_goods( ls_po-Status ) = abap_false.
        " The purchase order may have been completed or cancelled in the meantime
        lo_message = NEW #( textid   = zcx_merp_pur=>po_receipt_not_allowed
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( ls_po-DocumentNumber ) ).
      ELSEIF lr_header->PostingDate < ls_po-DocumentDate.
        " Goods cannot be received before they were ordered
        lo_message = NEW #( textid   = zcx_merp_pur=>posting_date_before_po_date
                            severity = if_abap_behv_message=>severity-error
                            attr1    = |{ ls_po-DocumentDate DATE = ISO }| ).
      ENDIF.

      " 2. The stock of an item is being posted by another user: the document waits for the next attempt
      IF lo_message IS NOT BOUND.
        LOOP AT lt_items REFERENCE INTO DATA(lr_locked) WHERE HeaderUUID = lr_header->DocumentUUID.
          ASSIGN lt_lock_failures[ company_code   = lr_header->CompanyCode
                                   warehouse_code = lr_header->WarehouseCode
                                   item_code      = lr_locked->ItemCode ] TO FIELD-SYMBOL(<ls_lock>).
          IF sy-subrc = 0.
            lo_message = NEW #( textid   = zcx_merp_pur=>stock_locked
                                severity = if_abap_behv_message=>severity-error
                                attr1    = CONV #( <ls_lock>-item_code )
                                attr2    = CONV #( <ls_lock>-warehouse_code )
                                attr3    = <ls_lock>-locked_by ).
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.

      " 3. Items of the purchase order are checked against its current open quantities and amounts
      IF lo_message IS NOT BOUND.
        DATA(lt_open_checks) = zcl_merp_doc_order_ref_logic=>check_open_values(
          it_items       = VALUE #( FOR doc_item IN lt_doc_items WHERE ( HeaderUUID = lr_header->DocumentUUID )
                                    ( doc_item ) )
          it_order_items = lt_open ).

        LOOP AT lt_items REFERENCE INTO DATA(lr_item) WHERE HeaderUUID = lr_header->DocumentUUID.
          ASSIGN lt_open_checks[ ItemUUID = lr_item->ItemUUID ] TO FIELD-SYMBOL(<ls_check>).
          IF sy-subrc <> 0.
            CONTINUE.
          ENDIF.

          " Message of the first failing rule: order item missing, quantity above open, open amounts changed
          lo_item_message = SWITCH #( <ls_check>-Result
            WHEN zcl_merp_doc_order_ref_logic=>c_open_check-item_not_found
              THEN NEW #( textid   = zcx_merp_pur=>po_item_not_found
                          severity = if_abap_behv_message=>severity-error
                          attr1    = CONV #( lr_item->ItemNo ) )
            WHEN zcl_merp_doc_order_ref_logic=>c_open_check-quantity_exceeded
              THEN NEW #( textid   = zcx_merp_pur=>po_open_quantity_exceeded
                          severity = if_abap_behv_message=>severity-error
                          attr1    = CONV #( lr_item->ItemNo )
                          attr2    = CONV #( <ls_check>-OpenQuantity ) )
            ELSE NEW #( textid   = zcx_merp_pur=>po_open_amounts_changed
                        severity = if_abap_behv_message=>severity-error
                        attr1    = CONV #( lr_item->ItemNo ) ) ).

          lv_items_valid = abap_false.
          APPEND VALUE #( %tky              = lr_item->%tky
                          %path             = VALUE #( GoodsReceipt-%is_draft    = lr_item->%is_draft
                                                       GoodsReceipt-DocumentUUID = lr_item->HeaderUUID )
                          %msg              = lo_item_message
                          %element-Quantity = if_abap_behv=>mk-on ) TO reported-goodsreceiptitem.
        ENDLOOP.
      ENDIF.

      IF lo_message IS BOUND OR lv_items_valid = abap_false.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-goodsreceipt.
        IF lo_message IS BOUND.
          APPEND VALUE #( %tky                 = lr_header->%tky
                          %msg                 = lo_message
                          %action-postDocument = if_abap_behv=>mk-on ) TO reported-goodsreceipt.
        ENDIF.
      ELSE.
        APPEND VALUE #( %tky   = lr_header->%tky
                        Status = zcl_merp_doc_gr_lifecycle=>c_status_posted ) TO lt_update.

        " This document now takes its part of the open values
        zcl_merp_doc_order_ref_logic=>consume_open_values(
          EXPORTING it_items       = VALUE #( FOR doc_item IN lt_doc_items WHERE ( HeaderUUID = lr_header->DocumentUUID )
                                              ( doc_item ) )
          CHANGING  ct_order_items = lt_open ).
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      " 4. Purchase orders follow the receipt progress including the documents posted now
      IF update_po_receipt_status(
           it_items    = VALUE #( FOR upd IN lt_update
                                  FOR item IN lt_items WHERE ( HeaderUUID          = upd-DocumentUUID
                                                               AND PoItemReferenceUUID IS NOT INITIAL )
                                  ( OrderItemReferenceUUID = item-PoItemReferenceUUID
                                    Quantity               = item-Quantity ) )
           it_progress = lt_progress
           iv_sign     = 1 ) = abap_false.

        " Without the purchase order update the goods receipts are not posted
        LOOP AT lt_update REFERENCE INTO DATA(lr_update).
          APPEND VALUE #( %tky        = lr_update->%tky
                          %fail-cause = if_abap_behv=>cause-conflict ) TO failed-goodsreceipt.
          APPEND VALUE #( %tky                 = lr_update->%tky
                          %msg                 = NEW zcx_merp_pur(
                                                   textid   = zcx_merp_pur=>post_not_allowed
                                                   severity = if_abap_behv_message=>severity-error
                                                   attr1    = CONV #( VALUE #( lt_headers[ %tky = lr_update->%tky ]-DocumentNumber
                                                                               OPTIONAL ) ) )
                          %action-postDocument = if_abap_behv=>mk-on ) TO reported-goodsreceipt.
        ENDLOOP.
        RETURN.
      ENDIF.

      " 5. Goods receipts are posted (stock movements are written by the saver)
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceipt
        UPDATE FIELDS ( Status )
        WITH lt_update
        FAILED DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      IF lt_mod_failed IS NOT INITIAL.
        failed-goodsreceipt   = CORRESPONDING #( BASE ( failed-goodsreceipt ) lt_mod_failed-goodsreceipt ).
        reported-goodsreceipt = CORRESPONDING #( BASE ( reported-goodsreceipt ) lt_mod_reported-goodsreceipt ).
        RETURN.
      ENDIF.
    ENDIF.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR header IN lt_result ( %tky = header-%tky %param = header ) ).
  ENDMETHOD.

  METHOD unpostDocument.
    DATA lt_update      TYPE TABLE FOR UPDATE zmerp_r_goodsreceipt.
    DATA lo_message     TYPE REF TO zcx_merp_pur.
    DATA lv_items_valid TYPE abap_bool.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
        FIELDS ( Status DocumentNumber CompanyCode WarehouseCode PoReferenceUUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers)
      ENTITY GoodsReceipt BY \_Items
        FIELDS ( HeaderUUID ItemNo ItemCode Quantity UnitOfMeasure PoItemReferenceUUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_items).

    " Lock first, then read (as in SAP): unposting takes the received goods out of the stock again,
    " so the purchase orders and the stock of the products stay locked until the end of the transaction
    DATA(lt_po_keys) = VALUE zif_merp_doc_po_sel=>tt_document_keys(
      FOR header IN lt_headers WHERE ( PoReferenceUUID IS NOT INITIAL ) ( DocumentUUID = header-PoReferenceUUID ) ).
    SORT lt_po_keys BY DocumentUUID.
    DELETE ADJACENT DUPLICATES FROM lt_po_keys COMPARING DocumentUUID.

    SET LOCKS OF zmerp_r_purchaseorder
      ENTITY PurchaseOrder
      FROM VALUE #( FOR po_key IN lt_po_keys ( DocumentUUID = po_key-DocumentUUID ) )
      FAILED DATA(ls_po_lock_failed).

    DATA(lt_stock_keys) = VALUE zif_merp_stock_sel=>tt_stock_keys(
      FOR item IN lt_items
      LET header = VALUE #( lt_headers[ DocumentUUID = item-HeaderUUID ] OPTIONAL ) IN
      ( CompanyCode   = header-CompanyCode
        WarehouseCode = header-WarehouseCode
        ItemCode      = item-ItemCode
        UnitOfMeasure = item-UnitOfMeasure ) ).

    DATA(lt_lock_failures) = zcl_merp_stock_control=>lock_stock( lt_stock_keys ).
    DATA(lo_stock)         = NEW zcl_merp_stock_control( lt_stock_keys ).

    " Receipt progress and numbers of the referenced purchase orders (the documents to be unposted are included)
    DATA(lo_po_selector) = NEW zcl_merp_doc_po_sel( ).
    DATA(lt_po_headers)  = lo_po_selector->zif_merp_doc_po_sel~read_headers( lt_po_keys ).
    DATA(lt_progress)    = lo_po_selector->zif_merp_doc_po_sel~read_progress( lt_po_keys ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      CLEAR lo_message.
      lv_items_valid = abap_true.

      " 1. Only posted documents can be unposted; the purchase order must not be locked by another user
      IF zcl_merp_doc_gr_lifecycle=>can_unpost( lr_header->Status ) = abap_false.
        lo_message = NEW #( textid   = zcx_merp_pur=>unpost_not_allowed
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( lr_header->DocumentNumber ) ).
      ELSEIF line_exists( ls_po_lock_failed-purchaseorder[ DocumentUUID = lr_header->PoReferenceUUID ] ).
        lo_message = NEW #( textid   = zcx_merp_pur=>document_locked
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( VALUE #( lt_po_headers[ DocumentUUID = lr_header->PoReferenceUUID ]-DocumentNumber
                                                        OPTIONAL ) ) ).
      ENDIF.

      " 2. The stock of an item is being posted by another user: the document waits for the next attempt
      IF lo_message IS NOT BOUND.
        LOOP AT lt_items REFERENCE INTO DATA(lr_locked) WHERE HeaderUUID = lr_header->DocumentUUID.
          ASSIGN lt_lock_failures[ company_code   = lr_header->CompanyCode
                                   warehouse_code = lr_header->WarehouseCode
                                   item_code      = lr_locked->ItemCode ] TO FIELD-SYMBOL(<ls_lock>).
          IF sy-subrc = 0.
            lo_message = NEW #( textid   = zcx_merp_pur=>stock_locked
                                severity = if_abap_behv_message=>severity-error
                                attr1    = CONV #( <ls_lock>-item_code )
                                attr2    = CONV #( <ls_lock>-warehouse_code )
                                attr3    = <ls_lock>-locked_by ).
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.

      " 3. Removing the movements of the document must not make the stock negative (products only);
      "    a covered document takes its quantities from the stock for the next documents of the request
      IF lo_message IS NOT BOUND.
        DATA(lt_shortages) = lo_stock->check_availability(
          iv_company_code   = lr_header->CompanyCode
          iv_warehouse_code = lr_header->WarehouseCode
          it_lines          = VALUE #( FOR item IN lt_items WHERE ( HeaderUUID = lr_header->DocumentUUID )
                                       ( item_uuid       = item-ItemUUID
                                         item_code       = item-ItemCode
                                         quantity        = item-Quantity
                                         unit_of_measure = item-UnitOfMeasure ) ) ).

        LOOP AT lt_items REFERENCE INTO DATA(lr_item) WHERE HeaderUUID = lr_header->DocumentUUID.
          IF line_exists( lt_shortages[ table_line = lr_item->ItemUUID ] ).
            lv_items_valid = abap_false.
            APPEND VALUE #( %tky              = lr_item->%tky
                            %path             = VALUE #( GoodsReceipt-%is_draft    = lr_item->%is_draft
                                                         GoodsReceipt-DocumentUUID = lr_item->HeaderUUID )
                            %msg              = NEW zcx_merp_pur(
                                                  textid   = zcx_merp_pur=>stock_would_be_negative
                                                  severity = if_abap_behv_message=>severity-error
                                                  attr1    = CONV #( lr_item->ItemNo )
                                                  attr2    = CONV #( lr_item->ItemCode )
                                                  attr3    = CONV #( lr_header->WarehouseCode ) )
                            %element-Quantity = if_abap_behv=>mk-on ) TO reported-goodsreceiptitem.
          ENDIF.
        ENDLOOP.
      ENDIF.

      IF lo_message IS BOUND OR lv_items_valid = abap_false.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-goodsreceipt.
        IF lo_message IS BOUND.
          APPEND VALUE #( %tky                   = lr_header->%tky
                          %msg                   = lo_message
                          %action-unpostDocument = if_abap_behv=>mk-on ) TO reported-goodsreceipt.
        ENDIF.
      ELSE.
        APPEND VALUE #( %tky   = lr_header->%tky
                        Status = zcl_merp_doc_gr_lifecycle=>c_status_new ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      " 4. Purchase orders follow the receipt progress without the documents unposted now
      "    (all items, services included: they close purchase order items as well)
      IF update_po_receipt_status(
           it_items    = VALUE #( FOR upd IN lt_update
                                  FOR item IN lt_items WHERE ( HeaderUUID          = upd-DocumentUUID
                                                               AND PoItemReferenceUUID IS NOT INITIAL )
                                  ( OrderItemReferenceUUID = item-PoItemReferenceUUID
                                    Quantity               = item-Quantity ) )
           it_progress = lt_progress
           iv_sign     = -1 ) = abap_false.

        " Without the purchase order update the goods receipts are not unposted
        LOOP AT lt_update REFERENCE INTO DATA(lr_update).
          APPEND VALUE #( %tky        = lr_update->%tky
                          %fail-cause = if_abap_behv=>cause-conflict ) TO failed-goodsreceipt.
          APPEND VALUE #( %tky                   = lr_update->%tky
                          %msg                   = NEW zcx_merp_pur(
                                                     textid   = zcx_merp_pur=>unpost_not_allowed
                                                     severity = if_abap_behv_message=>severity-error
                                                     attr1    = CONV #( VALUE #( lt_headers[ %tky = lr_update->%tky ]-DocumentNumber
                                                                                 OPTIONAL ) ) )
                          %action-unpostDocument = if_abap_behv=>mk-on ) TO reported-goodsreceipt.
        ENDLOOP.
        RETURN.
      ENDIF.

      " 5. Goods receipts return to 'New' (stock movements are removed by the saver)
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceipt
        UPDATE FIELDS ( Status )
        WITH lt_update
        FAILED DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      IF lt_mod_failed IS NOT INITIAL.
        failed-goodsreceipt   = CORRESPONDING #( BASE ( failed-goodsreceipt ) lt_mod_failed-goodsreceipt ).
        reported-goodsreceipt = CORRESPONDING #( BASE ( reported-goodsreceipt ) lt_mod_reported-goodsreceipt ).
        RETURN.
      ENDIF.
    ENDIF.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR header IN lt_result ( %tky = header-%tky %param = header ) ).
  ENDMETHOD.

  METHOD cancelDocument.
    DATA lt_update  TYPE TABLE FOR UPDATE zmerp_r_goodsreceipt.
    DATA lo_message TYPE REF TO zcx_merp_pur.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      CLEAR lo_message.

      IF zcl_merp_doc_gr_lifecycle=>can_cancel( lr_header->Status ) = abap_false.
        lo_message = NEW #( textid   = zcx_merp_pur=>cancel_not_allowed
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( lr_header->DocumentNumber ) ).
      ENDIF.

      IF lo_message IS BOUND.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-goodsreceipt.
        APPEND VALUE #( %tky                   = lr_header->%tky
                        %msg                   = lo_message
                        %action-cancelDocument = if_abap_behv=>mk-on ) TO reported-goodsreceipt.
      ELSE.
        APPEND VALUE #( %tky   = lr_header->%tky
                        Status = zcl_merp_doc_gr_lifecycle=>c_status_cancelled ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceipt
        UPDATE FIELDS ( Status )
        WITH lt_update
        FAILED DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      IF lt_mod_failed IS NOT INITIAL.
        failed-goodsreceipt   = CORRESPONDING #( BASE ( failed-goodsreceipt ) lt_mod_failed-goodsreceipt ).
        reported-goodsreceipt = CORRESPONDING #( BASE ( reported-goodsreceipt ) lt_mod_reported-goodsreceipt ).
        RETURN.
      ENDIF.
    ENDIF.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR header IN lt_result ( %tky = header-%tky %param = header ) ).
  ENDMETHOD.

  " --- Determinations on modify ---
  METHOD setHeaderDefaults.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_goodsreceipt.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
      FIELDS ( DocumentDate PostingDate Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    DATA(ls_generic_defaults) = zcl_merp_doc_util=>get_generic_header_defaults( ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      DATA(ls_header) = lr_header->*.

      IF ls_header-DocumentDate IS INITIAL.
        ls_header-DocumentDate = ls_generic_defaults-document_date.
      ENDIF.

      IF ls_header-PostingDate IS INITIAL.
        ls_header-PostingDate = ls_header-DocumentDate.
      ENDIF.

      IF ls_header-Status IS INITIAL.
        ls_header-Status = zcl_merp_doc_gr_lifecycle=>c_status_new.
      ENDIF.

      IF ls_header <> lr_header->*.
        APPEND CORRESPONDING #( ls_header ) TO lt_header_update.
      ENDIF.
    ENDLOOP.

    IF lt_header_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceipt
        UPDATE FIELDS ( DocumentDate PostingDate Status )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  METHOD deriveHeaderOnCompanyCode.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_goodsreceipt.

    " The currency is not derived here: it always comes from the purchase order (deriveDocFromPurchaseOrder)
    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
      FIELDS ( CompanyCode WarehouseCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " Warehouse master data in one selection
    DATA(lt_warehouses) = NEW zcl_merp_md_warehouse_sel( )->zif_merp_md_warehouse_sel~read_warehouses(
      VALUE #( FOR header IN lt_headers ( WarehouseCode = header-WarehouseCode ) )
    ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      DATA(ls_header) = lr_header->*.

      IF ls_header-CompanyCode IS NOT INITIAL.
        " A warehouse of another company is cleared
        IF ls_header-WarehouseCode IS NOT INITIAL.
          ASSIGN lt_warehouses[ WarehouseCode = ls_header-WarehouseCode ] TO FIELD-SYMBOL(<ls_warehouse>).
          IF sy-subrc <> 0 OR <ls_warehouse>-CompanyCode <> ls_header-CompanyCode.
            CLEAR ls_header-WarehouseCode.
          ENDIF.
        ENDIF.
      ENDIF.

      " Only changed headers are updated
      IF ls_header <> lr_header->*.
        APPEND CORRESPONDING #( ls_header ) TO lt_header_update.
      ENDIF.
    ENDLOOP.

    IF lt_header_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceipt
        UPDATE FIELDS ( WarehouseCode )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  METHOD deriveDatesOnDocumentDate.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_goodsreceipt.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
      FIELDS ( DocumentDate PostingDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      DATA(ls_header) = lr_header->*.

      IF ls_header-DocumentDate IS NOT INITIAL.
        IF ls_header-PostingDate IS NOT INITIAL
           AND zcl_merp_doc_validator=>is_posting_date_valid( iv_doc_date  = ls_header-DocumentDate
                                                              iv_post_date = ls_header-PostingDate ) = abap_false.
          ls_header-PostingDate = ls_header-DocumentDate.
        ENDIF.
      ENDIF.

      IF ls_header <> lr_header->*.
        APPEND CORRESPONDING #( ls_header ) TO lt_header_update.
      ENDIF.
    ENDLOOP.

    IF lt_header_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceipt
        UPDATE FIELDS ( PostingDate )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  METHOD syncItemCurrency.
    DATA lt_items_to_update TYPE TABLE FOR UPDATE zmerp_r_goodsreceipt\\GoodsReceiptItem.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
        FIELDS ( CurrencyCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers)
      ENTITY GoodsReceipt BY \_Items
        FIELDS ( HeaderUUID CurrencyCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_items).

    IF lt_headers IS INITIAL OR lt_items IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      ASSIGN lt_headers[ DocumentUUID = lr_item->HeaderUUID
                         %is_draft    = lr_item->%is_draft ] TO FIELD-SYMBOL(<ls_header>).

      IF sy-subrc = 0 AND lr_item->CurrencyCode <> <ls_header>-CurrencyCode.
        APPEND VALUE #(
          %tky         = lr_item->%tky
          CurrencyCode = <ls_header>-CurrencyCode
        ) TO lt_items_to_update.
      ENDIF.
    ENDLOOP.

    IF lt_items_to_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceiptItem
        UPDATE FIELDS ( CurrencyCode )
        WITH lt_items_to_update.
    ENDIF.
  ENDMETHOD.

  METHOD deriveDocFromPurchaseOrder.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_goodsreceipt.
    DATA lt_item_delete   TYPE TABLE FOR DELETE zmerp_r_goodsreceipt\\GoodsReceiptItem.
    DATA lt_item_create   TYPE TABLE FOR CREATE zmerp_r_goodsreceipt\_Items.
    DATA ls_item_create   LIKE LINE OF lt_item_create.

    " Headers with the changed purchase order reference and their current items
    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
        FIELDS ( PoReferenceUUID DocumentNumber CompanyCode WarehouseCode BusinessPartnerCode CurrencyCode
                 SupplierReference TotalNetAmount TotalGrossAmount )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers)
      ENTITY GoodsReceipt BY \_Items
        FIELDS ( ItemUUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_items).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " The item list always starts from scratch when the purchase order changes
    lt_item_delete = VALUE #( FOR item IN lt_items ( %tky = item-%tky ) ).

    " Purchase order headers and receipt progress (open quantities and amounts) in one selection each
    DATA(lt_po_keys) = VALUE zif_merp_doc_po_sel=>tt_document_keys(
      FOR header IN lt_headers ( DocumentUUID = header-PoReferenceUUID ) ).

    DATA(lo_po_selector) = NEW zcl_merp_doc_po_sel( ).
    DATA(lt_po_headers)  = lo_po_selector->zif_merp_doc_po_sel~read_headers( lt_po_keys ).
    DATA(lt_progress)    = lo_po_selector->zif_merp_doc_po_sel~read_progress( lt_po_keys ).

    " 1. Open (not yet received) quantities of a receivable purchase order become the new items.
    "    Amounts are taken from the open amounts, so earlier rounding differences are closed to zero.
    "    A numbered document keeps its company: an order of another company gives no items
    "    (rejected by validateHeaderFields)
    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      ASSIGN lt_po_headers[ DocumentUUID = lr_header->PoReferenceUUID ] TO FIELD-SYMBOL(<ls_po>).
      IF sy-subrc <> 0
         OR zcl_merp_doc_po_lifecycle=>can_receive_goods( <ls_po>-Status ) = abap_false
         OR ( lr_header->DocumentNumber IS NOT INITIAL AND <ls_po>-CompanyCode <> lr_header->CompanyCode ).
        CONTINUE.
      ENDIF.

      ls_item_create = VALUE #( %tky = lr_header->%tky ).

      LOOP AT lt_progress REFERENCE INTO DATA(lr_open) USING KEY ByHeader
           WHERE PoHeaderUUID = <ls_po>-DocumentUUID
             AND OpenQuantity > 0.
        APPEND VALUE #(
          %cid                = |{ lr_header->DocumentUUID }{ lines( ls_item_create-%target ) + 1 }|
          %is_draft           = lr_header->%is_draft
          ItemNo              = lr_open->PoItemNo
          ItemCode            = lr_open->ItemCode
          Quantity            = lr_open->OpenQuantity
          UnitOfMeasure       = lr_open->UnitOfMeasure
          CurrencyCode        = lr_open->CurrencyCode
          Price               = lr_open->Price
          VatCode             = lr_open->VatCode
          NetAmount           = lr_open->OpenNetAmount
          VatAmount           = lr_open->OpenVatAmount
          GrossAmount         = lr_open->OpenGrossAmount
          PoItemReferenceUUID = lr_open->PoItemUUID
        ) TO ls_item_create-%target.
      ENDLOOP.

      IF ls_item_create-%target IS NOT INITIAL.
        APPEND ls_item_create TO lt_item_create.
      ENDIF.
    ENDLOOP.

    " 2. Header totals of the new items via the shared item logic (headers without new items get zero totals)
    DATA(lt_totals) = NEW zcl_merp_doc_item_logic( )->calc_header_totals(
      it_header_keys = VALUE #( FOR header IN lt_headers
                                ( HeaderUUID = header-DocumentUUID
                                  IsDraft    = header-%is_draft ) )
      it_items       = VALUE #( FOR create IN lt_item_create
                                FOR target IN create-%target
                                ( HeaderUUID  = create-DocumentUUID
                                  IsDraft     = create-%is_draft
                                  NetAmount   = target-NetAmount
                                  VatAmount   = target-VatAmount
                                  GrossAmount = target-GrossAmount ) ) ).

    " 3. Header context is taken over from the purchase order, totals follow the new items
    LOOP AT lt_headers REFERENCE INTO lr_header.
      DATA(ls_header) = lr_header->*.

      ASSIGN lt_po_headers[ DocumentUUID = ls_header-PoReferenceUUID ] TO <ls_po>.
      IF sy-subrc <> 0.
        " The currency belongs to the purchase order: without an order there is none
        CLEAR ls_header-CurrencyCode.
      ELSEIF ls_header-DocumentNumber IS INITIAL OR <ls_po>-CompanyCode = ls_header-CompanyCode.
        " A numbered document keeps its company (the number carries the company prefix)
        ls_header-CompanyCode         = <ls_po>-CompanyCode.
        ls_header-WarehouseCode       = <ls_po>-WarehouseCode.
        ls_header-BusinessPartnerCode = <ls_po>-BusinessPartnerCode.
        ls_header-CurrencyCode        = <ls_po>-CurrencyCode.
        ls_header-SupplierReference   = <ls_po>-SupplierReference.
      ENDIF.

      ASSIGN lt_totals[ HeaderUUID = ls_header-DocumentUUID
                        IsDraft    = ls_header-%is_draft ] TO FIELD-SYMBOL(<ls_total>).
      IF sy-subrc = 0.
        ls_header-TotalNetAmount   = <ls_total>-TotalNetAmount.
        ls_header-TotalGrossAmount = <ls_total>-TotalGrossAmount.
      ENDIF.

      IF ls_header <> lr_header->*.
        APPEND CORRESPONDING #( ls_header ) TO lt_header_update.
      ENDIF.
    ENDLOOP.

    " Apply in a fixed order: remove old items, create new items, update the header
    IF lt_item_delete IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceiptItem
        DELETE FROM lt_item_delete.
    ENDIF.

    IF lt_item_create IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceipt
        CREATE BY \_Items
        FIELDS ( ItemNo ItemCode Quantity UnitOfMeasure CurrencyCode Price VatCode
                 NetAmount VatAmount GrossAmount PoItemReferenceUUID )
        WITH lt_item_create.
    ENDIF.

    IF lt_header_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceipt
        UPDATE FIELDS ( CompanyCode WarehouseCode BusinessPartnerCode CurrencyCode SupplierReference
                        TotalNetAmount TotalGrossAmount )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  METHOD clearPoOnHeaderChange.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_goodsreceipt.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
      FIELDS ( PoReferenceUUID CompanyCode BusinessPartnerCode WarehouseCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    DELETE lt_headers WHERE PoReferenceUUID IS INITIAL.
    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_po_headers) = NEW zcl_merp_doc_po_sel( )->zif_merp_doc_po_sel~read_headers(
      VALUE #( FOR header IN lt_headers ( DocumentUUID = header-PoReferenceUUID ) ) ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      DATA(ls_header) = lr_header->*.

      " Values taken over from the purchase order match it, so only a manual change clears the reference;
      " deriveDocFromPurchaseOrder then removes the items
      ASSIGN lt_po_headers[ DocumentUUID = ls_header-PoReferenceUUID ] TO FIELD-SYMBOL(<ls_po>).
      IF sy-subrc <> 0
         OR ls_header-CompanyCode         <> <ls_po>-CompanyCode
         OR ls_header-BusinessPartnerCode <> <ls_po>-BusinessPartnerCode
         OR ls_header-WarehouseCode       <> <ls_po>-WarehouseCode.
        CLEAR ls_header-PoReferenceUUID.
      ENDIF.

      IF ls_header <> lr_header->*.
        APPEND CORRESPONDING #( ls_header ) TO lt_header_update.
      ENDIF.
    ENDLOOP.

    IF lt_header_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceipt
        UPDATE FIELDS ( PoReferenceUUID )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  " --- Determinations on save ---
  METHOD assignDocumentNumber.
    DATA lt_gr_update TYPE TABLE FOR UPDATE zmerp_r_goodsreceipt.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
      FIELDS ( DocumentNumber CompanyCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    " Only documents without a number; without a company no number can be drawn
    " (that case is reported by validateHeaderFields)
    DELETE lt_headers WHERE DocumentNumber IS NOT INITIAL OR CompanyCode IS INITIAL.

    " Numbers per company (the company is the number range subobject); a document left without a number
    " by an NRO error is rejected by validateDocumentNumber
    DATA(lt_numbers) = zcl_merp_num_range_util=>get_doc_numbers(
      is_meta     = zif_merp_constants=>c_gr
      it_requests = VALUE #( FOR header IN lt_headers ( HeaderUUID  = header-DocumentUUID
                                                        IsDraft     = header-%is_draft
                                                        CompanyCode = header-CompanyCode ) ) ).

    lt_gr_update = VALUE #( FOR number IN lt_numbers ( %is_draft      = number-IsDraft
                                                       DocumentUUID   = number-HeaderUUID
                                                       DocumentNumber = number-DocumentNumber ) ).

    IF lt_gr_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceipt
        UPDATE FIELDS ( DocumentNumber )
        WITH lt_gr_update.
    ENDIF.
  ENDMETHOD.

  " --- Validations ---
  METHOD validateHeaderFields.
    DATA lv_has_error TYPE abap_bool.
    DATA lo_message   TYPE REF TO if_abap_behv_message.

    reported-goodsreceipt = VALUE #(
      BASE reported-goodsreceipt
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_company )
      ( %tky        = key-%tky
        %state_area = c_val_partner )
      ( %tky        = key-%tky
        %state_area = c_val_warehouse )
      ( %tky        = key-%tky
        %state_area = c_val_currency )
      ( %tky        = key-%tky
        %state_area = c_val_po_ref )
    ).

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
      FIELDS ( CompanyCode BusinessPartnerCode WarehouseCode CurrencyCode PoReferenceUUID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_companies) = NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_companies(
      VALUE #( FOR header IN lt_headers ( CompanyCode = header-CompanyCode ) )
    ).

    DATA(lt_partners) = NEW zcl_merp_md_bus_partner_sel( )->zif_merp_md_bus_partner_sel~read_partners(
      VALUE #( FOR header IN lt_headers ( PartnerCode = header-BusinessPartnerCode ) )
    ).

    DATA(lt_warehouses) = NEW zcl_merp_md_warehouse_sel( )->zif_merp_md_warehouse_sel~read_warehouses(
      VALUE #( FOR header IN lt_headers ( WarehouseCode = header-WarehouseCode ) )
    ).

    DATA(lt_po_headers) = NEW zcl_merp_doc_po_sel( )->zif_merp_doc_po_sel~read_headers(
      VALUE #( FOR header IN lt_headers ( DocumentUUID = header-PoReferenceUUID ) )
    ).

    " Per field: the first rule that fails gives the message (none if the field is valid)
    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      lv_has_error = abap_false.

      " 1. Purchase order: mandatory, exists, same company
      "    (the value help validates only in the UI; references written via API/EML are checked here;
      "    a numbered document keeps its company, so an order of another company is rejected here)
      lo_message = COND #(
        WHEN lr_header->PoReferenceUUID IS INITIAL
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>select_po_reference
                                 severity = if_abap_behv_message=>severity-error )
        WHEN NOT line_exists( lt_po_headers[ DocumentUUID = lr_header->PoReferenceUUID ] )
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>purchase_order_not_found
                                 severity = if_abap_behv_message=>severity-error )
        WHEN lr_header->CompanyCode IS NOT INITIAL
         AND lt_po_headers[ DocumentUUID = lr_header->PoReferenceUUID ]-CompanyCode <> lr_header->CompanyCode
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>po_company_mismatch
                                 attr1    = CONV string( lt_po_headers[ DocumentUUID = lr_header->PoReferenceUUID ]-DocumentNumber )
                                 attr2    = CONV string( lt_po_headers[ DocumentUUID = lr_header->PoReferenceUUID ]-CompanyCode )
                                 severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                     = lr_header->%tky
                        %state_area              = c_val_po_ref
                        %msg                     = lo_message
                        %element-PoReferenceUUID = if_abap_behv=>mk-on ) TO reported-goodsreceipt.
      ENDIF.

      " 2. Company: mandatory, exists
      lo_message = COND #(
        WHEN lr_header->CompanyCode IS INITIAL
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>select_company
                                 severity = if_abap_behv_message=>severity-error )
        WHEN NOT line_exists( lt_companies[ CompanyCode = lr_header->CompanyCode ] )
          THEN NEW zcx_merp_md( textid   = zcx_merp_md=>company_code_not_found
                                attr1    = CONV string( lr_header->CompanyCode )
                                severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                 = lr_header->%tky
                        %state_area          = c_val_company
                        %msg                 = lo_message
                        %element-CompanyCode = if_abap_behv=>mk-on ) TO reported-goodsreceipt.
      ENDIF.

      " 3. Partner: mandatory, exists, is a supplier
      lo_message = COND #(
        WHEN lr_header->BusinessPartnerCode IS INITIAL
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>select_business_partner
                                 severity = if_abap_behv_message=>severity-error )
        WHEN NOT line_exists( lt_partners[ PartnerCode = lr_header->BusinessPartnerCode ] )
          THEN NEW zcx_merp_md( textid   = zcx_merp_md=>business_partner_not_found
                                attr1    = CONV string( lr_header->BusinessPartnerCode )
                                severity = if_abap_behv_message=>severity-error )
        WHEN zcl_merp_doc_validator=>is_pur_partner_supplier(
               lt_partners[ PartnerCode = lr_header->BusinessPartnerCode ]-IsSupplier ) = abap_false
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>bp_is_not_supplier
                                 attr1    = CONV string( lr_header->BusinessPartnerCode )
                                 severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                         = lr_header->%tky
                        %state_area                  = c_val_partner
                        %msg                         = lo_message
                        %element-BusinessPartnerCode = if_abap_behv=>mk-on ) TO reported-goodsreceipt.
      ENDIF.

      " 4. Warehouse: mandatory, exists, belongs to the company
      lo_message = COND #(
        WHEN lr_header->WarehouseCode IS INITIAL
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>select_warehouse
                                 severity = if_abap_behv_message=>severity-error )
        WHEN NOT line_exists( lt_warehouses[ WarehouseCode = lr_header->WarehouseCode ] )
          THEN NEW zcx_merp_md( textid   = zcx_merp_md=>warehouse_not_found
                                attr1    = CONV string( lr_header->WarehouseCode )
                                severity = if_abap_behv_message=>severity-error )
        WHEN lr_header->CompanyCode IS NOT INITIAL
         AND lt_warehouses[ WarehouseCode = lr_header->WarehouseCode ]-CompanyCode <> lr_header->CompanyCode
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>warehouse_company_mismatch
                                 attr1    = CONV string( lr_header->WarehouseCode )
                                 attr2    = CONV string( lr_header->CompanyCode )
                                 severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                   = lr_header->%tky
                        %state_area            = c_val_warehouse
                        %msg                   = lo_message
                        %element-WarehouseCode = if_abap_behv=>mk-on ) TO reported-goodsreceipt.
      ENDIF.

      " 5. Currency: mandatory (taken from the purchase order; without an order only the order is reported)
      lo_message = COND #(
        WHEN lr_header->CurrencyCode IS INITIAL AND lr_header->PoReferenceUUID IS NOT INITIAL
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>select_currency
                                 severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                  = lr_header->%tky
                        %state_area           = c_val_currency
                        %msg                  = lo_message
                        %element-CurrencyCode = if_abap_behv=>mk-on ) TO reported-goodsreceipt.
      ENDIF.

      " Any error fails the instance
      IF lv_has_error = abap_true.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-goodsreceipt.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDates.
    DATA lv_has_error TYPE abap_bool.
    DATA lo_message   TYPE REF TO if_abap_behv_message.

    reported-goodsreceipt = VALUE #(
      BASE reported-goodsreceipt
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_doc_date )
      ( %tky        = key-%tky
        %state_area = c_val_post_date )
    ).

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
      FIELDS ( DocumentDate PostingDate Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    " Per field: the first rule that fails gives the message (none if the field is valid)
    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      lv_has_error = abap_false.

      " 1. Document date: mandatory, not in the future
      lo_message = COND #(
        WHEN lr_header->DocumentDate IS INITIAL
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>enter_document_date
                                 severity = if_abap_behv_message=>severity-error )
        WHEN zcl_merp_doc_validator=>is_document_date_valid( iv_doc_date = lr_header->DocumentDate
                                                             iv_today    = lv_today ) = abap_false
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>document_date_future_invalid
                                 severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                  = lr_header->%tky
                        %state_area           = c_val_doc_date
                        %msg                  = lo_message
                        %element-DocumentDate = if_abap_behv=>mk-on ) TO reported-goodsreceipt.
      ENDIF.

      " 2. Posting date: mandatory, not in the future, not before the document date
      lo_message = COND #(
        WHEN lr_header->PostingDate IS INITIAL
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>enter_posting_date
                                 severity = if_abap_behv_message=>severity-error )
        WHEN zcl_merp_doc_validator=>is_posting_date_not_future( iv_post_date = lr_header->PostingDate
                                                                 iv_today     = lv_today ) = abap_false
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>posting_date_future_invalid
                                 severity = if_abap_behv_message=>severity-error )
        WHEN lr_header->DocumentDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_posting_date_valid( iv_doc_date  = lr_header->DocumentDate
                                                            iv_post_date = lr_header->PostingDate ) = abap_false
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>posting_date_sequence_invalid
                                 severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                 = lr_header->%tky
                        %state_area          = c_val_post_date
                        %msg                 = lo_message
                        %element-PostingDate = if_abap_behv=>mk-on ) TO reported-goodsreceipt.
      ENDIF.

      " Any error fails the instance
      IF lv_has_error = abap_true.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-goodsreceipt.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDocumentNumber.
    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
      FIELDS ( DocumentNumber CompanyCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    " Without a company no number can be drawn; that case is already reported by validateHeaderFields
    LOOP AT lt_headers REFERENCE INTO DATA(lr_header)
         WHERE DocumentNumber IS INITIAL
           AND CompanyCode    IS NOT INITIAL.
      APPEND VALUE #(
        %tky        = lr_header->%tky
        %fail-cause = if_abap_behv=>cause-unspecific
      ) TO failed-goodsreceipt.

      APPEND VALUE #(
        %tky                    = lr_header->%tky
        %msg                    = NEW zcx_merp_pur(
                                    textid   = zcx_merp_pur=>doc_number_generation_failed
                                    severity = if_abap_behv_message=>severity-error )
        %element-DocumentNumber = if_abap_behv=>mk-on
      ) TO reported-goodsreceipt.
    ENDLOOP.
  ENDMETHOD.

  " --- Clearing of validation messages ---
  METHOD clearMessagesForHeaderFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
      FIELDS ( CompanyCode BusinessPartnerCode WarehouseCode CurrencyCode PoReferenceUUID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      IF lr_header->CompanyCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_company ) TO reported-goodsreceipt.
      ENDIF.
      IF lr_header->BusinessPartnerCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_partner ) TO reported-goodsreceipt.
      ENDIF.
      IF lr_header->WarehouseCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_warehouse ) TO reported-goodsreceipt.
      ENDIF.
      IF lr_header->CurrencyCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_currency ) TO reported-goodsreceipt.
      ENDIF.
      IF lr_header->PoReferenceUUID IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_po_ref ) TO reported-goodsreceipt.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD clearMessagesForDates.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
      FIELDS ( DocumentDate PostingDate Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      IF lr_header->DocumentDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_document_date_valid( iv_doc_date = lr_header->DocumentDate
                                                             iv_today    = lv_today ) = abap_true.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_doc_date ) TO reported-goodsreceipt.
      ENDIF.

      IF lr_header->PostingDate IS NOT INITIAL AND lr_header->DocumentDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_posting_date_not_future( iv_post_date = lr_header->PostingDate
                                                                 iv_today     = lv_today ) = abap_true
         AND zcl_merp_doc_validator=>is_posting_date_valid( iv_doc_date  = lr_header->DocumentDate
                                                            iv_post_date = lr_header->PostingDate ) = abap_true.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_post_date ) TO reported-goodsreceipt.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

 " --- Helpers ---
 METHOD calc_po_receipt_status.
    " Received / ordered per touched purchase order after posting or unposting the given items
    DATA(lt_order_progress) = zcl_merp_doc_order_ref_logic=>calc_order_progress(
      it_items       = it_items
      it_order_items = CORRESPONDING #( it_progress MAPPING OrderUUID     = PoHeaderUUID
                                                            OrderItemUUID = PoItemUUID
                                                            DoneQuantity  = ReceivedQuantity )
      iv_sign        = iv_sign ).

    LOOP AT lt_order_progress REFERENCE INTO DATA(lr_order).
      DATA(lv_status) = VALUE zmerp_po_status(
        it_progress[ KEY ByHeader COMPONENTS PoHeaderUUID = lr_order->OrderUUID ]-PoStatus OPTIONAL ).

      DATA(lv_new_status) = zcl_merp_doc_po_lifecycle=>derive_receipt_status(
        iv_status       = lv_status
        iv_any_received = lr_order->AnyDone
        iv_all_received = lr_order->AllDone ).

      IF lv_new_status <> lv_status.
        APPEND VALUE #( DocumentUUID = lr_order->OrderUUID
                        Status       = lv_new_status ) TO rt_status.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD update_po_receipt_status.
    rv_success = abap_true.

    DATA(lt_po_status) = calc_po_receipt_status( it_items    = it_items
                                                 it_progress = it_progress
                                                 iv_sign     = iv_sign ).
    IF lt_po_status IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zmerp_r_purchaseorder
      ENTITY PurchaseOrder
      EXECUTE setReceiptStatus
      FROM VALUE #( FOR po IN lt_po_status ( DocumentUUID   = po-DocumentUUID
                                             %param-Status = po-Status ) )
      FAILED DATA(lt_po_failed).

    rv_success = xsdbool( lt_po_failed IS INITIAL ).
  ENDMETHOD.

ENDCLASS.

"! Local behavior handler for Goods Receipt Item child entity.
CLASS lhc_zmerp_r_goodsreceiptitm DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_val_item_code TYPE string VALUE 'VALIDATE_ITEM_CODE',
      c_val_quantity  TYPE string VALUE 'VALIDATE_QUANTITY',
      c_val_price     TYPE string VALUE 'VALIDATE_PRICE',
      c_val_uom       TYPE string VALUE 'VALIDATE_UOM',
      c_val_vat_code  TYPE string VALUE 'VALIDATE_VAT_CODE'.

    TYPES: BEGIN OF ty_header_key,
             document_uuid TYPE sysuuid_x16,
             is_draft      TYPE abp_behv_flag,
           END OF ty_header_key.

    " Static buffer: filled in precheck_delete with the parents of the items being deleted
    " and consumed (and cleared) by calcHeaderTotals within the same request
    CLASS-DATA gt_deleted_headers TYPE STANDARD TABLE OF ty_header_key WITH EMPTY KEY.

    " --- Access and state ---
    "! Items copied from a purchase order: item code, price and VAT code are fixed by the order, only quantity can change.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING
        keys   REQUEST requested_features FOR GoodsReceiptItem
      RESULT   result.

    "! Remembers the parent documents of the items being deleted, so that calcHeaderTotals
    "! can still recalculate their totals after the deletion.
    METHODS precheck_delete FOR PRECHECK
      keys FOR DELETE GoodsReceiptItem.

    " --- Actions ---
    "! Sets quantity and amounts of the selected purchase order items to the current open values;
    "! items without open quantity are only reported, the user decides whether to remove them.
    METHODS fillOpenQuantity FOR MODIFY
      IMPORTING
        keys   FOR ACTION GoodsReceiptItem~fillOpenQuantity
      RESULT   result.

    " --- Determinations on modify ---
    "! Sets item defaults (ItemNo, Currency, UoM, VatCode) based on header and selected ItemCode.
    METHODS setItemDefaults FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR GoodsReceiptItem~setItemDefaults.

    "! Recalculates net, VAT and gross amounts of the item when quantity or price changes (via ZCL_MERP_DOC_CALC).
    METHODS calcAmountsOnQtyPrice FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR GoodsReceiptItem~calcAmountsOnQtyPrice.

    "! Recalculates VAT and gross amounts of the item when the VAT code changes; the net amount stays (via ZCL_MERP_DOC_CALC).
    METHODS calcAmountsOnVatCode FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR GoodsReceiptItem~calcAmountsOnVatCode.

    "! Recalculates total header net and gross amounts (via ZCL_MERP_DOC_CALC) when items are created, changed or deleted.
    METHODS calcHeaderTotals FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR GoodsReceiptItem~calcHeaderTotals.

    " --- Validations ---
    "! Validates item fields before saving: mandatory values, existence of item and VAT code in master data,
    "! duplicate item codes, positive quantity and price.
    METHODS validateItemFields FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR GoodsReceiptItem~validateItemFields.

    " --- Clearing of validation messages ---
    "! Clears validation messages of quantity, price, unit of measure and VAT code once the values are valid/filled.
    METHODS clearMessagesForItemFields FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR GoodsReceiptItem~clearMessagesForItemFields.

    "! Re-evaluates duplicate item code messages for ALL items of the document when an item code changes.
    METHODS handleMessagesOnItemModify FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR GoodsReceiptItem~handleMessagesOnItemModify.

ENDCLASS.

CLASS lhc_zmerp_r_goodsreceiptitm IMPLEMENTATION.

  " --- Access and state ---
  METHOD get_instance_features.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceiptItem
      FIELDS ( PoItemReferenceUUID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    result = VALUE #(
      FOR item IN lt_items
      LET lv_from_po = xsdbool( item-PoItemReferenceUUID IS NOT INITIAL )
          lv_draft   = xsdbool( item-%is_draft = if_abap_behv=>mk-on ) IN
      ( %tky                     = item-%tky
        %field-ItemCode          = COND #( WHEN lv_from_po = abap_true
                                           THEN if_abap_behv=>fc-f-read_only
                                           ELSE if_abap_behv=>fc-f-mandatory )
        %field-Price             = COND #( WHEN lv_from_po = abap_true
                                           THEN if_abap_behv=>fc-f-read_only
                                           ELSE if_abap_behv=>fc-f-mandatory )
        %field-VatCode           = COND #( WHEN lv_from_po = abap_true
                                           THEN if_abap_behv=>fc-f-read_only
                                           ELSE if_abap_behv=>fc-f-mandatory )
        %action-fillOpenQuantity = COND #( WHEN lv_from_po = abap_true AND lv_draft = abap_true
                                           THEN if_abap_behv=>fc-o-enabled
                                           ELSE if_abap_behv=>fc-o-disabled ) )
    ).
  ENDMETHOD.

  METHOD precheck_delete.
    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceiptItem
      FIELDS ( HeaderUUID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    " Parents of the deleted items, for calcHeaderTotals
    gt_deleted_headers = VALUE #( BASE gt_deleted_headers
      FOR item IN lt_items ( document_uuid = item-HeaderUUID
                             is_draft      = item-%is_draft ) ).

  ENDMETHOD.

  " --- Actions ---
  METHOD fillOpenQuantity.
    DATA lt_items_update TYPE TABLE FOR UPDATE zmerp_r_goodsreceipt\\GoodsReceiptItem.

    " Selected items and their parent headers (purchase order reference)
    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceiptItem
        FIELDS ( HeaderUUID ItemNo Quantity NetAmount VatAmount GrossAmount PoItemReferenceUUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_items)
      ENTITY GoodsReceiptItem BY \_GoodsReceipt
        FIELDS ( PoReferenceUUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers).

    " Current open quantities and amounts of the referenced purchase orders (posted receipts only)
    DATA(lt_progress) = NEW zcl_merp_doc_po_sel( )->zif_merp_doc_po_sel~read_progress(
      VALUE #( FOR header IN lt_headers ( DocumentUUID = header-PoReferenceUUID ) ) ).

    " Manually added items have no open quantity and are skipped
    LOOP AT lt_items REFERENCE INTO DATA(lr_item) WHERE PoItemReferenceUUID IS NOT INITIAL.
      DATA(ls_item) = lr_item->*.

      ASSIGN lt_progress[ PoItemUUID = ls_item-PoItemReferenceUUID ] TO FIELD-SYMBOL(<ls_open>).

      " 1. Nothing left to receive for the order item: only reported
      IF sy-subrc <> 0 OR <ls_open>-OpenQuantity <= 0.
        APPEND VALUE #(
          %tky  = ls_item-%tky
          %path = VALUE #( GoodsReceipt-%is_draft    = ls_item-%is_draft
                           GoodsReceipt-DocumentUUID = ls_item-HeaderUUID )
          %msg  = NEW zcx_merp_pur(
                    textid   = zcx_merp_pur=>po_item_nothing_open
                    attr1    = CONV string( ls_item-ItemNo )
                    severity = if_abap_behv_message=>severity-warning )
        ) TO reported-goodsreceiptitem.
        CONTINUE.
      ENDIF.

      " 2. Quantity and amounts follow the current open values of the order item
      ls_item-Quantity    = <ls_open>-OpenQuantity.
      ls_item-NetAmount   = <ls_open>-OpenNetAmount.
      ls_item-VatAmount   = <ls_open>-OpenVatAmount.
      ls_item-GrossAmount = <ls_open>-OpenGrossAmount.

      IF ls_item <> lr_item->*.
        APPEND CORRESPONDING #( ls_item ) TO lt_items_update.
      ENDIF.
    ENDLOOP.

    " Header totals are recalculated by calcHeaderTotals (triggered by the changed amounts)
    IF lt_items_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceiptItem
        UPDATE FIELDS ( Quantity NetAmount VatAmount GrossAmount )
        WITH lt_items_update.
    ENDIF.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceiptItem
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR item IN lt_result ( %tky = item-%tky %param = item ) ).
  ENDMETHOD.

  " --- Determinations on modify ---
    METHOD setItemDefaults.

    " Items and their parent headers (document currency)
    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceiptItem
        FIELDS ( HeaderUUID ItemNo ItemCode UnitOfMeasure VatCode CurrencyCode PoItemReferenceUUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_items)
      ENTITY GoodsReceiptItem BY \_GoodsReceipt
        FIELDS ( CurrencyCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " All items of the affected documents: highest used item number per document
    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt BY \_Items
      FIELDS ( HeaderUUID ItemNo )
      WITH CORRESPONDING #( lt_headers )
      RESULT DATA(lt_siblings).

    " Delegate the defaulting to the shared item logic (same for all documents), only changed items are returned;
    " lines of the purchase order keep their values (order item reference)
    DATA(lt_changed) = NEW zcl_merp_doc_item_logic( )->set_defaults(
      it_items             = CORRESPONDING #( lt_items MAPPING IsDraft                = %is_draft
                                                               OrderItemReferenceUUID = PoItemReferenceUUID )
      it_siblings          = CORRESPONDING #( lt_siblings MAPPING IsDraft = %is_draft )
      it_header_currencies = CORRESPONDING #( lt_headers MAPPING HeaderUUID = DocumentUUID
                                                                 IsDraft    = %is_draft ) ).

    DATA lt_update TYPE TABLE FOR UPDATE zmerp_r_goodsreceipt\\GoodsReceiptItem.

    " Map defaults back to the instances (UUID + draft state) of the transactional buffer
    LOOP AT lt_changed REFERENCE INTO DATA(lr_changed).
      ASSIGN lt_items[ ItemUUID  = lr_changed->ItemUUID
                       %is_draft = lr_changed->IsDraft ] TO FIELD-SYMBOL(<ls_item>).

      IF sy-subrc = 0.
        APPEND VALUE #(
          %tky          = <ls_item>-%tky
          ItemNo        = lr_changed->ItemNo
          CurrencyCode  = lr_changed->CurrencyCode
          UnitOfMeasure = lr_changed->UnitOfMeasure
          VatCode       = lr_changed->VatCode
        ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceiptItem
        UPDATE FIELDS ( ItemNo CurrencyCode UnitOfMeasure VatCode )
        WITH lt_update.
    ENDIF.
  ENDMETHOD.

  METHOD calcAmountsOnQtyPrice.
    DATA lt_items_update TYPE TABLE FOR UPDATE zmerp_r_goodsreceipt\\GoodsReceiptItem.

    " Bulk read modified items (Quantity and Price changes) and their parent headers (purchase order reference)
    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceiptItem
        FIELDS ( HeaderUUID ItemCode Quantity Price VatCode NetAmount VatAmount GrossAmount PoItemReferenceUUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_items)
      ENTITY GoodsReceiptItem BY \_GoodsReceipt
        FIELDS ( PoReferenceUUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Open quantities and amounts of the referenced purchase orders (posted receipts only)
    DATA(lt_progress) = NEW zcl_merp_doc_po_sel( )->zif_merp_doc_po_sel~read_progress(
      VALUE #( FOR header IN lt_headers ( DocumentUUID = header-PoReferenceUUID ) ) ).

    " Receiving the whole open quantity takes the open amounts, so the order item is closed to zero;
    " partial receipts and items without reference get the standard calculation
    zcl_merp_doc_order_ref_logic=>apply_open_amounts(
      EXPORTING it_items       = CORRESPONDING #( lt_items MAPPING IsDraft                = %is_draft
                                                                   OrderItemReferenceUUID = PoItemReferenceUUID )
                it_order_items = CORRESPONDING #( lt_progress MAPPING OrderUUID     = PoHeaderUUID
                                                                      OrderItemUUID = PoItemUUID
                                                                      DoneQuantity  = ReceivedQuantity )
      IMPORTING et_changed     = DATA(lt_open_changed)
                et_calc        = DATA(lt_recalc) ).

    " Delegate the recalculation to the shared item logic (same for all documents), only changed items are returned
    DATA(lt_changed) = NEW zcl_merp_doc_item_logic( )->recalc_on_qty_price( lt_recalc ).
    APPEND LINES OF lt_open_changed TO lt_changed.

    " Map the new amounts back to the instances (UUID + draft state) of the transactional buffer
    LOOP AT lt_changed REFERENCE INTO DATA(lr_changed).
      ASSIGN lt_items[ ItemUUID  = lr_changed->ItemUUID
                       %is_draft = lr_changed->IsDraft ] TO FIELD-SYMBOL(<ls_item>).

      IF sy-subrc = 0.
        APPEND VALUE #(
          %tky                 = <ls_item>-%tky
          NetAmount            = lr_changed->NetAmount
          VatAmount            = lr_changed->VatAmount
          GrossAmount          = lr_changed->GrossAmount
          %control-NetAmount   = if_abap_behv=>mk-on
          %control-VatAmount   = if_abap_behv=>mk-on
          %control-GrossAmount = if_abap_behv=>mk-on
        ) TO lt_items_update.
      ENDIF.
    ENDLOOP.

    IF lt_items_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceiptItem
        UPDATE FIELDS ( NetAmount VatAmount GrossAmount )
        WITH lt_items_update.
    ENDIF.
  ENDMETHOD.

  METHOD calcAmountsOnVatCode.
    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceiptItem
      FIELDS ( HeaderUUID VatCode NetAmount VatAmount GrossAmount PoItemReferenceUUID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    " Items copied from a purchase order keep the VAT code and amounts of the order (open amounts)
    DELETE lt_items WHERE PoItemReferenceUUID IS NOT INITIAL.

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Delegate the recalculation to the shared item logic (same for all documents), only changed items are returned
    DATA(lt_changed) = NEW zcl_merp_doc_item_logic( )->recalc_on_vat_code(
      CORRESPONDING #( lt_items MAPPING IsDraft = %is_draft ) ).

    DATA lt_items_update TYPE TABLE FOR UPDATE zmerp_r_goodsreceipt\\GoodsReceiptItem.

    " Map recalculated amounts back to the instances (UUID + draft state) of the transactional buffer
    LOOP AT lt_changed REFERENCE INTO DATA(lr_changed).
      ASSIGN lt_items[ ItemUUID  = lr_changed->ItemUUID
                       %is_draft = lr_changed->IsDraft ] TO FIELD-SYMBOL(<ls_item>).

      IF sy-subrc = 0.
        APPEND VALUE #(
          %tky                 = <ls_item>-%tky
          VatAmount            = lr_changed->VatAmount
          GrossAmount          = lr_changed->GrossAmount
          %control-VatAmount   = if_abap_behv=>mk-on
          %control-GrossAmount = if_abap_behv=>mk-on
        ) TO lt_items_update.
      ENDIF.
    ENDLOOP.

    IF lt_items_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceiptItem
        UPDATE FIELDS ( VatAmount GrossAmount )
        WITH lt_items_update.
    ENDIF.
  ENDMETHOD.

  METHOD calcHeaderTotals.
    " Read parent headers of the created/changed items (deleted items can no longer be read)
    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceiptItem BY \_GoodsReceipt
      FIELDS ( DocumentUUID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    " Add parents of the items deleted in this request (collected in precheck_delete)
    LOOP AT gt_deleted_headers REFERENCE INTO DATA(lr_deleted).
      APPEND VALUE #( DocumentUUID = lr_deleted->document_uuid
                      %is_draft    = lr_deleted->is_draft ) TO lt_headers.
    ENDLOOP.
    CLEAR gt_deleted_headers.

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " Each header once (several items of one document)
    SORT lt_headers BY DocumentUUID %is_draft.
    DELETE ADJACENT DUPLICATES FROM lt_headers COMPARING DocumentUUID %is_draft.

    " Read all items of those headers in one call to pass into the shared item logic
    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt BY \_Items
      FIELDS ( HeaderUUID NetAmount VatAmount GrossAmount )
      WITH CORRESPONDING #( lt_headers )
      RESULT DATA(lt_items).

    " Delegate the summation to the shared item logic (same for all documents)
    DATA(lt_totals) = NEW zcl_merp_doc_item_logic( )->calc_header_totals(
      it_header_keys = VALUE #( FOR header IN lt_headers
                                ( HeaderUUID = header-DocumentUUID
                                  IsDraft    = header-%is_draft ) )
      it_items       = CORRESPONDING #( lt_items MAPPING IsDraft = %is_draft ) ).

    DATA lt_gr_update TYPE TABLE FOR UPDATE zmerp_r_goodsreceipt.

    LOOP AT lt_totals REFERENCE INTO DATA(lr_total).
      ASSIGN lt_headers[ DocumentUUID = lr_total->HeaderUUID
                         %is_draft    = lr_total->IsDraft ] TO FIELD-SYMBOL(<ls_header>).

      IF sy-subrc = 0.
        APPEND VALUE #(
          %tky                      = <ls_header>-%tky
          TotalNetAmount            = lr_total->TotalNetAmount
          TotalGrossAmount          = lr_total->TotalGrossAmount
          %control-TotalNetAmount   = if_abap_behv=>mk-on
          %control-TotalGrossAmount = if_abap_behv=>mk-on
        ) TO lt_gr_update.
      ENDIF.
    ENDLOOP.

    IF lt_gr_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
        ENTITY GoodsReceipt
        UPDATE FIELDS ( TotalNetAmount TotalGrossAmount )
        WITH lt_gr_update.
    ENDIF.
  ENDMETHOD.

  " --- Validations ---
  METHOD validateItemFields.
    DATA lv_has_error TYPE abap_bool.
    DATA lo_message   TYPE REF TO if_abap_behv_message.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceiptItem
      FIELDS ( HeaderUUID ItemCode Quantity Price UnitOfMeasure VatCode PoItemReferenceUUID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Clear the messages of the previous validation run
    DATA(lt_state_areas) = VALUE string_table(
      ( c_val_item_code )
      ( c_val_quantity )
      ( c_val_price )
      ( c_val_uom )
      ( c_val_vat_code ) ).

    reported-goodsreceiptitem = VALUE #(
      BASE reported-goodsreceiptitem
      FOR item IN lt_items
      FOR area IN lt_state_areas
      ( %tky        = item-%tky
        %path       = VALUE #( GoodsReceipt-%is_draft    = item-%is_draft
                               GoodsReceipt-DocumentUUID = item-HeaderUUID )
        %state_area = area )
    ).

    " Documents of the checked items: duplicates are searched among all their items
    DATA lt_header_keys TYPE TABLE FOR READ IMPORT zmerp_r_goodsreceipt.
    lt_header_keys = VALUE #(
      FOR GROUPS of <g> IN lt_items GROUP BY ( HeaderUUID = <g>-HeaderUUID
                                               is_draft   = <g>-%is_draft )
      ( %tky-DocumentUUID = <g>-HeaderUUID
        %is_draft         = <g>-%is_draft )
    ).

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt BY \_Items
      FIELDS ( HeaderUUID ItemCode PoItemReferenceUUID )
      WITH CORRESPONDING #( lt_header_keys )
      RESULT DATA(lt_all_document_items).

    " Duplicates are checked among manual lines only: a purchase order line exists once per order item
    " (created by deriveDocFromPurchaseOrder, reference read-only), and a manual line may repeat its item
    DATA(lt_duplicates) = zcl_merp_doc_validator=>get_duplicate_item_codes(
      VALUE #( FOR doc_item IN lt_all_document_items WHERE ( PoItemReferenceUUID IS INITIAL )
               ( HeaderUUID = doc_item-HeaderUUID
                 ItemCode   = doc_item-ItemCode ) )
    ).

    " Referenced master data in one selection each
    DATA(lt_items_master) = NEW zcl_merp_md_item_sel( )->zif_merp_md_item_sel~read_items(
      VALUE #( FOR item IN lt_items ( ItemCode = item-ItemCode ) )
    ).

    DATA(lt_vat_rates) = NEW zcl_merp_md_vat_rate_sel( )->zif_merp_md_vat_rate_sel~read_vat_rates(
      VALUE #( FOR item IN lt_items ( VatCode = item-VatCode ) )
    ).

    " Per field: the first rule that fails gives the message (none if the field is valid)
    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      lv_has_error = abap_false.

      " 1. Item: mandatory, exists, not twice among manual lines
      lo_message = COND #(
        WHEN lr_item->ItemCode IS INITIAL
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>select_item
                                 severity = if_abap_behv_message=>severity-error )
        WHEN NOT line_exists( lt_items_master[ ItemCode = lr_item->ItemCode ] )
          THEN NEW zcx_merp_md( textid   = zcx_merp_md=>item_not_found
                                attr1    = CONV string( lr_item->ItemCode )
                                severity = if_abap_behv_message=>severity-error )
        WHEN lr_item->PoItemReferenceUUID IS INITIAL
         AND line_exists( lt_duplicates[ HeaderUUID = lr_item->HeaderUUID
                                         ItemCode   = lr_item->ItemCode ] )
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>item_duplicate_invalid
                                 attr1    = CONV string( lr_item->ItemCode )
                                 severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky              = lr_item->%tky
                        %path             = VALUE #( GoodsReceipt-%is_draft    = lr_item->%is_draft
                                                     GoodsReceipt-DocumentUUID = lr_item->HeaderUUID )
                        %state_area       = c_val_item_code
                        %msg              = lo_message
                        %element-ItemCode = if_abap_behv=>mk-on ) TO reported-goodsreceiptitem.
      ENDIF.

      " 2. Quantity: greater than zero
      lo_message = COND #(
        WHEN zcl_merp_doc_validator=>is_item_quantity_valid( lr_item->Quantity ) = abap_false
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>quantity_must_be_positive
                                 severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky              = lr_item->%tky
                        %path             = VALUE #( GoodsReceipt-%is_draft    = lr_item->%is_draft
                                                     GoodsReceipt-DocumentUUID = lr_item->HeaderUUID )
                        %state_area       = c_val_quantity
                        %msg              = lo_message
                        %element-Quantity = if_abap_behv=>mk-on ) TO reported-goodsreceiptitem.
      ENDIF.

      " 3. Price: greater than zero
      lo_message = COND #(
        WHEN zcl_merp_doc_validator=>is_item_price_valid( lr_item->Price ) = abap_false
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>price_must_be_positive
                                 severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky           = lr_item->%tky
                        %path          = VALUE #( GoodsReceipt-%is_draft    = lr_item->%is_draft
                                                  GoodsReceipt-DocumentUUID = lr_item->HeaderUUID )
                        %state_area    = c_val_price
                        %msg           = lo_message
                        %element-Price = if_abap_behv=>mk-on ) TO reported-goodsreceiptitem.
      ENDIF.

      " 4. Unit of measure: mandatory
      lo_message = COND #(
        WHEN lr_item->UnitOfMeasure IS INITIAL
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>select_unit_of_measure
                                 severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                   = lr_item->%tky
                        %path                  = VALUE #( GoodsReceipt-%is_draft    = lr_item->%is_draft
                                                          GoodsReceipt-DocumentUUID = lr_item->HeaderUUID )
                        %state_area            = c_val_uom
                        %msg                   = lo_message
                        %element-UnitOfMeasure = if_abap_behv=>mk-on ) TO reported-goodsreceiptitem.
      ENDIF.

      " 5. VAT code: mandatory, exists
      lo_message = COND #(
        WHEN lr_item->VatCode IS INITIAL
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>select_vat_code
                                 severity = if_abap_behv_message=>severity-error )
        WHEN NOT line_exists( lt_vat_rates[ VatCode = lr_item->VatCode ] )
          THEN NEW zcx_merp_md( textid   = zcx_merp_md=>vat_code_not_found
                                attr1    = CONV string( lr_item->VatCode )
                                severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky             = lr_item->%tky
                        %path            = VALUE #( GoodsReceipt-%is_draft    = lr_item->%is_draft
                                                    GoodsReceipt-DocumentUUID = lr_item->HeaderUUID )
                        %state_area      = c_val_vat_code
                        %msg             = lo_message
                        %element-VatCode = if_abap_behv=>mk-on ) TO reported-goodsreceiptitem.
      ENDIF.

      " Any error fails the instance
      IF lv_has_error = abap_true.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-goodsreceiptitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " --- Clearing of validation messages ---
  METHOD clearMessagesForItemFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    " A message is cleared once the field is valid or filled
    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceiptItem
      FIELDS ( HeaderUUID Quantity Price UnitOfMeasure VatCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_items REFERENCE INTO DATA(lr_item).

      " 1. Quantity
      IF zcl_merp_doc_validator=>is_item_quantity_valid( lr_item->Quantity ) = abap_true.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %path       = VALUE #( GoodsReceipt-%is_draft    = lr_item->%is_draft
                                               GoodsReceipt-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_quantity ) TO reported-goodsreceiptitem.
      ENDIF.

      " 2. Price
      IF zcl_merp_doc_validator=>is_item_price_valid( lr_item->Price ) = abap_true.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %path       = VALUE #( GoodsReceipt-%is_draft    = lr_item->%is_draft
                                               GoodsReceipt-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_price ) TO reported-goodsreceiptitem.
      ENDIF.

      " 3. Unit of measure
      IF lr_item->UnitOfMeasure IS NOT INITIAL.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %path       = VALUE #( GoodsReceipt-%is_draft    = lr_item->%is_draft
                                               GoodsReceipt-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_uom ) TO reported-goodsreceiptitem.
      ENDIF.

      " 4. VAT code
      IF lr_item->VatCode IS NOT INITIAL.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %path       = VALUE #( GoodsReceipt-%is_draft    = lr_item->%is_draft
                                               GoodsReceipt-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_vat_code ) TO reported-goodsreceiptitem.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD handleMessagesOnItemModify.
    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceiptItem
      FIELDS ( HeaderUUID ItemCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_header_keys TYPE TABLE FOR READ IMPORT zmerp_r_goodsreceipt.

    " Documents of the changed items
    lt_header_keys = VALUE #(
      FOR GROUPS of <g> IN lt_items GROUP BY ( HeaderUUID = <g>-HeaderUUID
                                               is_draft   = <g>-%is_draft )
      ( %tky-DocumentUUID = <g>-HeaderUUID
        %is_draft         = <g>-%is_draft )
    ).

    " All items of these documents: a changed item can create or remove a duplicate on another item
    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt BY \_Items
      FIELDS ( HeaderUUID ItemCode PoItemReferenceUUID )
      WITH CORRESPONDING #( lt_header_keys )
      RESULT DATA(lt_all_document_items).

    " Duplicate messages of all items are evaluated again
    reported-goodsreceiptitem = VALUE #(
      BASE reported-goodsreceiptitem
      FOR ls_all_item IN lt_all_document_items
      ( %tky        = ls_all_item-%tky
        %path       = VALUE #( GoodsReceipt-%is_draft    = ls_all_item-%is_draft
                               GoodsReceipt-DocumentUUID = ls_all_item-HeaderUUID )
        %state_area = c_val_item_code )
    ).

    " Duplicates among manual lines only (see validateItemFields)
    DATA(lt_duplicates) = zcl_merp_doc_validator=>get_duplicate_item_codes(
      VALUE #( FOR doc_item IN lt_all_document_items WHERE ( PoItemReferenceUUID IS INITIAL )
               ( HeaderUUID = doc_item-HeaderUUID
                 ItemCode   = doc_item-ItemCode ) )
    ).

    IF lt_duplicates IS INITIAL.
      RETURN.
    ENDIF.

    " Every item that is part of a duplicate gets the message
    LOOP AT lt_all_document_items REFERENCE INTO DATA(lr_doc_item) WHERE ItemCode            IS NOT INITIAL
                                                                     AND PoItemReferenceUUID IS INITIAL.

      IF line_exists( lt_duplicates[ HeaderUUID = lr_doc_item->HeaderUUID
                                     ItemCode   = lr_doc_item->ItemCode ] ).

        APPEND VALUE #(
          %tky              = lr_doc_item->%tky
          %path             = VALUE #( GoodsReceipt-%is_draft    = lr_doc_item->%is_draft
                                       GoodsReceipt-DocumentUUID = lr_doc_item->HeaderUUID )
          %state_area       = c_val_item_code
          %msg              = NEW zcx_merp_pur(
                                textid   = zcx_merp_pur=>item_duplicate_invalid
                                attr1    = CONV string( lr_doc_item->ItemCode )
                                severity = if_abap_behv_message=>severity-error )
          %element-ItemCode = if_abap_behv=>mk-on
        ) TO reported-goodsreceiptitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

"! Saver for Goods Receipt: writes stock movements (quantity and value) when a document is posted
"! and removes them when it leaves the posted status.
CLASS lsc_zmerp_r_goodsreceipt DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    CONSTANTS c_document_type TYPE zmerp_doc_type VALUE 'GR'.

    METHODS save_modified REDEFINITION.
ENDCLASS.

CLASS lsc_zmerp_r_goodsreceipt IMPLEMENTATION.

  METHOD save_modified.
    DATA lt_changed   TYPE zcl_merp_stock_posting=>tt_document_keys.
    DATA lt_posted    TYPE TABLE FOR READ IMPORT zmerp_r_goodsreceipt.
    DATA lt_movements TYPE zcl_merp_stock_posting=>tt_movements.

    " Only status changes are relevant for stock
    LOOP AT update-goodsreceipt REFERENCE INTO DATA(lr_header)
         WHERE %control-Status = if_abap_behv=>mk-on.

      " Any status change first removes the movements of the document ...
      APPEND VALUE #( document_uuid = lr_header->DocumentUUID ) TO lt_changed.

      " ... and posted documents get new movements
      IF zcl_merp_doc_gr_lifecycle=>is_posted( lr_header->Status ) = abap_true.
        APPEND VALUE #( %key = lr_header->%key ) TO lt_posted.
      ENDIF.
    ENDLOOP.

    zcl_merp_stock_posting=>delete_document_movements( lt_changed ).

    IF lt_posted IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_goodsreceipt IN LOCAL MODE
      ENTITY GoodsReceipt
        FIELDS ( CompanyCode WarehouseCode CurrencyCode PostingDate )
        WITH lt_posted
        RESULT DATA(lt_headers)
      ENTITY GoodsReceipt BY \_Items
        FIELDS ( HeaderUUID ItemCode Quantity UnitOfMeasure NetAmount )
        WITH CORRESPONDING #( lt_posted )
        RESULT DATA(lt_items).

    " One incoming movement per goods receipt item: positive quantity, value = net amount
    " (the document currency equals the company currency, checked on posting);
    " services are skipped by the stock posting
    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      ASSIGN lt_headers[ DocumentUUID = lr_item->HeaderUUID ] TO FIELD-SYMBOL(<ls_header>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        document_uuid      = lr_item->HeaderUUID
        document_item_uuid = lr_item->ItemUUID
        company_code       = <ls_header>-CompanyCode
        warehouse_code     = <ls_header>-WarehouseCode
        item_code          = lr_item->ItemCode
        quantity           = lr_item->Quantity
        unit_of_measure    = lr_item->UnitOfMeasure
        amount             = lr_item->NetAmount
        currency_code      = <ls_header>-CurrencyCode
        posting_date       = <ls_header>-PostingDate
      ) TO lt_movements.
    ENDLOOP.

    zcl_merp_stock_posting=>insert_movements( iv_document_type = c_document_type
                                              it_movements     = lt_movements ).
  ENDMETHOD.

ENDCLASS.
