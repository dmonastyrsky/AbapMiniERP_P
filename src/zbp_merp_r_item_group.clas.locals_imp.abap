"! Local behavior handler for Item Group BO entity.
CLASS lhc_zmerp_r_item_group DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_state_area_mandatory TYPE string VALUE 'VALIDATE_MANDATORY'.

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

    " Clear previous validation messages for this state area to prevent duplicate errors in UI
    reported-itemgroup = VALUE #(
      BASE reported-itemgroup
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_state_area_mandatory )
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

    LOOP AT lt_groups REFERENCE INTO DATA(lr_group).
      lv_has_error = abap_false.

      IF lr_group->Description IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_group->%tky
          %state_area          = c_state_area_mandatory
          %msg                 = NEW zcm_merp_messages(
                                   textid   = zcm_merp_messages=>enter_item_grp_desc
                                   severity = if_abap_behv_message=>severity-error )
          %element-Description = if_abap_behv=>mk-on
        ) TO reported-itemgroup.
      ENDIF.

      IF lr_group->DefaultVatCode IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                    = lr_group->%tky
          %state_area             = c_state_area_mandatory
          %msg                    = NEW zcm_merp_messages(
                                      textid   = zcm_merp_messages=>select_default_vat_code
                                      severity = if_abap_behv_message=>severity-error )
          %element-DefaultVatCode = if_abap_behv=>mk-on
        ) TO reported-itemgroup.
      ENDIF.

      IF lv_has_error = abap_true.
        " Mark entity instance as failed to prevent transaction commit
        APPEND VALUE #(
          %tky        = lr_group->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-itemgroup.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_create.
    IF entities IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT entities REFERENCE INTO DATA(lr_entity).
      IF lr_entity->ItemGroupCode IS INITIAL.

        DATA(lv_next_ig_code) = VALUE string( ).

        TRY.
            lv_next_ig_code = zcl_merp_num_range_util=>get_next_item_group_code_nro( ).
          CATCH cx_number_ranges.
            CLEAR lv_next_ig_code.
        ENDTRY.

        IF lv_next_ig_code IS NOT INITIAL.
          " Map generated business key to the draft/content creation ID (%cid)
          APPEND VALUE #(
            %cid          = lr_entity->%cid
            %is_draft     = lr_entity->%is_draft
            ItemGroupCode = lv_next_ig_code
          ) TO mapped-itemgroup.
        ELSE.
          APPEND VALUE #(
            %cid        = lr_entity->%cid
            %is_draft   = lr_entity->%is_draft
            %fail-cause = if_abap_behv=>cause-unspecific
          ) TO failed-itemgroup.

          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            %msg      = NEW zcm_merp_messages(
                          textid   = zcm_merp_messages=>item_group_number_failed
                          severity = if_abap_behv_message=>severity-error )
          ) TO reported-itemgroup.
        ENDIF.
      ELSE.
        " Preserve user-provided key if supplied during creation
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
          %msg                   = NEW zcm_merp_messages(
                                      textid   = zcm_merp_messages=>item_group_in_use
                                      attr1    = CONV #( lr_dep->itemgroupcode )
                                      attr2    = CONV #( lr_dep->usedinentity )
                                      severity = if_abap_behv_message=>severity-error )
        ) TO reported-itemgroup.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
