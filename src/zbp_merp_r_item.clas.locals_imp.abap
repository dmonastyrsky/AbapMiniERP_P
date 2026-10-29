"! Local behavior handler for Item BO entity.
CLASS lhc_zmerp_r_item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_val_desc  TYPE string VALUE 'VALIDATE_DESCRIPTION',
      c_val_type  TYPE string VALUE 'VALIDATE_ITEM_TYPE',
      c_val_group TYPE string VALUE 'VALIDATE_ITEM_GROUP',
      c_val_vat   TYPE string VALUE 'VALIDATE_DEFAULT_VAT',
      c_val_uom   TYPE string VALUE 'VALIDATE_BASE_UOM'.

    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
      REQUEST requested_authorizations FOR Item
      RESULT result.

    "! Validates mandatory fields before saving.
    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateMandatoryFields.

    "! Clears validation messages for fields that have been filled in.
    METHODS clearMessagesForFilledFields FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~clearMessagesForFilledFields.

    "! Assigns early numbers for new Item entities.
    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE Item.

    "! Pre-checks deletion dependencies in referenced entities.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE Item.

    "! Automatically sets Default VAT Code based on the selected Item Group.
    METHODS setDefaultVatCode FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~setDefaultVatCode.

ENDCLASS.

CLASS lhc_zmerp_r_item IMPLEMENTATION.

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
    reported-item = VALUE #(
      BASE reported-item
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_desc )
      ( %tky        = key-%tky
        %state_area = c_val_type )
      ( %tky        = key-%tky
        %state_area = c_val_group )
      ( %tky        = key-%tky
        %state_area = c_val_vat )
      ( %tky        = key-%tky
        %state_area = c_val_uom )
    ).

    " Read entity fields in local mode to bypass global authorization checks during validation
    READ ENTITIES OF zmerp_r_item IN LOCAL MODE
      ENTITY Item
      FIELDS ( Description ItemTypeCode ItemGroupCode DefaultVatCode BaseUnitOfMeasure )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky ) )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Bulk collect keys for cross-entity master data validation
    DATA(lt_group_keys) = VALUE zif_merp_md_item_group_sel=>tt_item_group_keys(
      FOR item IN lt_items WHERE ( ItemGroupCode IS NOT INITIAL )
      ( ItemGroupCode = item-ItemGroupCode )
    ).
    DATA(lt_vat_keys) = VALUE zif_merp_md_vat_rate_sel=>tt_vat_rate_keys(
      FOR item IN lt_items WHERE ( DefaultVatCode IS NOT INITIAL )
      ( VatCode = item-DefaultVatCode )
    ).

    " Execute optimized bulk selections via Master Data Selector interfaces
    DATA(lt_item_groups) = COND #(
      WHEN lt_group_keys IS NOT INITIAL
      THEN NEW zcl_merp_md_item_group_sel( )->zif_merp_md_item_group_sel~read_item_groups( lt_group_keys ) ).

    DATA(lt_vat_rates) = COND #(
      WHEN lt_vat_keys IS NOT INITIAL
      THEN NEW zcl_merp_md_vat_rate_sel( )->zif_merp_md_vat_rate_sel~read_vat_rates( lt_vat_keys ) ).

    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      lv_has_error = abap_false.

      " 1. Description Mandatory Validation
      IF lr_item->Description IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_item->%tky
          %state_area          = c_val_desc
          %msg                 = NEW zcx_merp_md(
                                   textid   = zcx_merp_md=>enter_item_description
                                   severity = if_abap_behv_message=>severity-error )
          %element-Description = if_abap_behv=>mk-on
        ) TO reported-item.
      ENDIF.

      " 2. Item Type Mandatory Validation
      IF lr_item->ItemTypeCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                  = lr_item->%tky
          %state_area           = c_val_type
          %msg                  = NEW zcx_merp_md(
                                    textid   = zcx_merp_md=>select_item_type
                                    severity = if_abap_behv_message=>severity-error )
          %element-ItemTypeCode = if_abap_behv=>mk-on
        ) TO reported-item.
      ENDIF.

      " 3. Item Group Mandatory & Existence Validation
      IF lr_item->ItemGroupCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                   = lr_item->%tky
          %state_area            = c_val_group
          %msg                   = NEW zcx_merp_md(
                                     textid   = zcx_merp_md=>select_item_group
                                     severity = if_abap_behv_message=>severity-error )
          %element-ItemGroupCode = if_abap_behv=>mk-on
        ) TO reported-item.
      ELSEIF NOT line_exists( lt_item_groups[ ItemGroupCode = lr_item->ItemGroupCode ] ).
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                   = lr_item->%tky
          %state_area            = c_val_group
          %msg                   = NEW zcx_merp_md(
                                     textid   = zcx_merp_md=>item_group_not_found
                                     attr1    = CONV string( lr_item->ItemGroupCode )
                                     severity = if_abap_behv_message=>severity-error )
          %element-ItemGroupCode = if_abap_behv=>mk-on
        ) TO reported-item.
      ENDIF.

      " 4. Default VAT Code Mandatory & Existence Validation
      IF lr_item->DefaultVatCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                    = lr_item->%tky
          %state_area             = c_val_vat
          %msg                    = NEW zcx_merp_md(
                                      textid   = zcx_merp_md=>select_default_vat_code
                                      severity = if_abap_behv_message=>severity-error )
          %element-DefaultVatCode = if_abap_behv=>mk-on
        ) TO reported-item.
      ELSEIF NOT line_exists( lt_vat_rates[ VatCode = lr_item->DefaultVatCode ] ).
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                    = lr_item->%tky
          %state_area             = c_val_vat
          %msg                    = NEW zcx_merp_md(
                                      textid   = zcx_merp_md=>vat_code_not_found
                                      attr1    = CONV string( lr_item->DefaultVatCode )
                                      severity = if_abap_behv_message=>severity-error )
          %element-DefaultVatCode = if_abap_behv=>mk-on
        ) TO reported-item.
      ENDIF.

      " 5. Base Unit of Measure Mandatory Validation
      IF lr_item->BaseUnitOfMeasure IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                       = lr_item->%tky
          %state_area                = c_val_uom
          %msg                       = NEW zcx_merp_md(
                                         textid   = zcx_merp_md=>select_base_unit
                                         severity = if_abap_behv_message=>severity-error )
          %element-BaseUnitOfMeasure = if_abap_behv=>mk-on
        ) TO reported-item.
      ENDIF.

      " If any business validation failed, prevent transaction save state
      IF lv_has_error = abap_true.
        APPEND VALUE #(
          %tky        = lr_item->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD clearMessagesForFilledFields.

    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zmerp_r_item IN LOCAL MODE
      ENTITY Item
      FIELDS ( Description ItemTypeCode ItemGroupCode DefaultVatCode BaseUnitOfMeasure )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      IF lr_item->Description IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_item->%tky %state_area = c_val_desc ) TO reported-item.
      ENDIF.
      IF lr_item->ItemTypeCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_item->%tky %state_area = c_val_type ) TO reported-item.
      ENDIF.
      IF lr_item->ItemGroupCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_item->%tky %state_area = c_val_group ) TO reported-item.
      ENDIF.
      IF lr_item->DefaultVatCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_item->%tky %state_area = c_val_vat ) TO reported-item.
      ENDIF.
      IF lr_item->BaseUnitOfMeasure IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_item->%tky %state_area = c_val_uom ) TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_create.
    IF entities IS INITIAL.
      RETURN.
    ENDIF.

    DATA lx_nro_error TYPE REF TO cx_root.
    DATA lt_codes     TYPE string_table.

    " Step 1: Count entities requiring key generation using the secondary key
    DATA(lv_needed_count) = REDUCE i( INIT count = 0
                                       FOR entity IN entities USING KEY entity
                                       WHERE ( ItemCode IS INITIAL )
                                       NEXT count += 1 ).

    " Step 2: Bulk allocation via NRO utility with exception capture
    IF lv_needed_count > 0.
      TRY.
          lt_codes = zcl_merp_num_range_util=>get_next_item_codes_nro( iv_count = lv_needed_count ).
        CATCH cx_number_ranges cx_root INTO lx_nro_error.
          CLEAR lt_codes.
      ENDTRY.
    ENDIF.

    DATA(lv_index) = 1.

    " Step 3: Map keys to instances safely
    LOOP AT entities REFERENCE INTO DATA(lr_entity).
      IF lr_entity->ItemCode IS INITIAL.
        READ TABLE lt_codes INDEX lv_index ASSIGNING FIELD-SYMBOL(<lv_code>).

        IF sy-subrc = 0 AND <lv_code> IS NOT INITIAL.
          " Map successfully generated key
          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            ItemCode  = CONV #( <lv_code> )
          ) TO mapped-item.

          " Increment index ONLY after processing an auto-numbered entity
          lv_index += 1.
        ELSE.
          " Mark entity failure
          APPEND VALUE #(
            %cid        = lr_entity->%cid
            %is_draft   = lr_entity->%is_draft
            %fail-cause = if_abap_behv=>cause-unspecific
          ) TO failed-item.

          " Report error with root cause exception reference if available
          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            %msg      = NEW zcx_merp_md(
                          textid   = zcx_merp_md=>item_generation_failed
                          previous = lx_nro_error
                          severity = if_abap_behv_message=>severity-error )
          ) TO reported-item.
        ENDIF.
      ELSE.
        " Retain explicitly provided code without affecting lt_codes indexing
        APPEND VALUE #(
          %cid      = lr_entity->%cid
          %is_draft = lr_entity->%is_draft
          ItemCode  = lr_entity->ItemCode
        ) TO mapped-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD precheck_delete.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_key,
             itemcode TYPE zmerp_item_code,
           END OF ty_key.

    TYPES: BEGIN OF ty_dependency,
             itemcode     TYPE zmerp_item_code,
             usedinentity TYPE zmerp_entity_name,
           END OF ty_dependency.

    DATA lt_keys TYPE SORTED TABLE OF ty_key WITH NON-UNIQUE KEY itemcode.
    DATA lt_dependencies TYPE SORTED TABLE OF ty_dependency WITH NON-UNIQUE KEY itemcode.
    DATA lv_failed_added TYPE abap_bool.

    " Collect key values and remove potential duplicates to optimize SQL predicate standard
    lt_keys = VALUE #( FOR key IN keys WHERE ( ItemCode IS NOT INITIAL ) ( itemcode = key-ItemCode ) ).
    DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING itemcode.

    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    " Bulk check database dependencies for collected key set
    SELECT DISTINCT
           usage~ItemCode     AS itemcode,
           usage~UsedInEntity AS usedinentity
      FROM zmerp_i_item_usage AS usage
      INNER JOIN @lt_keys AS key ON usage~ItemCode = key~itemcode
      INTO TABLE @lt_dependencies.

    IF lt_dependencies IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT keys REFERENCE INTO DATA(lr_key).
      lv_failed_added = abap_false.

      " ABAP runtime automatically performs a highly efficient binary boundary scan here
      LOOP AT lt_dependencies REFERENCE INTO DATA(lr_dep)
        WHERE itemcode = lr_key->ItemCode.

        " Record entity failure state ONCE per key
        IF lv_failed_added = abap_false.
          APPEND VALUE #(
            %tky        = lr_key->%tky
            %fail-cause = if_abap_behv=>cause-dependency
          ) TO failed-item.
          lv_failed_added = abap_true.
        ENDIF.

        " Report explicit dependency error message to UI
        APPEND VALUE #(
          %tky             = lr_key->%tky
          %element-ItemCode = if_abap_behv=>mk-on
          %msg             = NEW zcx_merp_md(
                                 textid   = zcx_merp_md=>item_in_use
                                 attr1    = CONV #( lr_dep->itemcode )
                                 attr2    = CONV #( lr_dep->usedinentity )
                                 severity = if_abap_behv_message=>severity-error )
        ) TO reported-item.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD setDefaultVatCode.
    " Read entity fields in local mode to bypass global authorization checks during validation
    READ ENTITIES OF zmerp_r_item IN LOCAL MODE
      ENTITY Item
      FIELDS ( ItemGroupCode DefaultVatCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    IF items IS INITIAL.
      RETURN.
    ENDIF.

    " Collect unique item group keys using the correct standard structure for the selector
    DATA(item_group_keys) = VALUE zif_merp_md_item_group_sel=>tt_item_group_keys(
      FOR item IN items WHERE ( ItemGroupCode IS NOT INITIAL )
      ( ItemGroupCode = item-ItemGroupCode )
    ).

    IF item_group_keys IS INITIAL.
      RETURN.
    ENDIF.

    " Read item groups master data by calling the selector directly in one line
    DATA(item_groups) = NEW zcl_merp_md_item_group_sel( )->zif_merp_md_item_group_sel~read_item_groups( item_group_keys ).

    IF item_groups IS INITIAL.
      RETURN.
    ENDIF.

    DATA items_to_update TYPE TABLE FOR UPDATE zmerp_r_item.

    " Map default VAT code from item groups back to items (overwrite only if values differ)
    LOOP AT items REFERENCE INTO DATA(lr_item) WHERE ItemGroupCode IS NOT INITIAL.
      ASSIGN item_groups[ ItemGroupCode = lr_item->ItemGroupCode ] TO FIELD-SYMBOL(<item_group>).

      IF sy-subrc = 0
         AND <item_group>-DefaultVatCode IS NOT INITIAL
         AND lr_item->DefaultVatCode <> <item_group>-DefaultVatCode.

        APPEND VALUE #(
          %tky           = lr_item->%tky
          DefaultVatCode = <item_group>-DefaultVatCode
        ) TO items_to_update.
      ENDIF.
    ENDLOOP.

    " Perform mass local update on RAP business object only if changes exist
    IF items_to_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_item IN LOCAL MODE
        ENTITY Item
        UPDATE FIELDS ( DefaultVatCode )
        WITH items_to_update.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
