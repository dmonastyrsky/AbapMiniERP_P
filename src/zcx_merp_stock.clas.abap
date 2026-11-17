"! Stock messages (Stock Transfer).
"! Messages shared by all documents are defined in ZCX_MERP_DOC.
CLASS zcx_merp_stock DEFINITION
  PUBLIC
  INHERITING FROM zcx_merp_doc
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF select_receiving_warehouse,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '007',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF select_receiving_warehouse,

      BEGIN OF receiving_warehouse_same,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '142',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF receiving_warehouse_same,

      " &1 = item code
      BEGIN OF item_not_stock_relevant,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '143',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_not_stock_relevant,

      " &1 = document number, &2 = using entity
      BEGIN OF stock_transfer_in_use,
        msgid TYPE symsgid VALUE 'ZMC_MERP_DOC',
        msgno TYPE symsgno VALUE '154',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF stock_transfer_in_use.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcx_merp_stock IMPLEMENTATION.
ENDCLASS.
