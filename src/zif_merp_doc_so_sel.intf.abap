"! Sales order selector. All methods read persisted (active) data only:
"! drafts and unsaved changes are not visible. Inside the sales order's own
"! handlers use READ ENTITIES ... IN LOCAL MODE instead.
INTERFACE zif_merp_doc_so_sel
  PUBLIC.

  TYPES ty_header TYPE zmerp_r_salesorder.
  TYPES ty_so_progress TYPE zmerp_i_so_progress.

  TYPES tt_headers TYPE SORTED TABLE OF ty_header WITH UNIQUE KEY DocumentUUID.
  TYPES tt_progress TYPE SORTED TABLE OF ty_so_progress WITH UNIQUE KEY SoItemUUID
                                                        WITH NON-UNIQUE SORTED KEY ByHeader COMPONENTS SoHeaderUUID.

  TYPES: BEGIN OF ty_document_key,
           DocumentUUID TYPE zmerp_r_salesorder-DocumentUUID,
         END OF ty_document_key,
         tt_document_keys TYPE STANDARD TABLE OF ty_document_key WITH EMPTY KEY.

  TYPES: BEGIN OF ty_usage,
           DocumentUUID TYPE zmerp_r_salesorder-DocumentUUID,
           UsedInEntity TYPE zmerp_entity_name,
         END OF ty_usage,
         tt_usages TYPE SORTED TABLE OF ty_usage WITH UNIQUE KEY DocumentUUID UsedInEntity.

  "! Reads headers of a list of sales orders (without items)
  "! @parameter it_document_keys | Table of sales order document keys
  "! @parameter rt_headers       | Sorted table of existing sales order headers data
  METHODS read_headers
    IMPORTING it_document_keys  TYPE tt_document_keys
    RETURNING VALUE(rt_headers) TYPE tt_headers.

  "! Reads the issue progress (ordered / issued / open quantity and amounts) of all items of the given sales orders
  "! @parameter it_document_keys | Table of sales order document keys
  "! @parameter rt_progress      | Sorted table of progress rows (one row per sales order item)
  METHODS read_progress
    IMPORTING it_document_keys   TYPE tt_document_keys
    RETURNING VALUE(rt_progress) TYPE tt_progress.

  "! Reads where the given sales orders are used (usage view): one row per document and using entity.
  "! Documents that are not used are not returned.
  "! @parameter it_document_keys | Keys to check
  "! @parameter rt_usages        | Documents in use with the entity that uses them
  METHODS read_usages
    IMPORTING it_document_keys TYPE tt_document_keys
    RETURNING VALUE(rt_usages) TYPE tt_usages.

ENDINTERFACE.
