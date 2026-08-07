"! Local behavior handler for Item BO entity.
CLASS lhc_zmerp_r_item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_state_area_mandatory TYPE string VALUE 'VALIDATE_MANDATORY'.

    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING
      REQUEST requested_authorizations FOR Item
      RESULT result.

    "! Validates mandatory fields before saving.
    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateMandatoryFields.

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
        %state_area = c_state_area_mandatory )
    ).

    " Read entity fields in local mode to bypass global authorization checks during validation
    READ ENTITIES OF zmerp_r_item IN LOCAL MODE
      ENTITY Item
      FIELDS ( Description ItemTypeCode ItemGroupCode DefaultVatCode BaseUnitOfMeasure )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_items REFERENCE INTO DATA(lr_item).
      lv_has_error = abap_false.

      IF lr_item->Description IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_item->%tky
          %state_area          = c_state_area_mandatory
          %msg                 = NEW zcm_merp_messages(
                                   textid   = zcm_merp_messages=>enter_item_desc
                                   severity = if_abap_behv_message=>severity-error )
          %element-Description = if_abap_behv=>mk-on
        ) TO reported-item.
      ENDIF.

      IF lr_item->ItemTypeCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                  = lr_item->%tky
          %state_area           = c_state_area_mandatory
          %msg                  = NEW zcm_merp_messages(
                                    textid   = zcm_merp_messages=>select_item_type
                                    severity = if_abap_behv_message=>severity-error )
          %element-ItemTypeCode = if_abap_behv=>mk-on
        ) TO reported-item.
      ENDIF.

      IF lr_item->ItemGroupCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                   = lr_item->%tky
          %state_area            = c_state_area_mandatory
          %msg                   = NEW zcm_merp_messages(
                                     textid   = zcm_merp_messages=>select_item_group
                                     severity = if_abap_behv_message=>severity-error )
          %element-ItemGroupCode = if_abap_behv=>mk-on
        ) TO reported-item.
      ENDIF.

      IF lr_item->DefaultVatCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                    = lr_item->%tky
          %state_area             = c_state_area_mandatory
          %msg                    = NEW zcm_merp_messages(
                                      textid   = zcm_merp_messages=>select_default_vat_code
                                      severity = if_abap_behv_message=>severity-error )
          %element-DefaultVatCode = if_abap_behv=>mk-on
        ) TO reported-item.
      ENDIF.

      IF lr_item->BaseUnitOfMeasure IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                       = lr_item->%tky
          %state_area                = c_state_area_mandatory
          %msg                       = NEW zcm_merp_messages(
                                         textid   = zcm_merp_messages=>select_base_unit
                                         severity = if_abap_behv_message=>severity-error )
          %element-BaseUnitOfMeasure = if_abap_behv=>mk-on
        ) TO reported-item.
      ENDIF.

      IF lv_has_error = abap_true.
        " Mark entity instance as failed to prevent transaction commit
        APPEND VALUE #(
          %tky        = lr_item->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_create.
    IF entities IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT entities REFERENCE INTO DATA(lr_entity).
      IF lr_entity->ItemCode IS INITIAL.

        DATA(lv_next_code) = VALUE string( ).

        TRY.
            lv_next_code = zcl_merp_num_range_util=>get_next_item_code_nro( ).
          CATCH cx_number_ranges.
            CLEAR lv_next_code.
        ENDTRY.

        IF lv_next_code IS NOT INITIAL.
          " Map generated business key to the draft/content creation ID (%cid)
          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            ItemCode  = lv_next_code
          ) TO mapped-item.
        ELSE.
          APPEND VALUE #(
            %cid        = lr_entity->%cid
            %is_draft   = lr_entity->%is_draft
            %fail-cause = if_abap_behv=>cause-unspecific
          ) TO failed-item.

          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            %msg      = NEW zcm_merp_messages(
                          textid   = zcm_merp_messages=>item_number_failed
                          severity = if_abap_behv_message=>severity-error )
          ) TO reported-item.
        ENDIF.
      ELSE.
        " Preserve user-provided key if supplied during creation
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
          %msg             = NEW zcm_merp_messages(
                                 textid   = zcm_merp_messages=>item_in_use
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
      FIELDS ( ItemGroupCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Filter out initial values on-the-fly to save memory and CPU cycles
    DATA(lt_group_codes) = VALUE zcl_merp_md_util=>tt_item_group_codes(
      FOR lr_item IN lt_items WHERE ( ItemGroupCode IS NOT INITIAL )
      ( lr_item-ItemGroupCode )
    ).

    IF lt_group_codes IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_vat_mapping) = zcl_merp_md_util=>get_item_groups_default_vat( lt_group_codes ).
    DATA lt_update TYPE TABLE FOR UPDATE zmerp_r_item.

    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_item>) WHERE ItemGroupCode IS NOT INITIAL.
      " Binary search on sorted table prevents CPU bottleneck and avoids dumps
      READ TABLE lt_vat_mapping ASSIGNING FIELD-SYMBOL(<ls_vat>)
        WITH TABLE KEY item_group_code = <ls_item>-ItemGroupCode.

      IF sy-subrc = 0.
        APPEND VALUE #(
          %tky                    = <ls_item>-%tky
          DefaultVatCode          = <ls_vat>-default_vat_code
          %control-DefaultVatCode = if_abap_behv=>mk-on
        ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zmerp_r_item IN LOCAL MODE
        ENTITY Item
        UPDATE FIELDS ( DefaultVatCode )
        WITH lt_update.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
