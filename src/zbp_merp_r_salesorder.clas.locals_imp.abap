"! Local behavior handler for Sales Order root entity.
CLASS lhc_zmerp_r_salesorder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      " Validation state areas for UI field highlighting
      c_val_company   TYPE string VALUE 'VALIDATE_COMPANY',
      c_val_partner   TYPE string VALUE 'VALIDATE_PARTNER',
      c_val_warehouse TYPE string VALUE 'VALIDATE_WAREHOUSE',
      c_val_currency  TYPE string VALUE 'VALIDATE_CURRENCY',
      c_val_items     TYPE string VALUE 'VALIDATE_ITEMS',
      c_val_doc_date  TYPE string VALUE 'VALIDATE_DOC_DATE',
      c_val_post_date TYPE string VALUE 'VALIDATE_POST_DATE'.

    " --- Access and state ---
    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR SalesOrder
        RESULT  result.

    "! Evaluates dynamic instance features for actions based on status.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING
        keys   REQUEST requested_features FOR SalesOrder
      RESULT   result.

    "! Pre-checks deletion conditions and status restrictions.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING
        keys FOR DELETE SalesOrder.

    " --- Actions ---
    "! Rejects the Sales Order (only while nothing is issued).
    METHODS rejectDocument FOR MODIFY
      IMPORTING
        keys   FOR ACTION SalesOrder~rejectDocument
      RESULT   result.

    "! Completes the Sales Order manually (the open quantities are not issued any more).
    METHODS completeDocument FOR MODIFY
      IMPORTING
        keys   FOR ACTION SalesOrder~completeDocument
      RESULT   result.

    "! Sets the issue status (Open / In Process / Completed) calculated by the goods issue.
    "! API for other business objects, not exposed in the service.
    METHODS setIssueStatus FOR MODIFY
      IMPORTING
        keys   FOR ACTION SalesOrder~setIssueStatus
      RESULT   result.

    "! Creates a goods issue draft for the Sales Order: the goods issue takes over the order and its
    "! open quantities exactly as when the order is selected in the goods issue (deriveDocFromSalesOrder).
    METHODS createGoodsIssue FOR MODIFY
      IMPORTING
        keys   FOR ACTION SalesOrder~createGoodsIssue
      RESULT   result.

    " --- Determinations on modify ---
    "! Sets default header values on document creation.
    METHODS setHeaderDefaults FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR SalesOrder~setHeaderDefaults.

    "! Derives dependent header fields when the company code changes.
    METHODS deriveHeaderOnCompanyCode FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR SalesOrder~deriveHeaderOnCompanyCode.

    "! Derives dependent header fields when the document date changes.
    METHODS deriveDatesOnDocumentDate FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR SalesOrder~deriveDatesOnDocumentDate.

    "! Keeps the currency of all items in sync with the header currency.
    METHODS syncItemCurrency FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR SalesOrder~syncItemCurrency.

    " --- Determinations on save ---
    "! Assigns the document number from the number range on first save.
    METHODS assignDocumentNumber FOR DETERMINE ON SAVE
      IMPORTING
        keys FOR SalesOrder~assignDocumentNumber.

    " --- Validations ---
    "! Validates mandatory header fields before saving.
    METHODS validateHeaderFields FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR SalesOrder~validateHeaderFields.

    "! A sales order is saved only with at least one item (there is no release step that would check it).
    METHODS validateItemsExist FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR SalesOrder~validateItemsExist.

    "! Validates document date and posting date consistency.
    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR SalesOrder~validateDates.

    "! A document is not saved without a number: runs after assignDocumentNumber
    "! (save determinations come before save validations) and fails the instance if no number was assigned.
    METHODS validateDocumentNumber FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR SalesOrder~validateDocumentNumber.

    " --- Clearing of validation messages ---
    "! Clears validation messages for organizational header fields that have been filled in.
    METHODS clearMessagesForHeaderFields FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR SalesOrder~clearMessagesForHeaderFields.

    "! Clears date validation messages for fields that have been fixed.
    METHODS clearMessagesForDates FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR SalesOrder~clearMessagesForDates.

ENDCLASS.

CLASS lhc_zmerp_r_salesorder IMPLEMENTATION.

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

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " Only saved (active) documents can be edited or processed; draft instances get no actions.
    " Delete follows the status only (in a draft it discards the draft)
    result = VALUE #(
      FOR header IN lt_headers
      LET lv_active   = xsdbool( header-%is_draft = if_abap_behv=>mk-off )
          lv_edit     = xsdbool( lv_active = abap_true
                             AND zcl_merp_doc_so_lifecycle=>can_edit( header-Status ) = abap_true )
          lv_complete = xsdbool( lv_active = abap_true
                             AND zcl_merp_doc_so_lifecycle=>can_complete( header-Status ) = abap_true )
          lv_reject   = xsdbool( lv_active = abap_true
                             AND zcl_merp_doc_so_lifecycle=>can_reject( header-Status ) = abap_true )
          lv_issue    = xsdbool( lv_active = abap_true
                             AND zcl_merp_doc_so_lifecycle=>can_issue_goods( header-Status ) = abap_true )
          lv_delete   = zcl_merp_doc_so_lifecycle=>can_delete( header-Status ) IN
      ( %tky                     = header-%tky
        %delete                  = COND #( WHEN lv_delete = abap_true
                                           THEN if_abap_behv=>fc-o-enabled
                                           ELSE if_abap_behv=>fc-o-disabled )
        %action-Edit             = COND #( WHEN lv_edit = abap_true
                                           THEN if_abap_behv=>fc-o-enabled
                                           ELSE if_abap_behv=>fc-o-disabled )
        %action-completeDocument = COND #( WHEN lv_complete = abap_true
                                           THEN if_abap_behv=>fc-o-enabled
                                           ELSE if_abap_behv=>fc-o-disabled )
        %action-rejectDocument   = COND #( WHEN lv_reject = abap_true
                                           THEN if_abap_behv=>fc-o-enabled
                                           ELSE if_abap_behv=>fc-o-disabled )
        %action-createGoodsIssue = COND #( WHEN lv_issue = abap_true
                                           THEN if_abap_behv=>fc-o-enabled
                                           ELSE if_abap_behv=>fc-o-disabled )
        " The document number carries the company prefix, so the company is fixed once it is assigned
        %field-CompanyCode       = COND #( WHEN header-DocumentNumber IS INITIAL
                                           THEN if_abap_behv=>fc-f-mandatory
                                           ELSE if_abap_behv=>fc-f-read_only ) )
    ).
  ENDMETHOD.

  METHOD precheck_delete.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_failed_added TYPE abap_bool.

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " Usages of all documents in one selection (the selector skips initial keys)
    DATA(lt_usages) = NEW zcl_merp_doc_so_sel( )->zif_merp_doc_so_sel~read_usages(
      VALUE #( FOR hdr IN lt_headers ( DocumentUUID = hdr-DocumentUUID ) ) ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_hdr).
      lv_failed_added = abap_false.

      " Delete only in status Open or Rejected
      IF zcl_merp_doc_so_lifecycle=>can_delete( lr_hdr->Status ) = abap_false.
        APPEND VALUE #(
          %tky        = lr_hdr->%tky
          %fail-cause = if_abap_behv=>cause-conflict
        ) TO failed-salesorder.

        APPEND VALUE #(
          %tky            = lr_hdr->%tky
          %element-Status = if_abap_behv=>mk-on
          %msg            = NEW zcx_merp_sd(
                               textid   = zcx_merp_sd=>delete_not_allowed
                               attr1    = CONV #( lr_hdr->DocumentNumber )
                               severity = if_abap_behv_message=>severity-error )
        ) TO reported-salesorder.
        CONTINUE.
      ENDIF.

      " Usage check: one message per using entity (sorted table: WHERE uses the table key)
      LOOP AT lt_usages REFERENCE INTO DATA(lr_usage) WHERE DocumentUUID = lr_hdr->DocumentUUID.

        IF lv_failed_added = abap_false.
          APPEND VALUE #(
            %tky        = lr_hdr->%tky
            %fail-cause = if_abap_behv=>cause-dependency
          ) TO failed-salesorder.
          lv_failed_added = abap_true.
        ENDIF.

        " Document number is shown to the user instead of the technical UUID
        APPEND VALUE #(
          %tky            = lr_hdr->%tky
          %element-Status = if_abap_behv=>mk-on
          %msg            = NEW zcx_merp_sd(
                               textid   = zcx_merp_sd=>sales_order_in_use
                               attr1    = CONV #( lr_hdr->DocumentNumber )
                               attr2    = CONV #( lr_usage->UsedInEntity )
                               severity = if_abap_behv_message=>severity-error )
        ) TO reported-salesorder.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  " --- Actions ---
  METHOD rejectDocument.
    DATA lt_update  TYPE TABLE FOR UPDATE zmerp_r_salesorder.
    DATA lo_message TYPE REF TO zcx_merp_sd.

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      CLEAR lo_message.

      " Only 'Open' documents can be rejected: an 'In Process' document has posted goods issues
      IF zcl_merp_doc_so_lifecycle=>can_reject( lr_header->Status ) = abap_false.
        lo_message = NEW #( textid   = zcx_merp_sd=>reject_not_allowed
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( lr_header->DocumentNumber ) ).
      ENDIF.

      IF lo_message IS BOUND.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-salesorder.

        APPEND VALUE #( %tky                   = lr_header->%tky
                        %msg                   = lo_message
                        %action-rejectDocument = if_abap_behv=>mk-on ) TO reported-salesorder.
      ELSE.
        APPEND VALUE #( %tky   = lr_header->%tky
                        Status = zcl_merp_doc_so_lifecycle=>c_status_rejected ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
        ENTITY SalesOrder
        UPDATE FIELDS ( Status )
        WITH lt_update
        FAILED DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      " Errors of the update are returned to the caller
      IF lt_mod_failed IS NOT INITIAL.
        failed-salesorder   = CORRESPONDING #( BASE ( failed-salesorder ) lt_mod_failed-salesorder ).
        reported-salesorder = CORRESPONDING #( BASE ( reported-salesorder ) lt_mod_reported-salesorder ).
        RETURN.
      ENDIF.
    ENDIF.

    " Action result: current state of the documents
    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR header IN lt_result ( %tky = header-%tky %param = header ) ).
  ENDMETHOD.

  METHOD completeDocument.
    DATA lt_update  TYPE TABLE FOR UPDATE zmerp_r_salesorder.
    DATA lo_message TYPE REF TO zcx_merp_sd.

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      CLEAR lo_message.

      " Only 'In Process' documents can be completed; open quantities are allowed
      IF zcl_merp_doc_so_lifecycle=>can_complete( lr_header->Status ) = abap_false.
        lo_message = NEW #( textid   = zcx_merp_sd=>complete_not_allowed
                            severity = if_abap_behv_message=>severity-error
                            attr1    = CONV #( lr_header->DocumentNumber ) ).
      ENDIF.

      IF lo_message IS BOUND.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-salesorder.

        APPEND VALUE #( %tky                     = lr_header->%tky
                        %msg                     = lo_message
                        %action-completeDocument = if_abap_behv=>mk-on ) TO reported-salesorder.
      ELSE.
        APPEND VALUE #( %tky   = lr_header->%tky
                        Status = zcl_merp_doc_so_lifecycle=>c_status_completed ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
        ENTITY SalesOrder
        UPDATE FIELDS ( Status )
        WITH lt_update
        FAILED DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      " Errors of the update are returned to the caller
      IF lt_mod_failed IS NOT INITIAL.
        failed-salesorder   = CORRESPONDING #( BASE ( failed-salesorder ) lt_mod_failed-salesorder ).
        reported-salesorder = CORRESPONDING #( BASE ( reported-salesorder ) lt_mod_reported-salesorder ).
        RETURN.
      ENDIF.
    ENDIF.

    " Action result: current state of the documents
    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR header IN lt_result ( %tky = header-%tky %param = header ) ).
  ENDMETHOD.

  METHOD createGoodsIssue.
    DATA lt_issuable TYPE TABLE FOR READ RESULT zmerp_r_salesorder.

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    " Goods can be issued only for 'Open' and 'In Process' orders
    " (the action is hidden otherwise; the check also covers EML callers)
    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      IF zcl_merp_doc_so_lifecycle=>can_issue_goods( lr_header->Status ) = abap_true.
        APPEND lr_header->* TO lt_issuable.
      ELSE.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-salesorder.
        APPEND VALUE #( %tky                     = lr_header->%tky
                        %msg                     = NEW zcx_merp_sd(
                                                     textid   = zcx_merp_sd=>so_issue_not_allowed
                                                     severity = if_abap_behv_message=>severity-error
                                                     attr1    = CONV #( lr_header->DocumentNumber ) )
                        %action-createGoodsIssue = if_abap_behv=>mk-on ) TO reported-salesorder.
      ENDIF.
    ENDLOOP.

    IF lt_issuable IS INITIAL.
      RETURN.
    ENDIF.

    " The same path as selecting the order in a goods issue: only the order reference is set,
    " header fields and items (open quantities and amounts) are derived by the goods issue itself
    MODIFY ENTITIES OF zmerp_r_goodsissue
      ENTITY GoodsIssue
      CREATE FIELDS ( SoReferenceUUID )
      WITH VALUE #( FOR so IN lt_issuable
                    ( %cid            = |{ so-DocumentUUID }|
                      %is_draft       = if_abap_behv=>mk-on
                      SoReferenceUUID = so-DocumentUUID ) )
      MAPPED DATA(ls_gi_mapped)
      FAILED DATA(ls_gi_failed)
      REPORTED DATA(ls_gi_reported).

    " New goods issue drafts (the action result; an app with a route to goods issues opens them)
    IF ls_gi_mapped-goodsissue IS NOT INITIAL.
      READ ENTITIES OF zmerp_r_goodsissue
        ENTITY GoodsIssue
        ALL FIELDS
        WITH VALUE #( FOR gi IN ls_gi_mapped-goodsissue ( %tky = gi-%tky ) )
        RESULT DATA(lt_issues).
    ENDIF.

    LOOP AT lt_issuable REFERENCE INTO lr_header.
      ASSIGN ls_gi_mapped-goodsissue[ %cid = |{ lr_header->DocumentUUID }| ] TO FIELD-SYMBOL(<ls_gi>).

      IF sy-subrc = 0.
        APPEND VALUE #( %tky   = lr_header->%tky
                        %param = CORRESPONDING #( VALUE #( lt_issues[ %tky = <ls_gi>-%tky ] OPTIONAL ) ) ) TO result.

        " The draft has no number yet (assigned on save): the user finds it in the goods issue list
        APPEND VALUE #( %tky = lr_header->%tky
                        %msg = NEW zcx_merp_sd(
                                 textid   = zcx_merp_sd=>goods_issue_draft_created
                                 severity = if_abap_behv_message=>severity-success
                                 attr1    = CONV #( lr_header->DocumentNumber ) ) ) TO reported-salesorder.
      ELSE.
        " Messages of the goods issue are returned on the sales order
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-salesorder.
        LOOP AT ls_gi_reported-goodsissue REFERENCE INTO DATA(lr_gi_message)
             WHERE %cid = |{ lr_header->DocumentUUID }|.
          APPEND VALUE #( %tky                     = lr_header->%tky
                          %msg                     = lr_gi_message->%msg
                          %action-createGoodsIssue = if_abap_behv=>mk-on ) TO reported-salesorder.
        ENDLOOP.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD setIssueStatus.
    DATA lt_update  TYPE TABLE FOR UPDATE zmerp_r_salesorder.
    DATA lo_message TYPE REF TO zcx_merp_sd.

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( Status DocumentNumber )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      CLEAR lo_message.

      ASSIGN keys[ %tky = lr_header->%tky ] TO FIELD-SYMBOL(<ls_key>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      " Only transitions within the issue lifecycle (Open / In Process / Completed) are allowed
      IF zcl_merp_doc_so_lifecycle=>is_issue_status( lr_header->Status ) = abap_false
         OR zcl_merp_doc_so_lifecycle=>is_issue_status( <ls_key>-%param-Status ) = abap_false.
        lo_message = NEW #( textid   = zcx_merp_sd=>invalid_document_status
                            severity = if_abap_behv_message=>severity-error ).
      ENDIF.

      IF lo_message IS BOUND.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-conflict ) TO failed-salesorder.
        APPEND VALUE #( %tky                   = lr_header->%tky
                        %msg                   = lo_message
                        %action-setIssueStatus = if_abap_behv=>mk-on ) TO reported-salesorder.
      ELSEIF <ls_key>-%param-Status <> lr_header->Status.
        APPEND VALUE #( %tky   = lr_header->%tky
                        Status = <ls_key>-%param-Status ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
        ENTITY SalesOrder
        UPDATE FIELDS ( Status )
        WITH lt_update
        FAILED DATA(lt_mod_failed)
        REPORTED DATA(lt_mod_reported).

      IF lt_mod_failed IS NOT INITIAL.
        failed-salesorder   = CORRESPONDING #( BASE ( failed-salesorder ) lt_mod_failed-salesorder ).
        reported-salesorder = CORRESPONDING #( BASE ( reported-salesorder ) lt_mod_reported-salesorder ).
        RETURN.
      ENDIF.
    ENDIF.

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR header IN lt_result ( %tky = header-%tky %param = header ) ).
  ENDMETHOD.

  " --- Determinations on modify ---
  METHOD setHeaderDefaults.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_salesorder.

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
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
        ls_header-Status = zcl_merp_doc_so_lifecycle=>c_status_open.
      ENDIF.

      " Only changed headers are updated
      IF ls_header <> lr_header->*.
        APPEND CORRESPONDING #( ls_header ) TO lt_header_update.
      ENDIF.
    ENDLOOP.

    IF lt_header_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
        ENTITY SalesOrder
        UPDATE FIELDS ( DocumentDate PostingDate Status )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  METHOD deriveHeaderOnCompanyCode.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_salesorder.

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
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
      MODIFY ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
        ENTITY SalesOrder
        UPDATE FIELDS ( CurrencyCode WarehouseCode )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  METHOD deriveDatesOnDocumentDate.
    DATA lt_header_update TYPE TABLE FOR UPDATE zmerp_r_salesorder.

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( DocumentDate PostingDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      DATA(ls_header) = lr_header->*.

      " A posting date before the new document date is moved to it
      IF ls_header-DocumentDate IS NOT INITIAL
         AND ls_header-PostingDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_posting_date_valid( iv_doc_date  = ls_header-DocumentDate
                                                            iv_post_date = ls_header-PostingDate ) = abap_false.
        ls_header-PostingDate = ls_header-DocumentDate.
      ENDIF.

      " Only changed headers are updated
      IF ls_header <> lr_header->*.
        APPEND CORRESPONDING #( ls_header ) TO lt_header_update.
      ENDIF.
    ENDLOOP.

    IF lt_header_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
        ENTITY SalesOrder
        UPDATE FIELDS ( PostingDate )
        WITH lt_header_update.
    ENDIF.
  ENDMETHOD.

  METHOD syncItemCurrency.
    DATA lt_items_to_update TYPE TABLE FOR UPDATE zmerp_r_salesorder\\SalesOrderItem.

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( CurrencyCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers)
      ENTITY SalesOrder BY \_Items
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
      MODIFY ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
        ENTITY SalesOrderItem
        UPDATE FIELDS ( CurrencyCode )
        WITH lt_items_to_update.
    ENDIF.
  ENDMETHOD.

  " --- Determinations on save ---
  METHOD assignDocumentNumber.
    DATA lt_so_update TYPE TABLE FOR UPDATE zmerp_r_salesorder.

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( DocumentNumber CompanyCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    " Only documents without a number; without a company no number can be drawn
    " (that case is reported by validateHeaderFields)
    DELETE lt_headers WHERE DocumentNumber IS NOT INITIAL OR CompanyCode IS INITIAL.

    " Numbers per company (the company is the number range subobject); a document left without a number
    " by an NRO error is rejected by validateDocumentNumber
    DATA(lt_numbers) = zcl_merp_num_range_util=>get_doc_numbers(
      is_meta     = zif_merp_constants=>c_so
      it_requests = VALUE #( FOR header IN lt_headers ( HeaderUUID  = header-DocumentUUID
                                                        IsDraft     = header-%is_draft
                                                        CompanyCode = header-CompanyCode ) ) ).

    lt_so_update = VALUE #( FOR number IN lt_numbers ( %is_draft      = number-IsDraft
                                                       DocumentUUID   = number-HeaderUUID
                                                       DocumentNumber = number-DocumentNumber ) ).

    IF lt_so_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
        ENTITY SalesOrder
        UPDATE FIELDS ( DocumentNumber )
        WITH lt_so_update.
    ENDIF.
  ENDMETHOD.

  " --- Validations ---
  METHOD validateHeaderFields.
    DATA lv_has_error TYPE abap_bool.
    DATA lo_message   TYPE REF TO if_abap_behv_message.

    " Clear the messages of the previous validation run
    reported-salesorder = VALUE #(
      BASE reported-salesorder
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

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
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
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>select_company
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
                        %element-CompanyCode = if_abap_behv=>mk-on ) TO reported-salesorder.
      ENDIF.

      " 2. Partner: mandatory, exists, is a customer
      lo_message = COND #(
        WHEN lr_header->BusinessPartnerCode IS INITIAL
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>select_business_partner
                                severity = if_abap_behv_message=>severity-error )
        WHEN NOT line_exists( lt_partners[ PartnerCode = lr_header->BusinessPartnerCode ] )
          THEN NEW zcx_merp_md( textid   = zcx_merp_md=>business_partner_not_found
                                attr1    = CONV string( lr_header->BusinessPartnerCode )
                                severity = if_abap_behv_message=>severity-error )
        WHEN zcl_merp_doc_validator=>is_sd_partner_customer(
               lt_partners[ PartnerCode = lr_header->BusinessPartnerCode ]-IsCustomer ) = abap_false
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>bp_is_not_customer
                                attr1    = CONV string( lr_header->BusinessPartnerCode )
                                severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                         = lr_header->%tky
                        %state_area                  = c_val_partner
                        %msg                         = lo_message
                        %element-BusinessPartnerCode = if_abap_behv=>mk-on ) TO reported-salesorder.
      ENDIF.

      " 3. Warehouse: mandatory, exists, belongs to the company
      lo_message = COND #(
        WHEN lr_header->WarehouseCode IS INITIAL
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>select_warehouse
                                severity = if_abap_behv_message=>severity-error )
        WHEN NOT line_exists( lt_warehouses[ WarehouseCode = lr_header->WarehouseCode ] )
          THEN NEW zcx_merp_md( textid   = zcx_merp_md=>warehouse_not_found
                                attr1    = CONV string( lr_header->WarehouseCode )
                                severity = if_abap_behv_message=>severity-error )
        WHEN lr_header->CompanyCode IS NOT INITIAL
         AND lt_warehouses[ WarehouseCode = lr_header->WarehouseCode ]-CompanyCode <> lr_header->CompanyCode
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>warehouse_company_mismatch
                                attr1    = CONV string( lr_header->WarehouseCode )
                                attr2    = CONV string( lr_header->CompanyCode )
                                severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                   = lr_header->%tky
                        %state_area            = c_val_warehouse
                        %msg                   = lo_message
                        %element-WarehouseCode = if_abap_behv=>mk-on ) TO reported-salesorder.
      ENDIF.

      " 4. Currency: mandatory, equals the company currency
      "    (only the company currency is allowed until currency conversion exists, D1)
      lo_message = COND #(
        WHEN lr_header->CurrencyCode IS INITIAL
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>select_currency
                                severity = if_abap_behv_message=>severity-error )
        WHEN line_exists( lt_companies[ CompanyCode = lr_header->CompanyCode ] )
         AND NOT line_exists( lt_companies[ CompanyCode  = lr_header->CompanyCode
                                            CurrencyCode = lr_header->CurrencyCode ] )
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>currency_not_company
                                attr1    = CONV string( lr_header->CurrencyCode )
                                attr2    = CONV string( lt_companies[ CompanyCode = lr_header->CompanyCode ]-CurrencyCode )
                                severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                  = lr_header->%tky
                        %state_area           = c_val_currency
                        %msg                  = lo_message
                        %element-CurrencyCode = if_abap_behv=>mk-on ) TO reported-salesorder.
      ENDIF.

      " Any error fails the instance
      IF lv_has_error = abap_true.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-salesorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateItemsExist.
    " Clear the messages of the previous validation run
    reported-salesorder = VALUE #(
      BASE reported-salesorder
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_items )
    ).

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder BY \_Items
        FIELDS ( ItemNo )
        WITH CORRESPONDING #( keys )
        LINK DATA(lt_links).

    " A sales order without items is rejected (a purchase order checks it at release)
    LOOP AT keys REFERENCE INTO DATA(lr_key).
      IF line_exists( lt_links[ source-%tky = lr_key->%tky ] ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky        = lr_key->%tky
                      %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-salesorder.

      APPEND VALUE #( %tky        = lr_key->%tky
                      %state_area = c_val_items
                      %msg        = NEW zcx_merp_sd( textid   = zcx_merp_sd=>document_empty_items_invalid
                                                     severity = if_abap_behv_message=>severity-error )
                    ) TO reported-salesorder.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDates.
    DATA lv_has_error TYPE abap_bool.
    DATA lo_message   TYPE REF TO if_abap_behv_message.

    " Clear the messages of the previous validation run
    reported-salesorder = VALUE #(
      BASE reported-salesorder
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_doc_date )
      ( %tky        = key-%tky
        %state_area = c_val_post_date )
    ).

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( DocumentDate PostingDate )
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
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>enter_document_date
                                severity = if_abap_behv_message=>severity-error )
        WHEN zcl_merp_doc_validator=>is_document_date_valid( iv_doc_date = lr_header->DocumentDate
                                                             iv_today    = lv_today ) = abap_false
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>document_date_future_invalid
                                severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                  = lr_header->%tky
                        %state_area           = c_val_doc_date
                        %msg                  = lo_message
                        %element-DocumentDate = if_abap_behv=>mk-on ) TO reported-salesorder.
      ENDIF.

      " 2. Posting date: mandatory, not in the future, not before the document date
      lo_message = COND #(
        WHEN lr_header->PostingDate IS INITIAL
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>enter_posting_date
                                severity = if_abap_behv_message=>severity-error )
        WHEN zcl_merp_doc_validator=>is_posting_date_not_future( iv_post_date = lr_header->PostingDate
                                                                 iv_today     = lv_today ) = abap_false
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>posting_date_future_invalid
                                severity = if_abap_behv_message=>severity-error )
        WHEN lr_header->DocumentDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_posting_date_valid( iv_doc_date  = lr_header->DocumentDate
                                                            iv_post_date = lr_header->PostingDate ) = abap_false
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>posting_date_sequence_invalid
                                severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                 = lr_header->%tky
                        %state_area          = c_val_post_date
                        %msg                 = lo_message
                        %element-PostingDate = if_abap_behv=>mk-on ) TO reported-salesorder.
      ENDIF.

      " Any error fails the instance
      IF lv_has_error = abap_true.
        APPEND VALUE #( %tky        = lr_header->%tky
                        %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-salesorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDocumentNumber.
    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
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
      ) TO failed-salesorder.

      APPEND VALUE #(
        %tky                    = lr_header->%tky
        %msg                    = NEW zcx_merp_sd(
                                    textid   = zcx_merp_sd=>doc_number_generation_failed
                                    severity = if_abap_behv_message=>severity-error )
        %element-DocumentNumber = if_abap_behv=>mk-on
      ) TO reported-salesorder.
    ENDLOOP.
  ENDMETHOD.

  " --- Clearing of validation messages ---
  METHOD clearMessagesForHeaderFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( CompanyCode BusinessPartnerCode WarehouseCode CurrencyCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).
      IF lr_header->CompanyCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_company ) TO reported-salesorder.
      ENDIF.

      IF lr_header->BusinessPartnerCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_partner ) TO reported-salesorder.
      ENDIF.

      IF lr_header->WarehouseCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_warehouse ) TO reported-salesorder.
      ENDIF.

      IF lr_header->CurrencyCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_currency ) TO reported-salesorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD clearMessagesForDates.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    " A message is cleared only when the date passes the checks of validateDates
    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( DocumentDate PostingDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT lt_headers REFERENCE INTO DATA(lr_header).

      " 1. Document date
      IF lr_header->DocumentDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_document_date_valid( iv_doc_date = lr_header->DocumentDate
                                                             iv_today    = lv_today ) = abap_true.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_doc_date ) TO reported-salesorder.
      ENDIF.

      " 2. Posting date
      IF lr_header->PostingDate IS NOT INITIAL AND lr_header->DocumentDate IS NOT INITIAL
         AND zcl_merp_doc_validator=>is_posting_date_not_future( iv_post_date = lr_header->PostingDate
                                                                 iv_today     = lv_today ) = abap_true
         AND zcl_merp_doc_validator=>is_posting_date_valid( iv_doc_date  = lr_header->DocumentDate
                                                            iv_post_date = lr_header->PostingDate ) = abap_true.
        APPEND VALUE #( %tky = lr_header->%tky %state_area = c_val_post_date ) TO reported-salesorder.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

"! Local behavior handler for Sales Order Item child entity.
CLASS lhc_zmerp_r_salesorderitm DEFINITION INHERITING FROM cl_abap_behavior_handler.
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
      IMPORTING keys FOR DELETE SalesOrderItem.

    " --- Determinations on modify ---
    "! Sets item defaults (ItemNo, Currency, UoM, VatCode) based on header and selected ItemCode.
    METHODS setItemDefaults FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR SalesOrderItem~setItemDefaults.

    "! Recalculates net, VAT and gross amounts of the item when quantity or price changes (via ZCL_MERP_DOC_CALC).
    METHODS calcAmountsOnQtyPrice FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR SalesOrderItem~calcAmountsOnQtyPrice.

    "! Recalculates VAT and gross amounts of the item when the VAT code changes; the net amount stays (via ZCL_MERP_DOC_CALC).
    METHODS calcAmountsOnVatCode FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR SalesOrderItem~calcAmountsOnVatCode.

    "! Recalculates total header net and gross amounts (via ZCL_MERP_DOC_CALC) when items are created, changed or deleted.
    METHODS calcHeaderTotals FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR SalesOrderItem~calcHeaderTotals.

    " --- Validations ---
    "! Validates item fields before saving: mandatory values, existence of item and VAT code in master data,
    "! duplicate item codes, positive quantity and price.
    METHODS validateItemFields FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR SalesOrderItem~validateItemFields.

    " --- Clearing of validation messages ---
    "! Clears validation messages of quantity, price, unit of measure and VAT code once the values are valid/filled.
    METHODS clearMessagesForItemFields FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR SalesOrderItem~clearMessagesForItemFields.

    "! Re-evaluates duplicate item code messages for ALL items of the document when an item code changes.
    METHODS handleMessagesOnItemModify FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR SalesOrderItem~handleMessagesOnItemModify.

ENDCLASS.

CLASS lhc_zmerp_r_salesorderitm IMPLEMENTATION.

  " --- Access and state ---
  METHOD precheck_delete.
    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
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
    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
        FIELDS ( HeaderUUID ItemNo ItemCode UnitOfMeasure VatCode CurrencyCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_items)
      ENTITY SalesOrderItem BY \_SalesOrder
        FIELDS ( CurrencyCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " All items of the affected documents: highest used item number per document
    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder BY \_Items
      FIELDS ( HeaderUUID ItemNo )
      WITH CORRESPONDING #( lt_headers )
      RESULT DATA(lt_siblings).

    " Delegate the defaulting to the shared item logic (same for all documents), only changed items are returned
    DATA(lt_changed) = NEW zcl_merp_doc_item_logic( )->set_defaults(
      it_items             = CORRESPONDING #( lt_items MAPPING IsDraft = %is_draft )
      it_siblings          = CORRESPONDING #( lt_siblings MAPPING IsDraft = %is_draft )
      it_header_currencies = CORRESPONDING #( lt_headers MAPPING HeaderUUID = DocumentUUID
                                                                 IsDraft    = %is_draft ) ).

    DATA lt_update TYPE TABLE FOR UPDATE zmerp_r_salesorder\\SalesOrderItem.

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
      MODIFY ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
        ENTITY SalesOrderItem
        UPDATE FIELDS ( ItemNo CurrencyCode UnitOfMeasure VatCode )
        WITH lt_update.
    ENDIF.
  ENDMETHOD.

  METHOD calcAmountsOnQtyPrice.
    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
      FIELDS ( HeaderUUID ItemCode Quantity Price VatCode NetAmount VatAmount GrossAmount )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Delegate the recalculation to the shared item logic (same for all documents), only changed items are returned
    DATA(lt_changed) = NEW zcl_merp_doc_item_logic( )->recalc_on_qty_price(
      CORRESPONDING #( lt_items MAPPING IsDraft = %is_draft ) ).

    DATA lt_items_update TYPE TABLE FOR UPDATE zmerp_r_salesorder\\SalesOrderItem.

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
      MODIFY ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
        ENTITY SalesOrderItem
        UPDATE FIELDS ( NetAmount VatAmount GrossAmount )
        WITH lt_items_update.
    ENDIF.
  ENDMETHOD.

  METHOD calcAmountsOnVatCode.
    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
      FIELDS ( HeaderUUID VatCode NetAmount VatAmount GrossAmount )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Delegate the recalculation to the shared item logic (same for all documents), only changed items are returned
    DATA(lt_changed) = NEW zcl_merp_doc_item_logic( )->recalc_on_vat_code(
      CORRESPONDING #( lt_items MAPPING IsDraft = %is_draft ) ).

    DATA lt_items_update TYPE TABLE FOR UPDATE zmerp_r_salesorder\\SalesOrderItem.

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
      MODIFY ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
        ENTITY SalesOrderItem
        UPDATE FIELDS ( VatAmount GrossAmount )
        WITH lt_items_update.
    ENDIF.
  ENDMETHOD.

  METHOD calcHeaderTotals.
    " Read parent headers of the created/changed items (deleted items can no longer be read)
    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem BY \_SalesOrder
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
    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder BY \_Items
      FIELDS ( HeaderUUID NetAmount VatAmount GrossAmount )
      WITH CORRESPONDING #( lt_headers )
      RESULT DATA(lt_items).

    " Delegate the summation to the shared item logic (same for all documents)
    DATA(lt_totals) = NEW zcl_merp_doc_item_logic( )->calc_header_totals(
      it_header_keys = VALUE #( FOR header IN lt_headers
                                ( HeaderUUID = header-DocumentUUID
                                  IsDraft    = header-%is_draft ) )
      it_items       = CORRESPONDING #( lt_items MAPPING IsDraft = %is_draft ) ).

    DATA lt_so_update TYPE TABLE FOR UPDATE zmerp_r_salesorder.

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
        ) TO lt_so_update.
      ENDIF.
    ENDLOOP.

    IF lt_so_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
        ENTITY SalesOrder
        UPDATE FIELDS ( TotalNetAmount TotalGrossAmount )
        WITH lt_so_update.
    ENDIF.
  ENDMETHOD.

  " --- Validations ---
  METHOD validateItemFields.
    DATA lv_has_error TYPE abap_bool.
    DATA lo_message   TYPE REF TO if_abap_behv_message.

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
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

    reported-salesorderitem = VALUE #(
      BASE reported-salesorderitem
      FOR item IN lt_items
      FOR area IN lt_state_areas
      ( %tky        = item-%tky
        %path       = VALUE #( SalesOrder-%is_draft    = item-%is_draft
                               SalesOrder-DocumentUUID = item-HeaderUUID )
        %state_area = area )
    ).

    " Documents of the checked items: duplicates are searched among all their items
    DATA lt_header_keys TYPE TABLE FOR READ IMPORT zmerp_r_salesorder.
    lt_header_keys = VALUE #(
      FOR GROUPS of <g> IN lt_items GROUP BY ( HeaderUUID = <g>-HeaderUUID
                                               is_draft   = <g>-%is_draft )
      ( %tky-DocumentUUID = <g>-HeaderUUID
        %is_draft         = <g>-%is_draft )
    ).

    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder BY \_Items
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
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>select_item
                                severity = if_abap_behv_message=>severity-error )
        WHEN NOT line_exists( lt_items_master[ ItemCode = lr_item->ItemCode ] )
          THEN NEW zcx_merp_md( textid   = zcx_merp_md=>item_not_found
                                attr1    = CONV string( lr_item->ItemCode )
                                severity = if_abap_behv_message=>severity-error )
        WHEN line_exists( lt_duplicates[ HeaderUUID = lr_item->HeaderUUID
                                         ItemCode   = lr_item->ItemCode ] )
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>item_duplicate_invalid
                                attr1    = CONV string( lr_item->ItemCode )
                                severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky              = lr_item->%tky
                        %path             = VALUE #( SalesOrder-%is_draft    = lr_item->%is_draft
                                                     SalesOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area       = c_val_item_code
                        %msg              = lo_message
                        %element-ItemCode = if_abap_behv=>mk-on ) TO reported-salesorderitem.
      ENDIF.

      " 2. Quantity: greater than zero
      lo_message = COND #(
        WHEN zcl_merp_doc_validator=>is_item_quantity_valid( lr_item->Quantity ) = abap_false
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>quantity_must_be_positive
                                severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky              = lr_item->%tky
                        %path             = VALUE #( SalesOrder-%is_draft    = lr_item->%is_draft
                                                     SalesOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area       = c_val_quantity
                        %msg              = lo_message
                        %element-Quantity = if_abap_behv=>mk-on ) TO reported-salesorderitem.
      ENDIF.

      " 3. Price: greater than zero
      lo_message = COND #(
        WHEN zcl_merp_doc_validator=>is_item_price_valid( lr_item->Price ) = abap_false
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>price_must_be_positive
                                severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky           = lr_item->%tky
                        %path          = VALUE #( SalesOrder-%is_draft    = lr_item->%is_draft
                                                  SalesOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area    = c_val_price
                        %msg           = lo_message
                        %element-Price = if_abap_behv=>mk-on ) TO reported-salesorderitem.
      ENDIF.

      " 4. Unit of measure: mandatory
      lo_message = COND #(
        WHEN lr_item->UnitOfMeasure IS INITIAL
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>select_unit_of_measure
                                severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky                   = lr_item->%tky
                        %path                  = VALUE #( SalesOrder-%is_draft    = lr_item->%is_draft
                                                          SalesOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area            = c_val_uom
                        %msg                   = lo_message
                        %element-UnitOfMeasure = if_abap_behv=>mk-on ) TO reported-salesorderitem.
      ENDIF.

      " 5. VAT code: mandatory, exists
      lo_message = COND #(
        WHEN lr_item->VatCode IS INITIAL
          THEN NEW zcx_merp_sd( textid   = zcx_merp_sd=>select_vat_code
                                severity = if_abap_behv_message=>severity-error )
        WHEN NOT line_exists( lt_vat_rates[ VatCode = lr_item->VatCode ] )
          THEN NEW zcx_merp_md( textid   = zcx_merp_md=>vat_code_not_found
                                attr1    = CONV string( lr_item->VatCode )
                                severity = if_abap_behv_message=>severity-error ) ).

      IF lo_message IS BOUND.
        lv_has_error = abap_true.
        APPEND VALUE #( %tky             = lr_item->%tky
                        %path            = VALUE #( SalesOrder-%is_draft    = lr_item->%is_draft
                                                    SalesOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area      = c_val_vat_code
                        %msg             = lo_message
                        %element-VatCode = if_abap_behv=>mk-on ) TO reported-salesorderitem.
      ENDIF.

      " Any error fails the instance
      IF lv_has_error = abap_true.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %fail-cause = if_abap_behv=>cause-unspecific ) TO failed-salesorderitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " --- Clearing of validation messages ---
  METHOD clearMessagesForItemFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    " A message is cleared once the field is valid or filled
    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
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
                        %path       = VALUE #( SalesOrder-%is_draft    = lr_item->%is_draft
                                               SalesOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_quantity ) TO reported-salesorderitem.
      ENDIF.

      " 2. Price
      IF zcl_merp_doc_validator=>is_item_price_valid( lr_item->Price ) = abap_true.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %path       = VALUE #( SalesOrder-%is_draft    = lr_item->%is_draft
                                               SalesOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_price ) TO reported-salesorderitem.
      ENDIF.

      " 3. Unit of measure
      IF lr_item->UnitOfMeasure IS NOT INITIAL.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %path       = VALUE #( SalesOrder-%is_draft    = lr_item->%is_draft
                                               SalesOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_uom ) TO reported-salesorderitem.
      ENDIF.

      " 4. VAT code
      IF lr_item->VatCode IS NOT INITIAL.
        APPEND VALUE #( %tky        = lr_item->%tky
                        %path       = VALUE #( SalesOrder-%is_draft    = lr_item->%is_draft
                                               SalesOrder-DocumentUUID = lr_item->HeaderUUID )
                        %state_area = c_val_vat_code ) TO reported-salesorderitem.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD handleMessagesOnItemModify.
    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
      FIELDS ( HeaderUUID ItemCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_header_keys TYPE TABLE FOR READ IMPORT zmerp_r_salesorder.

    " Documents of the changed items
    lt_header_keys = VALUE #(
      FOR GROUPS of <g> IN lt_items GROUP BY ( HeaderUUID = <g>-HeaderUUID
                                               is_draft   = <g>-%is_draft )
      ( %tky-DocumentUUID = <g>-HeaderUUID
        %is_draft         = <g>-%is_draft )
    ).

    " All items of these documents: a changed item can create or remove a duplicate on another item
    READ ENTITIES OF zmerp_r_salesorder IN LOCAL MODE
      ENTITY SalesOrder BY \_Items
      FIELDS ( HeaderUUID ItemCode )
      WITH CORRESPONDING #( lt_header_keys )
      RESULT DATA(lt_all_document_items).

    " Duplicate messages of all items are evaluated again
    reported-salesorderitem = VALUE #(
      BASE reported-salesorderitem
      FOR ls_all_item IN lt_all_document_items
      ( %tky        = ls_all_item-%tky
        %path       = VALUE #( SalesOrder-%is_draft    = ls_all_item-%is_draft
                               SalesOrder-DocumentUUID = ls_all_item-HeaderUUID )
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
          %path             = VALUE #( SalesOrder-%is_draft    = lr_doc_item->%is_draft
                                       SalesOrder-DocumentUUID = lr_doc_item->HeaderUUID )
          %state_area       = c_val_item_code
          %msg              = NEW zcx_merp_sd(
                                textid   = zcx_merp_sd=>item_duplicate_invalid
                                attr1    = CONV string( lr_doc_item->ItemCode )
                                severity = if_abap_behv_message=>severity-error )
          %element-ItemCode = if_abap_behv=>mk-on
        ) TO reported-salesorderitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
