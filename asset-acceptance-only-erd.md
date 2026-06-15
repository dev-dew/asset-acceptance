# Asset Acceptance ONLY — ERD (เฉพาะ feature นี้)

> ตัดออก: contracts, substations, agreements, SAP sync, status history  
> Prefix ตาราง: `aa_` = asset acceptance

## ไฟล์

| ไฟล์ | ใช้งาน |
|------|--------|
| `asset-acceptance-only.dbml` | Import dbdiagram.io |
| `asset-acceptance-only.schema.sql` | PostgreSQL DDL |
| `asset-acceptance-only.queries.sql` | ตัวอย่าง query |

---

## ERD ภาพรวม

```mermaid
erDiagram
  aa_wbs ||--o{ aa_auc_records : has
  aa_wbs ||--o{ aa_work_jobs : session
  aa_auc_types ||--o{ aa_auc_records : types

  aa_work_jobs ||--o{ aa_auc_selections : selects
  aa_auc_records ||--o{ aa_auc_selections : selected

  aa_work_jobs ||--o{ aa_boq_lines : boq
  aa_boq_lines ||--o| aa_boq_mappings : mapped
  aa_asset_groups ||--o{ aa_boq_mappings : target

  aa_work_jobs ||--o{ aa_boq_calc_groups : calc
  aa_boq_calc_groups ||--o{ aa_boq_calc_items : items

  aa_work_jobs ||--o{ aa_equipment_sections : equip
  aa_equipment_sections ||--o{ aa_equipment_categories : cat
  aa_equipment_sections ||--o{ aa_equipment_items : items
  aa_boq_lines ||--o{ aa_equipment_items : source

  aa_work_jobs ||--o{ aa_bid_price_notes : notes
  aa_work_jobs ||--o{ aa_allocation_summaries : summary
  aa_work_jobs ||--o{ aa_allocation_lines : lines
  aa_allocation_lines ||--o{ aa_allocation_sub_lines : sub

  aa_work_jobs ||--o{ aa_documents : docs
  aa_documents ||--o{ aa_posting_lines : posting

  aa_wbs {
    bigint id PK
    varchar wbs UK
    varchar work_name
  }

  aa_work_jobs {
    bigint id PK
    bigint wbs_id FK
    enum status
    numeric boq_total
    numeric boq_diff
  }

  aa_boq_lines {
    bigint id PK
    int seq
    enum work_type
    enum boq_category
    numeric total_cost
  }

  aa_boq_mappings {
    bigint boq_line_id FK
    bigint asset_group_id FK
  }
```

---

## โครงสร้างตามแท็บ UI

```mermaid
flowchart TB
  WBS[aa_wbs]
  JOB[aa_work_jobs]

  subgraph tab1 [สรุปมูลค่า]
    AUC[aa_auc_records]
    SEL[aa_auc_selections]
  end

  subgraph tab2 [รวมมูลค่าตาม BOQ]
    BOQ[aa_boq_lines]
    MAP[aa_boq_mappings]
    CALC[aa_boq_calc_groups]
    NOTE[aa_bid_price_notes]
  end

  subgraph tab3 [คำนวณครุภัณฑ์]
    EQ[aa_equipment_items]
  end

  subgraph tab4 [ปันส่วน]
    ALLOC[aa_allocation_lines]
  end

  subgraph tab5 [บันทึกรับทรัพย์สิน]
    AA[aa_posting_lines]
  end

  WBS --> JOB
  WBS --> AUC
  JOB --> SEL --> AUC
  JOB --> BOQ --> MAP
  JOB --> CALC
  JOB --> NOTE
  BOQ --> EQ
  JOB --> ALLOC
  JOB --> AA
```

---

## FK Map (20 ตาราง)

```
aa_wbs
  ├── aa_auc_records
  └── aa_work_jobs                    ← ROOT
        ├── aa_auc_selections → aa_auc_records
        ├── aa_boq_lines
        │     └── aa_boq_mappings → aa_asset_groups
        ├── aa_boq_calc_groups → aa_boq_calc_items
        ├── aa_equipment_sections
        │     ├── aa_equipment_categories
        │     └── aa_equipment_items → aa_asset_types, aa_asset_sub_types
        ├── aa_bid_price_notes
        ├── aa_allocation_summaries
        ├── aa_allocation_lines → aa_asset_classes, aa_account_codes
        │     └── aa_allocation_sub_lines
        └── aa_documents
              ├── aa_posting_lines
              └── aa_report_preview_rows
```

---

## Map UI → ตาราง

| แท็บ | ตาราง |
|------|--------|
| สรุปมูลค่า | `aa_auc_records`, `aa_auc_selections` |
| รายการ BOQ | `aa_boq_lines`, `aa_boq_mappings` |
| คำนวณมูลค่า | `aa_boq_calc_groups`, `aa_boq_calc_items` |
| SUMMARY OF BID PRICE | `aa_bid_price_notes` |
| คำนวณครุภัณฑ์ | `aa_equipment_sections`, `aa_equipment_items` |
| ปันส่วน | `aa_allocation_summaries`, `aa_allocation_lines` |
| บันทึกรับทรัพย์สิน | `aa_documents`, `aa_posting_lines` |

---

## เปรียบเทียบกับ schema เต็ม

| รายการ | Schema เต็ม | Schema ONLY |
|--------|-------------|-------------|
| ตาราง | ~26 | **20** |
| contracts/substations | มี | **ไม่มี** |
| Entry point | contract_wbs | **aa_wbs** |
| Prefix | work_job_* | **aa_*** |
| Scope | ทั้งโครงการ | **เฉพาะ Asset Acceptance** |
