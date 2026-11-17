"! Local behavior handler for Stock Transfer root entity.
CLASS lhc_zmerp_r_stocktransfer DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_val_company        TYPE string VALUE 'VALIDATE_COMPANY',
      c_val_warehouse      TYPE string VALUE 'VALIDATE_WAREHOUSE',
      c_val_recv_warehouse TYPE string VALUE 'VALIDATE_RECV_WAREHOUSE',
      c_val_doc_date       TYPE string VALUE 'VALIDATE_DOC_DATE',
      c_val_post_date      TYPE string VALUE 'VALIDATE_POST_DATE'.

    " --- Access and state ---
    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR StockTransfer
        RESULT  result.

    "! Evaluates dynamic instance features for actions based on status.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING
        keys   REQUEST requested_features FOR StockTransfer
      RESULT   result.

    "! Pre-checks deletion conditions and status restrictions.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING
        keys FOR DELETE StockTransfer.

    " --- Actions ---
    "! Posts the Stock Transfer.
    METHODS postDocument FOR MODIFY
      IMPORTING
        keys   FOR ACTION StockTransfer~postDocument
      RESULT   result.

    "! Unposts the Stock Transfer (back to 'New').
    METHODS unpostDocument FOR MODIFY
      IMPORTING
        keys   FOR ACTION StockTransfer~unpostDocument
      RESULT   result.

    "! Cancels the Stock Transfer.
    METHODS cancelDocument FOR MODIFY
      IMPORTING
        keys   FOR ACTION StockTransfer~cancelDocument
      RESULT   result.

    " --- Determinations on modify ---
    "! Sets default header values on document creation.
    METHODS setHeaderDefaults FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR StockTransfer~setHeaderDefaults.

    "! Clears warehouses of another company when the company code changes.
    METHODS deriveHeaderOnCompanyCode FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR StockTransfer~deriveHeaderOnCompanyCode.

    "! Derives dependent header fields when the document date changes.
    METHODS deriveDatesOnDocumentDate FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR StockTransfer~deriveDatesOnDocumentDate.

    "! Keeps the issuing warehouse of all items in sync with the header.
    METHODS syncItemWarehouse FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR StockTransfer~syncItemWarehouse.

    "! Keeps the receiving warehouse of all items in sync with the header.
    METHODS syncItemReceivingWarehouse FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR StockTransfer~syncItemReceivingWarehouse.

    " --- Determinations on save ---
    "! Assigns the document number from the number range on first save.
    METHODS assignDocumentNumber FOR DETERMINE ON SAVE
      IMPORTING
        keys FOR StockTransfer~assignDocumentNumber.

    " --- Validations ---
    "! Validates company and warehouses before saving.
    METHODS validateHeaderFields FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR StockTransfer~validateHeaderFields.

    "! Validates document date and posting date consistency.
    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR StockTransfer~validateDates.

    "! A document is not saved without a number.
    METHODS validateDocumentNumber FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR StockTransfer~validateDocumentNumber.

    " --- Clearing of validation messages ---
    "! Clears validation messages for header fields that have been filled in.
    METHODS clearMessagesForHeaderFields FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR StockTransfer~clearMessagesForHeaderFields.

    "! Clears date validation messages for fields that have been fixed.
    METHODS clearMessagesForDates FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR StockTransfer~clearMessagesForDates.

ENDCLASS.

CLASS lhc_zmerp_r_stocktransfer IMPLEMENTATION.

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

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
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
                             AND zcl_merp_doc_st_lifecycle=>can_edit( header-Status ) = abap_true )
          lv_post   = xsdbool( lv_active = abap_true
                             AND zcl_merp_doc_st_lifecycle=>can_post( header-Status ) = abap_true )
          lv_unpost = xsdbool( lv_active = abap_true
                             AND zcl_merp_doc_st_lifecycle=>can_unpost( header-Status ) = abap_true )
          lv_cancel = xsdbool( lv_active = abap_true
                             AND zcl_merp_doc_st_lifecycle=>can_cancel( header-Status ) = abap_true )
          lv_delete = zcl_merp_doc_st_lifecycle=>can_delete( header-Status ) IN
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

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_usages) = NEW zcl_merp_doc_st_sel( )->zif_merp_doc_st_sel~read_usages(
      VALUE #( FOR hdr IN lt_headers ( DocumentUUID = hdr-DocumentUUID ) ) ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_hdr).
      lv_failed_added = abap_false.

      IF zcl_merp_doc_st_lifecycle=>can_delete( lr_hdr->Status ) = abap_false.
        APPEND VALUE #(
          %tky        = lr_hdr->%tky
          %fail-cause = if_abap_behv=>cause-conflict
        ) TO failed-stocktransfer.

        APPEND VALUE #(
          %tky            = lr_hdr->%tky
          %element-Status = if_abap_behv=>mk-on
          %msg            = NEW zcx_merp_stock(
                               textid   = zcx_merp_stock=>delete_not_allowed
                               attr1    = CONV #( lr_hdr->DocumentNumber )
                               severity = if_abap_behv_message=>severity-error )
        ) TO reported-stocktransfer.
        CONTINUE.
      ENDIF.

      LOOP AT lt_usages REFERENCE INTO DATA(lr_usage) WHERE DocumentUUID = lr_hdr->DocumentUUID.

        IF lv_failed_added = abap_false.
          APPEND VALUE #(
            %tky        = lr_hdr->%tky
            %fail-cause = if_abap_behv=>cause-dependency
          ) TO failed-stocktransfer.
          lv_failed_added = abap_true.
        ENDIF.

        APPEND VALUE #(
          %tky            = lr_hdr->%tky
          %element-Status = if_abap_behv=>mk-on
          %msg            = NEW zcx_merp_stock(
                               textid   = zcx_merp_stock=>stock_transfer_in_use
                               attr1    = CONV #( lr_hdr->DocumentNumber )
                               attr2    = CONV #( lr_usage->UsedInEntity )
                               severity = if_abap_behv_message=>severity-error )
        ) TO reported-stocktransfer.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  " --- Actions ---
  METHOD postDocument.
    DATA lt_update      TYPE TABLE FOR UPDATE zmerp_r_stocktransfer.
    DATA lo_message     TYPE REF TO zcx_merp_stock.
    DATA lv_items_valid TYPE abap_bool.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
        FIELDS ( Status DocumentNumber CompanyCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers)
      ENTITY StockTransfer BY \_Items
        FIELDS ( HeaderUUID ItemNo ItemCode Quantity UnitOfMeasure WarehouseCode ReceivingWarehouseCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_items).

    " Lock first, then read (as in SAP): the stock of both warehouses of each line stays locked
    " until the end of the transaction
    DATA(lt_stock_keys) = VALUE zif_merp_stock_sel=>tt_stock_keys(
      FOR item IN lt_items
      LET header = VALUE #( lt_headers[ DocumentUUID = item-HeaderUUID ] OPTIONAL ) IN
      ( CompanyCode   = header-CompanyCode
        WarehouseCode = item-WarehouseCode
        ItemCode      = item-ItemCode
        UnitOfMeasure = item-UnitOfMeasure )
      ( CompanyCode   = header-CompanyCode
        WarehouseCode = item-ReceivingWarehouseCode
        ItemCode      = item-ItemCode
        UnitOfMeasure = item-UnitOfMeasure ) ).

    DATA(lt_lock_failures) = zcl_merp_stock_control=>lock_stock( lt_stock_keys ).
    DATA(lo_stock)         = NEW zcl_merp_stock_control( lt_stock_keys ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      CLEAR lo_message.
      lv_items_valid = abap_true.

      " 1. Header checks
      IF zcl_merp_doc_st_lifecycle=>can_post( lr_header->Status ) = abap_false.
        lo_message = NEW #( textid   = zcx_merp_stock=>post_not_allowed
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( lr_header->DocumentNumber ) ).
      ELSEIF NOT line_exists( lt_items[ HeaderUUID = lr_header->DocumentUUID ] ).
        lo_message = NEW #( textid   = zcx_merp_stock=>document_empty_items_invalid
                            severity = if_abap_behv_message=>severity-error ).
      ENDIF.

      " 2. The stock of an item in one of the warehouses is being posted by another user
      IF lo_message IS NOT BOUND.
        LOOP AT lt_lock_failures REFERENCE INTO DATA(lr_lock) WHERE company_code = lr_header->CompanyCode.
          IF line_exists( lt_items[ HeaderUUID    = lr_header->DocumentUUID
                                    ItemCode      = lr_lock->item_code
                                    WarehouseCode = lr_lock->warehouse_code ] )
             OR line_exists( lt_items[ HeaderUUID             = lr_header->DocumentUUID
                                       ItemCode               = lr_lock->item_code
                                       ReceivingWarehouseCode = lr_lock->warehouse_code ] ).
            lo_message = NEW #( textid   = zcx_merp_stock=>stock_locked
                                severity = if_abap_behv_message=>severity-error
                                attr1    = CONV #( lr_lock->item_code )
                                attr2    = CONV #( lr_lock->warehouse_code )
                                attr3    = lr_lock->locked_by ).
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.

      " 3. Availability in the issuing warehouse (ST3); a covered document takes its quantities
      "    from the stock, so further documents of the request are checked against the rest
      IF lo_message IS NOT BOUND.
        DATA(lt_shortages) = lo_stock->check_availability(
          iv_company_code = lr_header->CompanyCode
          it_lines        = VALUE #( FOR item IN lt_items WHERE ( HeaderUUID = lr_header->DocumentUUID )
                                     ( item_uuid       = item-ItemUUID
                                       item_code       = item-ItemCode
                                       warehouse_code  = item-WarehouseCode
                                       quantity        = item-Quantity
                                       unit_of_measure = item-UnitOfMeasure ) ) ).

        LOOP AT lt_items REFERENCE INTO DATA(lr_item) WHERE HeaderUUID = lr_header->DocumentUUID.
          IF line_exists( lt_shortages[ table_line = lr_item->ItemUUID ] ).
            lv_items_valid = abap_false.
            APPEND VALUE #( %tky              = lr_item->%tky
                            %path             = VALUE #( StockTransfer-%is_draft    = lr_item->%is_draft
                                                         StockTransfer-DocumentUUID = lr_item->HeaderUUID )
                            %msg              = NEW zcx_merp_stock(
                                                  textid   = zcx_merp_stock=>stock_would_be_negative
                                                  severity = if_abap_behv_message=>severity-error
                                                  attr1    = CONV #( lr_item->ItemNo )
                                                  attr2    = CONV #( lr_item->ItemCode )
                                                  attr3    = CONV #( lr_item->WarehouseCode ) )
                            %element-Quantity = if_abap_behv=>mk-on ) TO reported-stocktransferitem.
          ENDIF.
        ENDLOOP.
      ENDIF.

      IF lo_message IS BOUND OR lv_items_valid = abap_false.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-stocktransfer.
        IF lo_message IS BOUND.
          APPEND VALUE #( %tky                 = lr_header->%tky
                          %msg                 = lo_message
                          %action-postDocument = if_abap_behv=>mk-on ) TO reported-stocktransfer.
        ENDIF.
      ELSE.
        APPEND VALUE #( %tky   = lr_header->%tky
                        Status = zcl_merp_doc_st_lifecycle=>c_status_posted ) TO lt_update.
      ENDIF.
    ENDLOOP.

    " 4. Stock transfers are posted (stock movements are written by the saver)
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
        ENTITY StockTransfer
        UPDATE FIELDS ( Status )
        WITH lt_update
        FAILED DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      IF lt_mod_failed IS NOT INITIAL.
        failed-stocktransfer   = CORRESPONDING #( BASE ( failed-stocktransfer ) lt_mod_failed-stocktransfer ).
        reported-stocktransfer = CORRESPONDING #( BASE ( reported-stocktransfer ) lt_mod_reported-stocktransfer ).
        RETURN.
      ENDIF.
    ENDIF.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR header IN lt_result ( %tky = header-%tky %param = header ) ).
  ENDMETHOD.

  METHOD unpostDocument.
    DATA lt_update      TYPE TABLE FOR UPDATE zmerp_r_stocktransfer.
    DATA lo_message     TYPE REF TO zcx_merp_stock.
    DATA lv_items_valid TYPE abap_bool.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
        FIELDS ( Status DocumentNumber CompanyCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers)
      ENTITY StockTransfer BY \_Items
        FIELDS ( HeaderUUID ItemNo ItemCode Quantity UnitOfMeasure WarehouseCode ReceivingWarehouseCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_items).

    " Lock first, then read: unposting takes the goods out of the receiving warehouse again
    DATA(lt_stock_keys) = VALUE zif_merp_stock_sel=>tt_stock_keys(
      FOR item IN lt_items
      LET header = VALUE #( lt_headers[ DocumentUUID = item-HeaderUUID ] OPTIONAL ) IN
      ( CompanyCode   = header-CompanyCode
        WarehouseCode = item-WarehouseCode
        ItemCode      = item-ItemCode
        UnitOfMeasure = item-UnitOfMeasure )
      ( CompanyCode   = header-CompanyCode
        WarehouseCode = item-ReceivingWarehouseCode
        ItemCode      = item-ItemCode
        UnitOfMeasure = item-UnitOfMeasure ) ).

    DATA(lt_lock_failures) = zcl_merp_stock_control=>lock_stock( lt_stock_keys ).
    DATA(lo_stock)         = NEW zcl_merp_stock_control( lt_stock_keys ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      CLEAR lo_message.
      lv_items_valid = abap_true.

      " 1. Only posted documents can be unposted
      IF zcl_merp_doc_st_lifecycle=>can_unpost( lr_header->Status ) = abap_false.
        lo_message = NEW #( textid   = zcx_merp_stock=>unpost_not_allowed
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( lr_header->DocumentNumber ) ).
      ENDIF.

      " 2. The stock of an item in one of the warehouses is being posted by another user
      IF lo_message IS NOT BOUND.
        LOOP AT lt_lock_failures REFERENCE INTO DATA(lr_lock) WHERE company_code = lr_header->CompanyCode.
          IF line_exists( lt_items[ HeaderUUID    = lr_header->DocumentUUID
                                    ItemCode      = lr_lock->item_code
                                    WarehouseCode = lr_lock->warehouse_code ] )
             OR line_exists( lt_items[ HeaderUUID             = lr_header->DocumentUUID
                                       ItemCode               = lr_lock->item_code
                                       ReceivingWarehouseCode = lr_lock->warehouse_code ] ).
            lo_message = NEW #( textid   = zcx_merp_stock=>stock_locked
                                severity = if_abap_behv_message=>severity-error
                                attr1    = CONV #( lr_lock->item_code )
                                attr2    = CONV #( lr_lock->warehouse_code )
                                attr3    = lr_lock->locked_by ).
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.

      " 3. The receiving warehouse must not become negative (as GR20)
      IF lo_message IS NOT BOUND.
        DATA(lt_shortages) = lo_stock->check_availability(
          iv_company_code = lr_header->CompanyCode
          it_lines        = VALUE #( FOR item IN lt_items WHERE ( HeaderUUID = lr_header->DocumentUUID )
                                     ( item_uuid       = item-ItemUUID
                                       item_code       = item-ItemCode
                                       warehouse_code  = item-ReceivingWarehouseCode
                                       quantity        = item-Quantity
                                       unit_of_measure = item-UnitOfMeasure ) ) ).

        LOOP AT lt_items REFERENCE INTO DATA(lr_item) WHERE HeaderUUID = lr_header->DocumentUUID.
          IF line_exists( lt_shortages[ table_line = lr_item->ItemUUID ] ).
            lv_items_valid = abap_false.
            APPEND VALUE #( %tky              = lr_item->%tky
                            %path             = VALUE #( StockTransfer-%is_draft    = lr_item->%is_draft
                                                         StockTransfer-DocumentUUID = lr_item->HeaderUUID )
                            %msg              = NEW zcx_merp_stock(
                                                  textid   = zcx_merp_stock=>stock_would_be_negative
                                                  severity = if_abap_behv_message=>severity-error
                                                  attr1    = CONV #( lr_item->ItemNo )
                                                  attr2    = CONV #( lr_item->ItemCode )
                                                  attr3    = CONV #( lr_item->ReceivingWarehouseCode ) )
                            %element-Quantity = if_abap_behv=>mk-on ) TO reported-stocktransferitem.
          ENDIF.
        ENDLOOP.
      ENDIF.

      IF lo_message IS BOUND OR lv_items_valid = abap_false.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-stocktransfer.
        IF lo_message IS BOUND.
          APPEND VALUE #( %tky                   = lr_header->%tky
                          %msg                   = lo_message
                          %action-unpostDocument = if_abap_behv=>mk-on ) TO reported-stocktransfer.
        ENDIF.
      ELSE.
        APPEND VALUE #( %tky   = lr_header->%tky
                        Status = zcl_merp_doc_st_lifecycle=>c_status_new ) TO lt_update.
      ENDIF.
    ENDLOOP.

    " 4. Stock transfers return to 'New' (stock movements are removed by the saver)
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
        ENTITY StockTransfer
        UPDATE FIELDS ( Status )
        WITH lt_update
        FAILED DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      IF lt_mod_failed IS NOT INITIAL.
        failed-stocktransfer   = CORRESPONDING #( BASE ( failed-stocktransfer ) lt_mod_failed-stocktransfer ).
        reported-stocktransfer = CORRESPONDING #( BASE ( reported-stocktransfer ) lt_mod_reported-stocktransfer ).
        RETURN.
      ENDIF.
    ENDIF.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR header IN lt_result ( %tky = header-%tky %param = header ) ).
  ENDMETHOD.

  METHOD cancelDocument.
    DATA lt_update  TYPE TABLE FOR UPDATE zmerp_r_stocktransfer.
    DATA lo_message TYPE REF TO zcx_merp_stock.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      CLEAR lo_message.

      IF zcl_merp_doc_st_lifecycle=>can_cancel( lr_header->Status ) = abap_false.
        lo_message = NEW #( textid   = zcx_merp_stock=>cancel_not_allowed
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( lr_header->DocumentNumber ) ).
      ENDIF.

      IF lo_message IS BOUND.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-stocktransfer.
        APPEND VALUE #( %tky                   = lr_header->%tky
                        %msg                   = lo_message
                        %action-cancelDocument = if_abap_behv=>mk-on ) TO reported-stocktransfer.
      ELSE.
        APPEND VALUE #( %tky   = lr_header->%tky
                        Status = zcl_merp_doc_st_lifecycle=>c_status_cancelled ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
        ENTITY StockTransfer
        UPDATE FIELDS ( Status )
        WITH lt_update
        FAILED DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      IF lt_mod_failed IS NOT INITIAL.
        failed-stocktransfer   = CORRESPONDING #( BASE ( failed-stocktransfer ) lt_mod_failed-stocktransfer ).
        reported-stocktransfer = CORRESPONDING #( BASE ( reported-stocktransfer ) lt_mod_reported-stocktransfer ).
        RETURN.
      ENDIF.
    ENDIF.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR header IN lt_result ( %tky = header-%tky %param = header ) ).
  ENDMETHOD.

  " --- Determinations on modify ---
  METHOD setHeaderDefaults.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_stocktransfer.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
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
        ls_header-Status = zcl_merp_doc_st_lifecycle=>c_status_new.
      ENDIF.

      IF ls_header <> lr_header->*.
        APPEND CORRESPONDING #( ls_header ) TO lt_header_update.
      ENDIF.
    ENDLOOP.

    IF lt_header_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
        ENTITY StockTransfer
        UPDATE FIELDS ( DocumentDate PostingDate Status )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  METHOD deriveHeaderOnCompanyCode.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_stocktransfer.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
      FIELDS ( CompanyCode WarehouseCode ReceivingWarehouseCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_warehouses) = NEW zcl_merp_md_warehouse_sel( )->zif_merp_md_warehouse_sel~read_warehouses(
      VALUE #( FOR header IN lt_headers ( WarehouseCode = header-WarehouseCode )
                                        ( WarehouseCode = header-ReceivingWarehouseCode ) ) ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      DATA(ls_header) = lr_header->*.

      IF ls_header-CompanyCode IS NOT INITIAL.
        " Warehouses of another company are cleared
        IF ls_header-WarehouseCode IS NOT INITIAL
           AND VALUE #( lt_warehouses[ WarehouseCode = ls_header-WarehouseCode ]-CompanyCode OPTIONAL )
               <> ls_header-CompanyCode.
          CLEAR ls_header-WarehouseCode.
        ENDIF.

        IF ls_header-ReceivingWarehouseCode IS NOT INITIAL
           AND VALUE #( lt_warehouses[ WarehouseCode = ls_header-ReceivingWarehouseCode ]-CompanyCode OPTIONAL )
               <> ls_header-CompanyCode.
          CLEAR ls_header-ReceivingWarehouseCode.
        ENDIF.
      ENDIF.

      IF ls_header <> lr_header->*.
        APPEND CORRESPONDING #( ls_header ) TO lt_header_update.
      ENDIF.
    ENDLOOP.

    IF lt_header_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
        ENTITY StockTransfer
        UPDATE FIELDS ( WarehouseCode ReceivingWarehouseCode )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  METHOD deriveDatesOnDocumentDate.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_stocktransfer.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
      FIELDS ( DocumentDate PostingDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      DATA(ls_header) = lr_header->*.

      IF ls_header-DocumentDate IS NOT INITIAL
         AND ls_header-PostingDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_posting_date_valid( iv_doc_date  = ls_header-DocumentDate
                                                            iv_post_date = ls_header-PostingDate ) = abap_false.
        ls_header-PostingDate = ls_header-DocumentDate.
      ENDIF.

      IF ls_header <> lr_header->*.
        APPEND CORRESPONDING #( ls_header ) TO lt_header_update.
      ENDIF.
    ENDLOOP.

    IF lt_header_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
        ENTITY StockTransfer
        UPDATE FIELDS ( PostingDate )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  METHOD syncItemWarehouse.
    DATA lt_items_to_update TYPE TABLE FOR UPDATE zmerp_r_stocktransfer\\StockTransferItem.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
        FIELDS ( WarehouseCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers)
      ENTITY StockTransfer BY \_Items
        FIELDS ( HeaderUUID WarehouseCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_items).

    IF lt_headers IS INITIAL OR lt_items IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      ASSIGN lt_headers[ DocumentUUID = lr_item->HeaderUUID
                         %is_draft    = lr_item->%is_draft ] TO FIELD-SYMBOL(<ls_header>).

      IF sy-subrc = 0 AND lr_item->WarehouseCode <> <ls_header>-WarehouseCode.
        APPEND VALUE #(
          %tky          = lr_item->%tky
          WarehouseCode = <ls_header>-WarehouseCode
        ) TO lt_items_to_update.
      ENDIF.
    ENDLOOP.

    IF lt_items_to_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
        ENTITY StockTransferItem
        UPDATE FIELDS ( WarehouseCode )
        WITH lt_items_to_update.
    ENDIF.
  ENDMETHOD.

  METHOD syncItemReceivingWarehouse.
    DATA lt_items_to_update TYPE TABLE FOR UPDATE zmerp_r_stocktransfer\\StockTransferItem.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
        FIELDS ( ReceivingWarehouseCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers)
      ENTITY StockTransfer BY \_Items
        FIELDS ( HeaderUUID ReceivingWarehouseCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_items).

    IF lt_headers IS INITIAL OR lt_items IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      ASSIGN lt_headers[ DocumentUUID = lr_item->HeaderUUID
                         %is_draft    = lr_item->%is_draft ] TO FIELD-SYMBOL(<ls_header>).

      IF sy-subrc = 0 AND lr_item->ReceivingWarehouseCode <> <ls_header>-ReceivingWarehouseCode.
        APPEND VALUE #(
          %tky                   = lr_item->%tky
          ReceivingWarehouseCode = <ls_header>-ReceivingWarehouseCode
        ) TO lt_items_to_update.
      ENDIF.
    ENDLOOP.

    IF lt_items_to_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
        ENTITY StockTransferItem
        UPDATE FIELDS ( ReceivingWarehouseCode )
        WITH lt_items_to_update.
    ENDIF.
  ENDMETHOD.

  " --- Determinations on save ---
  METHOD assignDocumentNumber.
    DATA lt_st_update TYPE TABLE FOR UPDATE zmerp_r_stocktransfer.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
      FIELDS ( DocumentNumber CompanyCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    DELETE lt_headers WHERE DocumentNumber IS NOT INITIAL OR CompanyCode IS INITIAL.

    DATA(lt_numbers) = zcl_merp_num_range_util=>get_doc_numbers(
      is_meta     = zif_merp_constants=>c_st
      it_requests = VALUE #( FOR header IN lt_headers ( HeaderUUID  = header-DocumentUUID
                                                        IsDraft     = header-%is_draft
                                                        CompanyCode = header-CompanyCode ) ) ).

    lt_st_update = VALUE #( FOR number IN lt_numbers ( %is_draft      = number-IsDraft
                                                       DocumentUUID   = number-HeaderUUID
                                                       DocumentNumber = number-DocumentNumber ) ).

    IF lt_st_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
        ENTITY StockTransfer
        UPDATE FIELDS ( DocumentNumber )
        WITH lt_st_update.
    ENDIF.
  ENDMETHOD.

  " --- Validations ---
  METHOD validateHeaderFields.
    DATA lv_has_error TYPE abap_bool.
    DATA lo_message   TYPE REF TO if_abap_behv_message.

    reported-stocktransfer = VALUE #(
      BASE reported-stocktransfer
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_company )
      ( %tky        = key-%tky
        %state_area = c_val_warehouse )
      ( %tky        = key-%tky
        %state_area = c_val_recv_warehouse )
    ).

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
      FIELDS ( CompanyCode WarehouseCode ReceivingWarehouseCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_companies) = NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_companies(
      VALUE #( FOR header IN lt_headers ( CompanyCode = header-CompanyCode ) ) ).

    DATA(lt_warehouses) = NEW zcl_merp_md_warehouse_sel( )->zif_merp_md_warehouse_sel~read_warehouses(
      VALUE #( FOR header IN lt_headers ( WarehouseCode = header-WarehouseCode )
                                        ( WarehouseCode = header-ReceivingWarehouseCode ) ) ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      lv_has_error = abap_false.

      " 1. Company: mandatory, exists
      lo_message = COND #(
        WHEN lr_header->CompanyCode IS INITIAL
          THEN NEW zcx_merp_stock( textid   = zcx_merp_stock=>select_company
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
                        %element-CompanyCode = if_abap_behv=>mk-on ) TO reported-stocktransfer.
      ENDIF.

      " 2. Issuing warehouse: mandatory, exists, belongs to the company
      lo_message = COND #(
        WHEN lr_header->WarehouseCode IS INITIAL
          THEN NEW zcx_merp_stock( textid   = zcx_merp_stock=>select_warehouse
                                   severity = if_abap_behv_message=>severity-error )
        WHEN NOT line_exists( lt_warehouses[ WarehouseCode = lr_header->WarehouseCode ] )
          THEN NEW zcx_merp_md( textid   = zcx_merp_md=>warehouse_not_found
                                attr1    = CONV string( lr_header->WarehouseCode )
                                severity = if_abap_behv_message=>severity-error )
        WHEN lr_header->CompanyCode IS NOT INITIAL
         AND lt_warehouses[ WarehouseCode = lr_header->WarehouseCode ]-CompanyCode <> lr_header->CompanyCode
          THEN NEW zcx_merp_stock( textid   = zcx_merp_stock=>warehouse_company_mismatch
                                   attr1    = CONV string( lr_header->WarehouseCode )
                                   attr2    = CONV string( lr_header->CompanyCode )
                                   severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                   = lr_header->%tky
                        %state_area            = c_val_warehouse
                        %msg                   = lo_message
                        %element-WarehouseCode = if_abap_behv=>mk-on ) TO reported-stocktransfer.
      ENDIF.

      " 3. Receiving warehouse: mandatory, exists, belongs to the company, differs from the issuing warehouse
      lo_message = COND #(
        WHEN lr_header->ReceivingWarehouseCode IS INITIAL
          THEN NEW zcx_merp_stock( textid   = zcx_merp_stock=>select_receiving_warehouse
                                   severity = if_abap_behv_message=>severity-error )
        WHEN NOT line_exists( lt_warehouses[ WarehouseCode = lr_header->ReceivingWarehouseCode ] )
          THEN NEW zcx_merp_md( textid   = zcx_merp_md=>warehouse_not_found
                                attr1    = CONV string( lr_header->ReceivingWarehouseCode )
                                severity = if_abap_behv_message=>severity-error )
        WHEN lr_header->CompanyCode IS NOT INITIAL
         AND lt_warehouses[ WarehouseCode = lr_header->ReceivingWarehouseCode ]-CompanyCode <> lr_header->CompanyCode
          THEN NEW zcx_merp_stock( textid   = zcx_merp_stock=>warehouse_company_mismatch
                                   attr1    = CONV string( lr_header->ReceivingWarehouseCode )
                                   attr2    = CONV string( lr_header->CompanyCode )
                                   severity = if_abap_behv_message=>severity-error )
        WHEN lr_header->ReceivingWarehouseCode = lr_header->WarehouseCode
          THEN NEW zcx_merp_stock( textid   = zcx_merp_stock=>receiving_warehouse_same
                                   severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                            = lr_header->%tky
                        %state_area                     = c_val_recv_warehouse
                        %msg                            = lo_message
                        %element-ReceivingWarehouseCode = if_abap_behv=>mk-on ) TO reported-stocktransfer.
      ENDIF.

      IF lv_has_error = abap_true.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-stocktransfer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDates.
    DATA lv_has_error TYPE abap_bool.
    DATA lo_message   TYPE REF TO if_abap_behv_message.

    reported-stocktransfer = VALUE #(
      BASE reported-stocktransfer
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_doc_date )
      ( %tky        = key-%tky
        %state_area = c_val_post_date )
    ).

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
      FIELDS ( DocumentDate PostingDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      lv_has_error = abap_false.

      " 1. Document date: mandatory, not in the future
      lo_message = COND #(
        WHEN lr_header->DocumentDate IS INITIAL
          THEN NEW zcx_merp_stock( textid   = zcx_merp_stock=>enter_document_date
                                   severity = if_abap_behv_message=>severity-error )
        WHEN zcl_merp_doc_validator=>is_document_date_valid( iv_doc_date = lr_header->DocumentDate
                                                             iv_today    = lv_today ) = abap_false
          THEN NEW zcx_merp_stock( textid   = zcx_merp_stock=>document_date_future_invalid
                                   severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                  = lr_header->%tky
                        %state_area           = c_val_doc_date
                        %msg                  = lo_message
                        %element-DocumentDate = if_abap_behv=>mk-on ) TO reported-stocktransfer.
      ENDIF.

      " 2. Posting date: mandatory, not in the future, not before the document date
      lo_message = COND #(
        WHEN lr_header->PostingDate IS INITIAL
          THEN NEW zcx_merp_stock( textid   = zcx_merp_stock=>enter_posting_date
                                   severity = if_abap_behv_message=>severity-error )
        WHEN zcl_merp_doc_validator=>is_posting_date_not_future( iv_post_date = lr_header->PostingDate
                                                                 iv_today     = lv_today ) = abap_false
          THEN NEW zcx_merp_stock( textid   = zcx_merp_stock=>posting_date_future_invalid
                                   severity = if_abap_behv_message=>severity-error )
        WHEN lr_header->DocumentDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_posting_date_valid( iv_doc_date  = lr_header->DocumentDate
                                                            iv_post_date = lr_header->PostingDate ) = abap_false
          THEN NEW zcx_merp_stock( textid   = zcx_merp_stock=>posting_date_sequence_invalid
                                   severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                 = lr_header->%tky
                        %state_area          = c_val_post_date
                        %msg                 = lo_message
                        %element-PostingDate = if_abap_behv=>mk-on ) TO reported-stocktransfer.
      ENDIF.

      IF lv_has_error = abap_true.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-stocktransfer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDocumentNumber.
    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
      FIELDS ( DocumentNumber CompanyCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header)
         WHERE DocumentNumber IS INITIAL
           AND CompanyCode    IS NOT INITIAL.
      APPEND VALUE #(
        %tky        = lr_header->%tky
        %fail-cause = if_abap_behv=>cause-unspecific
      ) TO failed-stocktransfer.

      APPEND VALUE #(
        %tky                    = lr_header->%tky
        %msg                    = NEW zcx_merp_stock(
                                    textid   = zcx_merp_stock=>doc_number_generation_failed
                                    severity = if_abap_behv_message=>severity-error )
        %element-DocumentNumber = if_abap_behv=>mk-on
      ) TO reported-stocktransfer.
    ENDLOOP.
  ENDMETHOD.

  " --- Clearing of validation messages ---
  METHOD clearMessagesForHeaderFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
      FIELDS ( CompanyCode WarehouseCode ReceivingWarehouseCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      IF lr_header->CompanyCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_company ) TO reported-stocktransfer.
      ENDIF.
      IF lr_header->WarehouseCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_warehouse ) TO reported-stocktransfer.
      ENDIF.
      IF lr_header->ReceivingWarehouseCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_recv_warehouse ) TO reported-stocktransfer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD clearMessagesForDates.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
      FIELDS ( DocumentDate PostingDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      IF lr_header->DocumentDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_document_date_valid( iv_doc_date = lr_header->DocumentDate
                                                             iv_today    = lv_today ) = abap_true.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_doc_date ) TO reported-stocktransfer.
      ENDIF.

      IF lr_header->PostingDate IS NOT INITIAL AND lr_header->DocumentDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_posting_date_not_future( iv_post_date = lr_header->PostingDate
                                                                 iv_today     = lv_today ) = abap_true
         AND zcl_merp_doc_validator=>is_posting_date_valid( iv_doc_date  = lr_header->DocumentDate
                                                            iv_post_date = lr_header->PostingDate ) = abap_true.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_post_date ) TO reported-stocktransfer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

"! Local behavior handler for Stock Transfer Item child entity.
CLASS lhc_zmerp_r_stocktransferitm DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_val_item_code TYPE string VALUE 'VALIDATE_ITEM_CODE',
      c_val_quantity  TYPE string VALUE 'VALIDATE_QUANTITY',
      c_val_uom       TYPE string VALUE 'VALIDATE_UOM'.

    TYPES: BEGIN OF ty_header_key,
             document_uuid TYPE sysuuid_x16,
             is_draft      TYPE abp_behv_flag,
           END OF ty_header_key.

    " Parents of the items being deleted: filled in precheck_delete, consumed by handleMessagesOnItemModify
    CLASS-DATA gt_deleted_headers TYPE STANDARD TABLE OF ty_header_key WITH EMPTY KEY.

    " --- Access and state ---
    "! Remembers the documents of the items being deleted (deleted items can no longer be read).
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE StockTransferItem.

    " --- Determinations on modify ---
    "! Sets item defaults: item number and UoM from the item, both warehouses from the header.
    METHODS setItemDefaults FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR StockTransferItem~setItemDefaults.

    " --- Validations ---
    "! Validates item fields: item exists, is kept in stock and is not entered twice, positive quantity, UoM.
    METHODS validateItemFields FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR StockTransferItem~validateItemFields.

    " --- Clearing of validation messages ---
    "! Clears validation messages of quantity and unit of measure once the values are valid/filled.
    METHODS clearMessagesForItemFields FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR StockTransferItem~clearMessagesForItemFields.

    "! Re-evaluates duplicate item code messages for ALL items of the document when an item code
    "! changes or an item is deleted.
    METHODS handleMessagesOnItemModify FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR StockTransferItem~handleMessagesOnItemModify.

ENDCLASS.

CLASS lhc_zmerp_r_stocktransferitm IMPLEMENTATION.

  " --- Access and state ---
  METHOD precheck_delete.
    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransferItem
      FIELDS ( HeaderUUID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    gt_deleted_headers = VALUE #( BASE gt_deleted_headers
      FOR item IN lt_items ( document_uuid = item-HeaderUUID
                             is_draft      = item-%is_draft ) ).
  ENDMETHOD.

  " --- Determinations on modify ---
  METHOD setItemDefaults.
    DATA lt_update      TYPE TABLE FOR UPDATE zmerp_r_stocktransfer\\StockTransferItem.
    DATA lt_recv_update TYPE TABLE FOR UPDATE zmerp_r_stocktransfer\\StockTransferItem.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransferItem
        FIELDS ( HeaderUUID ItemNo ItemCode UnitOfMeasure WarehouseCode ReceivingWarehouseCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_items)
      ENTITY StockTransferItem BY \_StockTransfer
        FIELDS ( WarehouseCode ReceivingWarehouseCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer BY \_Items
      FIELDS ( HeaderUUID ItemNo )
      WITH CORRESPONDING #( lt_headers )
      RESULT DATA(lt_siblings).

    " Item number, UoM and issuing warehouse via the shared item logic (VAT and currency are not used here)
    DATA(lt_changed) = NEW zcl_merp_doc_item_logic( )->set_defaults(
      it_items           = CORRESPONDING #( lt_items MAPPING IsDraft = %is_draft )
      it_siblings        = CORRESPONDING #( lt_siblings MAPPING IsDraft = %is_draft )
      it_header_defaults = CORRESPONDING #( lt_headers MAPPING HeaderUUID = DocumentUUID
                                                               IsDraft    = %is_draft ) ).

    LOOP AT lt_changed REFERENCE INTO DATA(lr_changed).
      ASSIGN lt_items[ ItemUUID  = lr_changed->ItemUUID
                       %is_draft = lr_changed->IsDraft ] TO FIELD-SYMBOL(<ls_item>).

      IF sy-subrc = 0.
        APPEND VALUE #(
          %tky          = <ls_item>-%tky
          ItemNo        = lr_changed->ItemNo
          UnitOfMeasure = lr_changed->UnitOfMeasure
          WarehouseCode = lr_changed->WarehouseCode
        ) TO lt_update.
      ENDIF.
    ENDLOOP.

    " Receiving warehouse from the header (only if not yet set, as the issuing warehouse)
    LOOP AT lt_items REFERENCE INTO DATA(lr_item) WHERE ReceivingWarehouseCode IS INITIAL.
      ASSIGN lt_headers[ DocumentUUID = lr_item->HeaderUUID
                         %is_draft    = lr_item->%is_draft ] TO FIELD-SYMBOL(<ls_header>).

      IF sy-subrc = 0 AND <ls_header>-ReceivingWarehouseCode IS NOT INITIAL.
        APPEND VALUE #(
          %tky                   = lr_item->%tky
          ReceivingWarehouseCode = <ls_header>-ReceivingWarehouseCode
        ) TO lt_recv_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
        ENTITY StockTransferItem
        UPDATE FIELDS ( ItemNo UnitOfMeasure WarehouseCode )
        WITH lt_update.
    ENDIF.

    IF lt_recv_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
        ENTITY StockTransferItem
        UPDATE FIELDS ( ReceivingWarehouseCode )
        WITH lt_recv_update.
    ENDIF.
  ENDMETHOD.

  " --- Validations ---
  METHOD validateItemFields.
    DATA lv_has_error TYPE abap_bool.
    DATA lo_message   TYPE REF TO if_abap_behv_message.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransferItem
      FIELDS ( HeaderUUID ItemCode Quantity UnitOfMeasure )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_state_areas) = VALUE string_table(
      ( c_val_item_code )
      ( c_val_quantity )
      ( c_val_uom ) ).

    reported-stocktransferitem = VALUE #(
      BASE reported-stocktransferitem
      FOR item IN lt_items
      FOR area IN lt_state_areas
      ( %tky        = item-%tky
        %path       = VALUE #( StockTransfer-%is_draft    = item-%is_draft
                               StockTransfer-DocumentUUID = item-HeaderUUID )
        %state_area = area )
    ).

    DATA lt_header_keys TYPE TABLE FOR READ IMPORT zmerp_r_stocktransfer.
    lt_header_keys = VALUE #(
      FOR GROUPS of <g> IN lt_items GROUP BY ( HeaderUUID = <g>-HeaderUUID
                                               is_draft   = <g>-%is_draft )
      ( %tky-DocumentUUID = <g>-HeaderUUID
        %is_draft         = <g>-%is_draft )
    ).

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer BY \_Items
      FIELDS ( HeaderUUID ItemCode )
      WITH CORRESPONDING #( lt_header_keys )
      RESULT DATA(lt_all_document_items).

    DATA(lt_duplicates) = zcl_merp_doc_validator=>get_duplicate_item_codes(
      VALUE #( FOR doc_item IN lt_all_document_items
               ( HeaderUUID = doc_item-HeaderUUID
                 ItemCode   = doc_item-ItemCode ) )
    ).

    DATA(lo_item_selector) = NEW zcl_merp_md_item_sel( ).
    DATA(lt_item_keys)     = VALUE zif_merp_md_item_sel=>tt_item_keys(
                               FOR item IN lt_items ( ItemCode = item-ItemCode ) ).
    DATA(lt_items_master)  = lo_item_selector->zif_merp_md_item_sel~read_items( lt_item_keys ).
    DATA(lt_stock_items)   = lo_item_selector->zif_merp_md_item_sel~read_stock_items( lt_item_keys ).

    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      lv_has_error = abap_false.

      " 1. Item: mandatory, exists, kept in stock (ST5), not twice in the document
      lo_message = COND #(
        WHEN lr_item->ItemCode IS INITIAL
          THEN NEW zcx_merp_stock( textid   = zcx_merp_stock=>select_item
                                   severity = if_abap_behv_message=>severity-error )
        WHEN NOT line_exists( lt_items_master[ ItemCode = lr_item->ItemCode ] )
          THEN NEW zcx_merp_md( textid   = zcx_merp_md=>item_not_found
                                attr1    = CONV string( lr_item->ItemCode )
                                severity = if_abap_behv_message=>severity-error )
        WHEN NOT line_exists( lt_stock_items[ table_line = lr_item->ItemCode ] )
          THEN NEW zcx_merp_stock( textid   = zcx_merp_stock=>item_not_stock_relevant
                                   attr1    = CONV string( lr_item->ItemCode )
                                   severity = if_abap_behv_message=>severity-error )
        WHEN line_exists( lt_duplicates[ HeaderUUID = lr_item->HeaderUUID
                                         ItemCode   = lr_item->ItemCode ] )
          THEN NEW zcx_merp_stock( textid   = zcx_merp_stock=>item_duplicate_invalid
                                   attr1    = CONV string( lr_item->ItemCode )
                                   severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky              = lr_item->%tky
                        %path             = VALUE #( StockTransfer-%is_draft    = lr_item->%is_draft
                                                     StockTransfer-DocumentUUID = lr_item->HeaderUUID )
                        %state_area       = c_val_item_code
                        %msg              = lo_message
                        %element-ItemCode = if_abap_behv=>mk-on ) TO reported-stocktransferitem.
      ENDIF.

      " 2. Quantity: greater than zero
      lo_message = COND #(
        WHEN zcl_merp_doc_validator=>is_item_quantity_valid( lr_item->Quantity ) = abap_false
          THEN NEW zcx_merp_stock( textid   = zcx_merp_stock=>quantity_must_be_positive
                                   severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky              = lr_item->%tky
                        %path             = VALUE #( StockTransfer-%is_draft    = lr_item->%is_draft
                                                     StockTransfer-DocumentUUID = lr_item->HeaderUUID )
                        %state_area       = c_val_quantity
                        %msg              = lo_message
                        %element-Quantity = if_abap_behv=>mk-on ) TO reported-stocktransferitem.
      ENDIF.

      " 3. Unit of measure: mandatory
      lo_message = COND #(
        WHEN lr_item->UnitOfMeasure IS INITIAL
          THEN NEW zcx_merp_stock( textid   = zcx_merp_stock=>select_unit_of_measure
                                   severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                   = lr_item->%tky
                        %path                  = VALUE #( StockTransfer-%is_draft    = lr_item->%is_draft
                                                          StockTransfer-DocumentUUID = lr_item->HeaderUUID )
                        %state_area            = c_val_uom
                        %msg                   = lo_message
                        %element-UnitOfMeasure = if_abap_behv=>mk-on ) TO reported-stocktransferitem.
      ENDIF.

      IF lv_has_error = abap_true.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-stocktransferitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " --- Clearing of validation messages ---
  METHOD clearMessagesForItemFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransferItem
      FIELDS ( HeaderUUID Quantity UnitOfMeasure )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      IF zcl_merp_doc_validator=>is_item_quantity_valid( lr_item->Quantity ) = abap_true.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %path       = VALUE #( StockTransfer-%is_draft    = lr_item->%is_draft
                                               StockTransfer-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_quantity ) TO reported-stocktransferitem.
      ENDIF.

      IF lr_item->UnitOfMeasure IS NOT INITIAL.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %path       = VALUE #( StockTransfer-%is_draft    = lr_item->%is_draft
                                               StockTransfer-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_uom ) TO reported-stocktransferitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD handleMessagesOnItemModify.
    DATA lt_header_keys TYPE TABLE FOR READ IMPORT zmerp_r_stocktransfer.

    " Documents of the changed items; deleted items cannot be read, their documents come from precheck_delete
    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransferItem
      FIELDS ( HeaderUUID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    lt_header_keys = VALUE #(
      FOR item IN lt_items ( %tky-DocumentUUID = item-HeaderUUID
                             %is_draft         = item-%is_draft ) ).

    lt_header_keys = VALUE #( BASE lt_header_keys
      FOR deleted IN gt_deleted_headers ( %tky-DocumentUUID = deleted-document_uuid
                                          %is_draft         = deleted-is_draft ) ).
    CLEAR gt_deleted_headers.

    SORT lt_header_keys BY DocumentUUID %is_draft.
    DELETE ADJACENT DUPLICATES FROM lt_header_keys COMPARING DocumentUUID %is_draft.

    IF lt_header_keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer BY \_Items
      FIELDS ( HeaderUUID ItemCode )
      WITH CORRESPONDING #( lt_header_keys )
      RESULT DATA(lt_all_document_items).

    reported-stocktransferitem = VALUE #(
      BASE reported-stocktransferitem
      FOR ls_all_item IN lt_all_document_items
      ( %tky        = ls_all_item-%tky
        %path       = VALUE #( StockTransfer-%is_draft    = ls_all_item-%is_draft
                               StockTransfer-DocumentUUID = ls_all_item-HeaderUUID )
        %state_area = c_val_item_code )
    ).

    DATA(lt_duplicates) = zcl_merp_doc_validator=>get_duplicate_item_codes(
      VALUE #( FOR doc_item IN lt_all_document_items
               ( HeaderUUID = doc_item-HeaderUUID
                 ItemCode   = doc_item-ItemCode ) )
    ).

    IF lt_duplicates IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_all_document_items REFERENCE INTO DATA(lr_doc_item) WHERE ItemCode IS NOT INITIAL.
      IF line_exists( lt_duplicates[ HeaderUUID = lr_doc_item->HeaderUUID
                                     ItemCode   = lr_doc_item->ItemCode ] ).
        APPEND VALUE #(
          %tky              = lr_doc_item->%tky
          %path             = VALUE #( StockTransfer-%is_draft    = lr_doc_item->%is_draft
                                       StockTransfer-DocumentUUID = lr_doc_item->HeaderUUID )
          %state_area       = c_val_item_code
          %msg              = NEW zcx_merp_stock(
                                textid   = zcx_merp_stock=>item_duplicate_invalid
                                attr1    = CONV string( lr_doc_item->ItemCode )
                                severity = if_abap_behv_message=>severity-error )
          %element-ItemCode = if_abap_behv=>mk-on
        ) TO reported-stocktransferitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

"! Saver for Stock Transfer: writes the stock movements (issue in the issuing warehouse and receipt
"! in the receiving warehouse at the same value) when a document is posted and removes them when it
"! leaves the posted status.
CLASS lsc_zmerp_r_stocktransfer DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    CONSTANTS c_document_type TYPE zmerp_doc_type VALUE 'ST'.

    METHODS save_modified REDEFINITION.
ENDCLASS.

CLASS lsc_zmerp_r_stocktransfer IMPLEMENTATION.

  METHOD save_modified.
    DATA lt_changed   TYPE zcl_merp_stock_posting=>tt_document_keys.
    DATA lt_posted    TYPE TABLE FOR READ IMPORT zmerp_r_stocktransfer.
    DATA lt_movements TYPE zcl_merp_stock_posting=>tt_movements.

    LOOP AT update-stocktransfer REFERENCE INTO DATA(lr_header)
         WHERE %control-Status = if_abap_behv=>mk-on.

      " Any status change first removes the movements of the document ...
      APPEND VALUE #( document_uuid = lr_header->DocumentUUID ) TO lt_changed.

      " ... and posted documents get new movements
      IF zcl_merp_doc_st_lifecycle=>is_posted( lr_header->Status ) = abap_true.
        APPEND VALUE #( %key = lr_header->%key ) TO lt_posted.
      ENDIF.
    ENDLOOP.

    zcl_merp_stock_posting=>delete_document_movements( lt_changed ).

    IF lt_posted IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_stocktransfer IN LOCAL MODE
      ENTITY StockTransfer
        FIELDS ( CompanyCode PostingDate )
        WITH lt_posted
        RESULT DATA(lt_headers)
      ENTITY StockTransfer BY \_Items
        FIELDS ( HeaderUUID ItemCode Quantity UnitOfMeasure WarehouseCode ReceivingWarehouseCode )
        WITH CORRESPONDING #( lt_posted )
        RESULT DATA(lt_items).

    " Stock is kept in the company currency
    DATA(lt_companies) = NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_companies(
      VALUE #( FOR header IN lt_headers ( CompanyCode = header-CompanyCode ) ) ).

    " One issue per line with the receiving warehouse: the stock posting values it at moving average
    " cost of the issuing warehouse and adds the receipt in the receiving warehouse (ST2)
    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      ASSIGN lt_headers[ DocumentUUID = lr_item->HeaderUUID ] TO FIELD-SYMBOL(<ls_header>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        document_uuid            = lr_item->HeaderUUID
        document_item_uuid       = lr_item->ItemUUID
        company_code             = <ls_header>-CompanyCode
        warehouse_code           = lr_item->WarehouseCode
        receiving_warehouse_code = lr_item->ReceivingWarehouseCode
        item_code                = lr_item->ItemCode
        quantity                 = - lr_item->Quantity
        unit_of_measure          = lr_item->UnitOfMeasure
        currency_code            = VALUE #( lt_companies[ CompanyCode = <ls_header>-CompanyCode ]-CurrencyCode OPTIONAL )
        posting_date             = <ls_header>-PostingDate
      ) TO lt_movements.
    ENDLOOP.

    zcl_merp_stock_posting=>insert_movements( iv_document_type = c_document_type
                                              it_movements     = lt_movements ).
  ENDMETHOD.

ENDCLASS.
