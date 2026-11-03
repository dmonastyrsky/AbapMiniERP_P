INTERFACE zif_merp_md_item_sel
  PUBLIC.

  TYPES ty_item TYPE zmerp_r_item.
  TYPES tt_items TYPE SORTED TABLE OF ty_item WITH UNIQUE KEY ItemCode.

  TYPES: BEGIN OF ty_item_key,
           ItemCode TYPE zmerp_r_item-ItemCode,
         END OF ty_item_key,
         tt_item_keys TYPE STANDARD TABLE OF ty_item_key WITH EMPTY KEY.

  TYPES: BEGIN OF ty_usage,
           ItemCode     TYPE zmerp_r_item-ItemCode,
           UsedInEntity TYPE zmerp_entity_name,
           IsDocument   TYPE abap_boolean,
         END OF ty_usage,
         tt_usages TYPE SORTED TABLE OF ty_usage WITH UNIQUE KEY ItemCode UsedInEntity.

  "! Reads master data for a single item
  "! @parameter iv_item_code       | Requested item key
  "! @parameter rs_item            | Returned item data structure
  "! @raising zcx_merp_md | Raised if the requested item code does not exist
  METHODS read_item
    IMPORTING iv_item_code TYPE zmerp_r_item-ItemCode
    RETURNING VALUE(rs_item) TYPE ty_item
    RAISING   zcx_merp_md.

  "! Reads master data for a list of items
  "! @parameter it_item_keys | Table of item keys
  "! @parameter rt_items     | Sorted table of existing items data
  METHODS read_items
    IMPORTING it_item_keys TYPE tt_item_keys
    RETURNING VALUE(rt_items) TYPE tt_items.

  "! Reads where the given items are used (usage view): one row per code and using entity.
  "! Codes that are not used are not returned.
  "! @parameter it_item_keys | Keys to check
  "! @parameter rt_usages    | Codes in use with the entity that uses them
  METHODS read_usages
    IMPORTING it_item_keys TYPE tt_item_keys
    RETURNING VALUE(rt_usages) TYPE tt_usages.

ENDINTERFACE.
