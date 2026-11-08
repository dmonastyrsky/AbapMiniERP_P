"! Local behavior handler for Purchase Order root entity.
CLASS lhc_zmerp_r_purchaseorder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      " Validation state areas for UI field highlighting
      c_val_company        TYPE string VALUE 'VALIDATE_COMPANY',
      c_val_partner        TYPE string VALUE 'VALIDATE_PARTNER',
      c_val_warehouse      TYPE string VALUE 'VALIDATE_WAREHOUSE',
      c_val_currency       TYPE string VALUE 'VALIDATE_CURRENCY',
      c_val_doc_date       TYPE string VALUE 'VALIDATE_DOC_DATE',
      c_val_post_date      TYPE string VALUE 'VALIDATE_POST_DATE',
      c_val_deliv_date     TYPE string VALUE 'VALIDATE_DELIV_DATE'.

    " --- Access and state ---
    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR PurchaseOrder
        RESULT  result.

    "! Evaluates dynamic instance features for actions based on status.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING
        keys   REQUEST requested_features FOR PurchaseOrder
      RESULT   result.

    "! Pre-checks deletion conditions and status restrictions.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING
        keys FOR DELETE PurchaseOrder.

    " --- Actions ---
    "! Releases the Purchase Order.
    METHODS releaseDocument FOR MODIFY
      IMPORTING
        keys   FOR ACTION PurchaseOrder~releaseDocument
      RESULT   result.

    "! Moves the Purchase Order to 'In Delivery' and stores the delivery date entered by the user.
    METHODS setInDeliveryDocument FOR MODIFY
      IMPORTING
        keys   FOR ACTION PurchaseOrder~setInDeliveryDocument
      RESULT   result.

    "! Default value of the 'In Delivery' dialog: the delivery date of the document, otherwise its document date.
    METHODS GetDefaultsForSetInDelivery FOR READ
      IMPORTING
        keys   FOR FUNCTION PurchaseOrder~GetDefaultsForSetInDelivery
      RESULT   result.

    "! Cancels the Purchase Order.
    METHODS cancelDocument FOR MODIFY
      IMPORTING
        keys   FOR ACTION PurchaseOrder~cancelDocument
      RESULT   result.

    "! Completes the Purchase Order manually (also with open quantities, e.g. short delivery).
    METHODS completeDocument FOR MODIFY
      IMPORTING
        keys   FOR ACTION PurchaseOrder~completeDocument
      RESULT   result.

    "! Sets the receipt status (Approved / In Delivery / Completed) calculated by the goods receipt.
    "! API for other business objects, not exposed in the service.
    METHODS setReceiptStatus FOR MODIFY
      IMPORTING
        keys   FOR ACTION PurchaseOrder~setReceiptStatus
      RESULT   result.

    " --- Determinations on modify ---
    "! Sets default header values on document creation.
    METHODS setHeaderDefaults FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrder~setHeaderDefaults.

    "! Derives dependent header fields when the company code changes.
    METHODS deriveHeaderOnCompanyCode FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrder~deriveHeaderOnCompanyCode.

    "! Derives dependent header fields when the document date changes.
    METHODS deriveDatesOnDocumentDate FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrder~deriveDatesOnDocumentDate.

    "! Keeps the currency of all items in sync with the header currency.
    METHODS syncItemCurrency FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrder~syncItemCurrency.

    " --- Determinations on save ---
    "! Assigns the document number from the number range on first save.
    METHODS assignDocumentNumber FOR DETERMINE ON SAVE
      IMPORTING
        keys FOR PurchaseOrder~assignDocumentNumber.

    " --- Validations ---
    "! Validates mandatory header fields before saving.
    METHODS validateHeaderFields FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR PurchaseOrder~validateHeaderFields.

    "! Validates document date and delivery date consistency.
    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR PurchaseOrder~validateDates.

    "! A document is not saved without a number: runs after assignDocumentNumber
    "! (save determinations come before save validations) and fails the instance if no number was assigned.
    METHODS validateDocumentNumber FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR PurchaseOrder~validateDocumentNumber.

    " --- Clearing of validation messages ---
    "! Clears validation messages for organizational header fields that have been filled in.
    METHODS clearMessagesForHeaderFields FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrder~clearMessagesForHeaderFields.

    "! Clears date validation messages for fields that have been fixed.
    METHODS clearMessagesForDates FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrder~clearMessagesForDates.

ENDCLASS.

CLASS lhc_zmerp_r_purchaseorder IMPLEMENTATION.

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

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " An 'In Delivery' document can be cancelled only while it has no posted goods receipts.
    " New and Approved documents cannot have posted receipts (a receipt moves the order on)
    DATA(lt_received) = NEW zcl_merp_doc_po_sel( )->zif_merp_doc_po_sel~read_received_documents(
      VALUE #( FOR header IN lt_headers WHERE ( Status = zcl_merp_doc_po_lifecycle=>c_status_in_delivery )
               ( DocumentUUID = header-DocumentUUID ) ) ).

    " Only saved (active) documents can be edited or processed; draft instances get no actions.
    " Delete follows the status only (in a draft it discards the draft)
    result = VALUE #(
      FOR header IN lt_headers
      LET lv_active   = xsdbool( header-%is_draft = if_abap_behv=>mk-off )
          lv_edit     = xsdbool( lv_active = abap_true
                             AND zcl_merp_doc_po_lifecycle=>can_edit( header-Status ) = abap_true )
          lv_release  = xsdbool( lv_active = abap_true
                             AND zcl_merp_doc_po_lifecycle=>can_release( header-Status ) = abap_true )
          lv_delivery = xsdbool( lv_active = abap_true
                             AND zcl_merp_doc_po_lifecycle=>can_set_in_delivery( header-Status ) = abap_true )
          lv_complete = xsdbool( lv_active = abap_true
                             AND zcl_merp_doc_po_lifecycle=>can_complete( header-Status ) = abap_true )
          lv_cancel   = xsdbool( lv_active = abap_true
                             AND zcl_merp_doc_po_lifecycle=>can_cancel( header-Status ) = abap_true
                             AND NOT line_exists( lt_received[ DocumentUUID = header-DocumentUUID ] ) )
          lv_delete   = zcl_merp_doc_po_lifecycle=>can_delete( header-Status ) IN
      ( %tky                          = header-%tky
        %delete                       = COND #( WHEN lv_delete = abap_true
                                                THEN if_abap_behv=>fc-o-enabled
                                                ELSE if_abap_behv=>fc-o-disabled )
        %action-Edit                  = COND #( WHEN lv_edit = abap_true
                                                THEN if_abap_behv=>fc-o-enabled
                                                ELSE if_abap_behv=>fc-o-disabled )
        %action-releaseDocument       = COND #( WHEN lv_release = abap_true
                                                THEN if_abap_behv=>fc-o-enabled
                                                ELSE if_abap_behv=>fc-o-disabled )
        %action-setInDeliveryDocument = COND #( WHEN lv_delivery = abap_true
                                                THEN if_abap_behv=>fc-o-enabled
                                                ELSE if_abap_behv=>fc-o-disabled )
        %action-completeDocument      = COND #( WHEN lv_complete = abap_true
                                                THEN if_abap_behv=>fc-o-enabled
                                                ELSE if_abap_behv=>fc-o-disabled )
        %action-cancelDocument        = COND #( WHEN lv_cancel = abap_true
                                                THEN if_abap_behv=>fc-o-enabled
                                                ELSE if_abap_behv=>fc-o-disabled )
        " The document number carries the company prefix, so the company is fixed once it is assigned
        %field-CompanyCode            = COND #( WHEN header-DocumentNumber IS INITIAL
                                                THEN if_abap_behv=>fc-f-mandatory
                                                ELSE if_abap_behv=>fc-f-read_only ) )
    ).
  ENDMETHOD.

  METHOD precheck_delete.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_failed_added TYPE abap_bool.

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " Usages of all documents in one selection (the selector skips initial keys)
    DATA(lt_usages) = NEW zcl_merp_doc_po_sel( )->zif_merp_doc_po_sel~read_usages(
      VALUE #( FOR hdr IN lt_headers ( DocumentUUID = hdr-DocumentUUID ) ) ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_hdr).
      lv_failed_added = abap_false.

      " Delete only in status New or Cancelled
      IF zcl_merp_doc_po_lifecycle=>can_delete( lr_hdr->Status ) = abap_false.
        APPEND VALUE #(
          %tky        = lr_hdr->%tky
          %fail-cause = if_abap_behv=>cause-conflict
        ) TO failed-purchaseorder.

        APPEND VALUE #(
          %tky            = lr_hdr->%tky
          %element-Status = if_abap_behv=>mk-on
          %msg            = NEW zcx_merp_pur(
                               textid   = zcx_merp_pur=>delete_not_allowed
                               attr1    = CONV #( lr_hdr->DocumentNumber )
                               severity = if_abap_behv_message=>severity-error )
        ) TO reported-purchaseorder.
        CONTINUE.
      ENDIF.

      " Usage check: one message per using entity (sorted table: WHERE uses the table key)
      LOOP AT lt_usages REFERENCE INTO DATA(lr_usage) WHERE DocumentUUID = lr_hdr->DocumentUUID.

        IF lv_failed_added = abap_false.
          APPEND VALUE #(
            %tky        = lr_hdr->%tky
            %fail-cause = if_abap_behv=>cause-dependency
          ) TO failed-purchaseorder.
          lv_failed_added = abap_true.
        ENDIF.

        " Document number is shown to the user instead of the technical UUID
        APPEND VALUE #(
          %tky            = lr_hdr->%tky
          %element-Status = if_abap_behv=>mk-on
          %msg            = NEW zcx_merp_pur(
                               textid   = zcx_merp_pur=>purchase_order_in_use
                               attr1    = CONV #( lr_hdr->DocumentNumber )
                               attr2    = CONV #( lr_usage->UsedInEntity )
                               severity = if_abap_behv_message=>severity-error )
        ) TO reported-purchaseorder.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  " --- Actions ---
  METHOD releaseDocument.
    DATA lt_update  TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.
    DATA lo_message TYPE REF TO zcx_merp_pur.

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( Status  DocumentNumber )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers)
      ENTITY PurchaseOrder BY \_Items
        FIELDS ( ItemCode )
        WITH CORRESPONDING #( keys )
        LINK DATA(lt_links).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      CLEAR lo_message.

      " Document must be in 'New' status to be released
      IF zcl_merp_doc_po_lifecycle=>can_release( lr_header->Status ) = abap_false.
        lo_message = NEW #( textid   = zcx_merp_pur=>release_not_allowed
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( lr_header->DocumentNumber ) ).

      " Document cannot be released without at least one item
      ELSEIF NOT line_exists( lt_links[ source-%tky = lr_header->%tky ] ).
        lo_message = NEW #( textid   = zcx_merp_pur=>document_empty_items_invalid
                            severity = if_abap_behv_message=>severity-error ).
      ENDIF.

      IF lo_message IS BOUND.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-purchaseorder.

        APPEND VALUE #( %tky                    = lr_header->%tky
                        %msg                    = lo_message
                        %action-releaseDocument = if_abap_behv=>mk-on ) TO reported-purchaseorder.
      ELSE.
        APPEND VALUE #( %tky   = lr_header->%tky
                        Status = zcl_merp_doc_po_lifecycle=>c_status_approved ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( Status )
        WITH lt_update
        FAILED DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      " Errors of the update are returned to the caller
      IF lt_mod_failed IS NOT INITIAL.
        failed-purchaseorder   = CORRESPONDING #( BASE ( failed-purchaseorder ) lt_mod_failed-purchaseorder ).
        reported-purchaseorder = CORRESPONDING #( BASE ( reported-purchaseorder ) lt_mod_reported-purchaseorder ).
        RETURN.
      ENDIF.
    ENDIF.

    " Action result: current state of the documents
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR header IN lt_result ( %tky = header-%tky %param = header ) ).
  ENDMETHOD.

  METHOD setInDeliveryDocument.
    DATA lt_update        TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.
    DATA lo_message       TYPE REF TO zcx_merp_pur.
    DATA lv_delivery_date TYPE zmerp_delivery_date.

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( Status DocumentNumber DocumentDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      CLEAR lo_message.

      " Delivery date entered in the dialog (proposed by GetDefaultsForSetInDelivery)
      lv_delivery_date = VALUE #( keys[ %tky = lr_header->%tky ]-%param-DeliveryDate OPTIONAL ).

      " Only Approved documents can be moved to delivery
      IF zcl_merp_doc_po_lifecycle=>can_set_in_delivery( lr_header->Status ) = abap_false.
        lo_message = NEW #( textid   = zcx_merp_pur=>set_delivery_not_allowed
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( lr_header->DocumentNumber ) ).

      " Delivery date is mandatory (the dialog field can be cleared by the user)
      ELSEIF lv_delivery_date IS INITIAL.
        lo_message = NEW #( textid   = zcx_merp_pur=>enter_delivery_date
                            severity = if_abap_behv_message=>severity-error ).

      " Delivery date must not precede the document date (as in validateDates)
      ELSEIF zcl_merp_doc_validator=>is_delivery_date_valid( iv_doc_date   = lr_header->DocumentDate
                                                             iv_deliv_date = lv_delivery_date ) = abap_false.
        lo_message = NEW #( textid   = zcx_merp_pur=>delivery_date_before_doc_date
                            severity = if_abap_behv_message=>severity-error ).
      ENDIF.

      IF lo_message IS BOUND.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-purchaseorder.

        APPEND VALUE #( %tky                          = lr_header->%tky
                        %msg                          = lo_message
                        %action-setInDeliveryDocument = if_abap_behv=>mk-on ) TO reported-purchaseorder.
      ELSE.
        APPEND VALUE #( %tky         = lr_header->%tky
                        Status       = zcl_merp_doc_po_lifecycle=>c_status_in_delivery
                        DeliveryDate = lv_delivery_date ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( Status DeliveryDate )
        WITH lt_update
        FAILED DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      " Errors of the update are returned to the caller
      IF lt_mod_failed IS NOT INITIAL.
        failed-purchaseorder   = CORRESPONDING #( BASE ( failed-purchaseorder ) lt_mod_failed-purchaseorder ).
        reported-purchaseorder = CORRESPONDING #( BASE ( reported-purchaseorder ) lt_mod_reported-purchaseorder ).
        RETURN.
      ENDIF.
    ENDIF.

    " Action result: current state of the documents
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR header IN lt_result ( %tky = header-%tky %param = header ) ).
  ENDMETHOD.

  METHOD GetDefaultsForSetInDelivery.
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( DocumentDate DeliveryDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    result = VALUE #(
      FOR header IN lt_headers
      ( %tky                = header-%tky
        %param-DeliveryDate = COND #( WHEN header-DeliveryDate IS NOT INITIAL
                                      THEN header-DeliveryDate
                                      ELSE header-DocumentDate ) ) ).
  ENDMETHOD.

  METHOD cancelDocument.
    DATA lt_update  TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.
    DATA lo_message TYPE REF TO zcx_merp_pur.

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    " A cancelled order with posted goods receipts would leave stock without an order.
    " New and Approved documents cannot have posted receipts (a receipt moves the order on)
    DATA(lt_received) = NEW zcl_merp_doc_po_sel( )->zif_merp_doc_po_sel~read_received_documents(
      VALUE #( FOR header IN lt_headers WHERE ( Status = zcl_merp_doc_po_lifecycle=>c_status_in_delivery )
               ( DocumentUUID = header-DocumentUUID ) ) ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      CLEAR lo_message.

      " New, Approved and In Delivery documents can be cancelled, In Delivery only without posted receipts
      IF zcl_merp_doc_po_lifecycle=>can_cancel( lr_header->Status ) = abap_false.
        lo_message = NEW #( textid   = zcx_merp_pur=>cancel_not_allowed
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( lr_header->DocumentNumber ) ).
      ELSEIF line_exists( lt_received[ DocumentUUID = lr_header->DocumentUUID ] ).
        lo_message = NEW #( textid   = zcx_merp_pur=>po_has_posted_receipts
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( lr_header->DocumentNumber ) ).
      ENDIF.

      IF lo_message IS BOUND.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-purchaseorder.

        APPEND VALUE #( %tky                   = lr_header->%tky
                        %msg                   = lo_message
                        %action-cancelDocument = if_abap_behv=>mk-on ) TO reported-purchaseorder.
      ELSE.
        APPEND VALUE #( %tky   = lr_header->%tky
                        Status = zcl_merp_doc_po_lifecycle=>c_status_cancelled ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( Status )
        WITH lt_update
        FAILED DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      " Errors of the update are returned to the caller
      IF lt_mod_failed IS NOT INITIAL.
        failed-purchaseorder   = CORRESPONDING #( BASE ( failed-purchaseorder ) lt_mod_failed-purchaseorder ).
        reported-purchaseorder = CORRESPONDING #( BASE ( reported-purchaseorder ) lt_mod_reported-purchaseorder ).
        RETURN.
      ENDIF.
    ENDIF.

    " Action result: current state of the documents
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR header IN lt_result ( %tky = header-%tky %param = header ) ).
  ENDMETHOD.

  METHOD completeDocument.
    DATA lt_update  TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.
    DATA lo_message TYPE REF TO zcx_merp_pur.

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      CLEAR lo_message.

      " Only 'Approved' or 'In Delivery' documents can be completed; open quantities are allowed
      IF zcl_merp_doc_po_lifecycle=>can_complete( lr_header->Status ) = abap_false.
        lo_message = NEW #( textid   = zcx_merp_pur=>complete_not_allowed
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( lr_header->DocumentNumber ) ).
      ENDIF.

      IF lo_message IS BOUND.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-purchaseorder.

        APPEND VALUE #( %tky                     = lr_header->%tky
                        %msg                     = lo_message
                        %action-completeDocument = if_abap_behv=>mk-on ) TO reported-purchaseorder.
      ELSE.
        APPEND VALUE #( %tky   = lr_header->%tky
                        Status = zcl_merp_doc_po_lifecycle=>c_status_completed ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( Status )
        WITH lt_update
        FAILED DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      " Errors of the update are returned to the caller
      IF lt_mod_failed IS NOT INITIAL.
        failed-purchaseorder   = CORRESPONDING #( BASE ( failed-purchaseorder ) lt_mod_failed-purchaseorder ).
        reported-purchaseorder = CORRESPONDING #( BASE ( reported-purchaseorder ) lt_mod_reported-purchaseorder ).
        RETURN.
      ENDIF.
    ENDIF.

    " Action result: current state of the documents
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR header IN lt_result ( %tky = header-%tky %param = header ) ).
  ENDMETHOD.

  METHOD setReceiptStatus.
    DATA lt_update  TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.
    DATA lo_message TYPE REF TO zcx_merp_pur.

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      CLEAR lo_message.

      ASSIGN keys[ %tky = lr_header->%tky ] TO FIELD-SYMBOL(<ls_key>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      " Only transitions within the receipt lifecycle (Approved / In Delivery / Completed) are allowed
      IF zcl_merp_doc_po_lifecycle=>is_receipt_status( lr_header->Status ) = abap_false
         OR zcl_merp_doc_po_lifecycle=>is_receipt_status( <ls_key>-%param-Status ) = abap_false.
        lo_message = NEW #( textid   = zcx_merp_pur=>invalid_document_status
                            severity = if_abap_behv_message=>severity-error ).
      ENDIF.

      IF lo_message IS BOUND.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-purchaseorder.
        APPEND VALUE #( %tky                     = lr_header->%tky
                        %msg                     = lo_message
                        %action-setReceiptStatus = if_abap_behv=>mk-on ) TO reported-purchaseorder.
      ELSEIF <ls_key>-%param-Status <> lr_header->Status.
        APPEND VALUE #( %tky   = lr_header->%tky
                        Status = <ls_key>-%param-Status ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( Status )
        WITH lt_update
        FAILED DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      IF lt_mod_failed IS NOT INITIAL.
        failed-purchaseorder   = CORRESPONDING #( BASE ( failed-purchaseorder ) lt_mod_failed-purchaseorder ).
        reported-purchaseorder = CORRESPONDING #( BASE ( reported-purchaseorder ) lt_mod_reported-purchaseorder ).
        RETURN.
      ENDIF.
    ENDIF.

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR header IN lt_result ( %tky = header-%tky %param = header ) ).
  ENDMETHOD.

  " --- Determinations on modify ---
  METHOD setHeaderDefaults.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
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
        ls_header-Status = zcl_merp_doc_po_lifecycle=>c_status_new.
      ENDIF.

      " Only changed headers are updated
      IF ls_header <> lr_header->*.
        APPEND CORRESPONDING #( ls_header ) TO lt_header_update.
      ENDIF.
    ENDLOOP.

    IF lt_header_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( DocumentDate PostingDate Status )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  METHOD deriveHeaderOnCompanyCode.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( CompanyCode CurrencyCode WarehouseCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " Company and warehouse master data in one selection each
    DATA(lt_companies) = NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_companies(
      VALUE #( FOR header IN lt_headers ( CompanyCode = header-CompanyCode ) )
    ).

    DATA(lt_warehouses) = NEW zcl_merp_md_warehouse_sel( )->zif_merp_md_warehouse_sel~read_warehouses(
      VALUE #( FOR header IN lt_headers ( WarehouseCode = header-WarehouseCode ) )
    ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      DATA(ls_header) = lr_header->*.

      IF ls_header-CompanyCode IS NOT INITIAL.
        " The currency follows the company currency
        ASSIGN lt_companies[ CompanyCode = ls_header-CompanyCode ] TO FIELD-SYMBOL(<ls_company>).
        IF sy-subrc = 0 AND <ls_company>-CurrencyCode IS NOT INITIAL.
          ls_header-CurrencyCode = <ls_company>-CurrencyCode.
        ENDIF.

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
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( CurrencyCode WarehouseCode )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  METHOD deriveDatesOnDocumentDate.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( DocumentDate PostingDate DeliveryDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      DATA(ls_header) = lr_header->*.

      IF ls_header-DocumentDate IS NOT INITIAL.
        " A posting date before the new document date is moved to it
        IF ls_header-PostingDate IS NOT INITIAL
           AND zcl_merp_doc_validator=>is_posting_date_valid( iv_doc_date  = ls_header-DocumentDate
                                                              iv_post_date = ls_header-PostingDate ) = abap_false.
          ls_header-PostingDate = ls_header-DocumentDate.
        ENDIF.

        " A delivery date before the new document date is moved to it
        IF ls_header-DeliveryDate IS NOT INITIAL
           AND zcl_merp_doc_validator=>is_delivery_date_valid( iv_doc_date = ls_header-DocumentDate
                                                               iv_deliv_date = ls_header-DeliveryDate ) = abap_false.
          ls_header-DeliveryDate = ls_header-DocumentDate.
        ENDIF.
      ENDIF.

      " Only changed headers are updated
      IF ls_header <> lr_header->*.
        APPEND CORRESPONDING #( ls_header ) TO lt_header_update.
      ENDIF.
    ENDLOOP.

    IF lt_header_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( PostingDate DeliveryDate )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  METHOD syncItemCurrency.
    DATA lt_items_to_update TYPE TABLE FOR UPDATE zmerp_r_purchaseorder\\PurchaseOrderItem.

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( CurrencyCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers)
      ENTITY PurchaseOrder BY \_Items
        FIELDS ( HeaderUUID CurrencyCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_items).

    IF lt_headers IS INITIAL OR lt_items IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      ASSIGN lt_headers[ DocumentUUID = lr_item->HeaderUUID
                         %is_draft    = lr_item->%is_draft ] TO FIELD-SYMBOL(<ls_header>).

      " Item currency follows the header currency
      IF sy-subrc = 0 AND lr_item->CurrencyCode <> <ls_header>-CurrencyCode.
        APPEND VALUE #(
          %tky         = lr_item->%tky
          CurrencyCode = <ls_header>-CurrencyCode
        ) TO lt_items_to_update.
      ENDIF.
    ENDLOOP.

    IF lt_items_to_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrderItem
        UPDATE FIELDS ( CurrencyCode )
        WITH lt_items_to_update.
    ENDIF.
  ENDMETHOD.

  " --- Determinations on save ---
  METHOD assignDocumentNumber.
    DATA lt_company_headers TYPE TABLE FOR READ RESULT zmerp_r_purchaseorder.
    DATA lt_codes           TYPE string_table.
    DATA lt_po_update       TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( DocumentNumber CompanyCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    " Only documents without a number; without a company no number can be drawn
    " (that case is reported by validateHeaderFields)
    DELETE lt_headers WHERE DocumentNumber IS NOT INITIAL OR CompanyCode IS INITIAL.

    " Numbers are drawn per company (the company is the number range subobject)
    LOOP AT lt_headers INTO DATA(ls_header)
         GROUP BY ( company_code = ls_header-CompanyCode )
         INTO DATA(lg_company).

      lt_company_headers = VALUE #( FOR member IN GROUP lg_company ( member ) ).

      " An NRO error leaves the documents of this company without a number
      TRY.
          lt_codes = zcl_merp_num_range_util=>get_next_po_numbers_nro(
            iv_company_code = lg_company-company_code
            iv_count        = lines( lt_company_headers ) ).
        CATCH cx_number_ranges.
          CLEAR lt_codes.
      ENDTRY.

      " Numbers in the order of the documents; a document without a number is rejected by validateDocumentNumber
      LOOP AT lt_company_headers REFERENCE INTO DATA(lr_header).
        DATA(lv_code) = VALUE string( lt_codes[ sy-tabix ] OPTIONAL ).
        IF lv_code IS NOT INITIAL.
          APPEND VALUE #( %tky           = lr_header->%tky
                          DocumentNumber = CONV #( lv_code ) ) TO lt_po_update.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    IF lt_po_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( DocumentNumber )
        WITH lt_po_update.
    ENDIF.
  ENDMETHOD.

  " --- Validations ---
  METHOD validateHeaderFields.
    DATA lv_has_error TYPE abap_bool.
    DATA lo_message   TYPE REF TO if_abap_behv_message.

    " Clear the messages of the previous validation run
    reported-purchaseorder = VALUE #(
      BASE reported-purchaseorder
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_company )
      ( %tky        = key-%tky
        %state_area = c_val_partner )
      ( %tky        = key-%tky
        %state_area = c_val_warehouse )
      ( %tky        = key-%tky
        %state_area = c_val_currency )
    ).

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( CompanyCode BusinessPartnerCode WarehouseCode CurrencyCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " Referenced master data in one selection each
    DATA(lt_companies) = NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_companies(
      VALUE #( FOR header IN lt_headers ( CompanyCode = header-CompanyCode ) )
    ).

    DATA(lt_partners) = NEW zcl_merp_md_bus_partner_sel( )->zif_merp_md_bus_partner_sel~read_partners(
      VALUE #( FOR header IN lt_headers ( PartnerCode = header-BusinessPartnerCode ) )
    ).

    DATA(lt_warehouses) = NEW zcl_merp_md_warehouse_sel( )->zif_merp_md_warehouse_sel~read_warehouses(
      VALUE #( FOR header IN lt_headers ( WarehouseCode = header-WarehouseCode ) )
    ).

    " Per field: the first rule that fails gives the message (none if the field is valid)
    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      lv_has_error = abap_false.

      " 1. Company: mandatory, exists
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
                        %element-CompanyCode = if_abap_behv=>mk-on ) TO reported-purchaseorder.
      ENDIF.

      " 2. Partner: mandatory, exists, is a supplier
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
                        %element-BusinessPartnerCode = if_abap_behv=>mk-on ) TO reported-purchaseorder.
      ENDIF.

      " 3. Warehouse: mandatory, exists, belongs to the company
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
                        %element-WarehouseCode = if_abap_behv=>mk-on ) TO reported-purchaseorder.
      ENDIF.

      " 4. Currency: mandatory, equals the company currency
      "    (only the company currency is allowed until currency conversion exists, D1)
      lo_message = COND #(
        WHEN lr_header->CurrencyCode IS INITIAL
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>select_currency
                                 severity = if_abap_behv_message=>severity-error )
        WHEN line_exists( lt_companies[ CompanyCode = lr_header->CompanyCode ] )
         AND NOT line_exists( lt_companies[ CompanyCode  = lr_header->CompanyCode
                                            CurrencyCode = lr_header->CurrencyCode ] )
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>currency_not_company
                                 attr1    = CONV string( lr_header->CurrencyCode )
                                 attr2    = CONV string( lt_companies[ CompanyCode = lr_header->CompanyCode ]-CurrencyCode )
                                 severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                  = lr_header->%tky
                        %state_area           = c_val_currency
                        %msg                  = lo_message
                        %element-CurrencyCode = if_abap_behv=>mk-on ) TO reported-purchaseorder.
      ENDIF.

      " Any error fails the instance
      IF lv_has_error = abap_true.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-purchaseorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDates.
    DATA lv_has_error TYPE abap_bool.
    DATA lo_message   TYPE REF TO if_abap_behv_message.

    " Clear the messages of the previous validation run
    reported-purchaseorder = VALUE #(
      BASE reported-purchaseorder
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_doc_date )
      ( %tky        = key-%tky
        %state_area = c_val_post_date )
      ( %tky        = key-%tky
        %state_area = c_val_deliv_date )
    ).

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( DocumentDate PostingDate DeliveryDate Status )
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
                        %element-DocumentDate = if_abap_behv=>mk-on ) TO reported-purchaseorder.
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
                        %element-PostingDate = if_abap_behv=>mk-on ) TO reported-purchaseorder.
      ENDIF.

      " 3. Delivery date (optional): not in the past while New, not before the document date
      lo_message = COND #(
        WHEN lr_header->DeliveryDate IS NOT INITIAL
         AND zcl_merp_doc_po_lifecycle=>is_delivery_date_actual( iv_status        = lr_header->Status
                                                                 iv_delivery_date = lr_header->DeliveryDate
                                                                 iv_today         = lv_today ) = abap_false
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>delivery_date_past_invalid
                                 severity = if_abap_behv_message=>severity-error )
        WHEN lr_header->DeliveryDate IS NOT INITIAL AND lr_header->DocumentDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_delivery_date_valid( iv_doc_date   = lr_header->DocumentDate
                                                             iv_deliv_date = lr_header->DeliveryDate ) = abap_false
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>delivery_date_before_doc_date
                                 severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                  = lr_header->%tky
                        %state_area           = c_val_deliv_date
                        %msg                  = lo_message
                        %element-DeliveryDate = if_abap_behv=>mk-on ) TO reported-purchaseorder.
      ENDIF.

      " Any error fails the instance
      IF lv_has_error = abap_true.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-purchaseorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDocumentNumber.
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
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
      ) TO failed-purchaseorder.

      APPEND VALUE #(
        %tky                    = lr_header->%tky
        %msg                    = NEW zcx_merp_pur(
                                    textid   = zcx_merp_pur=>doc_number_generation_failed
                                    severity = if_abap_behv_message=>severity-error )
        %element-DocumentNumber = if_abap_behv=>mk-on
      ) TO reported-purchaseorder.
    ENDLOOP.
  ENDMETHOD.

  " --- Clearing of validation messages ---
  METHOD clearMessagesForHeaderFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( CompanyCode BusinessPartnerCode WarehouseCode CurrencyCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      IF lr_header->CompanyCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_company ) TO reported-purchaseorder.
      ENDIF.

      IF lr_header->BusinessPartnerCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_partner ) TO reported-purchaseorder.
      ENDIF.

      IF lr_header->WarehouseCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_warehouse ) TO reported-purchaseorder.
      ENDIF.

      IF lr_header->CurrencyCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_currency ) TO reported-purchaseorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD clearMessagesForDates.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    " A message is cleared only when the date passes the checks of validateDates
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( DocumentDate PostingDate DeliveryDate Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).

      " 1. Document date
      IF lr_header->DocumentDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_document_date_valid( iv_doc_date = lr_header->DocumentDate
                                                             iv_today    = lv_today ) = abap_true.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_doc_date ) TO reported-purchaseorder.
      ENDIF.

      " 2. Posting date
      IF lr_header->PostingDate IS NOT INITIAL AND lr_header->DocumentDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_posting_date_not_future( iv_post_date = lr_header->PostingDate
                                                                 iv_today     = lv_today ) = abap_true
         AND zcl_merp_doc_validator=>is_posting_date_valid( iv_doc_date  = lr_header->DocumentDate
                                                            iv_post_date = lr_header->PostingDate ) = abap_true.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_post_date ) TO reported-purchaseorder.
      ENDIF.

      " 3. Delivery date
      IF lr_header->DeliveryDate IS NOT INITIAL AND lr_header->DocumentDate IS NOT INITIAL.
        DATA(lv_del_valid) = zcl_merp_doc_validator=>is_delivery_date_valid( iv_doc_date   = lr_header->DocumentDate
                                                                             iv_deliv_date = lr_header->DeliveryDate ).

        IF lv_del_valid = abap_true.
          lv_del_valid = zcl_merp_doc_po_lifecycle=>is_delivery_date_actual( iv_status        = lr_header->Status
                                                                         iv_delivery_date = lr_header->DeliveryDate
                                                                         iv_today         = lv_today ).
        ENDIF.

        IF lv_del_valid = abap_true.
          APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_deliv_date ) TO reported-purchaseorder.
        ENDIF.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

"! Local behavior handler for Purchase Order Item child entity.
CLASS lhc_zmerp_r_purchaseorderitm DEFINITION INHERITING FROM cl_abap_behavior_handler.
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
    "! Remembers the parent documents of the items being deleted, so that calcHeaderTotals
    "! can still recalculate their totals after the deletion.
    METHODS precheck_delete FOR PRECHECK
      keys FOR DELETE PurchaseOrderItem.

    " --- Determinations on modify ---
    "! Sets item defaults (ItemNo, Currency, UoM, VatCode) based on header and selected ItemCode.
    METHODS setItemDefaults FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrderItem~setItemDefaults.

    "! Recalculates net, VAT and gross amounts of the item when quantity or price changes (via ZCL_MERP_DOC_CALC).
    METHODS calcAmountsOnQtyPrice FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrderItem~calcAmountsOnQtyPrice.

    "! Recalculates VAT and gross amounts of the item when the VAT code changes; the net amount stays (via ZCL_MERP_DOC_CALC).
    METHODS calcAmountsOnVatCode FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrderItem~calcAmountsOnVatCode.

    "! Recalculates total header net and gross amounts (via ZCL_MERP_DOC_CALC) when items are created, changed or deleted.
    METHODS calcHeaderTotals FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrderItem~calcHeaderTotals.

    " --- Validations ---
    "! Validates item fields before saving: mandatory values, existence of item and VAT code in master data,
    "! duplicate item codes, positive quantity and price.
    METHODS validateItemFields FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR PurchaseOrderItem~validateItemFields.

    " --- Clearing of validation messages ---
    "! Clears validation messages of quantity, price, unit of measure and VAT code once the values are valid/filled.
    METHODS clearMessagesForItemFields FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrderItem~clearMessagesForItemFields.

    "! Re-evaluates duplicate item code messages for ALL items of the document when an item code changes.
    METHODS handleMessagesOnItemModify FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrderItem~handleMessagesOnItemModify.

ENDCLASS.

CLASS lhc_zmerp_r_purchaseorderitm IMPLEMENTATION.

  " --- Access and state ---
  METHOD precheck_delete.
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrderItem
      FIELDS ( HeaderUUID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    " Parents of the deleted items, for calcHeaderTotals
    gt_deleted_headers = VALUE #( BASE gt_deleted_headers
      FOR item IN lt_items ( document_uuid = item-HeaderUUID
                             is_draft      = item-%is_draft ) ).
  ENDMETHOD.

  " --- Determinations on modify ---
  METHOD setItemDefaults.

    " Items and their parent headers (document currency)
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrderItem
        FIELDS ( HeaderUUID ItemNo ItemCode UnitOfMeasure VatCode CurrencyCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_items)
      ENTITY PurchaseOrderItem BY \_PurchaseOrder
        FIELDS ( CurrencyCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " All items of the affected documents: highest used item number per document
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder BY \_Items
      FIELDS ( HeaderUUID ItemNo )
      WITH CORRESPONDING #( lt_headers )
      RESULT DATA(lt_siblings).

    " Delegate the defaulting to the shared item logic (same for all documents), only changed items are returned
    DATA(lt_changed) = NEW zcl_merp_doc_item_logic( )->set_defaults(
      it_items             = CORRESPONDING #( lt_items MAPPING IsDraft = %is_draft )
      it_siblings          = CORRESPONDING #( lt_siblings MAPPING IsDraft = %is_draft )
      it_header_currencies = CORRESPONDING #( lt_headers MAPPING HeaderUUID = DocumentUUID
                                                                 IsDraft    = %is_draft ) ).

    DATA lt_update TYPE TABLE FOR UPDATE zmerp_r_purchaseorder\\PurchaseOrderItem.

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
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrderItem
        UPDATE FIELDS ( ItemNo CurrencyCode UnitOfMeasure VatCode )
        WITH lt_update.
    ENDIF.
  ENDMETHOD.

  METHOD calcAmountsOnQtyPrice.
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrderItem
      FIELDS ( HeaderUUID ItemCode Quantity Price VatCode NetAmount VatAmount GrossAmount )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Delegate the recalculation to the shared item logic (same for all documents), only changed items are returned
    DATA(lt_changed) = NEW zcl_merp_doc_item_logic( )->recalc_on_qty_price(
      CORRESPONDING #( lt_items MAPPING IsDraft = %is_draft ) ).

    DATA lt_items_update TYPE TABLE FOR UPDATE zmerp_r_purchaseorder\\PurchaseOrderItem.

    " Map recalculated amounts back to the instances (UUID + draft state) of the transactional buffer
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
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrderItem
        UPDATE FIELDS ( NetAmount VatAmount GrossAmount )
        WITH lt_items_update.
    ENDIF.
  ENDMETHOD.

  METHOD calcAmountsOnVatCode.
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrderItem
      FIELDS ( HeaderUUID VatCode NetAmount VatAmount GrossAmount )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Delegate the recalculation to the shared item logic (same for all documents), only changed items are returned
    DATA(lt_changed) = NEW zcl_merp_doc_item_logic( )->recalc_on_vat_code(
      CORRESPONDING #( lt_items MAPPING IsDraft = %is_draft ) ).

    DATA lt_items_update TYPE TABLE FOR UPDATE zmerp_r_purchaseorder\\PurchaseOrderItem.

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
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrderItem
        UPDATE FIELDS ( VatAmount GrossAmount )
        WITH lt_items_update.
    ENDIF.
  ENDMETHOD.

  METHOD calcHeaderTotals.
    " Read parent headers of the created/changed items (deleted items can no longer be read)
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrderItem BY \_PurchaseOrder
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
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder BY \_Items
      FIELDS ( HeaderUUID NetAmount VatAmount GrossAmount )
      WITH CORRESPONDING #( lt_headers )
      RESULT DATA(lt_items).

    " Delegate the summation to the shared item logic (same for all documents)
    DATA(lt_totals) = NEW zcl_merp_doc_item_logic( )->calc_header_totals(
      it_header_keys = VALUE #( FOR header IN lt_headers
                                ( HeaderUUID = header-DocumentUUID
                                  IsDraft    = header-%is_draft ) )
      it_items       = CORRESPONDING #( lt_items MAPPING IsDraft = %is_draft ) ).

    DATA lt_po_update TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.

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
        ) TO lt_po_update.
      ENDIF.
    ENDLOOP.

    IF lt_po_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( TotalNetAmount TotalGrossAmount )
        WITH lt_po_update.
    ENDIF.
  ENDMETHOD.

  " --- Validations ---
  METHOD validateItemFields.
    DATA lv_has_error TYPE abap_bool.
    DATA lo_message   TYPE REF TO if_abap_behv_message.

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrderItem
      FIELDS ( HeaderUUID ItemCode Quantity Price UnitOfMeasure VatCode )
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

    reported-purchaseorderitem = VALUE #(
      BASE reported-purchaseorderitem
      FOR item IN lt_items
      FOR area IN lt_state_areas
      ( %tky        = item-%tky
        %path       = VALUE #( PurchaseOrder-%is_draft    = item-%is_draft
                               PurchaseOrder-DocumentUUID = item-HeaderUUID )
        %state_area = area )
    ).

    " Documents of the checked items: duplicates are searched among all their items
    DATA lt_header_keys TYPE TABLE FOR READ IMPORT zmerp_r_purchaseorder.
    lt_header_keys = VALUE #(
      FOR GROUPS of <g> IN lt_items GROUP BY ( HeaderUUID = <g>-HeaderUUID
                                               is_draft   = <g>-%is_draft )
      ( %tky-DocumentUUID = <g>-HeaderUUID
        %is_draft         = <g>-%is_draft )
    ).

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder BY \_Items
      FIELDS ( HeaderUUID ItemCode )
      WITH CORRESPONDING #( lt_header_keys )
      RESULT DATA(lt_all_document_items).

    DATA(lt_duplicates) = zcl_merp_doc_validator=>get_duplicate_item_codes(
      CORRESPONDING zcl_merp_doc_validator=>tt_item_fields( lt_all_document_items )
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

      " 1. Item: mandatory, exists, not twice in the document
      lo_message = COND #(
        WHEN lr_item->ItemCode IS INITIAL
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>select_item
                                 severity = if_abap_behv_message=>severity-error )
        WHEN NOT line_exists( lt_items_master[ ItemCode = lr_item->ItemCode ] )
          THEN NEW zcx_merp_md( textid   = zcx_merp_md=>item_not_found
                                attr1    = CONV string( lr_item->ItemCode )
                                severity = if_abap_behv_message=>severity-error )
        WHEN line_exists( lt_duplicates[ HeaderUUID = lr_item->HeaderUUID
                                         ItemCode   = lr_item->ItemCode ] )
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>item_duplicate_invalid
                                 attr1    = CONV string( lr_item->ItemCode )
                                 severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky              = lr_item->%tky
                        %path             = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                                     PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area       = c_val_item_code
                        %msg              = lo_message
                        %element-ItemCode = if_abap_behv=>mk-on ) TO reported-purchaseorderitem.
      ENDIF.

      " 2. Quantity: greater than zero
      lo_message = COND #(
        WHEN zcl_merp_doc_validator=>is_item_quantity_valid( lr_item->Quantity ) = abap_false
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>quantity_must_be_positive
                                 severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky              = lr_item->%tky
                        %path             = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                                     PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area       = c_val_quantity
                        %msg              = lo_message
                        %element-Quantity = if_abap_behv=>mk-on ) TO reported-purchaseorderitem.
      ENDIF.

      " 3. Price: greater than zero
      lo_message = COND #(
        WHEN zcl_merp_doc_validator=>is_item_price_valid( lr_item->Price ) = abap_false
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>price_must_be_positive
                                 severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky           = lr_item->%tky
                        %path          = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                                  PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area    = c_val_price
                        %msg           = lo_message
                        %element-Price = if_abap_behv=>mk-on ) TO reported-purchaseorderitem.
      ENDIF.

      " 4. Unit of measure: mandatory
      lo_message = COND #(
        WHEN lr_item->UnitOfMeasure IS INITIAL
          THEN NEW zcx_merp_pur( textid   = zcx_merp_pur=>select_unit_of_measure
                                 severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                   = lr_item->%tky
                        %path                  = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                                          PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area            = c_val_uom
                        %msg                   = lo_message
                        %element-UnitOfMeasure = if_abap_behv=>mk-on ) TO reported-purchaseorderitem.
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
                        %path            = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                                    PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area      = c_val_vat_code
                        %msg             = lo_message
                        %element-VatCode = if_abap_behv=>mk-on ) TO reported-purchaseorderitem.
      ENDIF.

      " Any error fails the instance
      IF lv_has_error = abap_true.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-purchaseorderitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " --- Clearing of validation messages ---
  METHOD clearMessagesForItemFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    " A message is cleared once the field is valid or filled
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrderItem
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
                        %path       = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                               PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_quantity ) TO reported-purchaseorderitem.
      ENDIF.

      " 2. Price
      IF zcl_merp_doc_validator=>is_item_price_valid( lr_item->Price ) = abap_true.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %path       = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                               PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_price ) TO reported-purchaseorderitem.
      ENDIF.

      " 3. Unit of measure
      IF lr_item->UnitOfMeasure IS NOT INITIAL.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %path       = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                               PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_uom ) TO reported-purchaseorderitem.
      ENDIF.

      " 4. VAT code
      IF lr_item->VatCode IS NOT INITIAL.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %path       = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                               PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_vat_code ) TO reported-purchaseorderitem.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD handleMessagesOnItemModify.
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrderItem
      FIELDS ( HeaderUUID ItemCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_header_keys TYPE TABLE FOR READ IMPORT zmerp_r_purchaseorder.

    " Documents of the changed items
    lt_header_keys = VALUE #(
      FOR GROUPS of <g> IN lt_items GROUP BY ( HeaderUUID = <g>-HeaderUUID
                                               is_draft   = <g>-%is_draft )
      ( %tky-DocumentUUID = <g>-HeaderUUID
        %is_draft         = <g>-%is_draft )
    ).

    " All items of these documents: a changed item can create or remove a duplicate on another item
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder BY \_Items
      FIELDS ( HeaderUUID ItemCode )
      WITH CORRESPONDING #( lt_header_keys )
      RESULT DATA(lt_all_document_items).

    " Duplicate messages of all items are evaluated again
    reported-purchaseorderitem = VALUE #(
      BASE reported-purchaseorderitem
      FOR ls_all_item IN lt_all_document_items
      ( %tky        = ls_all_item-%tky
        %path       = VALUE #( PurchaseOrder-%is_draft    = ls_all_item-%is_draft
                               PurchaseOrder-DocumentUUID = ls_all_item-HeaderUUID )
        %state_area = c_val_item_code )
    ).

    DATA(lt_duplicates) = zcl_merp_doc_validator=>get_duplicate_item_codes(
      CORRESPONDING zcl_merp_doc_validator=>tt_item_fields( lt_all_document_items )
    ).

    IF lt_duplicates IS INITIAL.
      RETURN.
    ENDIF.

    " Every item that is part of a duplicate gets the message
    LOOP AT lt_all_document_items REFERENCE INTO DATA(lr_doc_item) WHERE ItemCode IS NOT INITIAL.

      IF line_exists( lt_duplicates[ HeaderUUID = lr_doc_item->HeaderUUID
                                     ItemCode   = lr_doc_item->ItemCode ] ).

        APPEND VALUE #(
          %tky              = lr_doc_item->%tky
          %path             = VALUE #( PurchaseOrder-%is_draft    = lr_doc_item->%is_draft
                                       PurchaseOrder-DocumentUUID = lr_doc_item->HeaderUUID )
          %state_area       = c_val_item_code
          %msg              = NEW zcx_merp_pur(
                                textid   = zcx_merp_pur=>item_duplicate_invalid
                                attr1    = CONV string( lr_doc_item->ItemCode )
                                severity = if_abap_behv_message=>severity-error )
          %element-ItemCode = if_abap_behv=>mk-on
        ) TO reported-purchaseorderitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.



