"! Local behavior handler for Business Partner BO entity.
CLASS lhc_zmerp_r_bus_partner DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      c_val_name TYPE string VALUE 'VALIDATE_PARTNER_NAME',
      c_val_role TYPE string VALUE 'VALIDATE_PARTNER_ROLE'.

    "! Evaluates global authorizations for CUD operations.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR BusinessPartner
      RESULT result.

    "! Validates mandatory fields before saving.
    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR BusinessPartner~validateMandatoryFields.

    "! Clears validation messages for fields that have been filled in.
    METHODS clearMessagesForFilledFields FOR DETERMINE ON MODIFY
      IMPORTING keys FOR BusinessPartner~clearMessagesForFilledFields.

    "! Assigns early numbers for new Business Partner entities.
    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE BusinessPartner.

    "! Pre-checks deletion dependencies in referenced entities.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE BusinessPartner.

ENDCLASS.


CLASS lhc_zmerp_r_bus_partner IMPLEMENTATION.

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
    reported-businesspartner = VALUE #(
      BASE reported-businesspartner
      FOR key IN keys
      ( %tky        = key-%tky
        %state_area = c_val_name )
      ( %tky        = key-%tky
        %state_area = c_val_role )
    ).

    " Read entity fields in local mode to bypass global authorization checks during validation
    READ ENTITIES OF zmerp_r_bus_partner IN LOCAL MODE
      ENTITY BusinessPartner
      FIELDS ( PartnerName IsCustomer IsSupplier )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_bp).

    IF lt_bp IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_bp REFERENCE INTO DATA(lr_bp).
      lv_has_error = abap_false.

      " 1. Business Partner Name Mandatory Validation
      IF lr_bp->PartnerName IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                 = lr_bp->%tky
          %state_area          = c_val_name
          %msg                 = NEW zcx_merp_md(
                                   textid   = zcx_merp_md=>enter_partner_name
                                   severity = if_abap_behv_message=>severity-error )
          %element-PartnerName = if_abap_behv=>mk-on
        ) TO reported-businesspartner.
      ENDIF.

      " 2. Partner Roles Validation (At least one role must be selected)
      IF lr_bp->IsCustomer IS INITIAL AND lr_bp->IsSupplier IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky                = lr_bp->%tky
          %state_area         = c_val_role
          %msg                = NEW zcx_merp_md(
                                  textid   = zcx_merp_md=>select_partner_role
                                  severity = if_abap_behv_message=>severity-error )
          %element-IsCustomer = if_abap_behv=>mk-on
          %element-IsSupplier = if_abap_behv=>mk-on
        ) TO reported-businesspartner.
      ENDIF.

      IF lv_has_error = abap_true.
        " Mark entity instance as failed to prevent transaction commit
        APPEND VALUE #(
          %tky        = lr_bp->%tky
          %fail-cause = if_abap_behv=>cause-unspecific
        ) TO failed-businesspartner.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD clearMessagesForFilledFields.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    " Read entity state in local mode
    READ ENTITIES OF zmerp_r_bus_partner IN LOCAL MODE
      ENTITY BusinessPartner
      FIELDS ( PartnerName IsCustomer IsSupplier )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_bp).

    LOOP AT lt_bp REFERENCE INTO DATA(lr_bp).
      " Clear message area for Business Partner Name
      IF lr_bp->PartnerName IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_bp->%tky %state_area = c_val_name ) TO reported-businesspartner.
      ENDIF.

      " Clear message area for Partner Roles if at least one checkbox is set
      IF lr_bp->IsCustomer IS NOT INITIAL OR lr_bp->IsSupplier IS NOT INITIAL.
        APPEND VALUE #( %tky = lr_bp->%tky %state_area = c_val_role ) TO reported-businesspartner.
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
                                       WHERE ( PartnerCode IS INITIAL )
                                       NEXT count += 1 ).

    " Step 2: Bulk allocation via NRO utility with exception capture
    IF lv_needed_count > 0.
      TRY.
          lt_codes = zcl_merp_num_range_util=>get_next_bp_codes_nro( iv_count = lv_needed_count ).
        CATCH cx_number_ranges cx_root INTO lx_nro_error.
          CLEAR lt_codes.
      ENDTRY.
    ENDIF.

    DATA(lv_index) = 1.

    " Step 3: Map keys to instances safely
    LOOP AT entities REFERENCE INTO DATA(lr_entity).
      IF lr_entity->PartnerCode IS INITIAL.
        READ TABLE lt_codes INDEX lv_index ASSIGNING FIELD-SYMBOL(<lv_code>).

        IF sy-subrc = 0 AND <lv_code> IS NOT INITIAL.
          " Map successfully generated key
          APPEND VALUE #(
            %cid        = lr_entity->%cid
            %is_draft   = lr_entity->%is_draft
            PartnerCode = CONV #( <lv_code> )
          ) TO mapped-businesspartner.

          " Increment index ONLY after processing an auto-numbered entity
          lv_index += 1.
        ELSE.
          " Mark entity failure
          APPEND VALUE #(
            %cid        = lr_entity->%cid
            %is_draft   = lr_entity->%is_draft
            %fail-cause = if_abap_behv=>cause-unspecific
          ) TO failed-businesspartner.

          " Report error with root cause exception reference if available
          APPEND VALUE #(
            %cid      = lr_entity->%cid
            %is_draft = lr_entity->%is_draft
            %msg      = NEW zcx_merp_md(
                          textid   = zcx_merp_md=>bus_part_generation_failed
                          previous = lx_nro_error
                          severity = if_abap_behv_message=>severity-error )
          ) TO reported-businesspartner.
        ENDIF.
      ELSE.
        " Retain explicitly provided code without affecting lt_codes indexing
        APPEND VALUE #(
          %cid        = lr_entity->%cid
          %is_draft   = lr_entity->%is_draft
          PartnerCode = lr_entity->PartnerCode
        ) TO mapped-businesspartner.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD precheck_delete.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_key,
             partnercode TYPE zmerp_bus_part_code,
           END OF ty_key.

    TYPES: BEGIN OF ty_dependency,
             partnercode  TYPE zmerp_bus_part_code,
             usedinentity TYPE zmerp_entity_name,
           END OF ty_dependency.

    DATA lt_keys TYPE SORTED TABLE OF ty_key WITH NON-UNIQUE KEY partnercode.
    DATA lt_dependencies TYPE SORTED TABLE OF ty_dependency WITH NON-UNIQUE KEY partnercode.
    DATA lv_failed_added TYPE abap_bool.

    " Collect key values and remove potential duplicates to optimize SQL predicate standard
    lt_keys = VALUE #( FOR key IN keys WHERE ( PartnerCode IS NOT INITIAL ) ( partnercode = key-PartnerCode ) ).
    DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING partnercode.

    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    " Bulk check database dependencies for collected key set
    SELECT DISTINCT
           usage~PartnerCode  AS partnercode,
           usage~UsedInEntity AS usedinentity
      FROM zmerp_i_bus_partner_usage AS usage
      INNER JOIN @lt_keys AS key ON usage~PartnerCode = key~partnercode
      INTO TABLE @lt_dependencies.

    IF lt_dependencies IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT keys REFERENCE INTO DATA(lr_key).
      lv_failed_added = abap_false.

      " ABAP runtime automatically performs a highly efficient binary boundary scan here
      LOOP AT lt_dependencies REFERENCE INTO DATA(lr_dep)
        WHERE partnercode = lr_key->PartnerCode.

        " Record entity failure state ONCE per key
        IF lv_failed_added = abap_false.
          APPEND VALUE #(
            %tky        = lr_key->%tky
            %fail-cause = if_abap_behv=>cause-dependency
          ) TO failed-businesspartner.
          lv_failed_added = abap_true.
        ENDIF.

        " Report explicit dependency error message to UI
        APPEND VALUE #(
          %tky                 = lr_key->%tky
          %element-PartnerCode = if_abap_behv=>mk-on
          %msg                 = NEW zcx_merp_md(
                                     textid   = zcx_merp_md=>business_partner_in_use
                                     attr1    = CONV #( lr_dep->partnercode )
                                     attr2    = CONV #( lr_dep->usedinentity )
                                     severity = if_abap_behv_message=>severity-error )
        ) TO reported-businesspartner.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
