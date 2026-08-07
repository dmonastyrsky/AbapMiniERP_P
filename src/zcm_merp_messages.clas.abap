CLASS zcm_merp_messages DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_t100_dyn_msg .
    INTERFACES if_t100_message .
    INTERFACES if_abap_behv_message .

    " Mandatory & Selection Validations (001 - 020)
    CONSTANTS:
      BEGIN OF enter_partner_name,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF enter_partner_name,

      BEGIN OF select_partner_role,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '002',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF select_partner_role,

      BEGIN OF enter_company_name,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '003',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF enter_company_name,

      BEGIN OF enter_company_code,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '004',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF enter_company_code,

      BEGIN OF enter_country,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '005',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF enter_country,

      BEGIN OF enter_currency,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '006',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF enter_currency,

      BEGIN OF enter_item_desc,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '007',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF enter_item_desc,

      BEGIN OF select_item_type,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '008',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF select_item_type,

      BEGIN OF select_item_group,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '009',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF select_item_group,

      BEGIN OF select_base_unit,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '010',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF select_base_unit,

      BEGIN OF enter_item_grp_desc,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '011',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF enter_item_grp_desc,

      BEGIN OF enter_vat_name,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '012',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF enter_vat_name,

      BEGIN OF select_default_vat_code,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '013',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF select_default_vat_code,

      BEGIN OF invalid_vat_percentage,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '014',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF invalid_vat_percentage,

      BEGIN OF enter_warehouse_name,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '015',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF enter_warehouse_name,

      BEGIN OF enter_company_prefix,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '016',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF enter_company_prefix.

    " Existence Checks (021 - 040)
    CONSTANTS:
      BEGIN OF business_partner_not_found,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '021',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF business_partner_not_found,

      BEGIN OF company_code_not_found,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '022',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF company_code_not_found,

      BEGIN OF item_not_found,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '023',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_not_found,

      BEGIN OF item_group_not_found,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '024',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_group_not_found,

      BEGIN OF vat_code_not_found,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '025',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF vat_code_not_found,

      BEGIN OF warehouse_not_found,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '026',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF warehouse_not_found.

    " Referential Integrity & Usage Checks (041 - 060)
    CONSTANTS:
      BEGIN OF business_partner_in_use,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '041',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF business_partner_in_use,

      BEGIN OF company_code_in_use,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '042',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF company_code_in_use,

      BEGIN OF item_in_use,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '043',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_in_use,

      BEGIN OF item_group_in_use,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '044',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_group_in_use,

      BEGIN OF vat_rate_in_use,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '045',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF vat_rate_in_use,

      BEGIN OF warehouse_in_use,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '046',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF warehouse_in_use.

    " Technical & Number Range Failures (061 - 080)
    CONSTANTS:
      BEGIN OF bp_number_failed,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '061',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF bp_number_failed,

      BEGIN OF company_code_number_failed,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '062',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF company_code_number_failed,

      BEGIN OF item_number_failed,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '063',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_number_failed,

      BEGIN OF item_group_number_failed,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '064',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_group_number_failed,

      BEGIN OF vat_number_failed,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '065',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF vat_number_failed,

      BEGIN OF warehouse_number_failed,
        msgid TYPE symsgid VALUE 'ZMC_MERP',
        msgno TYPE symsgno VALUE '066',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF warehouse_number_failed.

    DATA:
      mv_attr1 TYPE string,
      mv_attr2 TYPE string,
      mv_attr3 TYPE string,
      mv_attr4 TYPE string.

    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        attr1    TYPE string OPTIONAL
        attr2    TYPE string OPTIONAL
        attr3    TYPE string OPTIONAL
        attr4    TYPE string OPTIONAL
        previous LIKE previous OPTIONAL
        severity TYPE if_abap_behv_message=>t_severity OPTIONAL.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcm_merp_messages IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).

    me->mv_attr1 = attr1.
    me->mv_attr2 = attr2.
    me->mv_attr3 = attr3.
    me->mv_attr4 = attr4.

    if_t100_dyn_msg~msgv1 = attr1.
    if_t100_dyn_msg~msgv2 = attr2.
    if_t100_dyn_msg~msgv3 = attr3.
    if_t100_dyn_msg~msgv4 = attr4.

    if_abap_behv_message~m_severity = severity.

    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
