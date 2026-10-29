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
      c_val_deliv_date     TYPE string VALUE 'VALIDATE_DELIV_DATE',

      " Purchase order lifecycle statuses
      c_status_new         TYPE zmerp_po_status VALUE 'N',
      c_status_approved    TYPE zmerp_po_status VALUE 'A',
      c_status_in_delivery TYPE zmerp_po_status VALUE 'P',
      c_status_completed   TYPE zmerp_po_status VALUE 'C',
      c_status_cancelled   TYPE zmerp_po_status VALUE 'X'.

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

    "! Releases the Purchase Order.
    METHODS releaseDocument FOR MODIFY
      IMPORTING
        keys   FOR ACTION PurchaseOrder~releaseDocument
      RESULT   result.

    "! Cancels the Purchase Order.
    METHODS cancelDocument FOR MODIFY
      IMPORTING
        keys   FOR ACTION PurchaseOrder~cancelDocument
      RESULT   result.

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

    "! Assigns the document number from the number range on first save.
    METHODS assignDocumentNumber FOR DETERMINE ON SAVE
      IMPORTING
        keys FOR PurchaseOrder~assignDocumentNumber.

    "! Validates document date and delivery date consistency.
    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR PurchaseOrder~validateDates.

    "! Validates mandatory header fields before saving.
    METHODS validateHeaderFields FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR PurchaseOrder~validateHeaderFields.

    "! Clears date validation messages for fields that have been fixed.
    METHODS clearMessagesForDates FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrder~clearMessagesForDates.

    "! Clears validation messages for organizational header fields that have been filled in.
    METHODS clearMessagesForHeaderFields FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrder~clearMessagesForHeaderFields.

ENDCLASS.

CLASS lhc_zmerp_r_purchaseorder IMPLEMENTATION.

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
      FIELDS ( Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " Only saved (active) documents can be edited or processed; draft instances get no actions
    result = VALUE #(
      FOR header IN lt_headers
      LET lv_active = xsdbool( header-%is_draft = if_abap_behv=>mk-off )
          lv_new    = xsdbool( header-Status = c_status_new )
          lv_open   = xsdbool( header-Status = c_status_new OR header-Status = c_status_approved ) IN
      ( %tky                    = header-%tky
        %action-Edit            = COND #( WHEN lv_active = abap_true AND lv_new = abap_true
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
        %action-releaseDocument = COND #( WHEN lv_active = abap_true AND lv_new = abap_true
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
        %action-cancelDocument  = COND #( WHEN lv_active = abap_true AND lv_open = abap_true
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled ) )
    ).
  ENDMETHOD.

  METHOD validateHeaderFields.
    DATA lv_has_error TYPE abap_bool.

    " Clear previous validation messages for this state area to prevent duplicate errors in UI
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

    " Read entity fields in local mode to bypass global authorization checks during validation
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( CompanyCode BusinessPartnerCode WarehouseCode CurrencyCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " Bulk collect keys for cross-entity master data validation to eliminate DB roundtrips
    DATA(lt_company_keys) = VALUE zif_merp_md_comp_code_sel=>tt_company_keys(
      FOR header IN lt_headers WHERE ( CompanyCode IS NOT INITIAL )
      ( CompanyCode = header-CompanyCode )
    ).
    DATA(lt_bp_keys) = VALUE zif_merp_md_bus_partner_sel=>tt_partner_keys(
      FOR header IN lt_headers WHERE ( BusinessPartnerCode IS NOT INITIAL )
      ( PartnerCode = header-BusinessPartnerCode )
    ).
    DATA(lt_warehouse_keys) = VALUE zif_merp_md_warehouse_sel=>tt_warehouse_keys(
      FOR header IN lt_headers WHERE ( WarehouseCode IS NOT INITIAL )
      ( WarehouseCode = header-WarehouseCode )
    ).

    " Execute optimized bulk selection via Master Data Selector interface regardless of user restrictions
    DATA(lt_companies) = COND #(
      WHEN lt_company_keys IS NOT INITIAL
      THEN NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_companies( lt_company_keys ) ).

    DATA(lt_partners) = COND #(
      WHEN lt_bp_keys IS NOT INITIAL
      THEN NEW zcl_merp_md_bus_partner_sel( )->zif_merp_md_bus_partner_sel~read_partners( lt_bp_keys ) ).

    DATA(lt_warehouses) = COND #(
      WHEN lt_warehouse_keys IS NOT INITIAL
      THEN NEW zcl_merp_md_warehouse_sel( )->zif_merp_md_warehouse_sel~read_warehouses( lt_warehouse_keys ) ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      lv_has_error = abap_false.

      " 1. Company Code Mandatory & Existence Validation
      IF lr_header->CompanyCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_header->%tky
          %state_area          = c_val_company
          %msg                 = NEW zcx_merp_pur(
                                   textid   = zcx_merp_pur=>select_company
                                   severity = if_abap_behv_message=>severity-error )
          %element-CompanyCode = if_abap_behv=>mk-on
        ) TO reported-purchaseorder.
      ELSEIF NOT line_exists( lt_companies[ CompanyCode = lr_header->CompanyCode ] ).
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_header->%tky
          %state_area          = c_val_company
          %msg                 = NEW zcx_merp_md(
                                   textid   = zcx_merp_md=>company_code_not_found
                                   attr1    = CONV string( lr_header->CompanyCode )
                                   severity = if_abap_behv_message=>severity-error )
          %element-CompanyCode = if_abap_behv=>mk-on
        ) TO reported-purchaseorder.
      ENDIF.

      " 2. Business Partner / Supplier Mandatory & Existence Validation
      IF lr_header->BusinessPartnerCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                         = lr_header->%tky
          %state_area                  = c_val_partner
          %msg                         = NEW zcx_merp_pur(
                                           textid   = zcx_merp_pur=>select_business_partner
                                           severity = if_abap_behv_message=>severity-error )
          %element-BusinessPartnerCode = if_abap_behv=>mk-on
        ) TO reported-purchaseorder.
      ELSEIF NOT line_exists( lt_partners[ PartnerCode = lr_header->BusinessPartnerCode ] ).
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                         = lr_header->%tky
          %state_area                  = c_val_partner
          %msg                 = NEW zcx_merp_md(
                                   textid   = zcx_merp_md=>business_partner_not_found
                                   attr1    = CONV string( lr_header->BusinessPartnerCode )
                                   severity = if_abap_behv_message=>severity-error )
          %element-BusinessPartnerCode = if_abap_behv=>mk-on
        ) TO reported-purchaseorder.
            ELSEIF zcl_merp_doc_validator=>is_pur_partner_supplier(
               lt_partners[ PartnerCode = lr_header->BusinessPartnerCode ]-IsSupplier ) = abap_false.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                         = lr_header->%tky
          %state_area                  = c_val_partner
          %msg                         = NEW zcx_merp_pur(
                                           textid   = zcx_merp_pur=>bp_is_not_supplier
                                           attr1    = CONV string( lr_header->BusinessPartnerCode )
                                           severity = if_abap_behv_message=>severity-error )
          %element-BusinessPartnerCode = if_abap_behv=>mk-on
        ) TO reported-purchaseorder.
      ENDIF.

      " 3. Warehouse Mandatory, Existence & Cross-check Validation
      IF lr_header->WarehouseCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                   = lr_header->%tky
          %state_area            = c_val_warehouse
          %msg                   = NEW zcx_merp_pur(
                                     textid   = zcx_merp_pur=>select_warehouse
                                     severity = if_abap_behv_message=>severity-error )
          %element-WarehouseCode = if_abap_behv=>mk-on
        ) TO reported-purchaseorder.
      ELSEIF NOT line_exists( lt_warehouses[ WarehouseCode = lr_header->WarehouseCode ] ).
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                   = lr_header->%tky
          %state_area            = c_val_warehouse
          %msg                 = NEW zcx_merp_md(
                                   textid   = zcx_merp_md=>warehouse_not_found
                                   attr1    = CONV string( lr_header->WarehouseCode )
                                   severity = if_abap_behv_message=>severity-error )
          %element-WarehouseCode = if_abap_behv=>mk-on
        ) TO reported-purchaseorder.
      ELSEIF lr_header->CompanyCode IS NOT INITIAL AND lt_warehouses[ WarehouseCode = lr_header->WarehouseCode ]-CompanyCode <> lr_header->CompanyCode.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                   = lr_header->%tky
          %state_area            = c_val_warehouse
          %msg                   = NEW zcx_merp_pur(
                                     textid   = zcx_merp_pur=>warehouse_company_mismatch
                                     severity = if_abap_behv_message=>severity-error )
          %element-WarehouseCode = if_abap_behv=>mk-on
        ) TO reported-purchaseorder.
      ENDIF.

      " 4. Currency Code Mandatory Validation
      IF lr_header->CurrencyCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                  = lr_header->%tky
          %state_area           = c_val_currency
          %msg                  = NEW zcx_merp_pur(
                                    textid   = zcx_merp_pur=>select_currency
                                    severity = if_abap_behv_message=>severity-error )
          %element-CurrencyCode = if_abap_behv=>mk-on
        ) TO reported-purchaseorder.
      ENDIF.

      " If any validation failed, prevent transaction commit
      IF lv_has_error = abap_true.
        APPEND VALUE #(
          %tky        = lr_header->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-purchaseorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDates.
    DATA lv_has_error TYPE abap_bool.

    " Clear previous validation messages for individual date fields
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

    " Read date fields and status in local mode
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( DocumentDate PostingDate DeliveryDate Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      lv_has_error = abap_false.

      " 1. Document Date Validations
      IF lr_header->DocumentDate IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                  = lr_header->%tky
          %state_area           = c_val_doc_date
          %msg                  = NEW zcx_merp_pur(
                                    textid   = zcx_merp_pur=>enter_document_date
                                    severity = if_abap_behv_message=>severity-error )
          %element-DocumentDate = if_abap_behv=>mk-on
        ) TO reported-purchaseorder.
      ELSEIF zcl_merp_doc_validator=>is_document_date_valid( iv_doc_date = lr_header->DocumentDate
                                                             iv_today    = lv_today ) = abap_false.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                  = lr_header->%tky
          %state_area           = c_val_doc_date
          %msg                  = NEW zcx_merp_pur(
                                    textid   = zcx_merp_pur=>document_date_future_invalid
                                    severity = if_abap_behv_message=>severity-error )
          %element-DocumentDate = if_abap_behv=>mk-on
        ) TO reported-purchaseorder.
      ENDIF.

      " 2. Posting Date Validations
      IF lr_header->PostingDate IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_header->%tky
          %state_area          = c_val_post_date
          %msg                 = NEW zcx_merp_pur(
                                   textid   = zcx_merp_pur=>enter_posting_date
                                   severity = if_abap_behv_message=>severity-error )
          %element-PostingDate = if_abap_behv=>mk-on
        ) TO reported-purchaseorder.
      ELSEIF lr_header->DocumentDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_posting_date_valid( iv_doc_date  = lr_header->DocumentDate
                                                            iv_post_date = lr_header->PostingDate ) = abap_false.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_header->%tky
          %state_area          = c_val_post_date
          %msg                 = NEW zcx_merp_pur(
                                   textid   = zcx_merp_pur=>posting_date_sequence_invalid
                                   severity = if_abap_behv_message=>severity-error )
          %element-PostingDate = if_abap_behv=>mk-on
        ) TO reported-purchaseorder.
      ENDIF.

      " 3. Delivery Date Validations
      IF lr_header->DeliveryDate IS NOT INITIAL.
        " Past delivery date check holds only for active validation during New status creation phase
        IF lr_header->Status = c_status_new AND lr_header->DeliveryDate < lv_today.
          lv_has_error = abap_true.
          APPEND VALUE #(
            %tky                  = lr_header->%tky
            %state_area           = c_val_deliv_date
            %msg                  = NEW zcx_merp_pur(
                                      textid   = zcx_merp_pur=>delivery_date_past_invalid
                                      severity = if_abap_behv_message=>severity-error )
            %element-DeliveryDate = if_abap_behv=>mk-on
          ) TO reported-purchaseorder.
        ENDIF.

        " Validate chronology between core document date and logistical delivery date
        IF lr_header->DocumentDate IS NOT INITIAL
           AND zcl_merp_doc_validator=>is_delivery_date_valid( iv_doc_date = lr_header->DocumentDate
                                                               iv_del_date = lr_header->DeliveryDate ) = abap_false.
          lv_has_error = abap_true.
          APPEND VALUE #(
            %tky                  = lr_header->%tky
            %state_area           = c_val_deliv_date
            %msg                  = NEW zcx_merp_pur(
                                      textid   = zcx_merp_pur=>delivery_date_before_doc_date
                                      severity = if_abap_behv_message=>severity-error )
            %element-DeliveryDate = if_abap_behv=>mk-on
          ) TO reported-purchaseorder.
        ENDIF.
      ENDIF.

      " Enforce failed state mapping to reject database modification sequence if any rule triggers failure
      IF lv_has_error = abap_true.
        APPEND VALUE #(
          %tky        = lr_header->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-purchaseorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

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

    " Read actual state directly from transactional buffer
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( DocumentDate PostingDate DeliveryDate Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).

      " 1. Clear Document Date message area
      IF lr_header->DocumentDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_document_date_valid( iv_doc_date = lr_header->DocumentDate
                                                             iv_today    = lv_today ) = abap_true.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_doc_date ) TO reported-purchaseorder.
      ENDIF.

      " 2. Clear Posting Date message area
      IF lr_header->PostingDate IS NOT INITIAL AND lr_header->DocumentDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_posting_date_valid( iv_doc_date  = lr_header->DocumentDate
                                                            iv_post_date = lr_header->PostingDate ) = abap_true.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_post_date ) TO reported-purchaseorder.
      ENDIF.

      " 3. Clear Delivery Date message area
      IF lr_header->DeliveryDate IS NOT INITIAL AND lr_header->DocumentDate IS NOT INITIAL.
        DATA(lv_del_valid) = zcl_merp_doc_validator=>is_delivery_date_valid( iv_doc_date = lr_header->DocumentDate
                                                                             iv_del_date = lr_header->DeliveryDate ).

        IF lv_del_valid = abap_true.
          IF lr_header->Status = c_status_new AND lr_header->DeliveryDate < lv_today.
            lv_del_valid = abap_false.
          ENDIF.
        ENDIF.

        IF lv_del_valid = abap_true.
          APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_deliv_date ) TO reported-purchaseorder.
        ENDIF.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD releaseDocument.
    DATA lt_update  TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.
    DATA lo_message TYPE REF TO zcx_merp_pur.

    " Bulk read headers and linked items to minimize database roundtrips
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
      IF lr_header->Status <> c_status_new.
        lo_message = NEW #( textid   = zcx_merp_pur=>release_not_allowed
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( lr_header->DocumentNumber ) ).

      " Document cannot be released without at least one item
      ELSEIF NOT line_exists( lt_links[ source-%tky = lr_header->%tky ] ).
        lo_message = NEW #( textid   = zcx_merp_pur=>document_empty_items_invalid
                            severity = if_abap_behv_message=>severity-error ).
      ENDIF.

      " Handle validation results
      IF lo_message IS BOUND.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-purchaseorder.

        APPEND VALUE #( %tky                    = lr_header->%tky
                        %msg                    = lo_message
                        %action-releaseDocument = if_abap_behv=>mk-on ) TO reported-purchaseorder.
      ELSE.
        APPEND VALUE #( %tky   = lr_header->%tky
                        Status = c_status_approved ) TO lt_update.
      ENDIF.
    ENDLOOP.

    " Perform bulk update for successful documents in transactional buffer
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( Status )
        WITH lt_update
        FAILED DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      " Forward buffer failure exceptions directly to the UI layer
      IF lt_mod_failed IS NOT INITIAL.
        failed-purchaseorder   = CORRESPONDING #( BASE ( failed-purchaseorder ) lt_mod_failed-purchaseorder ).
        reported-purchaseorder = CORRESPONDING #( BASE ( reported-purchaseorder ) lt_mod_reported-purchaseorder ).
        RETURN.
      ENDIF.
    ENDIF.

    " Read the latest state from buffer to return requested action parameters
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR header IN lt_result ( %tky = header-%tky %param = header ) ).
  ENDMETHOD.

  METHOD cancelDocument.
    DATA lt_update  TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.
    DATA lo_message TYPE REF TO zcx_merp_pur.

    " Bulk read headers to check current document status
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      CLEAR lo_message.

      " Only New or Approved documents can be cancelled
      IF lr_header->Status <> c_status_new AND lr_header->Status <> c_status_approved.
        lo_message = NEW #( textid   = zcx_merp_pur=>cancel_not_allowed
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( lr_header->DocumentNumber ) ).
      ENDIF.

      " Handle validation results
      IF lo_message IS BOUND.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-purchaseorder.

        APPEND VALUE #( %tky                   = lr_header->%tky
                        %msg                   = lo_message
                        %action-cancelDocument = if_abap_behv=>mk-on ) TO reported-purchaseorder.
      ELSE.
        APPEND VALUE #( %tky   = lr_header->%tky
                        Status = c_status_cancelled ) TO lt_update.
      ENDIF.
    ENDLOOP.

    " Perform bulk update for successful documents in transactional buffer
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( Status )
        WITH lt_update
        FAILED DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      " Forward buffer failure exceptions directly to the UI layer
      IF lt_mod_failed IS NOT INITIAL.
        failed-purchaseorder   = CORRESPONDING #( BASE ( failed-purchaseorder ) lt_mod_failed-purchaseorder ).
        reported-purchaseorder = CORRESPONDING #( BASE ( reported-purchaseorder ) lt_mod_reported-purchaseorder ).
        RETURN.
      ENDIF.
    ENDIF.

    " Read the latest state from buffer to return requested action parameters
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR header IN lt_result ( %tky = header-%tky %param = header ) ).
  ENDMETHOD.

  METHOD setHeaderDefaults.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.

    " Bulk read to check current dates and status of the new document
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
        ls_header-Status = c_status_new.
      ENDIF.

      " Collect changes only if fields were actually initialized
      If ls_header <> lr_header->*.
        APPEND CORRESPONDING #( ls_header ) TO lt_header_update.
      ENDIF.
    ENDLOOP.

    " Apply generic defaults to the transactional buffer
    IF lt_header_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( DocumentDate PostingDate Status )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  METHOD deriveHeaderOnCompanyCode.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.

    " Bulk read fields related strictly to the company code mutation
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( CompanyCode CurrencyCode WarehouseCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " Collect master data keys for bulk read optimization
    DATA(lt_company_keys) = VALUE zif_merp_md_comp_code_sel=>tt_company_keys(
      FOR header IN lt_headers WHERE ( CompanyCode IS NOT INITIAL )
      ( CompanyCode = header-CompanyCode )
    ).
    DATA(lt_warehouse_keys) = VALUE zif_merp_md_warehouse_sel=>tt_warehouse_keys(
      FOR header IN lt_headers WHERE ( WarehouseCode IS NOT INITIAL )
      ( WarehouseCode = header-WarehouseCode )
    ).

    " Perform independent bulk master data selections
    DATA(lt_companies) = COND #(
      WHEN lt_company_keys IS NOT INITIAL
      THEN NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_companies( lt_company_keys ) ).

    DATA(lt_warehouses) = COND #(
      WHEN lt_warehouse_keys IS NOT INITIAL
      THEN NEW zcl_merp_md_warehouse_sel( )->zif_merp_md_warehouse_sel~read_warehouses( lt_warehouse_keys ) ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      DATA(ls_header) = lr_header->*.

      IF ls_header-CompanyCode IS NOT INITIAL.
        " Automatically align document currency with the company code currency
        ASSIGN lt_companies[ CompanyCode = ls_header-CompanyCode ] TO FIELD-SYMBOL(<company>).
        IF sy-subrc = 0 AND <company>-CurrencyCode IS NOT INITIAL.
          ls_header-CurrencyCode = <company>-CurrencyCode.
        ENDIF.

        " Validate and reset warehouse if it does not belong to the selected company
        IF ls_header-WarehouseCode IS NOT INITIAL.
          ASSIGN lt_warehouses[ WarehouseCode = ls_header-WarehouseCode ] TO FIELD-SYMBOL(<warehouse>).
          IF sy-subrc <> 0 OR <warehouse>-CompanyCode <> ls_header-CompanyCode.
            CLEAR ls_header-WarehouseCode.
          ENDIF.
        ENDIF.
      ENDIF.

      " Collect updates if master data alignment changed the header state
      IF ls_header <> lr_header->*.
        APPEND CORRESPONDING #( ls_header ) TO lt_header_update.
      ENDIF.
    ENDLOOP.

    " Apply master data alignment back to the transactional buffer
    IF lt_header_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( CurrencyCode WarehouseCode )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  METHOD deriveDatesOnDocumentDate.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.

    " Bulk read fields related strictly to the document date mutation
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
        " Automatically align posting date if it violates the validation rules
        IF ls_header-PostingDate IS NOT INITIAL
           AND zcl_merp_doc_validator=>is_posting_date_valid( iv_doc_date  = ls_header-DocumentDate
                                                              iv_post_date = ls_header-PostingDate ) = abap_false.
          ls_header-PostingDate = ls_header-DocumentDate.
        ENDIF.

        " Automatically align delivery date if it violates the chronological rules
        IF ls_header-DeliveryDate IS NOT INITIAL
           AND zcl_merp_doc_validator=>is_delivery_date_valid( iv_doc_date = ls_header-DocumentDate
                                                               iv_del_date = ls_header-DeliveryDate ) = abap_false.
          ls_header-DeliveryDate = ls_header-DocumentDate.
        ENDIF.
      ENDIF.

      " Collect updates if master data alignment changed the header state
      IF ls_header <> lr_header->*.
        APPEND CORRESPONDING #( ls_header ) TO lt_header_update.
      ENDIF.
    ENDLOOP.

    " Apply master data alignment back to the transactional buffer
    IF lt_header_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( PostingDate DeliveryDate )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  METHOD syncItemCurrency.
    DATA items_to_update TYPE TABLE FOR UPDATE zmerp_r_purchaseorder\\PurchaseOrderItem.

    " Bulk read parent headers and child items to check for currency mismatches
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
                         %is_draft    = lr_item->%is_draft ] TO FIELD-SYMBOL(<header>).

      " Align item currency with the parent document currency if they differ
      IF sy-subrc = 0 AND lr_item->CurrencyCode <> <header>-CurrencyCode.
        APPEND VALUE #(
          %tky         = lr_item->%tky
          CurrencyCode = <header>-CurrencyCode
        ) TO items_to_update.
      ENDIF.
    ENDLOOP.

    IF items_to_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrderItem
        UPDATE FIELDS ( CurrencyCode )
        WITH items_to_update.
    ENDIF.
  ENDMETHOD.

  METHOD assignDocumentNumber.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    DATA lx_nro_error TYPE REF TO cx_number_ranges.
    DATA lt_codes     TYPE string_table.
    DATA lt_po_update TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.

    " Step 1: Bulk read targets that lack a document number along with their CompanyCode context
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( DocumentNumber CompanyCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    DELETE lt_headers WHERE DocumentNumber IS NOT INITIAL.
    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " Step 2: Group by Company Code to perform bulk allocation safely per number range subobject
    DATA(lt_companies) = lt_headers.
    SORT lt_companies BY CompanyCode.
    DELETE ADJACENT DUPLICATES FROM lt_companies COMPARING CompanyCode.

    LOOP AT lt_companies REFERENCE INTO DATA(lr_company) WHERE CompanyCode IS NOT INITIAL.

      CLEAR lx_nro_error.

      " Count entities requiring key generation for this specific company code context
      DATA(lv_needed_count) = REDUCE i( INIT count = 0
                                         FOR header IN lt_headers
                                         WHERE ( CompanyCode = lr_company->CompanyCode )
                                         NEXT count += 1 ).
      IF lv_needed_count = 0.
        CONTINUE.
      ENDIF.

      " Bulk allocation via NRO utility with company subobject context and exception capture
      CLEAR lt_codes.
      TRY.
          lt_codes = zcl_merp_num_range_util=>get_next_po_codes_nro(
            iv_company_code = lr_company->CompanyCode
            iv_count        = lv_needed_count ).
        CATCH cx_number_ranges INTO lx_nro_error.
          CLEAR lt_codes.
      ENDTRY.

      DATA(lv_index) = 1.

      " Map zcl_merp_num_range_util results back to the master data sequence
      LOOP AT lt_headers REFERENCE INTO DATA(lr_hdr) WHERE CompanyCode = lr_company->CompanyCode.
        READ TABLE lt_codes INDEX lv_index ASSIGNING FIELD-SYMBOL(<lv_code>).

        IF sy-subrc = 0 AND <lv_code> IS NOT INITIAL.
          " Pack successfully generated code for global bulk local modify operation
          APPEND VALUE #(
            %tky           = lr_hdr->%tky
            DocumentNumber = CONV #( <lv_code> )
          ) TO lt_po_update.

          lv_index += 1.
        ELSE.
          " Report error metadata (RAP handles the transaction rollback automatically on save via severity-error)
          APPEND VALUE #(
            %tky = lr_hdr->%tky
            %msg = NEW zcx_merp_pur(
                     textid   = zcx_merp_pur=>doc_number_generation_failed
                     previous = lx_nro_error
                     severity = if_abap_behv_message=>severity-error )
            %element-documentnumber = if_abap_behv=>mk-on
          ) TO reported-purchaseorder.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    " Step 3: Write generated human-readable sequential keys back to the transactional buffer
    IF lt_po_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( DocumentNumber )
        WITH lt_po_update.
    ENDIF.
  ENDMETHOD.

  METHOD precheck_delete.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_key,
             documentuuid TYPE sysuuid_x16,
           END OF ty_key.

    TYPES: BEGIN OF ty_dependency,
             documentuuid TYPE sysuuid_x16,
             usedinentity TYPE zmerp_entity_name,
           END OF ty_dependency.

    DATA lt_keys TYPE SORTED TABLE OF ty_key WITH NON-UNIQUE KEY documentuuid.
    DATA lt_dependencies TYPE SORTED TABLE OF ty_dependency WITH NON-UNIQUE KEY documentuuid.
    DATA lv_failed_added TYPE abap_bool.

    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    lt_keys = VALUE #( FOR hdr IN lt_headers WHERE ( DocumentUUID IS NOT INITIAL ) ( documentuuid = hdr-DocumentUUID ) ).
    DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING documentuuid.

    IF lt_keys IS NOT INITIAL.
      SELECT DISTINCT
             usage~DocumentUUID AS documentuuid,
             usage~UsedInEntity AS usedinentity
        FROM zmerp_i_purchaseorder_usage AS usage
        INNER JOIN @lt_keys AS key ON usage~DocumentUUID = key~documentuuid
        INTO TABLE @lt_dependencies.
    ENDIF.

    LOOP AT lt_headers REFERENCE INTO DATA(lr_hdr).
      lv_failed_added = abap_false.

      " Lifecycle status check: allow deletion only for new or cancelled documents
      IF lr_hdr->Status <> c_status_new AND lr_hdr->Status <> c_status_cancelled.
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

      " Database dependency check
      LOOP AT lt_dependencies REFERENCE INTO DATA(lr_dep)
        WHERE documentuuid = lr_hdr->DocumentUUID.

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
                               attr2    = CONV #( lr_dep->usedinentity )
                               severity = if_abap_behv_message=>severity-error )
        ) TO reported-purchaseorder.
      ENDLOOP.
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
      c_val_vat_code  TYPE string VALUE 'VALIDATE_VAT_CODE',

      c_item_no_step  TYPE i VALUE 10.

    TYPES: BEGIN OF ty_header_key,
             document_uuid TYPE sysuuid_x16,
             is_draft      TYPE abp_behv_flag,
           END OF ty_header_key.

    CLASS-DATA gt_deleted_headers TYPE STANDARD TABLE OF ty_header_key WITH EMPTY KEY.

    "! Recalculates total header net and gross amounts using ZCL_MERP_DOC_CALC.
    METHODS calcHeaderTotals FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrderItem~calcHeaderTotals.

    "! Calculates net, VAT, and gross amounts for the item using ZCL_MERP_DOC_CALC.
    METHODS calcAmountsOnQtyPrice FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrderItem~calcAmountsOnQtyPrice.

    "! Calculates net, VAT, and gross amounts for the item using ZCL_MERP_DOC_CALC.
    METHODS calcAmountsOnVatCode FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrderItem~calcAmountsOnVatCode.

    "! Sets item defaults (ItemNo, Currency, UoM, VatCode) based on header and selected ItemCode.
    METHODS setItemDefaults FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrderItem~setItemDefaults.

    "! Validates mandatory item fields, prices, and quantities before saving.
    METHODS validateItemFields FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR PurchaseOrderItem~validateItemFields.

    "! Handles validation messages for item fields that have been filled/corrected on the fly.
    METHODS handleMessagesOnItemModify FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrderItem~handleMessagesOnItemModify.

    "! Clears validation messages for item fields that have been filled/corrected on the fly.
    METHODS clearMessagesForItemFields FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR PurchaseOrderItem~clearMessagesForItemFields.

    "! Pre-checks for dependencies and lifecycle status before allowing deletion of a Purchase Order Item.
    METHODS precheck_delete FOR PRECHECK
      keys FOR DELETE PurchaseOrderItem.

ENDCLASS.

CLASS lhc_zmerp_r_purchaseorderitm IMPLEMENTATION.

  METHOD validateItemFields.
    DATA lv_has_error TYPE abap_bool.

    " Read entity fields in local mode to bypass global authorization checks during validation
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrderItem
      FIELDS ( HeaderUUID ItemCode Quantity Price UnitOfMeasure VatCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Clear previous validation messages for individual field state areas to prevent duplicate errors in UI
    " (done after the READ, because %path requires HeaderUUID which is not part of the keys)
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

    " Gather header keys to read full document context for duplicate evaluation
    DATA lt_header_keys TYPE TABLE FOR READ IMPORT zmerp_r_purchaseorder.
    lt_header_keys = VALUE #(
      FOR GROUPS of <g> IN lt_items GROUP BY ( HeaderUUID = <g>-HeaderUUID
                                               is_draft   = <g>-%is_draft )
      ( %tky-DocumentUUID = <g>-HeaderUUID
        %is_draft         = <g>-%is_draft )
    ).

    " Read ALL items belonging to the affected headers to correctly evaluate duplicates
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder BY \_Items
      FIELDS ( HeaderUUID ItemCode )
      WITH CORRESPONDING #( lt_header_keys )
      RESULT DATA(lt_all_document_items).

    " Identify unique combinations of HeaderUUID and ItemCode that appear multiple times
    DATA(lt_duplicates) = zcl_merp_doc_validator=>get_duplicate_item_codes(
      CORRESPONDING zcl_merp_doc_validator=>tt_item_fields( lt_all_document_items )
    ).

    " Bulk collect item master data keys for cross-entity business validation
    DATA(lt_item_keys) = VALUE zif_merp_md_item_sel=>tt_item_keys(
      FOR item IN lt_items WHERE ( ItemCode IS NOT INITIAL )
      ( ItemCode = item-ItemCode )
    ).

    " Bulk collect VAT rate master data keys for cross-entity business validation
    DATA(lt_vat_keys) = VALUE zif_merp_md_vat_rate_sel=>tt_vat_rate_keys(
      FOR item IN lt_items WHERE ( VatCode IS NOT INITIAL )
      ( VatCode = item-VatCode )
    ).

    " Execute optimized bulk selections via Master Data Selector interfaces
    DATA(lt_items_master) = COND #(
      WHEN lt_item_keys IS NOT INITIAL
      THEN NEW zcl_merp_md_item_sel( )->zif_merp_md_item_sel~read_items( lt_item_keys ) ).

    " Execute optimized bulk selections via VAT Rate Master Data Selector interface
    DATA(lt_vat_rates) = COND #(
      WHEN lt_vat_keys IS NOT INITIAL
      THEN NEW zcl_merp_md_vat_rate_sel( )->zif_merp_md_vat_rate_sel~read_vat_rates( lt_vat_keys ) ).

    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      lv_has_error = abap_false.

      " 1. Mandatory, Master Data & Duplicate Validation: Item Code
      IF lr_item->ItemCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky              = lr_item->%tky
          %path             = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                       PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
          %state_area       = c_val_item_code
          %msg              = NEW zcx_merp_pur(
                                textid   = zcx_merp_pur=>select_item
                                severity = if_abap_behv_message=>severity-error )
          %element-ItemCode = if_abap_behv=>mk-on
        ) TO reported-purchaseorderitem.
      ELSEIF NOT line_exists( lt_items_master[ ItemCode = lr_item->ItemCode ] ).
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky              = lr_item->%tky
          %path             = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                       PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
          %state_area       = c_val_item_code
          %msg              = NEW zcx_merp_md(
                                textid   = zcx_merp_md=>item_not_found
                                attr1    = CONV string( lr_item->ItemCode )
                                severity = if_abap_behv_message=>severity-error )
          %element-ItemCode = if_abap_behv=>mk-on
        ) TO reported-purchaseorderitem.
      ELSEIF line_exists( lt_duplicates[ HeaderUUID = lr_item->HeaderUUID
                                         ItemCode   = lr_item->ItemCode ] ).
        " High-performance business validation: Catch duplicates under the same field state area
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky              = lr_item->%tky
          %path             = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                       PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
          %state_area       = c_val_item_code
          %msg              = NEW zcx_merp_pur(
                                textid   = zcx_merp_pur=>item_duplicate_invalid
                                attr1    = CONV string( lr_item->ItemCode )
                                severity = if_abap_behv_message=>severity-error )
          %element-ItemCode = if_abap_behv=>mk-on
        ) TO reported-purchaseorderitem.
      ENDIF.

      " 2. Business Logic Validation: Positive Quantity via Class Validator
      IF zcl_merp_doc_validator=>is_item_quantity_valid( lr_item->Quantity ) = abap_false.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky              = lr_item->%tky
          %path             = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                       PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
          %state_area       = c_val_quantity
          %msg              = NEW zcx_merp_pur(
                                textid   = zcx_merp_pur=>quantity_must_be_positive
                                severity = if_abap_behv_message=>severity-error )
          %element-Quantity = if_abap_behv=>mk-on
        ) TO reported-purchaseorderitem.
      ENDIF.

      " 3. Business Logic Validation: Positive Price via Class Validator
      IF zcl_merp_doc_validator=>is_item_price_valid( lr_item->Price ) = abap_false.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky           = lr_item->%tky
          %path          = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                    PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
          %state_area    = c_val_price
          %msg           = NEW zcx_merp_pur(
                             textid   = zcx_merp_pur=>price_must_be_positive
                             severity = if_abap_behv_message=>severity-error )
          %element-Price = if_abap_behv=>mk-on
        ) TO reported-purchaseorderitem.
      ENDIF.

      " 4. Mandatory Validation: Unit of Measure
      IF lr_item->UnitOfMeasure IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                   = lr_item->%tky
          %path                  = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                            PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
          %state_area            = c_val_uom
          %msg                   = NEW zcx_merp_pur(
                                     textid   = zcx_merp_pur=>select_unit_of_measure
                                     severity = if_abap_behv_message=>severity-error )
          %element-UnitOfMeasure = if_abap_behv=>mk-on
        ) TO reported-purchaseorderitem.
      ENDIF.

      " 5. Mandatory Validation: VAT Code
      IF lr_item->VatCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky             = lr_item->%tky
          %path            = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                      PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
          %state_area      = c_val_vat_code
          %msg             = NEW zcx_merp_pur(
                               textid   = zcx_merp_pur=>select_vat_code
                               severity = if_abap_behv_message=>severity-error )
          %element-VatCode = if_abap_behv=>mk-on
        ) TO reported-purchaseorderitem.
      ELSEIF NOT line_exists( lt_vat_rates[ VatCode = lr_item->VatCode ] ).
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky             = lr_item->%tky
          %path            = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                      PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
          %state_area      = c_val_vat_code
          %msg             = NEW zcx_merp_md(
                               textid   = zcx_merp_md=>vat_code_not_found
                               attr1    = CONV string( lr_item->VatCode )
                               severity = if_abap_behv_message=>severity-error )
          %element-VatCode = if_abap_behv=>mk-on
        ) TO reported-purchaseorderitem.
      ENDIF.

      " If any business validation failed, prevent transaction commit
      IF lv_has_error = abap_true.
        APPEND VALUE #(
          %tky        = lr_item->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-purchaseorderitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD handleMessagesOnItemModify.
    " Read modified items from local transactional buffer
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrderItem
      FIELDS ( HeaderUUID ItemCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Use correct implicit RAP type for root entity read operations
    DATA lt_header_keys TYPE TABLE FOR READ IMPORT zmerp_r_purchaseorder.

    " Group modified items by HeaderUUID and propagate draft state context correctly
    lt_header_keys = VALUE #(
      FOR GROUPS of <g> IN lt_items GROUP BY ( HeaderUUID = <g>-HeaderUUID
                                               is_draft   = <g>-%is_draft )
      ( %tky-DocumentUUID = <g>-HeaderUUID
        %is_draft         = <g>-%is_draft )
    ).

    " Read ALL items belonging to the affected headers to evaluate full document context
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder BY \_Items
      FIELDS ( HeaderUUID ItemCode )
      WITH CORRESPONDING #( lt_header_keys )
      RESULT DATA(lt_all_document_items).

    " UI FIX: Clear message state areas for ALL items within the document context
    reported-purchaseorderitem = VALUE #(
      BASE reported-purchaseorderitem
      FOR ls_all_item IN lt_all_document_items
      ( %tky        = ls_all_item-%tky
        %path       = VALUE #( PurchaseOrder-%is_draft    = ls_all_item-%is_draft
                               PurchaseOrder-DocumentUUID = ls_all_item-HeaderUUID )
        %state_area = c_val_item_code )
    ).

    " Get hash table of duplicate combinations using optimized validator method
    DATA(lt_duplicates) = zcl_merp_doc_validator=>get_duplicate_item_codes(
      CORRESPONDING zcl_merp_doc_validator=>tt_item_fields( lt_all_document_items )
    ).

    IF lt_duplicates IS INITIAL.
      RETURN.
    ENDIF.

    " Report duplicate errors back to the RAP framework for ALL lines currently involved in duplication
    LOOP AT lt_all_document_items REFERENCE INTO DATA(lr_doc_item) WHERE ItemCode IS NOT INITIAL.

      " Check if this specific document line is part of the duplicates found in the full context
      IF line_exists( lt_duplicates[ HeaderUUID = lr_doc_item->HeaderUUID
                                     ItemCode   = lr_doc_item->ItemCode ] ).

        APPEND VALUE #(
          %tky              = lr_doc_item->%tky " Primes the error exactly on each duplicate row
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

  METHOD clearMessagesForItemFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    " Read actual state directly from transactional buffer for modified items
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrderItem
      FIELDS ( HeaderUUID Quantity Price UnitOfMeasure VatCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_items REFERENCE INTO DATA(lr_item).

      " 1. Clear Quantity message area if value is valid via class validator
      IF zcl_merp_doc_validator=>is_item_quantity_valid( lr_item->Quantity ) = abap_true.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %path       = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                               PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_quantity ) TO reported-purchaseorderitem.
      ENDIF.

      " 2. Clear Price message area if value is valid via class validator
      IF zcl_merp_doc_validator=>is_item_price_valid( lr_item->Price ) = abap_true.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %path       = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                               PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_price ) TO reported-purchaseorderitem.
      ENDIF.

      " 3. Clear Unit of Measure message area if field is filled
      IF lr_item->UnitOfMeasure IS NOT INITIAL.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %path       = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                               PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_uom ) TO reported-purchaseorderitem.
      ENDIF.

      " 4. Clear VAT Code message area if field is filled
      IF lr_item->VatCode IS NOT INITIAL.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %path       = VALUE #( PurchaseOrder-%is_draft    = lr_item->%is_draft
                                               PurchaseOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_vat_code ) TO reported-purchaseorderitem.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD calcHeaderTotals.
    " Read parent headers of the changed (or deleted) items
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrderItem BY \_PurchaseOrder
      FIELDS ( DocumentUUID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT gt_deleted_headers REFERENCE INTO DATA(lr_deleted).
      APPEND VALUE #( DocumentUUID = lr_deleted->document_uuid
                      %is_draft    = lr_deleted->is_draft ) TO lt_headers.
    ENDLOOP.
    CLEAR gt_deleted_headers.

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " Cleanse input headers table to eliminate duplicates and prevent duplicate key updates in RAP buffer
    SORT lt_headers BY DocumentUUID %is_draft.
    DELETE ADJACENT DUPLICATES FROM lt_headers COMPARING DocumentUUID %is_draft.

    " Read all items of those headers in one call to pass into the calculation class
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder BY \_Items
      FIELDS ( HeaderUUID NetAmount VatAmount GrossAmount ) " Fetch all calculated financial components
      WITH CORRESPONDING #( lt_headers )
      RESULT DATA(lt_items).

    DATA lt_po_update TYPE TABLE FOR UPDATE zmerp_r_purchaseorder.

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      " Extract the exact item amount structures belonging to the current header document context (UUID + Draft status)
      DATA(lt_target_amounts) = VALUE zcl_merp_doc_calc=>tt_item_amounts(
        FOR item IN lt_items WHERE ( HeaderUUID = lr_header->DocumentUUID
                                     AND %is_draft  = lr_header->%is_draft )
        ( net_amount   = item-NetAmount
          vat_amount   = item-VatAmount
          gross_amount = item-GrossAmount )
      ).

      " Delegate execution to the pure business logic class that knows the calculation sequence
      DATA(ls_totals) = zcl_merp_doc_calc=>calculate_header_totals( lt_target_amounts ).

      " Pack the calculated totals directly into the transactional modification buffer
      APPEND VALUE #(
        %tky                      = lr_header->%tky
        TotalNetAmount            = ls_totals-total_net_amount
        TotalGrossAmount          = ls_totals-total_gross_amount
        %control-TotalNetAmount   = if_abap_behv=>mk-on
        %control-TotalGrossAmount = if_abap_behv=>mk-on
      ) TO lt_po_update.
    ENDLOOP.

    " Update header totals in the transactional buffer
    IF lt_po_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder
        UPDATE FIELDS ( TotalNetAmount TotalGrossAmount )
        WITH lt_po_update.
    ENDIF.
  ENDMETHOD.

  METHOD setItemDefaults.
    TYPES: BEGIN OF ty_counter,
             header_uuid TYPE sysuuid_x16,
             last_no     TYPE i,
           END OF ty_counter.

    DATA lt_counters TYPE HASHED TABLE OF ty_counter WITH UNIQUE KEY header_uuid.
    DATA lt_update   TYPE TABLE FOR UPDATE zmerp_r_purchaseorder\\PurchaseOrderItem.

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

    LOOP AT lt_siblings REFERENCE INTO DATA(lr_sibling).
      ASSIGN lt_counters[ header_uuid = lr_sibling->HeaderUUID ] TO FIELD-SYMBOL(<counter>).
      IF sy-subrc <> 0.
        INSERT VALUE #( header_uuid = lr_sibling->HeaderUUID )
          INTO TABLE lt_counters ASSIGNING <counter>.
      ENDIF.

      IF lr_sibling->ItemNo > <counter>-last_no.
        <counter>-last_no = lr_sibling->ItemNo.
      ENDIF.
    ENDLOOP.

    " Item master data for all selected item codes in one selector call
    DATA(lt_item_keys) = VALUE zif_merp_md_item_sel=>tt_item_keys(
      FOR item IN lt_items WHERE ( ItemCode IS NOT INITIAL )
      ( ItemCode = item-ItemCode )
    ).
    DATA(lt_items_master) = COND #(
      WHEN lt_item_keys IS NOT INITIAL
      THEN NEW zcl_merp_md_item_sel( )->zif_merp_md_item_sel~read_items( lt_item_keys ) ).

    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<item>).
      DATA(ls_item) = <item>.

      " Next free item number within the document
      IF ls_item-ItemNo IS INITIAL.
        ASSIGN lt_counters[ header_uuid = ls_item-HeaderUUID ] TO <counter>.
        IF sy-subrc = 0.
          <counter>-last_no += c_item_no_step.
          ls_item-ItemNo     = <counter>-last_no.
        ENDIF.
      ENDIF.

      " Item currency follows the document currency
      IF ls_item-CurrencyCode IS INITIAL.
        ASSIGN lt_headers[ DocumentUUID = ls_item-HeaderUUID
                           %is_draft    = ls_item-%is_draft ] TO FIELD-SYMBOL(<header>).
        IF sy-subrc = 0.
          ls_item-CurrencyCode = <header>-CurrencyCode.
        ENDIF.
      ENDIF.

      " UoM and VAT code are unconditionally inherited from the item master data
      IF ls_item-ItemCode IS NOT INITIAL.
        ASSIGN lt_items_master[ ItemCode = ls_item-ItemCode ] TO FIELD-SYMBOL(<master>).
        IF sy-subrc = 0.
          ls_item-UnitOfMeasure = <master>-BaseUnitOfMeasure.
          ls_item-VatCode       = <master>-DefaultVatCode.
        ENDIF.
      ENDIF.

      " Update only instances that really changed
      IF ls_item <> <item>.
        APPEND CORRESPONDING #( ls_item ) TO lt_update.
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
    " Bulk read modified items from the transactional buffer (Quantity and Price changes)
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrderItem
      FIELDS ( HeaderUUID ItemCode Quantity Price VatCode NetAmount VatAmount GrossAmount )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Collect unique VAT codes to optimize cross-entity selection
    DATA(lt_vat_keys) = VALUE zif_merp_md_vat_rate_sel=>tt_vat_rate_keys(
      FOR item IN lt_items WHERE ( VatCode IS NOT INITIAL )
      ( VatCode = item-VatCode )
    ).

    " Bulk select VAT percentages via the Master Data Selector interface
    DATA(lt_vat_rates) = COND #(
      WHEN lt_vat_keys IS NOT INITIAL
      THEN NEW zcl_merp_md_vat_rate_sel( )->zif_merp_md_vat_rate_sel~read_vat_rates( lt_vat_keys ) ).

    DATA lt_items_update TYPE TABLE FOR UPDATE zmerp_r_purchaseorder\\PurchaseOrderItem.

    " Recalculate item amounts using pure business logic core
    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      ASSIGN lt_vat_rates[ VatCode = lr_item->VatCode ] TO FIELD-SYMBOL(<ls_vat>).
      DATA(lv_percentage) = COND decfloat34( WHEN sy-subrc = 0 THEN <ls_vat>-percentage ELSE 0 ).

      " Quantity or price changed trigger event -> net -> VAT -> gross recalculation sequence
      DATA(ls_calculated_amounts) = zcl_merp_doc_calc=>calc_on_qty_price_change(
        iv_quantity       = lr_item->Quantity
        iv_price          = lr_item->Price
        iv_vat_percentage = lv_percentage
      ).

      " Prevent unnecessary roundtrips by checking if buffer values actually mutated
      IF lr_item->NetAmount   <> ls_calculated_amounts-net_amount   OR
         lr_item->VatAmount   <> ls_calculated_amounts-vat_amount   OR
         lr_item->GrossAmount <> ls_calculated_amounts-gross_amount.

        APPEND VALUE #(
          %tky                = lr_item->%tky
          NetAmount           = ls_calculated_amounts-net_amount
          VatAmount           = ls_calculated_amounts-vat_amount
          GrossAmount         = ls_calculated_amounts-gross_amount
          %control-NetAmount   = if_abap_behv=>mk-on
          %control-VatAmount   = if_abap_behv=>mk-on
          %control-GrossAmount = if_abap_behv=>mk-on
        ) TO lt_items_update.
      ENDIF.
    ENDLOOP.

    " Apply mass calculated amounts back to the RAP transactional buffer
    IF lt_items_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrderItem
        UPDATE FIELDS ( NetAmount VatAmount GrossAmount )
        WITH lt_items_update.
    ENDIF.
  ENDMETHOD.

  METHOD calcAmountsOnVatCode.
    " Bulk read modified items upon VAT code change mutation
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrderItem
      FIELDS ( HeaderUUID VatCode NetAmount VatAmount GrossAmount )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Collect unique VAT codes for optimized batch retrieval
    DATA(lt_vat_keys) = VALUE zif_merp_md_vat_rate_sel=>tt_vat_rate_keys(
      FOR item IN lt_items WHERE ( VatCode IS NOT INITIAL )
      ( VatCode = item-VatCode )
    ).

    " Select updated rates from Master Data Selector
    DATA(lt_vat_rates) = COND #(
      WHEN lt_vat_keys IS NOT INITIAL
      THEN NEW zcl_merp_md_vat_rate_sel( )->zif_merp_md_vat_rate_sel~read_vat_rates( lt_vat_keys ) ).

    DATA lt_items_update TYPE TABLE FOR UPDATE zmerp_r_purchaseorder\\PurchaseOrderItem.

    " Recalculate VAT and gross fields while net amount remains persistent
    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      ASSIGN lt_vat_rates[ VatCode = lr_item->VatCode ] TO FIELD-SYMBOL(<ls_vat>).
      DATA(lv_percentage) = COND decfloat34( WHEN sy-subrc = 0 THEN <ls_vat>-percentage ELSE 0 ).

      DATA(ls_current_amounts) = VALUE zcl_merp_doc_calc=>ty_item_amounts(
        net_amount   = lr_item->NetAmount
        vat_amount   = lr_item->VatAmount
        gross_amount = lr_item->GrossAmount
      ).

      " VAT rate changed trigger event -> VAT and gross calculation sequence
      DATA(ls_calculated_amounts) = zcl_merp_doc_calc=>calc_on_vat_rate_change(
        is_amounts        = ls_current_amounts
        iv_vat_percentage = lv_percentage
      ).

      IF lr_item->VatAmount <> ls_calculated_amounts-vat_amount OR
         lr_item->GrossAmount <> ls_calculated_amounts-gross_amount.

        APPEND VALUE #(
          %tky                = lr_item->%tky
          VatAmount           = ls_calculated_amounts-vat_amount
          GrossAmount         = ls_calculated_amounts-gross_amount
          %control-VatAmount   = if_abap_behv=>mk-on
          %control-GrossAmount = if_abap_behv=>mk-on
        ) TO lt_items_update.
      ENDIF.
    ENDLOOP.

    " Write back synchronized values to transactional buffer state
    IF lt_items_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrderItem
        UPDATE FIELDS ( VatAmount GrossAmount )
        WITH lt_items_update.
    ENDIF.
  ENDMETHOD.

  METHOD precheck_delete.
    READ ENTITIES OF zmerp_r_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrderItem
      FIELDS ( HeaderUUID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      APPEND VALUE #( document_uuid = lr_item->HeaderUUID
                      is_draft      = lr_item->%is_draft ) TO gt_deleted_headers.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

