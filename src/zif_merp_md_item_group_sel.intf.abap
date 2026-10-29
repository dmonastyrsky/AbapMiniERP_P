INTERFACE zif_merp_md_item_group_sel
  PUBLIC.

  TYPES ty_item_group TYPE zmerp_r_item_group.
  TYPES tt_item_groups TYPE SORTED TABLE OF ty_item_group WITH UNIQUE KEY ItemGroupCode.

  TYPES: BEGIN OF ty_item_group_key,
           ItemGroupCode TYPE zmerp_r_item_group-ItemGroupCode,
         END OF ty_item_group_key,
         tt_item_group_keys TYPE STANDARD TABLE OF ty_item_group_key WITH EMPTY KEY.

  "! Reads master data for a single item group
  "! @parameter iv_item_group_code | Requested item group key
  "! @parameter rs_item_group      | Returned item group data structure
  "! @raising zcx_merp_md | Raised if the requested item group does not exist
  METHODS read_item_group
    IMPORTING iv_item_group_code TYPE zmerp_r_item_group-ItemGroupCode
    RETURNING VALUE(rs_item_group) TYPE ty_item_group
    RAISING   zcx_merp_md.

  "! Reads master data for a list of item groups
  "! @parameter it_item_group_keys | Table of item group keys
  "! @parameter rt_item_groups     | Sorted table of existing item groups data
  METHODS read_item_groups
    IMPORTING it_item_group_keys TYPE tt_item_group_keys
    RETURNING VALUE(rt_item_groups) TYPE tt_item_groups.

  "! Validates item group codes and returns missing/invalid keys
  "! @parameter it_item_group_keys | Table of item group keys to validate
  "! @parameter rt_invalid_keys    | Table containing only keys that do not exist in DB
  METHODS validate_item_groups
    IMPORTING it_item_group_keys    TYPE tt_item_group_keys
    RETURNING VALUE(rt_invalid_keys) TYPE tt_item_group_keys.

ENDINTERFACE.
