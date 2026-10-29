"! Local behavior handler for Item Group BO entity.
CLASS lhc_zmerp_r_item_group DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_val_desc TYPE string VALUE 'VALIDATE_DESCRIPTION',
      c_val_vat  TYPE string VALUE 'VALIDATE_DEFAULT_VAT'.

    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations FOR ItemGroup
        RESULT result.

    "! Validates mandatory fields before saving.
    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR ItemGroup~validateMandatoryFields.

    "! Assigns early numbers for new Item Group entities.
    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE ItemGroup.

    "! Clears validation messages for fields that have been filled in.
    METHODS clearMessagesForFilledFields FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ItemGroup~clearMessagesForFilledFields.

    "! Pre-checks deletion dependencies in referenced entities.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE ItemGroup.

ENDCLASS.

CLASS lhc_zmerp_r_item_group IMPLEMENTATION.

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

    " Clear previous validation messages for individual state areas to prevent duplicate errors in UI
    reported-itemgroup = VALUE #(
      BASE reported-itemgroup
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_desc )
      ( %tky        = key-%tky
        %state_area = c_val_vat )
    ).

    " Read entity fields in local mode to bypass global authorization checks during validation
    READ ENTITIES OF zmerp_r_item_group IN LOCAL MODE
      ENTITY ItemGroup
      FIELDS ( Description DefaultVatCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_groups).

    IF lt_groups IS INITIAL.
      RETURN.
    ENDIF.

    " Bulk collect VAT rate master data keys for cross-entity business validation
    DATA(lt_vat_keys) = VALUE zif_merp_md_vat_rate_sel=>tt_vat_rate_keys(
      FOR grp IN lt_groups WHERE ( DefaultVatCode IS NOT INITIAL )
      ( VatCode = grp-DefaultVatCode )
    ).

    " Execute optimized bulk selection via VAT Rate Master Data Selector interface
    DATA(lt_vat_rates) = COND #(
      WHEN lt_vat_keys IS NOT INITIAL
      THEN NEW zcl_merp_md_vat_rate_sel( )->zif_merp_md_vat_rate_sel~read_vat_rates( lt_vat_keys ) ).

    LOOP AT lt_groups REFERENCE INTO DATA(lr_group).
      lv_has_error = abap_false.

      " 1. Item Group Description Mandatory Validation
      IF lr_group->Description IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_group->%tky
          %state_area          = c_val_desc
          %msg                 = NEW zcx_merp_md(
                                   textid   = zcx_merp_md=>enter_item_group_description
                                   severity = if_abap_behv_message=>severity-error )
          %element-Description = if_abap_behv=>mk-on
        ) TO reported-itemgroup.
      ENDIF.

      " 2. Default VAT Code Mandatory & Existence Validation
      IF lr_group->DefaultVatCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                    = lr_group->%tky
          %state_area             = c_val_vat
          %msg                    = NEW zcx_merp_md(
                                      textid   = zcx_merp_md=>select_default_vat_code
                                      severity = if_abap_behv_message=>severity-error )
          %element-DefaultVatCode = if_abap_behv=>mk-on
        ) TO reported-itemgroup.
      ELSEIF NOT line_exists( lt_vat_rates[ VatCode = lr_group->DefaultVatCode ] ).
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                    = lr_group->%tky
          %state_area             = c_val_vat
          %msg                    = NEW zcx_merp_md(
                                      textid   = zcx_merp_md=>vat_code_not_found
                                      attr1    = CONV string( lr_group->DefaultVatCode )
                                      severity = if_abap_behv_message=>severity-error )
          %element-DefaultVatCode = if_abap_behv=>mk-on
        ) TO reported-itemgroup.
      ENDIF.

      " If any business validation failed, prevent transaction commit
      IF lv_has_error = abap_true.
        APPEND VALUE #(
          %tky        = lr_group->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-itemgroup.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD clearMessagesForFilledFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    " Read entity state in local mode
    READ ENTITIES OF zmerp_r_item_group IN LOCAL MODE
      ENTITY ItemGroup
      FIELDS ( Description DefaultVatCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_groups).

    LOOP AT lt_groups REFERENCE INTO DATA(lr_group).
      " Clear message area for Description
      IF lr_group->Description IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_group->%tky %state_area = c_val_desc ) TO reported-itemgroup.
      ENDIF.

      " Clear message area for Default VAT Code
      IF lr_group->DefaultVatCode IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_group->%tky %state_area = c_val_vat ) TO reported-itemgroup.
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
                                       WHERE ( ItemGroupCode IS INITIAL )
                                       NEXT count += 1 ).

    " Step 2: Bulk allocation via NRO utility with exception capture
    IF lv_needed_count > 0.
      TRY.
          lt_codes = zcl_merp_num_range_util=>get_next_item_grp_codes_nro( iv_count = lv_needed_count ).
        CATCH cx_number_ranges cx_root INTO lx_nro_error.
          CLEAR lt_codes.
      ENDTRY.
    ENDIF.

    DATA(lv_index) = 1.

    " Step 3: Map keys to instances safely
    LOOP AT entities REFERENCE INTO DATA(lr_entity).
      IF lr_entity->ItemGroupCode IS INITIAL.
        READ TABLE lt_codes INDEX lv_index ASSIGNING FIELD-SYMBOL(<lv_code>).

        IF sy-subrc = 0 AND <lv_code> IS NOT INITIAL.
          " Map successfully generated key
          APPEND VALUE #(
            %cid          = lr_entity->%cid
            %is_draft     = lr_entity->%is_draft
            ItemGroupCode = CONV #( <lv_code> )
          ) TO mapped-itemgroup.

          " Increment index ONLY after processing an auto-numbered entity
          lv_index += 1.
        ELSE.
          " Mark entity failure
          APPEND VALUE #(
            %cid        = lr_entity->%cid
            %is_draft   = lr_entity->%is_draft
            %fail-cause = if_abap_behv=>cause-unspecific
          ) TO failed-itemgroup.

          " Report error with root cause exception reference if available
          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            %msg      = NEW zcx_merp_md(
                          textid   = zcx_merp_md=>item_group_generation_failed
                          previous = lx_nro_error
                          severity = if_abap_behv_message=>severity-error )
          ) TO reported-itemgroup.
        ENDIF.
      ELSE.
        " Retain explicitly provided code without affecting lt_codes indexing
        APPEND VALUE #(
          %cid          = lr_entity->%cid
          %is_draft     = lr_entity->%is_draft
          ItemGroupCode = lr_entity->ItemGroupCode
        ) TO mapped-itemgroup.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD precheck_delete.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_key,
             itemgroupcode TYPE zmerp_item_group_code,
           END OF ty_key.

    TYPES: BEGIN OF ty_dependency,
             itemgroupcode TYPE zmerp_item_group_code,
             usedinentity  TYPE zmerp_entity_name,
           END OF ty_dependency.

    DATA lt_keys TYPE SORTED TABLE OF ty_key WITH NON-UNIQUE KEY itemgroupcode.
    DATA lt_dependencies TYPE SORTED TABLE OF ty_dependency WITH NON-UNIQUE KEY itemgroupcode.
    DATA lv_failed_added TYPE abap_bool.

    " Collect key values and remove potential duplicates to optimize SQL predicate standard
    lt_keys = VALUE #( FOR key IN keys WHERE ( ItemGroupCode IS NOT INITIAL ) ( itemgroupcode = key-ItemGroupCode ) ).
    DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING itemgroupcode.

    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    " Bulk check database dependencies for collected key set
    SELECT DISTINCT
           usage~ItemGroupCode AS itemgroupcode,
           usage~UsedInEntity  AS usedinentity
      FROM zmerp_i_item_group_usage AS usage
      INNER JOIN @lt_keys AS key ON usage~ItemGroupCode = key~itemgroupcode
      INTO TABLE @lt_dependencies.

    IF lt_dependencies IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT keys REFERENCE INTO DATA(lr_key).
      lv_failed_added = abap_false.

      " ABAP runtime automatically performs a highly efficient binary boundary scan here
      LOOP AT lt_dependencies REFERENCE INTO DATA(lr_dep)
        WHERE itemgroupcode = lr_key->ItemGroupCode.

        " Record entity failure state ONCE per key
        IF lv_failed_added = abap_false.
          APPEND VALUE #(
            %tky        = lr_key->%tky
            %fail-cause = if_abap_behv=>cause-dependency
          ) TO failed-itemgroup.
          lv_failed_added = abap_true.
        ENDIF.

        " Report explicit dependency error message to UI
        APPEND VALUE #(
          %tky                   = lr_key->%tky
          %element-ItemGroupCode = if_abap_behv=>mk-on
          %msg                   = NEW zcx_merp_md(
                                      textid   = zcx_merp_md=>item_group_in_use
                                      attr1    = CONV #( lr_dep->itemgroupcode )
                                      attr2    = CONV #( lr_dep->usedinentity )
                                      severity = if_abap_behv_message=>severity-error )
        ) TO reported-itemgroup.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
