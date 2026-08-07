"! Local behavior handler for Warehouse BO entity.
CLASS lhc_zmerp_r_warehouse DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_state_area_mandatory TYPE string VALUE 'VALIDATE_MANDATORY',
      c_state_area_company   TYPE string VALUE 'VALIDATE_COMPANY'.

    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR Warehouse
        RESULT result.

    "! Validates mandatory fields before saving.
    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR Warehouse~validateMandatoryFields.

    "! Validates the existence of the assigned Company Code.
    METHODS validateCompanyCode FOR VALIDATE ON SAVE
      IMPORTING keys FOR Warehouse~validateCompanyCode.

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
        %state_area = c_state_area_mandatory )
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

    LOOP AT lt_warehouses REFERENCE INTO DATA(lr_whse).
      lv_has_error = abap_false.

      IF lr_whse->WarehouseName IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                   = lr_whse->%tky
          %state_area           = c_state_area_mandatory
          %msg                  = NEW zcm_merp_messages(
                                    textid   = zcm_merp_messages=>enter_warehouse_name
                                    severity = if_abap_behv_message=>severity-error )
          %element-WarehouseName = if_abap_behv=>mk-on
        ) TO reported-warehouse.
      ENDIF.

      IF lr_whse->CompanyCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                  = lr_whse->%tky
          %state_area           = c_state_area_mandatory
          %msg                  = NEW zcm_merp_messages(
                                    textid   = zcm_merp_messages=>enter_company_code
                                    severity = if_abap_behv_message=>severity-error )
          %element-CompanyCode  = if_abap_behv=>mk-on
        ) TO reported-warehouse.
      ENDIF.

      IF lv_has_error = abap_true.
        " Mark entity instance as failed to prevent transaction commit
        APPEND VALUE #(
          %tky        = lr_whse->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-warehouse.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateCompanyCode.
    " Clear previous validation messages for this state area to prevent duplicate errors in UI
    reported-warehouse = VALUE #(
      BASE reported-warehouse
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_state_area_company )
    ).

    " Read entity fields in local mode to bypass global authorization checks during validation
    READ ENTITIES OF zmerp_r_warehouse IN LOCAL MODE
      ENTITY Warehouse
      FIELDS ( CompanyCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_warehouses).

    TYPES: BEGIN OF ty_company_code,
             companycode TYPE zmerp_company_code,
           END OF ty_company_code.

    DATA lt_companies_to_check TYPE SORTED TABLE OF ty_company_code WITH NON-UNIQUE KEY companycode.

    lt_companies_to_check = VALUE #(
      FOR <whse_src> IN lt_warehouses
      WHERE ( CompanyCode IS NOT INITIAL )
      ( companycode = <whse_src>-CompanyCode )
    ).

    IF lt_companies_to_check IS INITIAL.
      RETURN.
    ENDIF.

    " Eliminate duplicates to optimize DB call and prevent potential dumps
    DELETE ADJACENT DUPLICATES FROM lt_companies_to_check COMPARING companycode.

    " Privileged access bypasses DCL rules to check existence regardless of user access restrictions
    SELECT DISTINCT CompanyCode AS companycode
      FROM zmerp_r_company_code WITH PRIVILEGED ACCESS
      FOR ALL ENTRIES IN @lt_companies_to_check
      WHERE CompanyCode = @lt_companies_to_check-companycode
      INTO TABLE @DATA(lt_existing_db).

    LOOP AT lt_warehouses REFERENCE INTO DATA(lr_whse) WHERE CompanyCode IS NOT INITIAL.
      " Binary search is performed automatically and faster because lt_existing_db has a unique key
      IF NOT line_exists( lt_existing_db[ companycode = lr_whse->CompanyCode ] ).
        " Mark entity instance as failed due to missing foreign key relationship
        APPEND VALUE #(
          %tky        = lr_whse->%tky
          %fail-cause = if_abap_behv=>cause-not_found
        ) TO failed-warehouse.

        APPEND VALUE #(
          %tky                 = lr_whse->%tky
          %state_area          = c_state_area_company
          %msg                 = NEW zcm_merp_messages(
                                   textid   = zcm_merp_messages=>company_code_not_found
                                   attr1    = CONV #( lr_whse->CompanyCode )
                                   severity = if_abap_behv_message=>severity-error )
          %element-CompanyCode = if_abap_behv=>mk-on
        ) TO reported-warehouse.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_create.
    IF entities IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT entities REFERENCE INTO DATA(lr_entity).
      IF lr_entity->WarehouseCode IS INITIAL.

        DATA(lv_next_wh_code) = VALUE string( ).

        TRY.
            lv_next_wh_code = zcl_merp_num_range_util=>get_next_warehouse_code_nro( ).
          CATCH cx_number_ranges.
            CLEAR lv_next_wh_code.
        ENDTRY.

        IF lv_next_wh_code IS NOT INITIAL.
          " Map generated business key to the draft/content creation ID (%cid)
          APPEND VALUE #(
            %cid          = lr_entity->%cid
            %is_draft     = lr_entity->%is_draft
            WarehouseCode = lv_next_wh_code
          ) TO mapped-warehouse.
        ELSE.
          APPEND VALUE #(
            %cid        = lr_entity->%cid
            %is_draft   = lr_entity->%is_draft
            %fail-cause = if_abap_behv=>cause-unspecific
          ) TO failed-warehouse.

          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            %msg      = NEW zcm_merp_messages(
                          textid   = zcm_merp_messages=>warehouse_number_failed
                          severity = if_abap_behv_message=>severity-error )
          ) TO reported-warehouse.
        ENDIF.
      ELSE.
        " Preserve user-provided key if supplied during creation
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
          %msg                  = NEW zcm_merp_messages(
                                      textid   = zcm_merp_messages=>warehouse_in_use
                                      attr1    = CONV #( lr_dep->warehousecode )
                                      attr2    = CONV #( lr_dep->usedinentity )
                                      severity = if_abap_behv_message=>severity-error )
        ) TO reported-warehouse.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
