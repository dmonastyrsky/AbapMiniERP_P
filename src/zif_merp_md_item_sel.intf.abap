INTERFACE zif_merp_md_item_sel
  PUBLIC.

  TYPES ty_item TYPE zmerp_r_item.
  TYPES tt_items TYPE SORTED TABLE OF ty_item WITH UNIQUE KEY ItemCode.

  TYPES: BEGIN OF ty_item_key,
           ItemCode TYPE zmerp_r_item-ItemCode,
         END OF ty_item_key,
         tt_item_keys TYPE STANDARD TABLE OF ty_item_key WITH EMPTY KEY.

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

  "! Validates item codes and returns missing/invalid keys
  "! @parameter it_item_keys     | Table of item keys to validate
  "! @parameter rt_invalid_keys  | Table containing only keys that do not exist in DB
  METHODS validate_items
    IMPORTING it_item_keys        TYPE tt_item_keys
    RETURNING VALUE(rt_invalid_keys) TYPE tt_item_keys.

ENDINTERFACE.
