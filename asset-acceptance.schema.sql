-- Asset Acceptance ONLY — PostgreSQL DDL (focused scope)
-- ไม่รวม contracts, substations, agreements

BEGIN;

CREATE TYPE aa_work_job_status AS ENUM (
  'draft', 'mapping', 'calculated', 'allocated', 'posted', 'cancelled'
);
CREATE TYPE aa_allocation_mode AS ENUM ('for_allocation', 'separate_asset');
CREATE TYPE aa_boq_work_type AS ENUM ('electrical', 'civil', 'equipment');
CREATE TYPE aa_boq_category AS ENUM ('ads', 'na');
CREATE TYPE aa_document_type AS ENUM ('as01', 'as02', 'aiab');

-- Entry
CREATE TABLE aa_wbs (
  id         BIGSERIAL PRIMARY KEY,
  wbs        VARCHAR(50)  NOT NULL UNIQUE,
  work_name  VARCHAR(255),
  active     BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- AUC
CREATE TABLE aa_auc_types (
  id   BIGSERIAL PRIMARY KEY,
  code VARCHAR(20)  NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL
);

CREATE TABLE aa_auc_records (
  id              BIGSERIAL PRIMARY KEY,
  wbs_id          BIGINT              NOT NULL REFERENCES aa_wbs(id),
  auc_type_id     BIGINT              NOT NULL REFERENCES aa_auc_types(id),
  auc_no          VARCHAR(50)         NOT NULL,
  auc_value       NUMERIC(18, 2)      NOT NULL DEFAULT 0,
  allocation_mode aa_allocation_mode  NOT NULL DEFAULT 'for_allocation',
  active          BOOLEAN             NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ,
  UNIQUE (wbs_id, auc_no)
);

-- Session root
CREATE TABLE aa_work_jobs (
  id                 BIGSERIAL PRIMARY KEY,
  wbs_id             BIGINT               NOT NULL REFERENCES aa_wbs(id),
  job_no             VARCHAR(50)          UNIQUE,
  status             aa_work_job_status   NOT NULL DEFAULT 'draft',
  boq_total          NUMERIC(18, 2)       NOT NULL DEFAULT 0,
  auc_selected_total NUMERIC(18, 2)       NOT NULL DEFAULT 0,
  boq_diff           NUMERIC(18, 2)       NOT NULL DEFAULT 0,
  created_at         TIMESTAMPTZ          NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ
);
CREATE INDEX idx_aa_work_jobs_wbs ON aa_work_jobs(wbs_id);

CREATE TABLE aa_auc_selections (
  id                BIGSERIAL PRIMARY KEY,
  work_job_id       BIGINT  NOT NULL REFERENCES aa_work_jobs(id) ON DELETE CASCADE,
  auc_record_id     BIGINT  NOT NULL REFERENCES aa_auc_records(id),
  is_selected       BOOLEAN NOT NULL DEFAULT FALSE,
  auto_selected     BOOLEAN NOT NULL DEFAULT FALSE,
  added_from_search BOOLEAN NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (work_job_id, auc_record_id)
);

-- Masters
CREATE TABLE aa_asset_groups (
  id   BIGSERIAL PRIMARY KEY,
  code VARCHAR(50)  NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL
);
CREATE TABLE aa_asset_product_types (
  id   BIGSERIAL PRIMARY KEY,
  code VARCHAR(10) NOT NULL UNIQUE,
  name VARCHAR(100)
);
CREATE TABLE aa_boq_groups (
  id        BIGSERIAL PRIMARY KEY,
  code      VARCHAR(50)  NOT NULL UNIQUE,
  name      VARCHAR(255) NOT NULL,
  work_type aa_boq_work_type
);
CREATE TABLE aa_asset_classes (
  id   BIGSERIAL PRIMARY KEY,
  code VARCHAR(20)  NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL
);
CREATE TABLE aa_account_codes (
  id             BIGSERIAL PRIMARY KEY,
  code           VARCHAR(20)  NOT NULL UNIQUE,
  name           VARCHAR(255) NOT NULL,
  asset_class_id BIGINT REFERENCES aa_asset_classes(id)
);
CREATE TABLE aa_asset_types (
  id   BIGSERIAL PRIMARY KEY,
  code VARCHAR(20)  NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL
);
CREATE TABLE aa_asset_sub_types (
  id            BIGSERIAL PRIMARY KEY,
  code          VARCHAR(20)  NOT NULL UNIQUE,
  name          VARCHAR(255) NOT NULL,
  asset_type_id BIGINT       NOT NULL REFERENCES aa_asset_types(id)
);

-- BOQ
CREATE TABLE aa_boq_lines (
  id              BIGSERIAL PRIMARY KEY,
  work_job_id     BIGINT            NOT NULL REFERENCES aa_work_jobs(id) ON DELETE CASCADE,
  seq             INT               NOT NULL,
  code            VARCHAR(50),
  item_name       VARCHAR(500)      NOT NULL,
  work_type       aa_boq_work_type  NOT NULL,
  boq_category    aa_boq_category   NOT NULL DEFAULT 'ads',
  boq_group_id    BIGINT            REFERENCES aa_boq_groups(id),
  product_type_id BIGINT            REFERENCES aa_asset_product_types(id),
  unit            VARCHAR(50),
  qty             NUMERIC(18, 4)    NOT NULL DEFAULT 0,
  material_cost   NUMERIC(18, 2)    NOT NULL DEFAULT 0,
  labor_cost      NUMERIC(18, 2)    DEFAULT 0,
  total_cost      NUMERIC(18, 2)    NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_aa_boq_lines_job ON aa_boq_lines(work_job_id, work_type, boq_category, seq);

CREATE TABLE aa_boq_mappings (
  id              BIGSERIAL PRIMARY KEY,
  work_job_id     BIGINT NOT NULL REFERENCES aa_work_jobs(id) ON DELETE CASCADE,
  boq_line_id     BIGINT NOT NULL REFERENCES aa_boq_lines(id) ON DELETE CASCADE,
  asset_group_id  BIGINT REFERENCES aa_asset_groups(id),
  saved_at        TIMESTAMPTZ,
  updated_at      TIMESTAMPTZ,
  UNIQUE (work_job_id, boq_line_id)
);

CREATE TABLE aa_boq_calc_groups (
  id          BIGSERIAL PRIMARY KEY,
  work_job_id BIGINT            NOT NULL REFERENCES aa_work_jobs(id) ON DELETE CASCADE,
  group_key   VARCHAR(50)       NOT NULL,
  title       VARCHAR(255)      NOT NULL,
  work_type   aa_boq_work_type  NOT NULL,
  sort_order  INT               NOT NULL DEFAULT 0,
  UNIQUE (work_job_id, group_key)
);

CREATE TABLE aa_boq_calc_items (
  id                BIGSERIAL PRIMARY KEY,
  group_id          BIGINT NOT NULL REFERENCES aa_boq_calc_groups(id) ON DELETE CASCADE,
  label             VARCHAR(500) NOT NULL,
  note              VARCHAR(500),
  electrical_amount NUMERIC(18, 2),
  civil_amount      NUMERIC(18, 2),
  total_amount      NUMERIC(18, 2),
  sort_order        INT NOT NULL DEFAULT 0
);

-- Equipment
CREATE TABLE aa_equipment_sections (
  id               BIGSERIAL PRIMARY KEY,
  work_job_id      BIGINT NOT NULL REFERENCES aa_work_jobs(id) ON DELETE CASCADE,
  section_key      VARCHAR(50)  NOT NULL,
  title            VARCHAR(255) NOT NULL,
  section_total    NUMERIC(18, 2) NOT NULL DEFAULT 0,
  subsection_total NUMERIC(18, 2),
  grand_total      NUMERIC(18, 2),
  sort_order       INT NOT NULL DEFAULT 0,
  UNIQUE (work_job_id, section_key)
);

CREATE TABLE aa_equipment_categories (
  id            BIGSERIAL PRIMARY KEY,
  section_id    BIGINT       NOT NULL REFERENCES aa_equipment_sections(id) ON DELETE CASCADE,
  category_name VARCHAR(255) NOT NULL,
  sort_order    INT          NOT NULL DEFAULT 0,
  UNIQUE (section_id, category_name)
);

CREATE TABLE aa_equipment_items (
  id                BIGSERIAL PRIMARY KEY,
  section_id        BIGINT         NOT NULL REFERENCES aa_equipment_sections(id) ON DELETE CASCADE,
  category_id       BIGINT         REFERENCES aa_equipment_categories(id),
  boq_line_id       BIGINT         REFERENCES aa_boq_lines(id),
  seq               INT            NOT NULL,
  item_name         VARCHAR(500)   NOT NULL,
  qty               NUMERIC(18, 4) NOT NULL DEFAULT 0,
  unit              VARCHAR(50),
  unit_price        NUMERIC(18, 2) NOT NULL DEFAULT 0,
  total_amount      NUMERIC(18, 2) NOT NULL DEFAULT 0,
  asset_type_id     BIGINT         REFERENCES aa_asset_types(id),
  asset_sub_type_id BIGINT         REFERENCES aa_asset_sub_types(id),
  sub_type_name     VARCHAR(255),
  updated_at        TIMESTAMPTZ
);

-- Bid price
CREATE TABLE aa_bid_price_notes (
  id          BIGSERIAL PRIMARY KEY,
  work_job_id BIGINT       NOT NULL REFERENCES aa_work_jobs(id) ON DELETE CASCADE,
  note_key    VARCHAR(50)  NOT NULL,
  note_text   TEXT,
  saved_at    TIMESTAMPTZ,
  UNIQUE (work_job_id, note_key)
);

-- Allocation
CREATE TABLE aa_allocation_summaries (
  id          BIGSERIAL PRIMARY KEY,
  work_job_id BIGINT            NOT NULL REFERENCES aa_work_jobs(id) ON DELETE CASCADE,
  label       VARCHAR(255)      NOT NULL,
  amount      NUMERIC(18, 2)    NOT NULL DEFAULT 0,
  work_type   aa_boq_work_type,
  is_warning  BOOLEAN           NOT NULL DEFAULT FALSE,
  sort_order  INT               NOT NULL DEFAULT 0
);

CREATE TABLE aa_allocation_lines (
  id                BIGSERIAL PRIMARY KEY,
  work_job_id       BIGINT         NOT NULL REFERENCES aa_work_jobs(id) ON DELETE CASCADE,
  seq               INT            NOT NULL,
  item_name         VARCHAR(255)   NOT NULL,
  asset_class_id    BIGINT         REFERENCES aa_asset_classes(id),
  account_code_id   BIGINT         REFERENCES aa_account_codes(id),
  boq_amount        NUMERIC(18, 2) NOT NULL DEFAULT 0,
  allocated_amount  NUMERIC(18, 2),
  allocated_percent NUMERIC(10, 4),
  total_amount      NUMERIC(18, 2) NOT NULL DEFAULT 0,
  is_non_allocated  BOOLEAN        NOT NULL DEFAULT FALSE
);

CREATE TABLE aa_allocation_sub_lines (
  id                 BIGSERIAL PRIMARY KEY,
  allocation_line_id BIGINT         NOT NULL REFERENCES aa_allocation_lines(id) ON DELETE CASCADE,
  seq                VARCHAR(20)    NOT NULL,
  item_name          VARCHAR(255)   NOT NULL,
  asset_class_id     BIGINT         REFERENCES aa_asset_classes(id),
  total_amount       NUMERIC(18, 2) NOT NULL DEFAULT 0,
  sort_order         INT            NOT NULL DEFAULT 0
);

-- AA posting
CREATE TABLE aa_documents (
  id            BIGSERIAL PRIMARY KEY,
  work_job_id   BIGINT            NOT NULL REFERENCES aa_work_jobs(id) ON DELETE CASCADE,
  document_type aa_document_type  NOT NULL,
  document_no   VARCHAR(50),
  pdf_url       VARCHAR(500),
  status        VARCHAR(30)       NOT NULL DEFAULT 'draft',
  posted_at     TIMESTAMPTZ
);

CREATE TABLE aa_posting_lines (
  id                 BIGSERIAL PRIMARY KEY,
  document_id        BIGINT         NOT NULL REFERENCES aa_documents(id) ON DELETE CASCADE,
  allocation_line_id BIGINT         REFERENCES aa_allocation_lines(id),
  equipment_item_id  BIGINT         REFERENCES aa_equipment_items(id),
  product_number     VARCHAR(50),
  description        VARCHAR(500),
  asset_class        VARCHAR(20),
  asset_group        VARCHAR(50),
  asset_code         VARCHAR(50),
  quantity           NUMERIC(18, 4),
  unit               VARCHAR(50),
  asset_value        NUMERIC(18, 2),
  wbs_element        VARCHAR(50),
  posting_date       DATE,
  sort_order         INT            NOT NULL DEFAULT 0
);

CREATE TABLE aa_report_preview_rows (
  id          BIGSERIAL PRIMARY KEY,
  document_id BIGINT  NOT NULL REFERENCES aa_documents(id) ON DELETE CASCADE,
  page_no     INT,
  row_data    JSONB,
  sort_order  INT     NOT NULL DEFAULT 0
);

COMMIT;
