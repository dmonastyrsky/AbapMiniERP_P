"! Purchase order selector. All methods read persisted (active) data only:
"! drafts and unsaved changes are not visible. Inside the purchase order's own
"! handlers use READ ENTITIES ... IN LOCAL MODE instead.
INTERFACE zif_merp_doc_po_sel
  PUBLIC.

  TYPES ty_header TYPE zmerp_r_purchaseorder.
  TYPES ty_po_progress TYPE zmerp_i_po_progress.

  TYPES tt_headers TYPE SORTED TABLE OF ty_header WITH UNIQUE KEY DocumentUUID.
  TYPES tt_progress TYPE SORTED TABLE OF ty_po_progress WITH UNIQUE KEY PoItemUUID
                                                        WITH NON-UNIQUE SORTED KEY ByHeader COMPONENTS PoHeaderUUID.

  TYPES: BEGIN OF ty_document_key,
           DocumentUUID TYPE zmerp_r_purchaseorder-DocumentUUID,
         END OF ty_document_key,
         tt_document_keys TYPE STANDARD TABLE OF ty_document_key WITH EMPTY KEY,
         tt_document_keys_sorted TYPE SORTED TABLE OF ty_document_key WITH UNIQUE KEY DocumentUUID.

  TYPES: BEGIN OF ty_usage,
           DocumentUUID TYPE zmerp_r_purchaseorder-DocumentUUID,
           UsedInEntity TYPE zmerp_entity_name,
         END OF ty_usage,
         tt_usages TYPE SORTED TABLE OF ty_usage WITH UNIQUE KEY DocumentUUID UsedInEntity.

  "! Reads headers of a list of purchase orders (without items)
  "! @parameter it_document_keys | Table of purchase order document keys
  "! @parameter rt_headers       | Sorted table of existing purchase order headers data
  METHODS read_headers
    IMPORTING it_document_keys  TYPE tt_document_keys
    RETURNING VALUE(rt_headers) TYPE tt_headers.

  "! Reads the receipt progress (ordered / received / open quantity and amounts) of all items of the given purchase orders
  "! @parameter it_document_keys | Table of purchase order document keys
  "! @parameter rt_progress      | Sorted table of progress rows (one row per purchase order item)
  METHODS read_progress
    IMPORTING it_document_keys   TYPE tt_document_keys
    RETURNING VALUE(rt_progress) TYPE tt_progress.

  "! Returns the purchase orders that have at least one posted goods receipt
  "! @parameter it_document_keys  | Table of purchase order document keys
  "! @parameter rt_document_keys  | Purchase orders with a received quantity on at least one item
  METHODS read_received_documents
    IMPORTING it_document_keys        TYPE tt_document_keys
    RETURNING VALUE(rt_document_keys) TYPE tt_document_keys_sorted.

  "! Reads where the given purchase orders are used (usage view): one row per document and using entity.
  "! Documents that are not used are not returned.
  "! @parameter it_document_keys | Keys to check
  "! @parameter rt_usages        | Documents in use with the entity that uses them
  METHODS read_usages
    IMPORTING it_document_keys TYPE tt_document_keys
    RETURNING VALUE(rt_usages) TYPE tt_usages.

ENDINTERFACE.
