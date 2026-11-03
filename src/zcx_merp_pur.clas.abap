"! Purchasing messages (Purchase Order, Goods Receipt and the link between them).
"! Messages shared by all documents are defined in ZCX_MERP_DOC.
CLASS zcx_merp_pur DEFINITION
  PUBLIC
  INHERITING FROM zcx_merp_doc
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CONSTANTS:
      " --- Header Mandatory Entries (053-056) ---
      BEGIN OF enter_supplier_reference,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '053',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF enter_supplier_reference,

      BEGIN OF enter_delivery_date,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '055',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF enter_delivery_date,

      BEGIN OF select_po_reference,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '056',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF select_po_reference,

      " --- Business Partner (108) ---
      " &1 = business partner code
      BEGIN OF bp_is_not_supplier,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '108',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF bp_is_not_supplier,

      " --- Delivery Date (104, 109) ---
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

      " --- Purchase Order Status (111, 116) ---
      " &1 = purchase order number
      BEGIN OF set_delivery_not_allowed,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '111',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF set_delivery_not_allowed,

      " &1 = purchase order number
      BEGIN OF po_receipt_not_allowed,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '116',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF po_receipt_not_allowed,

      " --- Goods Receipt vs. Purchase Order Dates (118) ---
      " &1 = purchase order document date
      BEGIN OF posting_date_before_po_date,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '118',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF posting_date_before_po_date,

      " --- Goods Receipt Items vs. Purchase Order Open Values (112-114) ---
      " &1 = goods receipt item number
      BEGIN OF po_item_nothing_open,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '112',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF po_item_nothing_open,

      " &1 = goods receipt item number, &2 = open quantity of the purchase order item
      BEGIN OF po_open_quantity_exceeded,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '113',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF po_open_quantity_exceeded,

      " &1 = goods receipt item number
      BEGIN OF po_open_amounts_changed,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '114',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF po_open_amounts_changed,

      " &1 = purchase order number
      BEGIN OF po_has_posted_receipts,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '119',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF po_has_posted_receipts,

      " &1 = goods receipt item number
      BEGIN OF po_item_not_found,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '120',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF po_item_not_found,

      " &1 = purchase order number, &2 = company code of the purchase order
      BEGIN OF po_company_mismatch,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '121',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF po_company_mismatch,

      " --- Dependency Checks (150, 152) ---
      " &1 = document number, &2 = entity that uses the document
      BEGIN OF purchase_order_in_use,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '150',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF purchase_order_in_use,

      BEGIN OF goods_receipt_in_use,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '152',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF goods_receipt_in_use,

      " --- Document Existence Checks (170, 172) ---
      " &1 = document number
      BEGIN OF purchase_order_not_found,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '170',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF purchase_order_not_found,

      BEGIN OF goods_receipt_not_found,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '172',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF goods_receipt_not_found.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcx_merp_pur IMPLEMENTATION.
ENDCLASS.
