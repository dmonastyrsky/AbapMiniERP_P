INTERFACE zif_merp_md_warehouse_sel
  PUBLIC.

  TYPES ty_warehouse TYPE zmerp_r_warehouse.
  TYPES tt_warehouses TYPE SORTED TABLE OF ty_warehouse WITH UNIQUE KEY WarehouseCode.

  TYPES: BEGIN OF ty_warehouse_key,
           WarehouseCode TYPE zmerp_r_warehouse-WarehouseCode,
         END OF ty_warehouse_key,
         tt_warehouse_keys TYPE STANDARD TABLE OF ty_warehouse_key WITH EMPTY KEY.

  "! Reads master data for a single warehouse
  "! @parameter iv_warehouse_code  | Requested warehouse key
  "! @parameter rs_warehouse       | Returned warehouse data structure
  "! @raising zcx_merp_md | Raised if the warehouse does not exist
  METHODS read_warehouse
    IMPORTING iv_warehouse_code TYPE zmerp_r_warehouse-WarehouseCode
    RETURNING VALUE(rs_warehouse) TYPE ty_warehouse
    RAISING   zcx_merp_md.

  "! Reads master data for a list of warehouses
  "! @parameter it_warehouse_keys | Table of warehouse keys
  "! @parameter rt_warehouses     | Sorted table of existing warehouses data
  METHODS read_warehouses
    IMPORTING it_warehouse_keys TYPE tt_warehouse_keys
    RETURNING VALUE(rt_warehouses) TYPE tt_warehouses.

  "! Validates warehouse codes and returns missing/invalid keys
  "! @parameter it_warehouse_keys | Table of warehouse keys to validate
  "! @parameter rt_invalid_keys   | Table containing only keys that do not exist in DB
  METHODS validate_warehouses
    IMPORTING it_warehouse_keys     TYPE tt_warehouse_keys
    RETURNING VALUE(rt_invalid_keys) TYPE tt_warehouse_keys.

ENDINTERFACE.
