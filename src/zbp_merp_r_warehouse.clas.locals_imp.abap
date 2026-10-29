"! Local behavior handler for Warehouse BO entity.
CLASS lhc_zmerp_r_warehouse DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_val_name    TYPE string VALUE 'VALIDATE_WAREHOUSE_NAME',
      c_val_company TYPE string VALUE 'VALIDATE_COMPANY_CODE'.

    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
      REQUEST requested_authorizations FOR Warehouse
      RESULT result.

    "! Validates mandatory fields before saving.
    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR Warehouse~validateMandatoryFields.

    "! Clears validation messages for fields that have been filled in.
    METHODS clearMessagesForFilledFields FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Warehouse~clearMessagesForFilledFields.

    "! Pre-checks deletion dependencies in referenced entities.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE Warehouse.

    "! Assigns early numbers for new Warehouse entities.
    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE Warehouse.
ENDCLASS.

CLASS lhc_zmerp_r_warehouse IMPLEMENTATION.

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

  METHOD validateMandatoryFields.
    DATA lv_has_error TYPE abap_bool.

    " Clear previous validation messages for this state area to prevent duplicate errors in UI
    reported-warehouse = VALUE #(
      BASE reported-warehouse
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_name )
      ( %tky        = key-%tky
        %state_area = c_val_company )
    ).

    " Read entity fields in local mode to bypass global authorization checks during validation
    READ ENTITIES OF zmerp_r_warehouse IN LOCAL MODE
      ENTITY Warehouse
      FIELDS ( WarehouseName CompanyCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_warehouses).

    IF lt_warehouses IS INITIAL.
      RETURN.
    ENDIF.

    " Bulk collect keys for cross-entity master data validation to eliminate DB roundtrips
    DATA(lt_company_keys) = VALUE zif_merp_md_comp_code_sel=>tt_company_keys(
      FOR whse IN lt_warehouses WHERE ( CompanyCode IS NOT INITIAL )
      ( CompanyCode = whse-CompanyCode )
    ).

    " Execute optimized bulk selection via Master Data Selector interface regardless of user restrictions
    DATA(lt_companies) = COND #(
      WHEN lt_company_keys IS NOT INITIAL
      THEN NEW zcl_merp_md_comp_code_sel( )->zif_merp_md_comp_code_sel~read_companies( lt_company_keys ) ).

    LOOP AT lt_warehouses REFERENCE INTO DATA(lr_whse).
      lv_has_error = abap_false.

      " 1. Warehouse Name Mandatory Validation
      IF lr_whse->WarehouseName IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                   = lr_whse->%tky
          %state_area           = c_val_name
          %msg                  = NEW zcx_merp_md(
                                    textid   = zcx_merp_md=>enter_warehouse_name
                                    severity = if_abap_behv_message=>severity-error )
          %element-WarehouseName = if_abap_behv=>mk-on
        ) TO reported-warehouse.
      ENDIF.

      " 2. Company Code Mandatory & Existence Validation
      IF lr_whse->CompanyCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                  = lr_whse->%tky
          %state_area           = c_val_company
          %msg                  = NEW zcx_merp_md(
                                    textid   = zcx_merp_md=>select_company
                                    severity = if_abap_behv_message=>severity-error )
          %element-CompanyCode  = if_abap_behv=>mk-on
        ) TO reported-warehouse.
      ELSEIF NOT line_exists( lt_companies[ CompanyCode = lr_whse->CompanyCode ] ).
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_whse->%tky
          %state_area          = c_val_company
          %msg                 = NEW zcx_merp_md(
                                   textid   = zcx_merp_md=>company_code_not_found
                                   attr1    = CONV string( lr_whse->CompanyCode )
                                   severity = if_abap_behv_message=>severity-error )
          %element-CompanyCode = if_abap_behv=>mk-on
        ) TO reported-warehouse.
      ENDIF.

      " If any validation failed, prevent transaction commit
      IF lv_has_error = abap_true.
        APPEND VALUE #(
          %tky        = lr_whse->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-warehouse.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD clearMessagesForFilledFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    " Read entity fields in local mode identically to the Item BO logic
    READ ENTITIES OF zmerp_r_warehouse IN LOCAL MODE
      ENTITY Warehouse
      FIELDS ( WarehouseName CompanyCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_warehouses).

    LOOP AT lt_warehouses REFERENCE INTO DATA(lr_whse).
      " Clear message area for Warehouse Name if it is filled
      IF lr_whse->WarehouseName IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_whse->%tky %state_area = c_val_name ) TO reported-warehouse.
      ENDIF.

      " Clear message area for Company Code if it is filled
      IF lr_whse->CompanyCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_whse->%tky %state_area = c_val_company ) TO reported-warehouse.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_create.
    IF entities IS INITIAL.
      RETURN.
    ENDIF.

    DATA lx_nro_error    TYPE REF TO cx_root.
    DATA lt_codes        TYPE string_table.

    " Step 1: Count entities requiring key generation using the secondary key
    DATA(lv_needed_count) = REDUCE i( INIT count = 0
                                  FOR entity IN entities USING KEY entity
                                  WHERE ( WarehouseCode IS INITIAL )
                                  NEXT count += 1 ).

    " Step 2: Bulk allocation via NRO utility with exception capture
    IF lv_needed_count > 0.
      TRY.
          lt_codes = zcl_merp_num_range_util=>get_next_wh_codes_nro( iv_count = lv_needed_count ).
        CATCH cx_number_ranges cx_root INTO lx_nro_error.
          CLEAR lt_codes.
      ENDTRY.
    ENDIF.

    DATA(lv_index) = 1.

    " Step 3: Map keys to instances safely
    LOOP AT entities REFERENCE INTO DATA(lr_entity).
      IF lr_entity->WarehouseCode IS INITIAL.
        READ TABLE lt_codes INDEX lv_index ASSIGNING FIELD-SYMBOL(<lv_code>).

        IF sy-subrc = 0 AND <lv_code> IS NOT INITIAL.
          " Map successfully generated key
          APPEND VALUE #(
            %cid          = lr_entity->%cid
            %is_draft     = lr_entity->%is_draft
            WarehouseCode = CONV #( <lv_code> )
          ) TO mapped-warehouse.

          " Increment index ONLY after processing an auto-numbered entity
          lv_index += 1.
        ELSE.
          " Mark entity failure
          APPEND VALUE #(
            %cid        = lr_entity->%cid
            %is_draft   = lr_entity->%is_draft
            %fail-cause = if_abap_behv=>cause-unspecific
          ) TO failed-warehouse.

          " Report error with root cause exception reference if available
          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            %msg      = NEW zcx_merp_md(
                          textid   = zcx_merp_md=>warehouse_generation_failed
                          previous = lx_nro_error
                          severity = if_abap_behv_message=>severity-error )
          ) TO reported-warehouse.
        ENDIF.
      ELSE.
        " Retain explicitly provided code without affecting lt_codes indexing
        APPEND VALUE #(
          %cid          = lr_entity->%cid
          %is_draft     = lr_entity->%is_draft
          WarehouseCode = lr_entity->WarehouseCode
        ) TO mapped-warehouse.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD precheck_delete.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_key,
             warehousecode TYPE zmerp_warehouse_code,
           END OF ty_key.

    TYPES: BEGIN OF ty_dependency,
             warehousecode TYPE zmerp_warehouse_code,
             usedinentity  TYPE zmerp_entity_name,
           END OF ty_dependency.

    DATA lt_keys TYPE SORTED TABLE OF ty_key WITH NON-UNIQUE KEY warehousecode.
    DATA lt_dependencies TYPE SORTED TABLE OF ty_dependency WITH NON-UNIQUE KEY warehousecode.
    DATA lv_failed_added TYPE abap_bool.

    " Collect key values and remove potential duplicates to optimize SQL predicate standard
    lt_keys = VALUE #( FOR key IN keys WHERE ( WarehouseCode IS NOT INITIAL ) ( warehousecode = key-WarehouseCode ) ).
    DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING warehousecode.

    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    " Bulk check database dependencies for collected key set
    SELECT DISTINCT
           usage~WarehouseCode AS warehousecode,
           usage~UsedInEntity  AS usedinentity
      FROM zmerp_i_warehouse_usage AS usage
      INNER JOIN @lt_keys AS key ON usage~WarehouseCode = key~warehousecode
      INTO TABLE @lt_dependencies.

    IF lt_dependencies IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT keys REFERENCE INTO DATA(lr_key).
      lv_failed_added = abap_false.

      " ABAP runtime automatically performs a highly efficient binary boundary scan here
      LOOP AT lt_dependencies REFERENCE INTO DATA(lr_dep)
        WHERE warehousecode = lr_key->WarehouseCode.

        " Record entity failure state ONCE per key
        IF lv_failed_added = abap_false.
          APPEND VALUE #(
            %tky        = lr_key->%tky
            %fail-cause = if_abap_behv=>cause-dependency
          ) TO failed-warehouse.
          lv_failed_added = abap_true.
        ENDIF.

        " Report explicit dependency error message to UI
        APPEND VALUE #(
          %tky                  = lr_key->%tky
          %element-WarehouseCode = if_abap_behv=>mk-on
          %msg                  = NEW zcx_merp_md(
                                      textid   = zcx_merp_md=>warehouse_in_use
                                      attr1    = CONV #( lr_dep->warehousecode )
                                      attr2    = CONV #( lr_dep->usedinentity )
                                      severity = if_abap_behv_message=>severity-error )
        ) TO reported-warehouse.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
