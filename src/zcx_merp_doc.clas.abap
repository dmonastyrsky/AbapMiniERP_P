CLASS zcx_merp_doc DEFINITION
  PUBLIC
  INHERITING FROM zcx_merp_base
  ABSTRACT
  CREATE PUBLIC .

  PUBLIC SECTION.
    CONSTANTS:
      " --- Mandatory Selection & Basic Field Checks (001-021) ---
      BEGIN OF select_company,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF select_company,

      BEGIN OF select_warehouse,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '002',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF select_warehouse,

      BEGIN OF select_vat_code,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '003',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF select_vat_code,

      BEGIN OF select_item_group,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '004',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF select_item_group,

      BEGIN OF select_item,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '005',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF select_item,

      BEGIN OF select_business_partner,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '006',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF select_business_partner,

      BEGIN OF select_currency,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '020',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF select_currency,

      BEGIN OF select_unit_of_measure,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '021',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF select_unit_of_measure,

      " --- Header Mandatory Entry Checks (050-052) ---
      BEGIN OF enter_document_date,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '050',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF enter_document_date,

      BEGIN OF enter_posting_date,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '051',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF enter_posting_date,

      BEGIN OF enter_responsible_person,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '052',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF enter_responsible_person,

      " --- Business Logic & Item Validations (100-107) ---
      BEGIN OF quantity_must_be_positive,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '100',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF quantity_must_be_positive,

      BEGIN OF price_must_be_positive,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '101',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF price_must_be_positive,

      BEGIN OF document_date_future_invalid,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '102',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF document_date_future_invalid,

      BEGIN OF posting_date_sequence_invalid,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '103',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF posting_date_sequence_invalid,

      BEGIN OF quantity_exceeds_ordered,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '105',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF quantity_exceeds_ordered,

      BEGIN OF document_empty_items_invalid,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '106',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF document_empty_items_invalid,

      BEGIN OF item_duplicate_invalid,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '107',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_duplicate_invalid,

      " --- Cross-Entity & Org Assignment Validations (110) ---
      BEGIN OF warehouse_company_mismatch,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '110',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1', "
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2', "
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF warehouse_company_mismatch,

      " --- Status Specifics ---
      BEGIN OF invalid_document_status,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '130',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF invalid_document_status,

      " --- Document Actions & Lifecycle Restrictions (131-134) ---
      BEGIN OF doc_number_already_exists,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '131',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF doc_number_already_exists,

      BEGIN OF delete_not_allowed,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '132',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF delete_not_allowed,

      BEGIN OF release_not_allowed,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '133',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF release_not_allowed,

      BEGIN OF cancel_not_allowed,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '134',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF cancel_not_allowed,

      " --- Number Range & Document Generation (200) ---
      BEGIN OF doc_number_generation_failed,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '200',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF doc_number_generation_failed.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcx_merp_doc IMPLEMENTATION.
ENDCLASS.
