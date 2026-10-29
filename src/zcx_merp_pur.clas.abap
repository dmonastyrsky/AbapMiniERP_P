CLASS zcx_merp_pur DEFINITION
  PUBLIC
  INHERITING FROM zcx_merp_doc
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CONSTANTS:
      " --- Header Specifics ---
      BEGIN OF enter_supplier_reference,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '053',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF enter_supplier_reference,

      BEGIN OF bp_is_not_supplier,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '108',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF bp_is_not_supplier,

      " --- Delivery & Items Specifics ---
      BEGIN OF delivery_date_past_invalid,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '104',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF delivery_date_past_invalid,

      BEGIN OF delivery_date_before_doc_date,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '109',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF delivery_date_before_doc_date,

      " --- Dependency Checks ---
      BEGIN OF purchase_order_in_use,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '150',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF purchase_order_in_use.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcx_merp_pur IMPLEMENTATION.
ENDCLASS.
