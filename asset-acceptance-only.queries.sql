-- Asset Acceptance ONLY — sample queries

-- 1) Resolve session จาก WBS
SELECT j.id AS work_job_id, j.job_no, j.status, j.boq_total, j.boq_diff,
       w.wbs, w.work_name
FROM aa_wbs w
LEFT JOIN LATERAL (
  SELECT * FROM aa_work_jobs
  WHERE wbs_id = w.id ORDER BY created_at DESC LIMIT 1
) j ON TRUE
WHERE w.wbs = :wbs_no;

-- 2) AUC + selection (สรุปมูลค่า)
SELECT ar.auc_no, ar.auc_value, ar.allocation_mode,
       COALESCE(s.is_selected, FALSE) AS is_selected
FROM aa_auc_records ar
JOIN aa_wbs w ON w.id = ar.wbs_id
LEFT JOIN aa_auc_selections s
  ON s.auc_record_id = ar.id AND s.work_job_id = :work_job_id
WHERE w.wbs = :wbs_no;

-- 3) BOQ + mapping (รายการ BOQ)
SELECT b.seq, b.code, b.item_name, b.material_cost, b.labor_cost, b.total_cost,
       g.code AS mapped_group
FROM aa_boq_lines b
LEFT JOIN aa_boq_mappings m ON m.boq_line_id = b.id AND m.work_job_id = b.work_job_id
LEFT JOIN aa_asset_groups g ON g.id = m.asset_group_id
WHERE b.work_job_id = :work_job_id AND b.work_type = :work_type
ORDER BY b.seq;

-- 4) Equipment (คำนวณครุภัณฑ์)
SELECT sec.title, cat.category_name, item.seq, item.item_name, item.total_amount
FROM aa_equipment_sections sec
LEFT JOIN aa_equipment_categories cat ON cat.section_id = sec.id
LEFT JOIN aa_equipment_items item ON item.section_id = sec.id
WHERE sec.work_job_id = :work_job_id
ORDER BY sec.sort_order, cat.sort_order, item.seq;

-- 5) Allocation (ปันส่วน)
SELECT al.seq, al.item_name, ac.code AS asset_class, al.boq_amount, al.total_amount
FROM aa_allocation_lines al
LEFT JOIN aa_asset_classes ac ON ac.id = al.asset_class_id
WHERE al.work_job_id = :work_job_id ORDER BY al.seq;

-- 6) AA posting (บันทึกรับทรัพย์สิน)
SELECT d.document_type, p.product_number, p.description, p.asset_value
FROM aa_documents d
JOIN aa_posting_lines p ON p.document_id = d.id
WHERE d.work_job_id = :work_job_id AND d.document_type = 'as01'
ORDER BY p.sort_order;
