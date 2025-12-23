USE Insurance;

SELECT * FROM auto_insurance_claims;

SELECT DISTINCT claimnumber
FROM auto_insurance_claims; #7294 claims;

DESCRIBE auto_insurance_claims;

#Find columns exists in df1 but not in auto_insurance_claim
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'df1_staging3_2'
  AND TABLE_SCHEMA = 'Insurance'
  AND COLUMN_NAME NOT IN (
    SELECT COLUMN_NAME
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'auto_insurance_claims'
      AND TABLE_SCHEMA = 'Insurance'
  );
  -- -> claim_status, claim_status_name, claim_submitted_date, cost_copay, cost_copay_deductible, cost_deductible, don_vi_boi_thuong
  -- gdv_xu_ly, loai_boi_thuong, loai_hinh, ngay_duyet_bt, ngay_thanh_toan, pham_vi, policy_end_date, policy_start_date, ubt_trans

#Find columns exists in auto_insurance_claim table but not in df1
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'auto_insurance_claims'
  AND TABLE_SCHEMA = 'Insurance'
  AND COLUMN_NAME NOT IN (
    SELECT COLUMN_NAME
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'df1_staging3_2'
      AND TABLE_SCHEMA = 'Insurance'
  );
  
  #Backup the original table, create a staging one with columns below:
  -- has_photos, compensation_amount, accidentdate, agencycode, agencycompensation, agencyname, anh_cap_don, approveddate, assignee_fullname, biensoxe, claimnumber, companyname, contractcode, cost_3rdparty, cost_assetliquidation, cost_cuuho, cost_giam_tru, cost_giamdinh, cost_khau_tru, cost_tong_khau_giam_tru, createddate, customer_name, customer_type, customercode, damageestimation, distributionchannelcode, distributionchannelname, distributionunitname, flex_approved_date, giatrixe, hangxe, hangxe.keyword, hieuxe, is30day_trans, kieugiaychungnhanbaohiem, loai_giam_dinh, loai_hinh_trans, loaixe, ma_dvbt, ma_dvgd, mdsd, namsanxuat, ngay_mo_hsbt, ngaybatdau, ngayketthuc, nguoi_thuc_hien, nguyen_nhan_ton_that, nhomxe, noi_dung_tai_nan, partnercode, payment_date, policycode, processdays, requesterdate, salestaffcompanycode, salestaffcompanyname, salestaffdepartmentcode, salestaffdepartmentname, salestaffname, so_luong_anh, so_ngay_phat_sinh, so_vu, sochongoi, solutioncompensation, statusname, stbt, stbt_truoc_thue, tenchuxe, tong_uoc_bt_truoc_thue, trongtai, ubt, ubt_truoc_thue, uoc_bt_ban_dau, updateddate
  CREATE TABLE claims_staging1_2 AS (SELECT has_photos, compensation_amount, accidentdate, agencycode, agencycompensation, agencyname, anh_cap_don, approveddate, assignee_fullname, biensoxe, claimnumber, companyname, contractcode, cost_3rdparty, cost_assetliquidation, cost_cuuho, cost_giam_tru, cost_giamdinh, cost_khau_tru, cost_tong_khau_giam_tru, createddate, customer_name, customer_type, customercode, damageestimation, distributionchannelcode, distributionchannelname, distributionunitname, flex_approved_date, giatrixe, hangxe, hieuxe, is30day_trans, kieugiaychungnhanbaohiem, loai_giam_dinh, loai_hinh_trans, loaixe, ma_dvbt, ma_dvgd, mdsd, namsanxuat, ngay_mo_hsbt, ngaybatdau, ngayketthuc, nguoi_thuc_hien, nguyen_nhan_ton_that, nhomxe, noi_dung_tai_nan, partnercode, payment_date, policycode, processdays, requesterdate, salestaffcompanycode, salestaffcompanyname, salestaffdepartmentcode, salestaffdepartmentname, salestaffname, so_luong_anh, so_ngay_phat_sinh, so_vu, sochongoi, solutioncompensation, statusname, stbt, stbt_truoc_thue, tenchuxe, tong_uoc_bt_truoc_thue, trongtai, ubt, ubt_truoc_thue, uoc_bt_ban_dau, updateddate
									FROM auto_insurance_claims);
                                    


SELECT DISTINCT loai_hinh_trans FROM claims_staging1_2; #'TNDS bắt buộc', 'Tai nạn LPX & NNTX', 'Vật chất xe', 'TNDS tự nguyện'

ALTER TABLE claims_staging1_2
CHANGE loai_hinh_trans coverage TEXT;

UPDATE claims_staging1_2
SET coverage = CASE WHEN coverage = 'Tai nạn LPX & NNTX' THEN 'Personal injury coverage'
					 WHEN coverage = 'TNDS bắt buộc' THEN 'Auto liability coverage'
                     WHEN coverage = 'Vật chất xe' THEN 'Collision coverage'
					 WHEN coverage = 'TNDS tự nguyện' THEN 'Comprehensive coverage'
                     ELSE 'Unknown' END;
                     
#Statusname
SELECT DISTINCT statusname FROM claims_staging1_2;
-- 'Chưa giám định'  -> 'assessment pending'
-- 'Đã hủy' -> 'cancelled'
-- 'Đang xử lý' -> 'in process'
-- 'Chờ lập PASC' -> 'estimate pending'
-- 'Đã chi trả bồi thường' -> 'paid out'
-- 'Đã duyệt' -> 'approved'
-- 'Từ chối' -> 'denied'
-- 'Đang xử lý bồi thường' -> 'in process'
-- 'Chờ hoàn thiện hồ sơ' -> 'documents pending'

#there's a value statusname = '2', which is not reasonable for statusname so look up for the claims with that statusname to check
SELECT *
FROM claims_staging1_2
WHERE statusname = '2'; #'A022200704C003748'

#Look up this claim number in df1_staging3_2
SELECT claimnumber, claim_status, claim_status_name, updateddate
FROM df1_staging3_2
WHERE claimnumber = 'A022200704C003748';
-- for this claim, claim status is 'paid out'

#Change the statusname = 'Đã chi trả bồi thường'
UPDATE claims_staging1_2
SET statusname = 'Đã chi trả bồi thường'
WHERE claimnumber = 'A022200704C003748';

#Translate statusname values
UPDATE claims_staging1_2
SET statusname = CASE 
							WHEN statusname = 'Chưa giám định' THEN 'assessment pending'
							WHEN statusname = 'Chờ lập PASC' THEN 'estimate pending'
                            WHEN statusname = 'Đã duyệt' THEN 'approved'
                            WHEN statusname = 'Đã chi trả bồi thường' THEN 'paid out'
                            WHEN statusname = 'Từ chối' THEN 'denied'
                            WHEN statusname = 'Đã huỷ' THEN 'cancelled'
                            WHEN statusname = 'Chờ hoàn thiện hồ sơ' THEN 'documents pending'
                            WHEN statusname = 'Đang xử lý' OR statusname = 'Đang xử lý bồi thường' THEN 'in process'
						END;

 
#don_vi_boi_thuong - agencycompensation  
ALTER TABLE df1_staging3
CHANGE don_vi_boi_thuong agencycompensation TEXT;

#df1: ngay_thanh_toan -> df2: paymentdate 
ALTER TABLE df1_staging3 
CHANGE ngay_thanh_toan paymentdate TEXT;

#df1: loai_boi_thuong -> df2: solutioncompensation  
ALTER TABLE df1_staging3 
CHANGE loai_boi_thuong solutioncompensation TEXT;

SELECT DISTINCT solutioncompensation FROM df1_staging3;

SELECT DISTINCT solutioncompensation FROM claims_staging1;

#
SELECT *
FROM claims_staging1
WHERE solutioncompensation = '12';
-- -> 1 claim and it's typo error. 

#Fix the typo error of claimnumber 'A022200704014805'
#partnercode, payment_date, processdays, policycode, requesterdate, salestaffcompanycode, salestaffcompanyname, salestaffdepartmentname, salestaffname, 
#so_luong_anh = 18, salestaffname, sochongoi, so_ngay_phat_sinh = 12, sovu = 2, solutioncompensation = 'Tự bồi thường', statusname = Đã chi trả bồi thường, stbt, stbt_truoc_thue, tenchuxe, updateddate, uoc_bt_ban_dau, ubt_truoc_thue, ubt, trongtai, tong_uoc_bt_truoc_thue, 
#PBT, thuongtnd, 18, 12, 2, 51, 7,6
UPDATE claims_staging1
SET partnercode = '-', 
	payment_date = '-',
    processdays = '-',
    policycode= '-',
    requesterdate = '-',
    salestaffcompanycode = '-',
    salestaffcompanyname = '-',
    salestaffdepartmentname = '-',
    salestaffname = '-', 
    salestaffname = '-', 
    sochongoi = '-', 
    so_luong_anh = '18', 
    so_ngay_phat_sinh = '12',
    so_vu = '2',
    solutioncompensation = 'Tự bồi thường',
    statusname = 'Đã chi trả bồi thường',
    tenchuxe = 'CÔNG TY TNHH VẬN TẢI VÀ DỊCH VỤ DU LỊCH HẢI VÂN',
    stbt = '-',
    stbt_truoc_thue = '-',
    updateddate = '-',
    uoc_bt_ban_dau = '-',
    ubt_truoc_thue = '-',
    ubt = '-',
    trongtai = '-',
    tong_uoc_bt_truoc_thue = '-'
WHERE claimnumber = 'A022200704C003748';

#Translate values of solutioncompensation
UPDATE df1_staging3
SET solutioncompensation = CASE WHEN solutioncompensation = 'Tự bồi thường' THEN 'Self-insurance'
								WHEN solutioncompensation = 'Bồi thường hệ thống' THEN 'Traditional insurance'
								ELSE 'Unknown'
							END
WHERE solutioncompensation IS NOT NULL;

UPDATE claims_staging1
SET solutioncompensation = CASE WHEN solutioncompensation = 'Tự bồi thường' THEN 'Self-insurance'
								WHEN solutioncompensation = 'Bồi thường hệ thống' THEN 'Traditional insurance'
								ELSE 'Unknown'
							END
WHERE solutioncompensation IS NOT NULL;

#df1: pham_vi -> df2: nguyen_nhan_ton_that  
#Translate pham_vi & nguyen_nhan_ton_that column name 
ALTER TABLE df1_staging3
CHANGE pham_vi damage_type TEXT;

ALTER TABLE claims_staging1
CHANGE nguyen_nhan_ton_that accident_type TEXT;

#Change invalid values from '-' or '' to 'Unknown
UPDATE claims_staging1
SET accident_type = 'Unknown'
WHERE accident_type = '' OR accident_type = '-';


SELECT DISTINCT damage_type FROM df1_staging3_2; 
-- 'Personal Injury Loss', 'Unclassified', 'Third-Party Vehicle Property', 'Partial/Total Loss', 'Theft', 'Other Third-Party Property', 'Multiple'


SELECT DISTINCT accident_type FROM claims_staging1;
-- 1. 'Đâm/va xe ô tô', 'Đâm/va xe ô tô,Khác', 'Đâm/va xe ô tô,Đâm/va vật thể cố định', 'Vật thể khác rơi vào,Đâm/va xe ô tô', 'Đâm/va vật thể cố định,Đâm/va xe ô tô' -> Cars Accidents
-- 2. 'Unknown'
-- 3. 'Đâm/va xe máy,Khác', 'Đâm/va xe máy', 'Khác,Đâm/va xe máy', 'Đâm/va xe máy,Đâm/va vật thể cố định', 'Đâm/va vật thể cố định,Đâm/va xe máy',  'Đâm/va xe máy,Vật thể khác rơi vào', 'Vật thể khác rơi vào,Đâm/va xe máy,Đâm/va vật thể cố định' -> Bicycle/Motorcycle Accidents
-- 4. 'Khác,Đâm/va vật thể cố định', 'Đâm/va vật thể cố định,Vật thể khác rơi vào', 'Đâm/va vật thể cố định', 'Vật thể khác rơi vào,Đâm/va vật thể cố định', 'Đâm/va động vật,Đâm/va vật thể cố định', 'Đâm/va động vật', 'Đâm/va vật thể cố định,Đâm/va động vật', 'Rơi xe', 'Lật xe', 'Rơi xe', 'Đâm/va vật thể cố định,Lật xe', 'Rơi xe,Lật xe' -> Single-Vehicle Accident
-- 5. 'Vật thể khác rơi vào', 'Bị phá hoại', 'Hỏa hoạn, cháy, nổ', 'Mất cắp', 'Do thiên nhiên','Thủy kích', 'Khác,Chi phí cứu hộ' -> External Causes/Non-Collison Damages
-- 6. 'Đâm/va xe máy,Đâm/va xe ô tô', 'Đâm/va xe ô tô,Đâm/va xe máy' -> Multi-Vehicle Accidents 

#Categorize & replace values in accident_type from claims_staging1
UPDATE claims_staging1
SET accident_type = 'Car Accidents'
WHERE accident_type = 'Đâm/va xe ô tô' OR accident_type = 'Đâm/va xe ô tô,Khác' OR accident_type = 'Đâm/va xe ô tô,Đâm/va vật thể cố định'
		OR accident_type = 'Vật thể khác rơi vào,Đâm/va xe ô tô' OR accident_type = 'Đâm/va vật thể cố định,Đâm/va xe ô tô';

UPDATE claims_staging1
SET accident_type = 'Bicycle/Motorcycle Accidents'
WHERE accident_type = 'Đâm/va xe máy,Khác' OR accident_type = 'Đâm/va xe máy' OR accident_type = 'Khác,Đâm/va xe máy'
		OR accident_type = 'Đâm/va xe máy,Đâm/va vật thể cố định' OR accident_type = 'Đâm/va vật thể cố định,Đâm/va xe máy'
        OR accident_type = 'Đâm/va xe máy,Vật thể khác rơi vào' OR accident_type = 'Vật thể khác rơi vào,Đâm/va xe máy,Đâm/va vật thể cố định';

UPDATE claims_staging1
SET accident_type = 'Single-Vehicle Accident'
WHERE accident_type = 'Khác,Đâm/va vật thể cố định' OR accident_type = 'Đâm/va vật thể cố định,Vật thể khác rơi vào' OR accident_type = 'Đâm/va vật thể cố định'
		OR accident_type = 'Vật thể khác rơi vào,Đâm/va vật thể cố định' OR accident_type = 'Đâm/va động vật,Đâm/va vật thể cố định'
        OR accident_type = 'Đâm/va động vật' OR accident_type = 'Đâm/va vật thể cố định,Đâm/va động vật' OR accident_type = 'Lật xe' 
        OR accident_type = 'Rơi xe' OR accident_type = 'Đâm/va vật thể cố định,Lật xe' OR accident_type = 'Rơi xe,Lật xe';

UPDATE claims_staging1
SET accident_type = 'External Causes/Non-Collison Damages'
WHERE accident_type = 'Vật thể khác rơi vào' OR accident_type = 'Bị phá hoại' OR accident_type = 'Hỏa hoạn, cháy, nổ'
		OR accident_type = 'Mất cắp' OR accident_type = 'Do thiên nhiên' OR accident_type = 'Thủy kích' OR accident_type = 'Khác,Chi phí cứu hộ';

UPDATE claims_staging1
SET accident_type = 'Multi-Vehicle Accidents '
WHERE accident_type = 'Đâm/va xe máy,Đâm/va xe ô tô' OR accident_type = 'Đâm/va xe ô tô,Đâm/va xe máy';


CREATE INDEX idx_claimnumber ON claims_staging1(claimnumber(25));
CREATE INDEX idx_damage_type ON claims_staging1(damage_type(50));


#** CANNOT DO THIS!
#Check for all claims that have valid 'damage_type' value in df1 & also exists in df2
#Change values of damage_type in claims_staging1 into same values as damage_type in df1
WITH damagetype_CTE AS (
	SELECT DISTINCT claimnumber, damage_type 
	FROM df1_staging3
	WHERE damage_type != 'Unknown' AND claimnumber IN (SELECT DISTINCT claimnumber
														FROM claims_staging1)
	) #6161 claims
UPDATE claims_staging1 AS t
JOIN damagetype_CTE AS s
	ON t.claimnumber = s.claimnumber
SET t.damage_type = s.damage_type;

#See claims that does not hold values of damage_type in df1
CREATE TEMPORARY TABLE damagetype_NotIn_df1 AS 
	SELECT claimnumber, damage_type, noi_dung_tai_nan
	FROM claims_staging1
	WHERE claimnumber NOT IN (SELECT DISTINCT claimnumber
							FROM df1_staging3
                            WHERE damage_type != 'Unknown')
;

SELECT DISTINCT damage_type
FROM damagetype_NotIn_df1;
-- 'Đâm/va xe máy'
-- 'Đâm/va xe ô tô'
-- 'Đâm/va vật thể cố định,Đâm/va xe máy'
-- 'Đâm/va xe máy,Vật thể khác rơi vào'
-- 'Đâm/va xe máy,Đâm/va xe ô tô'
-- 'Khác,Đâm/va xe máy'
-- 'Đâm/va xe ô tô,Đâm/va xe máy'

-- '-'
-- 'Khác'
-- 'Lật xe'
-- 'Vật thể khác rơi vào'
-- 'Bị phá hoại'
-- 'Rơi xe'
-- 'Thủy kích'
-- 'Đâm/va động vật'
-- 'Hỏa hoạn, cháy, nổ'
-- 'Mất cắp'

SELECT DISTINCT damage_type 
FROM df1_staging3; 
-- 'Tổn thất về người', 'Tài sản bên thứ 3 về xe', 'Tài sản bên thứ 3 khác'
-- 'Unknown', 'Tổn thất bộ phận/toàn bộ', 'Mất cắp bộ phận'

#Update values in damage_type of claims_staging1
UPDATE claims_staging1
SET damage_type = 'Unknown'
WHERE damage_type = '-' OR damage_type = 'Khác';

UPDATE claims_staging1
SET damage_type = 'Tổn thất bộ phận/toàn bộ'
WHERE damage_type = 'Lật xe' OR damage_type = 'Vật thể khác rơi vào' OR damage_type = 'Bị phá hoại' OR damage_type = 'Rơi xe'
		OR damage_type = 'Thủy kích' OR damage_type = 'Đâm/va động vật' OR damage_type = 'Hỏa hoạn, cháy, nổ';

UPDATE claims_staging1
SET damage_type = 'Mất cắp bộ phận'
WHERE damage_type = 'Mất cắp';

UPDATE claims_staging1
SET damage_type = 'Tài sản bên thứ 3 khác'
WHERE damage_type = 'Đâm/va vật thể cố định';

#Update damage_type in claims_staging1 with 'Tổn thất về người' values
WITH damagetype_CTE1 AS (
	SELECT claimnumber, damage_type, noi_dung_tai_nan
	FROM damagetype_NotIn_df1
	WHERE damage_type IN ('Đâm/va xe máy', 'Đâm/va xe ô tô', 'Đâm/va vật thể cố định', 'Đâm/va xe máy'
							'Đâm/va xe máy,Vật thể khác rơi vào', 'Đâm/va xe máy,Đâm/va xe ô tô'
							'Khác,Đâm/va xe máy', 'Đâm/va xe ô tô,Đâm/va xe máy')
    )
UPDATE claims_staging1
SET damage_type = 'Tổn thất về người'
WHERE claimnumber IN (SELECT claimnumber FROM damagetype_CTE1)
		AND (noi_dung_tai_nan LIKE '%người chết%' 
			OR noi_dung_tai_nan LIKE '%bị thương%'
			OR noi_dung_tai_nan LIKE '%tử vong%' 
            OR noi_dung_tai_nan LIKE '%cấp cứu%'
			OR noi_dung_tai_nan LIKE '%bệnh viện%'
            OR noi_dung_tai_nan LIKE '%nhập viện%')
;

WITH damagetype_CTE2 AS 
	(SELECT *
	FROM damagetype_NotIn_df1
	WHERE damage_type != 'Unknown' AND 
			(noi_dung_tai_nan LIKE '%người chết%' 
			OR noi_dung_tai_nan LIKE '%bị thương%'
			OR noi_dung_tai_nan LIKE '%tử vong%' 
            OR noi_dung_tai_nan LIKE '%cấp cứu%'
			OR noi_dung_tai_nan LIKE '%bệnh viện%'
            OR noi_dung_tai_nan LIKE '%nhập viện%')
	)
UPDATE claims_staging1
SET damage_type = 'Tổn thất về người'
WHERE damage_type IN ('Đâm/va xe máy', 'Đâm/va xe ô tô', 'Đâm/va vật thể cố định', 'Đâm/va xe máy'
							'Đâm/va xe máy,Vật thể khác rơi vào', 'Đâm/va xe máy,Đâm/va xe ô tô'
							'Khác,Đâm/va xe máy', 'Đâm/va xe ô tô,Đâm/va xe máy') 
;


#Fill in empty/null/invalid values
-- uoc_bt_ban_dau
UPDATE claims_staging1
SET uoc_bt_ban_dau = '0'
WHERE uoc_bt_ban_dau = '-';

UPDATE claims_staging1
SET uoc_bt_ban_dau = REPLACE(uoc_bt_ban_dau, ',', '')
WHERE uoc_bt_ban_dau LIKE '%,%';

SELECT MAX(LENGTH(uoc_bt_ban_dau))
FROM claims_staging1; #9

ALTER TABLE claims_staging1
CHANGE uoc_bt_ban_dau claim_estimate_first DECIMAL(15,2);


#Check if numeric columns have empty/invalid values
SELECT *
FROM claims_staging1
WHERE cost_tong_khau_giam_tru = '-' OR stbt = '-' OR stbt_truoc_thue = '-' OR tong_uoc_bt_truoc_thue = '-' 
		OR ubt = '-' OR ubt_truoc_thue = '-'; 


#Update the empty/invalid values in numeric columns to equal 0
UPDATE claims_staging1
SET  
    cost_giam_tru = CASE WHEN cost_giam_tru = '-' THEN '0' ELSE cost_giam_tru END,
    cost_khau_tru = CASE WHEN cost_khau_tru = '-' THEN '0' ELSE cost_khau_tru END,
    cost_tong_khau_giam_tru = CASE WHEN cost_tong_khau_giam_tru = '-' THEN '0' ELSE cost_tong_khau_giam_tru END,
    stbt = CASE WHEN stbt = '-' THEN '0' ELSE stbt END,
    stbt_truoc_thue = CASE WHEN stbt_truoc_thue = '-' THEN '0' ELSE stbt_truoc_thue END,
    tong_uoc_bt_truoc_thue = CASE WHEN tong_uoc_bt_truoc_thue = '-' THEN '0' ELSE tong_uoc_bt_truoc_thue END,
    ubt = CASE WHEN ubt = '-' THEN '0' ELSE ubt END,
    ubt_truoc_thue = CASE WHEN ubt_truoc_thue = '-' THEN '0' ELSE ubt_truoc_thue END
WHERE 
    cost_giam_tru = '-' OR 
    cost_khau_tru = '-' OR 
    cost_tong_khau_giam_tru = '-' OR 
    stbt = '-' OR 
    stbt_truoc_thue = '-' OR 
    tong_uoc_bt_truoc_thue = '-' OR 
    ubt = '-' OR 
    ubt_truoc_thue = '-';

SELECT * 
FROM claims_staging1
WHERE cost_3rdparty = '-' OR cost_assetliquidation = '-' OR cost_cuuho = '-' OR cost_giam_tru = '-'
		OR cost_giamdinh = '-' OR cost_khau_tru = '-' OR cost_tong_khau_giam_tru = '-'; #0
 
#Replace ',' with '' in values of these column
UPDATE claims_staging1
SET cost_3rdparty = REPLACE (cost_3rdparty, ',', ''), 
	cost_assetliquidation = REPLACE (cost_assetliquidation, ',', ''), 
    cost_cuuho = REPLACE (cost_cuuho, ',', ''), 
	cost_giam_tru = REPLACE (cost_giam_tru, ',', ''),
    cost_giamdinh = REPLACE (cost_giamdinh, ',', ''), 
	cost_khau_tru = REPLACE (cost_khau_tru, ',', ''), 
    cost_tong_khau_giam_tru = REPLACE (cost_tong_khau_giam_tru, ',', ''),
    stbt = REPLACE (stbt, ',', ''),
    stbt_truoc_thue = REPLACE (stbt_truoc_thue, ',', ''),
    tong_uoc_bt_truoc_thue = REPLACE (tong_uoc_bt_truoc_thue, ',', ''),
    ubt = REPLACE (ubt, ',', ''),
    ubt_truoc_thue = REPLACE (ubt_truoc_thue, ',', '');

#Check if cost columns has all 0 values
SELECT claimnumber, cost_3rdparty, cost_assetliquidation, cost_cuuho
FROM claims_staging1
WHERE cost_cuuho != 0;
#cost_3rdparty = 0, cost_assetliquidation 'A022104801C000074', cost_cuuho (10 claims)

#Check if compensation_amount column has all 0 values
SELECT claimnumber, compensation_amount
FROM claims_staging1
WHERE compensation_amount != 0; 
-- Yes all 0 -> delete column

#Drop column compensation_amount
ALTER TABLE claims_staging1
DROP COLUMN compensation_amount;

#Drop column cost_3rdparty
ALTER TABLE claims_staging1
DROP COLUMN cost_3rdparty;

#Change these columns from Text datatype to INT or BIGINT
ALTER TABLE claims_staging1
CHANGE 	cost_cuuho cost_towing DECIMAL(15,2), 
CHANGE	cost_giam_tru cost_copay DECIMAL(15,2),
CHANGE	cost_giamdinh cost_investigation DECIMAL(15,2), 
CHANGE	cost_khau_tru cost_deductible DECIMAL(15,2), 
CHANGE	cost_tong_khau_giam_tru cost_copay_deductible DECIMAL(15,2),
CHANGE	stbt compensation_total DECIMAL(15,2),
CHANGE	stbt_truoc_thue compensation_amount_beforetax DECIMAL(15,2),
CHANGE	tong_uoc_bt_truoc_thue total_claim_estimate DECIMAL(15,2),
CHANGE	ubt claim_estimate DECIMAL(15,2),
CHANGE	ubt_truoc_thue claim_estimate_beforetax DECIMAL(15,2);

SELECT DISTINCT statusname FROM claims_staging1;
-- 'Chưa giám định'
-- 'Đã hủy'
-- 'Đang xử lý'
-- 'Chờ lập PASC'
-- 'Đã chi trả bồi thường'
-- 'Đã duyệt'
-- 'Từ chối'
-- 'Đang xử lý bồi thường'

#Check if cost_copay_deductible is a sum of cost_copay & cost_deductible
WITH sum_cost_CTE AS (SELECT claimnumber, cost_towing, cost_investigation, cost_copay, cost_deductible, cost_copay_deductible, 
							(cost_copay + cost_deductible) = cost_copay_deductible AS is_sum_correct
					  FROM claims_staging1)
SELECT claimnumber, cost_towing, cost_investigation, cost_copay, cost_deductible, cost_copay_deductible, is_sum_correct
FROM sum_cost_CTE
WHERE is_sum_correct = 0
ORDER BY claimnumber; #402 rows gives cost_copay_deductible is NOT a sum of cost_copay & cost_deductible

#Check if claimnumber in those 402 rows have more than 1 rows


#check if claim_estimate != 0 or claim_estimate_beforetax != 0 but total_claim_estimate = 0
SELECT claimnumber, claim_estimate, claim_estimate_beforetax, total_claim_estimate
FROM (SELECT claimnumber, claim_estimate, claim_estimate_beforetax, total_claim_estimate
		FROM claims_staging1
		WHERE claim_estimate != 0 OR claim_estimate_beforetax != 0) AS s
WHERE s.total_claim_estimate = 0; #0 rows

#Check if compensation_amount_beforetax != 0 but compensation_total = 0
SELECT claimnumber, compensation_amount_beforetax, compensation_total
FROM (SELECT claimnumber, compensation_amount_beforetax, compensation_total
		FROM claims_staging1
		WHERE compensation_amount_beforetax != 0) AS s
WHERE s.compensation_total = 0; #0

#check if status = 'Đã chi trả bồi thường' or 'Đã duyệt' but compensation_total = 0
SELECT claimnumber, statusname, claim_estimate, claim_estimate_beforetax, total_claim_estimate, compensation_amount_beforetax, compensation_total
FROM claims_staging1
WHERE (statusname = 'Đã chi trả bồi thường' OR statusname = 'Đã duyệt') 
		AND compensation_total = 0; #148 rows

WITH accepted_none_compensation_CTE AS (
		SELECT claimnumber, statusname, claim_estimate, claim_estimate_beforetax, total_claim_estimate, compensation_amount_beforetax, compensation_total
		FROM claims_staging1
		WHERE (statusname = 'Đã chi trả bồi thường' OR statusname = 'Đã duyệt') 
				AND compensation_total = 0
) #148 rows return
SELECT claimnumber, claim_status_name, claim_status, ubt, stbt_truoc_thue, updateddate
FROM df1_staging3 
WHERE claimnumber IN (SELECT claimnumber FROM accepted_none_compensation_CTE) AND stbt_truoc_thue != 0
ORDER BY claimnumber, updateddate
;


#if those 148 rows have total_claim_estimate != 0 values, we fill in compensation_total = total_claim_estimate


#Check if claims have status 'Chưa giám định', 'Đã hủy', 'Đang xử lý', 'Chờ lập PASC', 'Từ chối', 'Đang xử lý bồi thường' but have compensation_total != 0
SELECT claimnumber, statusname, claim_estimate, claim_estimate_beforetax, total_claim_estimate, compensation_amount_beforetax, compensation_total
FROM (SELECT claimnumber, statusname, claim_estimate, claim_estimate_beforetax, total_claim_estimate, compensation_amount_beforetax, compensation_total
		FROM claims_staging1
		WHERE statusname = 'Chưa giám định' OR statusname = 'Đã hủy' OR statusname = 'Đang xử lý' OR statusname = 'Chờ lập PASC'
				OR statusname = 'Từ chối' OR statusname = 'Đang xử lý bồi thường') AS s
WHERE s.compensation_total != 0; #0

#Find claims with total_claim_estimate = 0 
SELECT claimnumber, statusname, claim_estimate, claim_estimate_beforetax, total_claim_estimate, compensation_amount_beforetax, compensation_total
FROM claims_staging1
WHERE total_claim_estimate = 0 AND statusname != 'Đã hủy';
-- 'A022201005C001406', 'Từ chối', '0.00', '0.00', '0.00', '0.00', '0.00'
-- 'A022200704C003748', 'Đã chi trả bồi thường', '0.00', '0.00', '0.00', '0.00', '0.00'

#Find those 2 claims above in different table
SELECT *
FROM df1_staging3
WHERE claimnumber = 'A022201005C001406' OR claimnumber = 'A022200704C003748'
ORDER BY claimnumber, updateddate;

SELECT *
FROM df2_new
WHERE claimnumber = 'A022201005C001406' OR claimnumber = 'A022200704C003748'
ORDER BY claimnumber;


-- There's more valid values in the other tables

#Fill in the missing info of those claims
 

SELECT claimnumber, cost_assetliquidation, cost_towing, cost_copay, cost_investigation, cost_deductible,
		cost_copay_deductible, compensation_total, compensation_amount_beforetax, total_claim_estimate, claim_estimate, claim_estimate_beforetax
FROM claims_staging1;


#Check for repeated/duplicated claimnumber
WITH duplicate_cte AS
	(SELECT *,
		ROW_NUMBER() OVER(PARTITION BY claimnumber) AS row_num
	FROM claims_staging1
	)
SELECT claimnumber, policycode, coverage, cost_towing, cost_investigation, cost_copay_deductible, accident_type, payment_date, statusname, compensation_total, compensation_amount_beforetax,
		total_claim_estimate, claim_estimate, claim_estimate_beforetax, claim_estimate_first, updateddate, row_num
FROM duplicate_cte
WHERE claimnumber IN (SELECT DISTINCT claimnumber FROM duplicate_CTE WHERE row_num > 1)
ORDER BY claimnumber, updateddate; #379

#Finding out if this claim has repeated exact rows or there's differences between two rows
SELECT * 
FROM auto_insurance_claims
WHERE claimnumber = 'A012205003C005241';
-- -> The difference between 2 rows is the 'coverage' column values
SELECT claimnumber, claim_status_name, cost_copay, cost_deductible, cost_copay_deductible, coverage, damage_type, stbt_truoc_thue, ubt, ubt_trans, uoc_bt_ban_dau, updateddate, claim_status
FROM df1_staging3
WHERE claimnumber = 'A012205003C005241'
ORDER BY updateddate;

SELECT claimnumber, claim_status_name, flex_ngay_duyet, loai_hinh, ngay_duyet_bt, pham_vi, stbt_truoc_thue, ubt, ubt_trans, uoc_bt_ban_dau, updateddate
FROM df1
WHERE claimnumber = 'A012205003C005241'
ORDER BY updateddate;

#Finding out if all repeated claim rows have differences in 'coverage' column values
#Check for repeated values
WITH duplicate_CTE AS 
		(SELECT *,
		ROW_NUMBER() OVER( PARTITION BY claimnumber, coverage) AS row_num
		FROM claims_staging1)
SELECT * 
FROM duplicate_CTE
WHERE row_num > 1
ORDER BY claimnumber, updateddate;
-- 0 rows return, which means all repeated claims are different in 'coverage' values

#Fix damage_type column
ALTER TABLE claims_staging1
CHANGE damage_type damage_type_wrong TEXT;

ALTER TABLE claims_staging1
ADD COLUMN damage_type TEXT;

UPDATE claims_staging1 AS t
JOIN (SELECT claimnumber, nguyen_nhan_ton_that FROM auto_insurance_claims) AS s
	ON t.claimnumber = s.claimnumber
SET t.damage_type = s.nguyen_nhan_ton_that
WHERE t.damage_type IS NULL;

#Check if there's any same claimnumbers with different total_claim_estimate 

#Check if there's any same claimnumbers with same total_claim_estimate and same claim_estimate, same compensation_total

#check if there's any same claimsnumbers > 2 rows with 0 value in claim_estimate, claim_estimate_beforetax -> if yes, that type of coverage is not considered
WITH repeated_claims_CTE AS (
	SELECT claimnumber, COUNT(*) AS count
	FROM claims_staging1
	GROUP BY claimnumber
	HAVING count > 1)
SELECT claimnumber, statusname, coverage, damage_type, damage_type_wrong, compensation_total, compensation_amount_beforetax, total_claim_estimate, claim_estimate, claim_estimate_beforetax
FROM claims_staging1
WHERE claimnumber IN (SELECT claimnumber
						FROM claims_staging1
						WHERE claimnumber IN (SELECT DISTINCT claimnumber FROM repeated_claims_CTE) AND (claim_estimate= 0 AND claim_estimate_beforetax = 0)
					)
;

-- 'Chờ lập PASC': 
-- 'Đang xử lí':
-- 'Đã chi trả bồi thường':
-- 'Đã huỷ':
-- 'Chưa giám định': 
-- 'Từ chối': 

#Check if there's any same claimnumbers > 2 rows with statusname = 'Đã chi trả bồi thường' have different compensation_total
WITH paid_out_diff_compensation_CTE1 AS
	(SELECT claimnumber, statusname, coverage, damage_type, damage_type_wrong, compensation_total, compensation_amount_beforetax, total_claim_estimate, claim_estimate, claim_estimate_beforetax,
			ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY coverage, compensation_total) AS row_num
	FROM claims_staging1
	WHERE statusname = 'Đã chi trả bồi thường')
SELECT claimnumber, statusname, coverage, damage_type, damage_type_wrong, compensation_total, compensation_amount_beforetax, total_claim_estimate, claim_estimate, claim_estimate_beforetax
FROM claims_staging1
WHERE claimnumber IN (SELECT claimnumber FROM paid_out_diff_compensation_CTE1 WHERE row_num > 1) 
ORDER BY claimnumber;

#Check if there's any same claimnumbers > 2 rows with statusname = 'Đã chi trả bồi thường' have same compensation_total
WITH paid_out_same_compensation_CTE AS
	(SELECT claimnumber, statusname, coverage, damage_type, damage_type_wrong, compensation_total, compensation_amount_beforetax, total_claim_estimate, claim_estimate, claim_estimate_beforetax,
			ROW_NUMBER() OVER (PARTITION BY claimnumber, compensation_total ORDER BY coverage) AS row_num
	FROM claims_staging1
	WHERE statusname = 'Đã chi trả bồi thường')
SELECT claimnumber, statusname, coverage, damage_type, damage_type_wrong, compensation_total, compensation_amount_beforetax, total_claim_estimate, claim_estimate, claim_estimate_beforetax
FROM claims_staging1
WHERE claimnumber IN (SELECT claimnumber FROM paid_out_same_compensation_CTE WHERE row_num > 1) 
ORDER BY claimnumber;

#Check if there's any same claimnumbers > 2 rows with statusname = 'Đã chi trả bồi thường' have same compensation_total
WITH repeated_claims_CTE AS (
	SELECT claimnumber, COUNT(*) AS count
	FROM claims_staging1
    WHERE statusname = 'Đã chi trả bồi thường'
	GROUP BY claimnumber
	HAVING count > 1)
SELECT claimnumber
FROM claims_staging1
WHERE claimnumber IN (SELECT claimnumber FROM repeated_claims_CTE)
GROUP BY claimnumber
HAVING COUNT(DISTINCT compensation_total) = 1; #0 row

-- 'A022200606C000064'

#check if there's claimnumbers with same total_claim_estimate & claim_estimate



#If the coverage is collision -> vat chat xe 

SELECT claimnumber, processdays, is30day_trans, statusname
FROM claims_staging1
ORDER BY claimnumber;

SELECT claimnumber, statusname, createddate, accidentdate, updateddate, payment_date, processdays, so_ngay_phat_sinh, assignee_fullname, solutioncompensation, compensation_total, agencycompensation
FROM claims_staging1
ORDER BY claimnumber;

#Check for invalid values of assignee_fullname
SELECT *
FROM claims_staging1
WHERE assignee_fullname = '' OR assignee_fullname = '-' OR assignee_fullname IS NULL;
-- -> None

#DElete column nguoi_thuc_hien
ALTER TABLE claims_staging1
DROP COLUMN nguoi_thuc_hien;

#Change column with dates from text to datetime datatype
SELECT claimnumber, statusname, updateddate, requesterdate, payment_date, ngay_mo_hsbt, ngaybatdau, ngayketthuc, flex_approved_date, createddate, approveddate, accidentdate
FROM claims_staging1;
-- # updateddate, requesterdate, payment_date, ngay_mo_hsbt, ngaybatdau, ngayketthuc, flex_approved_date, createddate, approveddate, accidentdate
-- '31-12-2021', '30/12/2021', '24/12/2021', '29/12/2021', '27/12/2021', '27/12/2022', 'Dec 31, 2021 @ 11:51:38.000', '23-12-2021', '-', '29/12/2021'

#Find the invalid values in datetime columns
SELECT *
FROM claims_staging1
WHERE updateddate = '-';
-- 'A022200704C003748'

SELECT claimnumber, statusname, createddate, payment_date, updateddate, requesterdate, ngay_mo_hsbt, ngaybatdau, ngayketthuc, flex_approved_date, approveddate, accidentdate
FROM claims_staging1
WHERE payment_date = '-'; #84 rows

SELECT claimnumber, statusname, createddate, payment_date, updateddate, requesterdate, ngay_mo_hsbt, ngaybatdau, ngayketthuc, flex_approved_date, approveddate, accidentdate
FROM claims_staging1
WHERE flex_approved_date = '-' OR approveddate = '-'; #1537 rows

SELECT claimnumber, statusname, createddate, payment_date, updateddate, requesterdate, ngay_mo_hsbt, ngaybatdau, ngayketthuc, flex_approved_date, approveddate, accidentdate
FROM claims_staging1
WHERE requesterdate = '-'; #A022200704C003748

#Fill in the invalid/empty values of datetime columns
UPDATE claims_staging1
SET updateddate = '29-06-2022'
WHERE claimnumber = 'A022200704C003748';

UPDATE claims_staging1
SET payment_date = ngaybatdau
WHERE payment_date = '-';

UPDATE claims_staging1
SET requesterdate = '07/05/2022'
WHERE claimnumber = 'A022200704C003748';

SELECT claimnumber, statusname, flex_approved_date, approveddate
FROM claims_staging1
WHERE (flex_approved_date = '-' AND approveddate != '-') OR (flex_approved_date != '-' AND approveddate = '-');
-- -> flex_approved_date is the date when the claim is given the last decision 

#Change the invalid/empty value to null in flex_approved_date and approveddate
UPDATE claims_staging1
SET flex_approved_date = NULL
WHERE flex_approved_date = '-';

UPDATE claims_staging1
SET approveddate = NULL
WHERE approveddate = '-';

#Change the datatype of flex_approved_date and approveddate
UPDATE claims_staging1
SET flex_approved_date = DATE(STR_TO_DATE(flex_approved_date, '%b %d, %Y @ %H:%i:%s.%f'))
WHERE flex_approved_date IS NOT NULL;

ALTER TABLE claims_staging1
MODIFY COLUMN flex_approved_date DATE;

UPDATE claims_staging1
SET approveddate = DATE(STR_TO_DATE(approveddate, '%b %d, %Y @ %H:%i:%s.%f'))
WHERE approveddate IS NOT NULL;

ALTER TABLE claims_staging1
MODIFY COLUMN approveddate DATE;

#Convert datatype from text to datetime: createddate (quote sent), payment_date (purchase), ngaybatdau, ngayketthuc, accidentdate, requesterdate, ngay_mo_hsbt, flex_approved_date, approveddate, updateddate
SELECT createddate, payment_date, ngaybatdau, ngayketthuc, ngayketthuc, requesterdate, ngay_mo_hsbt, flex_approved_date, approveddate, updateddate
FROM claims_staging1;

UPDATE claims_staging1
SET createddate = DATE(STR_TO_DATE(createddate, '%d-%m-%Y'))
WHERE createddate IS NOT NULL;
ALTER TABLE claims_staging1
MODIFY COLUMN createddate DATE;

#payment_date '24/12/2021'
UPDATE claims_staging1
SET payment_date = DATE(STR_TO_DATE(payment_date, '%d/%m/%Y'))
WHERE payment_date IS NOT NULL;
ALTER TABLE claims_staging1
MODIFY COLUMN payment_date DATE;

#ngaybatdau '13/12/2021'
UPDATE claims_staging1
SET ngaybatdau = DATE(STR_TO_DATE(ngaybatdau, '%d/%m/%Y'))
WHERE ngaybatdau IS NOT NULL;
ALTER TABLE claims_staging1
MODIFY COLUMN ngaybatdau DATE;

#ngayketthuc '31/12/2022'
UPDATE claims_staging1
SET ngayketthuc = DATE(STR_TO_DATE(ngayketthuc, '%d/%m/%Y'))
WHERE ngayketthuc IS NOT NULL;
ALTER TABLE claims_staging1
MODIFY COLUMN ngayketthuc DATE;

#requesterdate '23/01/2022'
UPDATE claims_staging1
SET requesterdate = DATE(STR_TO_DATE(requesterdate, '%d/%m/%Y'))
WHERE requesterdate IS NOT NULL;
ALTER TABLE claims_staging1
MODIFY COLUMN requesterdate DATE;

#ngay_mo_hsbt '23/01/2022'
UPDATE claims_staging1
SET ngay_mo_hsbt = DATE(STR_TO_DATE(ngay_mo_hsbt, '%d/%m/%Y'))
WHERE ngay_mo_hsbt IS NOT NULL;
ALTER TABLE claims_staging1
MODIFY COLUMN ngay_mo_hsbt DATE;

#accidentdate '23/01/2022'
UPDATE claims_staging1
SET accidentdate = DATE(STR_TO_DATE(accidentdate, '%d/%m/%Y'))
WHERE accidentdate IS NOT NULL;
ALTER TABLE claims_staging1
MODIFY COLUMN accidentdate DATE;

#updateddate '22-08-2022'
UPDATE claims_staging1
SET updateddate = DATE(STR_TO_DATE(updateddate, '%d-%m-%Y'))
WHERE updateddate IS NOT NULL;
ALTER TABLE claims_staging1
MODIFY COLUMN updateddate DATE;

#Check if createddate < payment_date, ngaybatdau < ngayketthuc, accidentdate < requesterdate, requesterdate < ngay_mo_hsbt
SELECT claimnumber, statusname, createddate, payment_date, updateddate, requesterdate, ngay_mo_hsbt, ngaybatdau, ngayketthuc, flex_approved_date, approveddate, accidentdate
FROM claims_staging1
WHERE createddate > payment_date; #580

SELECT claimnumber, statusname, createddate, payment_date, updateddate, requesterdate, ngay_mo_hsbt, ngaybatdau, ngayketthuc, flex_approved_date, approveddate, accidentdate
FROM claims_staging1
WHERE ngaybatdau > ngayketthuc; #0 ngaybatdau > ngayketthuc

SELECT claimnumber, statusname, createddate, payment_date, updateddate, requesterdate, ngay_mo_hsbt, ngaybatdau, ngayketthuc, flex_approved_date, approveddate, accidentdate
FROM claims_staging1
WHERE accidentdate > requesterdate; #0 accidentdate > requesterdate

SELECT claimnumber, statusname, createddate, payment_date, updateddate, requesterdate, ngay_mo_hsbt, ngaybatdau, ngayketthuc, flex_approved_date, approveddate, accidentdate
FROM claims_staging1
WHERE requesterdate > ngay_mo_hsbt; #3 requesterdate > ngay_mo_hsbt

#Change the invalid values in which requesterdate > ngay_mo_hsbt, replace requesterdate = accidentdate
UPDATE claims_staging1
SET requesterdate = accidentdate
WHERE requesterdate > ngay_mo_hsbt;

#Recheck lai accuracy cua processdays values
ALTER TABLE claims_staging1
ADD COLUMN cal_processdays INT;

SELECT claimnumber, statusname, accidentdate, processdays, requesterdate, ngay_mo_hsbt, flex_approved_date, approveddate, updateddate
FROM claims_staging1
ORDER BY claimnumber;

#Claims in which status is in process, approved, paid-out but processdays value = 0
SELECT claimnumber, statusname, processdays, DATEDIFF(approveddate, ngay_mo_hsbt) AS Calculated_ProcessDays, requesterdate, ngay_mo_hsbt, approveddate, updateddate
FROM claims_staging1
WHERE processdays = '0' AND statusname != 'Đã hủy' AND statusname != 'Chờ lập PASC' AND statusname != 'Chưa giám định'
ORDER BY claimnumber, updateddate;
-- -> 27 rows

#Claims in which processdays value is in valid
SELECT claimnumber, statusname, processdays, DATEDIFF(approveddate, ngay_mo_hsbt) AS Calculated_ProcessDays, requesterdate, ngay_mo_hsbt, approveddate, updateddate
FROM claims_staging1
WHERE processdays IS NULL OR processdays = '' OR processdays = '-';  #'A022202804C000200'

#Calculate and fill out the processdays column with valid values
UPDATE claims_staging1
SET processdays = CASE 
						WHEN approveddate IS NOT NULL THEN CAST(DATEDIFF(approveddate, ngay_mo_hsbt) AS CHAR)
						ELSE CAST(DATEDIFF(updateddate, ngay_mo_hsbt) AS CHAR)
				END
WHERE (processdays = '0' OR processdays = '-') AND statusname != 'Đã hủy' AND statusname != 'Chờ lập PASC' AND statusname != 'Chưa giám định';

UPDATE claims_staging1
SET processdays = 0
WHERE claimnumber = 'A022202804C000200';

#Convert the processdays from Text to Int
ALTER TABLE claims_staging1
MODIFY COLUMN processdays INT;

#look up createddate > payment_date (not priority because we don't need to use these 2 columns)


#Fill in null/invalid values of needed columns


#Created new backup table for claims_staing1
CREATE TABLE claims_staging2 AS
SELECT * FROM claims_staging1;

#Delete duplicated rows:
-- create temporary table with duplicated claims
CREATE TEMPORARY TABLE temp_duplicated AS
WITH duplicate_cte AS
	(SELECT *,
		ROW_NUMBER() OVER(PARTITION BY claimnumber) AS row_num
	FROM claims_staging1
	)
SELECT claimnumber, policycode, coverage, statusname, compensation_total, compensation_amount_beforetax,
		total_claim_estimate, claim_estimate, claim_estimate_beforetax, claim_estimate_first, updateddate, row_num
FROM duplicate_cte
WHERE claimnumber IN (SELECT DISTINCT claimnumber FROM duplicate_CTE WHERE row_num > 1)
ORDER BY claimnumber, updateddate; #379 rows
-- -> these repeated rows have different coverage

-- For statusname = đã chi trả bồi thường, if row has compensation_total = 0 -> del
DELETE FROM claims_staging2
WHERE (statusname = 'Đã chi trả bồi thường' OR statusname = 'Đã duyệt')
  AND compensation_total = '0.00'
  AND claimnumber IN (SELECT DISTINCT claimnumber FROM temp_duplicated);

-- For statusname = đã chi trả bồi thường, if row has compensation_total diff & != 0 -> take the SUM(compensation_total), SUM(compensation_amount_before), SUM(total_claim_estimated),... #A022200707C001164
UPDATE claims_staging2 cs
JOIN (
    SELECT claimnumber,
           SUM(compensation_total) AS total_compensation,
           SUM(compensation_amount_beforetax) AS total_amount_beforetax,
           SUM(claim_estimate_first) AS total_claim_estimate_first, 
           GROUP_CONCAT(DISTINCT coverage ORDER BY coverage SEPARATOR ', ') AS new_coverage
    FROM temp_duplicated
    WHERE statusname = 'Đã chi trả bồi thường'
    GROUP BY claimnumber
    HAVING COUNT(DISTINCT compensation_total) > 1
       AND COUNT(CASE WHEN compensation_total = 0 THEN 1 END) = 0
) AS sums
  ON cs.claimnumber = sums.claimnumber
SET cs.compensation_total = sums.total_compensation,
    cs.compensation_amount_beforetax = sums.total_amount_beforetax,
    cs.claim_estimate_first = sums.total_claim_estimate_first,
    cs.coverage = sums.new_coverage;
    
-- 'A022200707C001164','42316640.00','39628455.00','15000000.00','Auto liability coverage, Collision coverage'
-- 'A022201004C004687','2902000.00','2687037.00','3000000.00','Auto liability coverage, Collision coverage'
-- 'A022201907C002174','37186232.00','34355855.00','35000000.00','Auto liability coverage, Collision coverage'
-- 'A032202308C004536','16059645.00','14870042.00','11000000.00','Auto liability coverage, Collision coverage'
-- 'A032202308C005272','62001000.00','60912054.00','60000000.00','Auto liability coverage, Collision coverage'
-- 'A032202308C007326','18864000.00','17209091.00','20000000.00','Auto liability coverage, Collision coverage'

-- For statusname = đang xử lý, if row has claim_estimate = 0 -> del
DELETE FROM claims_staging2
WHERE  	statusname = 'Đang xử lý' 
		AND claim_estimate = 0 
        AND claimnumber IN (SELECT DISTINCT claimnumber FROM temp_duplicated); #8

-- For statusname = đang xử lý, chờ lập PASC, if row has claim_estimate diff & != 0, we take the claim_estimate= SUM(all_rows), change coverage column values
UPDATE claims_staging2 cs
JOIN (
    SELECT claimnumber,
           SUM(claim_estimate) AS total_claim_estimate,
           SUM(claim_estimate_beforetax) AS total_claim_estimate_beforetax,
           SUM(claim_estimate_first) AS toatl_claim_estimate_first,
           GROUP_CONCAT(DISTINCT coverage ORDER BY coverage SEPARATOR ' ') AS new_coverage
    FROM temp_duplicated
    WHERE statusname = 'Đang xử lý'
    GROUP BY claimnumber
    HAVING COUNT(DISTINCT claim_estimate) > 1
       AND COUNT(CASE WHEN claim_estimate = 0 THEN 1 END) = 0
) AS sums
  ON cs.claimnumber = sums.claimnumber
SET cs.claim_estimate = sums.total_claim_estimate,
    cs.claim_estimate_beforetax = sums.total_claim_estimate_beforetax,
    cs.claim_estimate_first = sums.toatl_claim_estimate_first,
    cs.coverage = sums.new_coverage;  #'A022202007C000578'

-- For statusname = đã huỷ, if row has claim_estimate = 0 for all columns estimate-> sum(claim_estimate_first) 
DELETE FROM claims_staging2
WHERE 	statusname = 'Đã huỷ' 
		AND claim_estimate_first = 0 
		AND claimnumber IN (SELECT DISTINCT claimnumber FROM temp_duplicated);

WITH CTE_1 AS 
			(SELECT 	claimnumber, 
						SUM(claim_estimate_first) AS sum_claim_estimate_first, 
						GROUP_CONCAT(DISTINCT coverage ORDER BY coverage SEPARATOR ' ') AS new_coverage
			FROM temp_duplicated
			WHERE statusname = 'Đã huỷ'
            GROUP BY claimnumber
			HAVING COUNT(DISTINCT claim_estimate_first) > 1
			)
UPDATE claims_staging2 AS t
JOIN CTE_1 AS s
ON t.claimnumber = s.claimnumber
SET t.claim_estimate_first =  s.sum_claim_estimate_first,
	t.coverage = s.new_coverage; #20 'A022104505C000089'
    
#delete duplicated rows, keep the one with lastest updateddate (notice the one with all 0 in 'đã huỷ'
WITH CTE_cancelled_0est AS (
		SELECT claimnumber, policycode, coverage, statusname, compensation_total, compensation_amount_beforetax,
				total_claim_estimate, claim_estimate, claim_estimate_beforetax, claim_estimate_first, updateddate,
		ROW_NUMBER() OVER (PARTITION BY claimnumber, claim_estimate_first ORDER BY updateddate) AS row_num
		FROM claims_staging2)
SELECT claimnumber, policycode, coverage, statusname, compensation_total, compensation_amount_beforetax,
				total_claim_estimate, claim_estimate, claim_estimate_beforetax, claim_estimate_first, updateddate
FROM claims_staging2
WHERE EXISTS (SELECT 1
				FROM CTE_cancelled_0est AS s
				WHERE s.claimnumber = claims_staging2.claimnumber
				AND s.row_num > 1)
ORDER BY claimnumber;


WITH CTE_cancelled_0est AS (
		SELECT claimnumber, policycode, coverage, statusname, compensation_total, compensation_amount_beforetax,
				total_claim_estimate, claim_estimate, claim_estimate_beforetax, claim_estimate_first, updateddate,
				RANK() OVER (PARTITION BY claimnumber ORDER BY updateddate) AS row_num
		FROM claims_staging2)
SELECT claimnumber, policycode, coverage, statusname, compensation_total, compensation_amount_beforetax,
				total_claim_estimate, claim_estimate, claim_estimate_beforetax, claim_estimate_first, updateddate
FROM CTE_cancelled_0est
WHERE row_num > 1; #35

-- 'A022200806C001837', 'A022200806006055', 'Collision coverage', 'Chờ lập PASC', '0.00', '0.00', '1000000.00', '1000000.00', '1000000.00', '1000000.00', '2022-04-28'
-- 'A022200806C001837', 'A022200806006055', 'Personal injury coverage', 'Chờ lập PASC', '0.00', '0.00', '1000000.00', '0.00', '0.00', '0.00', '2022-04-28'

-- 'A022201106C003040', 'A022201106016386', 'Personal injury coverage', 'Chưa giám định', '0.00', '0.00', '15000000.00', '0.00', '0.00', '0.00', '2022-04-21'

   SELECT claimnumber, MIN(coverage) AS coverage, claim_estimate_first
    FROM claims_staging2
    WHERE statusname = 'Đã huỷ'
    GROUP BY claimnumber, claim_estimate_first
    HAVING COUNT(*) > 1
    ORDER BY claimnumber; #27 #710

WITH CTE_Duplicated AS
		(SELECT claimnumber, policycode, coverage, statusname, compensation_total, compensation_amount_beforetax,
			total_claim_estimate, claim_estimate, claim_estimate_beforetax, claim_estimate_first, updateddate,
			RANK() OVER (PARTITION BY claimnumber ORDER BY total_claim_estimate DESC, claim_estimate DESC, claim_estimate_first DESC, compensation_total DESC, coverage) AS row_num
		FROM claims_staging1)
SELECT claimnumber, policycode, coverage, statusname, compensation_total, compensation_amount_beforetax,
		total_claim_estimate, claim_estimate, claim_estimate_beforetax, claim_estimate_first, updateddate
FROM claims_staging1
WHERE claimnumber IN (SELECT DISTINCT claimnumber FROM CTE_Duplicated WHERE row_num > 1);

SELECT claimnumber, policycode, coverage, statusname, compensation_total, compensation_amount_beforetax,
			total_claim_estimate, claim_estimate, claim_estimate_beforetax, claim_estimate_first, updateddate,
			RANK() OVER (PARTITION BY claimnumber ORDER BY total_claim_estimate DESC, claim_estimate DESC, claim_estimate_first DESC, compensation_total DESC, coverage) AS row_num
		FROM claims_staging1;
    
    SELECT COUNT(*)
    FROM claims_staging2
    WHERE statusname = 'Đã huỷ';  #772 #737 w/o duplicated -> 35 duplicated rows

#delete duplicated rows, keep the one with lastest updateddate (notice the one with all 0 in 'đã huỷ'

SELECT claimnumber, coverage, statusname, compensation_total, compensation_amount_beforetax,
		total_claim_estimate, claim_estimate, claim_estimate_beforetax, claim_estimate_first, updateddate
FROM claims_staging2
WHERE claimnumber = 'A022200806C001837'
ORDER BY claimnumber, updateddate ;

##METHOD 2 for delete duplicated rows:
CREATE TABLE claims_staging3 AS
SELECT * FROM claims_staging1;
-- 1. Find rows with same claimnumbers but 2 diff values & != 0

    SELECT DISTINCT statusname FROM claims_staging2;
-- 'Đã hủy'
-- 'Chờ lập PASC'
-- 'Đã chi trả bồi thường'
-- 'Đã duyệt'
-- 'Đang xử lý'
-- 'Từ chối'
-- 'Đang xử lý bồi thường'
-- 'Chờ hoàn thiện hồ sơ'

SELECT claimnumber, coverage, statusname, compensation_total, compensation_amount_beforetax,
		total_claim_estimate, claim_estimate, claim_estimate_beforetax, claim_estimate_first, updateddate
FROM temp_duplicated
WHERE claimnumber = 'A022102804C000128'
ORDER BY claimnumber, updateddate ;

#Find rows with same claimnumbers but have different values & they're != 0
UPDATE claims_staging3 cs
JOIN (
    SELECT claimnumber,
			SUM(claim_estimate_first) AS total_claim_estimate_first,
            SUM(claim_estimate) AS total_claim_estimate,
            SUM(claim_estimate_beforetax) AS total_claim_estimate_beforetax,
            SUM(compensation_amount_beforetax) AS total_compensation_amount_beforetax,
            SUM(compensation_total) AS total_compensation_total,
            GROUP_CONCAT(DISTINCT coverage ORDER BY coverage SEPARATOR ', ') AS new_coverage
    FROM temp_duplicated
    WHERE statusname = 'Đã chi trả bồi thường' OR statusname = 'Đã duyệt'
    GROUP BY claimnumber
    HAVING COUNT(DISTINCT compensation_total) >= 1
			AND COUNT(CASE WHEN compensation_total = 0 THEN 1 END) = 0
) AS sums
  ON cs.claimnumber = sums.claimnumber
SET 
    cs.claim_estimate_first = sums.total_claim_estimate_first,
	cs.claim_estimate = sums.total_claim_estimate,
	cs.claim_estimate_beforetax = sums.total_claim_estimate_beforetax,
	cs.compensation_amount_beforetax = sums.total_compensation_amount_beforetax,
	cs.compensation_total = sums.total_compensation_total,
    cs.coverage = sums.new_coverage; 

UPDATE claims_staging3 cs
JOIN (
    SELECT claimnumber,
			SUM(claim_estimate_first) AS total_claim_estimate_first,
            SUM(claim_estimate) AS total_claim_estimate,
            SUM(claim_estimate_beforetax) AS total_claim_estimate_beforetax,
            GROUP_CONCAT(DISTINCT coverage ORDER BY coverage SEPARATOR ', ') AS new_coverage
    FROM temp_duplicated
    WHERE statusname = 'Đang xử lý bồi thường' OR statusname = 'Từ chối' OR statusname = 'Đang xử lý' 
			OR statusname = 'Chờ lập PASC' OR statusname = 'Chờ hoàn thiện hồ sơ'
    GROUP BY claimnumber
    HAVING COUNT(DISTINCT claim_estimate) >= 1
			AND COUNT(CASE WHEN claim_estimate = 0 THEN 1 END) = 0
) AS sums
  ON cs.claimnumber = sums.claimnumber
SET 
    cs.claim_estimate_first = sums.total_claim_estimate_first,
	cs.claim_estimate = sums.total_claim_estimate,
	cs.claim_estimate_beforetax = sums.total_claim_estimate_beforetax,
    cs.coverage = sums.new_coverage;

UPDATE claims_staging3 cs
JOIN (
    SELECT claimnumber,
			SUM(claim_estimate_first) AS total_claim_estimate_first,
            GROUP_CONCAT(DISTINCT coverage ORDER BY coverage SEPARATOR ', ') AS new_coverage
    FROM temp_duplicated
    WHERE statusname = 'Đã huỷ'
    GROUP BY claimnumber
    HAVING COUNT(DISTINCT claim_estimate_first) >= 1
			AND COUNT(CASE WHEN claim_estimate_first = 0 THEN 1 END) = 0
) AS sums
  ON cs.claimnumber = sums.claimnumber
SET 
    cs.claim_estimate_first = sums.total_claim_estimate_first,
    cs.coverage = sums.new_coverage;

#2. Find the duplicated rows with different values
WITH CTE_Duplicated AS
		(SELECT claimnumber, policycode, coverage, statusname, compensation_total, compensation_amount_beforetax,
			total_claim_estimate, claim_estimate, claim_estimate_beforetax, claim_estimate_first, updateddate,
			RANK() OVER (PARTITION BY claimnumber ORDER BY total_claim_estimate DESC, claim_estimate DESC, claim_estimate_first DESC, compensation_total DESC, coverage) AS row_num
		FROM claims_staging3)
SELECT claimnumber, policycode, coverage, statusname, compensation_total, compensation_amount_beforetax,
		total_claim_estimate, claim_estimate, claim_estimate_beforetax, claim_estimate_first, updateddate
FROM claims_staging3
WHERE claimnumber IN (SELECT DISTINCT claimnumber FROM CTE_Duplicated WHERE row_num > 1); #349

#Delete uneccessary rows of a same claimnumber
CREATE TABLE claims_staging4
LIKE claims_staging3;
ALTER TABLE claims_staging4 ADD COLUMN row_num INT;

INSERT INTO claims_staging4
SELECT *, 
		RANK() OVER (PARTITION BY claimnumber ORDER BY total_claim_estimate DESC, claim_estimate DESC, claim_estimate_first DESC, compensation_total DESC, coverage) AS row_num
FROM claims_staging3;

DELETE FROM claims_staging4
WHERE row_num > 1;

SELECT claimnumber 
FROM claims_staging4
GROUP BY claimnumber
HAVING COUNT(*) > 1; #15

#Delete duplicated rows with all same values
CREATE TABLE claims_staging5
LIKE claims_staging4;

ALTER TABLE claims_staging5
ADD COLUMN row_num2 INT;

INSERT INTO claims_staging5
SELECT *, 
		ROW_NUMBER() OVER (PARTITION BY claimnumber) AS row_num2
        FROM claims_staging4;

DELETE FROM claims_staging5
WHERE row_num2 > 1;


SELECT claimnumber, policycode, coverage, statusname, compensation_total, compensation_amount_beforetax,
		total_claim_estimate, claim_estimate, claim_estimate_beforetax, claim_estimate_first, updateddate, row_num2
FROM claims_staging5
WHERE claimnumber = 'A022102804C000128';

#Check for empty values in each column
-- accidentdate, statusname, processdays, claimnumber, cost_tong_khau_giam_tru, compensation_total, cost_copay_deduction,  coverage, agencyname, 
-- assignee_fullname, accident_type, loaixe, hangxe, damageestimation, customer_type, agencycompensation, updateddate, payment_date, 'claim_estimate', 'total_claim_estimate'

#agencycompensation
SELECT claimnumber, statusname, accidentdate, requesterdate, approveddate, payment_date, processdays, cost_assetliquidation, cost_towing, cost_investigation, cost_copay_deductible,
		coverage, assignee_fullname, accident_type, loaixe, hangxe, customer_type, 
        agencycompensation, damageestimation, claim_estimate_first, total_claim_estimate, compensation_total
FROM claims_staging5
WHERE agencycompensation = '-' OR agencycompensation = '' OR agencycompensation IS NULL; #A022201206C000210

SELECT claimnumber, assignee_fullname
FROM claims_staging5
WHERE claimnumber = 'A022201206C000210'; #gdv_xu_ly = 'Trần Xuân Hoàng'

SELECT claimnumber, agencycompensation, assignee_fullname
FROM claims_staging5
WHERE assignee_fullname = 'Trần Xuân Hoàng'; -- 'Bảo Long Đồng Nai'

#Insert into the empty values 
UPDATE claims_staging5
SET agencycompensation = 'Bảo Long Đồng Nai'
WHERE claimnumber = 'A022201206C000210';


#convert damageestimation from text to int 
UPDATE claims_staging5
SET damageestimation = CAST(REPLACE(damageestimation, ',', '') AS DECIMAL(12,2));

#translate values from VNmese to English
SELECT DISTINCT statusname
FROM claims_staging5;

UPDATE claims_staging5
SET statusname = CASE 
					WHEN statusname = 'Đã hủy' THEN 'cancelled'
					WHEN 	statusname = 'Đang xử lý' 
							OR statusname = 'Đang xử lý bồi thường' 
                            OR statusname = 'Chờ lập PASC' 
                            OR statusname = 'Chưa giám định' 
                            OR statusname = 'Chờ hoàn thiện hồ sơ'
							THEN 'in process'
					WHEN statusname = 'Đã duyệt' THEN 'approved'
                    WHEN statusname = 'Đã chi trả bồi thường' THEN 'paid out'
                    WHEN statusname = 'Từ chối' THEN 'denied'
				END;

SELECT DISTINCT loaixe
FROM claims_staging5;

UPDATE claims_staging5
SET loaixe = CASE 
					WHEN loaixe = 'Xe không kinh doanh đến 08 chỗ'
							OR loaixe = 'Xe bán tải (pickup, minivan)'
							OR loaixe = 'Xe không kinh doanh trên 08 chỗ'
						THEN 'Private Passenger Vehicles'
                    WHEN loaixe = 'Xe tải'
							OR loaixe = 'Xe đầu kéo'
							OR loaixe = 'Rơ mooc thông thường'
						THEN 'Commercial Freight Vehicles'
                    WHEN loaixe = 'Xe kinh doanh vận tải hành khách liên tỉnh, Xe giường nằm'
							OR loaixe = 'Xe kinh doanh chở người còn lại'
							OR loaixe = 'Xe kinh doanh chở người đến 08 chỗ'
                            OR loaixe = 'Xe tập lái'
						THEN 'Commercial Passenger Vehicles'
					WHEN loaixe = 'Xe taxi công nghệ'
							OR loaixe = 'Xe taxi truyền thống'
						THEN 'Ride-share Vehicles'
					WHEN loaixe = 'Trên 50 cc'
							OR loaixe = 'Xe mô tô ba bánh, xe gắn máy và các loại xe cơ giới tương tự' 
						THEN 'Motorcycles'
					WHEN loaixe = 'Xe bus'
							OR loaixe = 'Xe cứu thương'
						THEN 'Government & Emergency Vehicles'
					WHEN loaixe = 'Xe chở tiền'
							OR loaixe = 'Xe hoạt động trong vùng khai thác khoáng sản'
							OR loaixe = 'Xe hoạt động trong nội cảng, khu công nghiệp, sân bay'
                            OR loaixe = 'Xe chuyên dùng còn lại'
                            OR loaixe = 'Xe đông lạnh'
						THEN 'Specialized Vehicles'
					END;


SELECT DISTINCT claimnumber FROM claims_staging5;
UPDATE claims_staging5
SET customer_type = CASE 
					WHEN customer_type = 'Tổ chức' THEN 'business'
                    WHEN customer_type = 'Cá nhân' THEN 'personal'
                    END;

#Translate ngay_mo_hsbt column name to claim_opened_date
ALTER TABLE claims_staging5
CHANGE COLUMN ngay_mo_hsbt claim_opened_date DATE; 

ALTER TABLE claims_staging5
CHANGE COLUMN damage_type_wrong damage_type TEXT;

SELECT DISTINCT damage_type
FROM claims_staging5;

-- 'Tổn thất về người'
-- 'Unknown'
-- 'Tài sản bên thứ 3 về xe'
-- 'Tổn thất bộ phận/toàn bộ'
-- 'Tài sản bên thứ 3 khác'
-- 'Khác,Đâm/va xe máy'
-- 'Đâm/va vật thể cố định,Vật thể khác rơi vào'
-- 'Đâm/va xe máy,Đâm/va xe ô tô'
-- 'Mất cắp bộ phận'
-- 'Đâm/va vật thể cố định,Đâm/va xe máy'
-- 'Đâm/va xe máy,Vật thể khác rơi vào'


UPDATE claims_staging5
SET damage_type = CASE 
						WHEN damage_type = 'Tổn thất về người' THEN 'Personal Injury Loss'
						WHEN damage_type = 'Tổn thất bộ phận/toàn bộ' THEN 'Partial/Total Loss'
                        WHEN damage_type = 'Tài sản bên thứ 3 về xe' THEN 'Third-Party Vehicle Property'
                        WHEN damage_type = 'Tài sản bên thứ 3 khác' THEN 'Other Third-Party Property'
                        WHEN damage_type = 'Mất cắp bộ phận' THEN 'Theft'
					END;
                    

#Create temp table that stored damage_type and claimnumber form original/source table
CREATE TEMPORARY TABLE claims_temp AS
SELECT DISTINCT claimnumber, nguyen_nhan_ton_that, loai_hinh_trans
FROM auto_insurance_claims;

ALTER TABLE claims_temp 
CHANGE nguyen_nhan_ton_that damage_type TEXT;

UPDATE claims_temp
SET damage_type = 'Tổn thất bộ phận/toàn bộ'
WHERE damage_type = 'Lật xe' OR damage_type = 'Vật thể khác rơi vào' OR damage_type = 'Bị phá hoại' OR damage_type = 'Rơi xe'
		OR damage_type = 'Thủy kích' OR damage_type = 'Đâm/va động vật' OR damage_type = 'Hỏa hoạn, cháy, nổ' OR damage_type = 'Rơi xe,Lật xe';

UPDATE claims_temp
SET damage_type = 'Mất cắp bộ phận'
WHERE damage_type = 'Mất cắp';

UPDATE claims_temp
SET damage_type = 'Tài sản bên thứ 3 khác'
WHERE damage_type = 'Đâm/va vật thể cố định' OR damage_type = 'Khác,Đâm/va vật thể cố định';

UPDATE claims_temp
SET damage_type = 'Tổn thất bộ phận/toàn bộ'
WHERE loai_hinh_trans = 'Vật chất xe' AND damage_type != 'Tổn thất bộ phận/toàn bộ' AND damage_type != 'Mất cắp bộ phận' AND damage_type != 'Tài sản bên thứ 3 khác';

UPDATE claims_temp
SET damage_type = 'Tổn thất về người'
WHERE damage_type != 'Tổn thất bộ phận/toàn bộ' AND damage_type != 'Mất cắp bộ phận' AND damage_type != 'Tài sản bên thứ 3 khác' AND (loai_hinh_trans = 'Tai nạn LPX & NNTX' OR loai_hinh_trans = 'TNDS tự nguyện');


#Update damage_type in claims_staging1 with 'Tổn thất về người' values
WITH damagetype_CTE2 AS 
	(SELECT claimnumber
	FROM auto_insurance_claims
	WHERE  noi_dung_tai_nan LIKE '%người chết%' 
			OR noi_dung_tai_nan LIKE '%bị thương%'
			OR noi_dung_tai_nan LIKE '%tử vong%' 
            OR noi_dung_tai_nan LIKE '%cấp cứu%'
			OR noi_dung_tai_nan LIKE '%bệnh viện%'
            OR noi_dung_tai_nan LIKE '%nhập viện%')
UPDATE claims_temp
SET damage_type = 'Tổn thất về người'
WHERE claimnumber IN (SELECT claimnumber FROM damagetype_CTE2);


SELECT  claimnumber, noi_dung_tai_nan, nguyen_nhan_ton_that, loai_hinh_trans 
FROM auto_insurance_claims;


UPDATE claims_temp
SET damage_type = 'Tài sản bên thứ 3 về xe'
WHERE loai_hinh_trans = 'TNDS bắt buộc' 
		AND (damage_type = 'Đâm/va xe máy,Khác' OR damage_type = 'Đâm/va xe máy' OR damage_type = 'Khác,Đâm/va xe máy'
			OR damage_type = 'Đâm/va xe máy,Đâm/va vật thể cố định' OR damage_type = 'Đâm/va vật thể cố định,Đâm/va xe máy'
			OR damage_type = 'Đâm/va xe máy,Vật thể khác rơi vào'
			OR damage_type = 'Đâm/va động vật' OR damage_type = 'Vật thể khác rơi vào,Đâm/va xe máy,Đâm/va vật thể cố định'
            OR damage_type = 'Đâm/va xe ô tô' OR damage_type = 'Đâm/va xe ô tô,Khác' OR damage_type = 'Đâm/va xe ô tô,Đâm/va vật thể cố định'
			OR damage_type = 'Vật thể khác rơi vào,Đâm/va xe ô tô' OR damage_type = 'Đâm/va vật thể cố định,Đâm/va xe ô tô' OR damage_type =  'Đâm/va xe máy,Đâm/va xe ô tô');


UPDATE claims_temp
SET damage_type = 'Tài sản bên thứ 3 khác'
WHERE loai_hinh_trans = 'TNDS bắt buộc' 
		AND (damage_type = 'Khác,Đâm/va vật thể cố định' 
			OR damage_type = 'Đâm/va vật thể cố định,Vật thể khác rơi vào' 
			OR damage_type = 'Đâm/va vật thể cố định'
			OR damage_type = 'Vật thể khác rơi vào,Đâm/va vật thể cố định' 
            OR damage_type = 'Đâm/va động vật,Đâm/va vật thể cố định'
			OR damage_type = 'Đâm/va vật thể cố định,Đâm/va động vật' 
            OR damage_type = 'Đâm/va vật thể cố định,Lật xe');

#Update values in damage_type of claims_staging1
UPDATE claims_temp
SET damage_type = 'Unknown'
WHERE damage_type = '-' OR damage_type = 'Khác';

#Translate value in damage_type
-- 'Tổn thất về người' -> Personal Injury Loss
-- 'Tổn thất bộ phận/toàn bộ' -> Partial/Total Loss
-- 'Tài sản bên thứ 3 về xe' -> Third-Party Vehicle Property
-- 'Tài sản bên thứ 3 khác' -> Other Third-Party Property
-- 'Mất cắp bộ phận' -> Theft

SELECT DISTINCT damage_type FROM claims_temp;

UPDATE claims_temp
SET damage_type = CASE 
						WHEN damage_type = 'Tổn thất về người' THEN 'Personal Injury Loss'
						WHEN damage_type = 'Tổn thất bộ phận/toàn bộ' THEN 'Partial/Total Loss'
                        WHEN damage_type = 'Tài sản bên thứ 3 về xe' THEN 'Third-Party Vehicle Property'
                        WHEN damage_type = 'Tài sản bên thứ 3 khác' THEN 'Other Third-Party Property'
                        WHEN damage_type = 'Mất cắp bộ phận' THEN 'Theft'
                        ELSE 'Unknown'
					END;

#Join merge table claims_staging5 to claims_temp
CREATE TABLE claims_staging6 AS
SELECT * FROM claims_staging5;

UPDATE claims_staging6 AS t
JOIN claims_temp AS s
ON s.claimnumber = t.claimnumber
SET t.damage_type = s.damage_type;

#Transalte column name
-- statusname (claim_status), accidentdate (claim_accident_date), requesterdate (claim_submitted_date), claim_opened_date (claim_opened_date), approveddate (claim_approved_date), payment_date (payment_date), processdays,
-- cost_copay_deductible (cost_copay_deductible), coverage (coverage), assignee_fullname (gdv_xu_ly), damage_type (damage_type) , loaixe (vehicle_type), hangxe (vehicle_make), customer_type (customer_type), 
-- agencycompensation (agencycompensation), damageestimation, claim_estimate_first (uoc_bt_ban_dau), total_claim_estimate (ubt_trans), compensation_total (stbt_truoc_thue)

-- claim_status (claim_status), claim_accident_date (claim_accident_date), claim_submitted_date (claim_submitted_date), claim_opened_date (claim_opened_date), claim_approved_date (claim_approved_date) payment_date (payment_date), processdays, cost_assetliquidation, cost_towing, 
-- cost_investigation, cost_copay_deductible (cost_copay_deductible), coverage (coverage), assignee_fullname (assignee_fullname), damage_type (damage_type) , vehicle_type (vehicle_type), vehicle_make (vehicle_make), customer_type (customer_type), 
-- agencycompensation (agencycompensation), damageestimation, claim_estimate_first (claim_estimate_first), total_claim_estimate (total_claim_estimate), compensation_total (compensation_total)

SELECT *
FROM claims_staging6;

-- Create new table to drop unnecessary columns and translate column names to match with claims_staging
CREATE TABLE claims_staging7 AS
SELECT claimnumber, statusname, accidentdate, requesterdate, claim_opened_date, approveddate,
		payment_date, processdays, cost_copay_deductible, coverage, assignee_fullname, damage_type, loaixe, hangxe, customer_type,
        agencycompensation, claim_estimate_first, total_claim_estimate, compensation_total, updateddate
FROM claims_staging6;

DESCRIBE claims_staging7;

#Translate column names & convert data type
ALTER TABLE claims_staging7
CHANGE statusname claim_status TEXT;

ALTER TABLE claims_staging7
CHANGE accidentdate claim_accident_date DATE;

ALTER TABLE claims_staging7
CHANGE requesterdate claim_submitted_date DATE;

ALTER TABLE claims_staging7
CHANGE approveddate claim_approved_date DATE;

ALTER TABLE claims_staging7
CHANGE loaixe vehicle_type TEXT;

ALTER TABLE claims_staging7
CHANGE hangxe vehicle_make TEXT;

-- Check null values at numerical value columns
SELECT *
FROM claims_staging7
WHERE claim_estimate_first IS NULL OR total_claim_estimate IS NULL OR compensation_total IS NULL; #0

-- Check empty values 
SELECT *
FROM claims_staging7
WHERE processdays = 0; #1012


#For 'cancelled' claims & processdays = 0, get the processdays = updateddate - claim_submitted_date
UPDATE claims_staging7
SET processdays = updateddate - claim_submitted_date
WHERE claim_status = 'cancelled' AND processdays = 0;

#check null for number columns
SELECT *
FROM claims_staging7
WHERE claim_estimate_first IS NULL OR total_claim_estimate IS NULL OR compensation_total IS NULL OR cost_copay_deductible IS NULL;

-- Create new table to drop unnecessary columns and translate column names to match with claims_staging
CREATE TABLE claims_staging8 AS
SELECT claimnumber, policycode, statusname, accidentdate, requesterdate, claim_opened_date, approveddate,
		payment_date, processdays, cost_copay_deductible, coverage, assignee_fullname, damage_type, loaixe, hangxe, customer_type,
        agencycompensation, claim_estimate_first, total_claim_estimate, compensation_total, updateddate
FROM claims_staging6;


#Translate column names & convert data type
ALTER TABLE claims_staging8
CHANGE statusname claim_status TEXT;

ALTER TABLE claims_staging8
CHANGE accidentdate claim_accident_date DATE;

ALTER TABLE claims_staging8
CHANGE requesterdate claim_submitted_date DATE;

ALTER TABLE claims_staging8
CHANGE approveddate claim_approved_date DATE;

ALTER TABLE claims_staging8
CHANGE loaixe vehicle_type TEXT;

ALTER TABLE claims_staging8
CHANGE hangxe vehicle_make TEXT;


#For 'cancelled' claims & processdays = 0, get the processdays = updateddate - claim_submitted_date
UPDATE claims_staging8
SET processdays = updateddate - claim_submitted_date
WHERE claim_status = 'cancelled' AND processdays = 0;

SELECT claimnumber, policy_start_date, policy_end_date, claim_accident_date, claim_submitted_date, claim_opened_date, claim_approved_date, ngay_duyet_bt, 
documents_pending_date, estimate_pending_date, assessment_pending_date, process_start_date
FROM df1_staging3_approved;

SELECT claimnumber, claim_status, policy_start_date, policy_end_date, claim_accident_date, claim_submitted_date, claim_opened_date, claim_approved_date, ngay_duyet_bt, 
documents_pending_date, estimate_pending_date, assessment_pending_date, process_start_date
FROM df1_staging3_2_nodup;

SELECT claimnumber, claim_status_name, updateddate, payment_date
FROM df1_staging3_2_nodup
WHERE claimnumber = 'A012200008C006281' OR claimnumber = 'A012200008C006693'
ORDER BY claimnumber, updateddate;




#how many null of estimate_pending_date
SELECT COUNT(DISTINCT claimnumber)
FROM df1_staging3_2_nodup
WHERE estimate_pending_date IS NULL;
-- 3052 claims/13,709 claims

#how many null of assessment_pending_date
SELECT COUNT(DISTINCT claimnumber)
FROM df1_staging3_2_nodup
WHERE assessment_pending_date IS NULL;
-- 10,666 claims/13,709 claims

#how many null of documents_pending_date
SELECT COUNT(DISTINCT claimnumber)
FROM df1_staging3_2_nodup
WHERE documents_pending_date IS NULL;
#13,694 claims/13,709 claims

SELECT *
FROM claim_final_3
WHERE claim_status = 'cancelled' OR claim_status = 'denied';


CREATE TABLE claims_final_3 AS
SELECT * FROM claims_final_2;

ALTER TABLE claims_final_3
MODIFY COLUMN processdays INT NULL;

UPDATE claims_final_3
SET processdays = NULL;

UPDATE claims_final_3
SET processdays = CASE
    WHEN claim_status IN ('approved', 'paid out')
        THEN DATEDIFF(claim_approved_date, claim_submitted_date)
    WHEN claim_status IN ('denied', 'cancelled')
        THEN DATEDIFF(updateddate, claim_submitted_date)
    ELSE NULL
END;


SELECT *
FROM claims_final_3
WHERE assignee_fullname = 'Phạm Ý Vượt';

SELECT *
FROM claims_final_3
WHERE claimnumber = 'A032204801C000841';

SELECT policycode, createddate, start_date, end_date, finalprice
FROM df3_staging
WHERE createddate > start_date;

SELECT *
FROM df3_staging
ORDER BY certificate_no;

USE Insurance;

SELECT
    SUM(
        finalprice /
        (TIMESTAMPDIFF(MONTH, start_date, end_date) + 1)
    ) AS Earned_Premium
FROM df3_staging
WHERE start_date <= '2022-01-31'
  AND end_date   >= '2022-01-01'; #5,140,363,031
  
  SELECT
    SUM(
        finalprice /
        (TIMESTAMPDIFF(MONTH, start_date, end_date) + 1)
    ) AS Earned_Premium
FROM df3_staging
WHERE start_date <= '2022-02-28'
  AND end_date   >= '2022-02-01'; 
  
  SELECT
    SUM(
        finalprice /
        (TIMESTAMPDIFF(MONTH, start_date, end_date) + 1)
    ) AS Earned_Premium
FROM df3_staging
WHERE start_date >= '2022-02-01'
  AND end_date   >  '2022-02-28';

  SELECT
    SUM(
        finalprice /
        (TIMESTAMPDIFF(MONTH, start_date, end_date) + 1)
    ) AS Earned_Premium
FROM df3_staging
WHERE start_date >= '2022-08-01'
  AND end_date   >  '2022-08-31'; #300,282,839

SELECT
    SUM(
        finalprice /
        (TIMESTAMPDIFF(MONTH, start_date, end_date) + 1)
    ) AS Earned_Premium
FROM df3_staging
WHERE start_date >= '2022-09-01'
  AND end_date   >  '2022-09-30'; #260,340,473
  
SELECT
    SUM(
        finalprice /
        (TIMESTAMPDIFF(MONTH, start_date, end_date) + 1)
    ) AS Earned_Premium
FROM df3_staging
WHERE start_date >= '2022-10-01'
  AND end_date   >  '2022-10-31'; #170,710,587


SELECT
    SUM(
        finalprice /
        (TIMESTAMPDIFF(MONTH, start_date, end_date) + 1)
    ) AS Earned_Premium
FROM df3_staging
WHERE start_date >= '2022-11-01'
  AND end_date   >  '2022-10-31'; #170,710,587
  
  
CREATE TABLE calendar_months AS
WITH RECURSIVE months AS (
    SELECT DATE('2011-11-01') AS calendar_month
    UNION ALL
    SELECT DATE_ADD(calendar_month, INTERVAL 1 MONTH)
    FROM months
    WHERE calendar_month < '2030-07-03'
)
SELECT calendar_month FROM months;


SELECT * FROM calendar_months;

SELECT
    c.calendar_month,
    SUM(
        p.finalprice /
        (TIMESTAMPDIFF(MONTH, p.start_date, p.end_date) + 1)
    ) AS earned_premium
FROM calendar_months c
JOIN df3_staging p
  ON c.calendar_month BETWEEN
     DATE_FORMAT(p.start_date, '%Y-%m-01')
 AND DATE_FORMAT(p.end_date,   '%Y-%m-01')
GROUP BY c.calendar_month; 

UPDATE calendar_months c
LEFT JOIN (
    SELECT
        c.calendar_month,
        SUM(
            p.finalprice /
            (TIMESTAMPDIFF(MONTH, p.start_date, p.end_date) + 1)
        ) AS earned_premium
    FROM calendar_months c
    JOIN df3_staging p
      ON c.calendar_month BETWEEN
         DATE_FORMAT(p.start_date, '%Y-%m-01')
     AND DATE_FORMAT(p.end_date,   '%Y-%m-01')
    GROUP BY c.calendar_month
) ep
ON c.calendar_month = ep.calendar_month
SET c.earned_premium = ep.earned_premium;

CREATE TABLE earned_premium_monthly AS
SELECT
    c.calendar_month,
    SUM(
        p.finalprice /
        (TIMESTAMPDIFF(MONTH, p.start_date, p.end_date) + 1)
    ) AS earned_premium
FROM calendar_months c
JOIN df3_staging p
  ON c.calendar_month BETWEEN
     DATE_FORMAT(p.start_date, '%Y-%m-01')
 AND DATE_FORMAT(p.end_date,   '%Y-%m-01')
GROUP BY c.calendar_month;

SELECT * FROM earned_premium_monthly;

SELECT
    DATE_FORMAT(claim_submitted_date, '%Y-%m-01') AS calendar_month,
    SUM(compensation_total) AS claims_amount,
    COUNT(DISTINCT claimnumber) AS claim_count
FROM claims_final_2
GROUP BY calendar_month;

SELECT
    ep.calendar_month,
    ep.earned_premium,
    cl.incurred_losses,
    cl.incurred_losses / ep.earned_premium AS loss_ratio
FROM earned_premium_monthly ep
LEFT JOIN (
    SELECT
        DATE_FORMAT(claim_submitted_date, '%Y-%m-01') AS calendar_month,
        SUM(compensation_total) AS incurred_losses
    FROM claims_final_2
    WHERE claim_status ='paid out'
    GROUP BY calendar_month
) cl
ON ep.calendar_month = cl.calendar_month;

CREATE VIEW v_monthly_loss_ratio AS
SELECT
    ep.calendar_month,
    ep.earned_premium,
    COALESCE(cl.incurred_losses, 0) AS incurred_losses
FROM earned_premium_monthly ep
LEFT JOIN (
    SELECT
        DATE_FORMAT(claim_submitted_date, '%Y-%m-01') AS calendar_month,
        SUM(compensation_total) AS incurred_losses
    FROM claims_final_2
    WHERE claim_status IN ('paid out')
    GROUP BY calendar_month
) cl
ON ep.calendar_month = cl.calendar_month;

SELECT * FROM v_monthly_loss_ratio;

CREATE OR REPLACE VIEW v_monthly_policy_claim_counts AS
SELECT
    c.calendar_month,

    /* Number of active policies */
    COALESCE(ap.active_policies, 0) AS active_policies,

    /* Number of newly submitted claims */
    COALESCE(nc.new_claims, 0) AS new_claims

FROM calendar_months c

/* ---- Active policies ---- */
LEFT JOIN (
    SELECT
        cm.calendar_month,
        COUNT(p.policycode) AS active_policies
    FROM calendar_months cm
    JOIN df3_staging p
      ON cm.calendar_month BETWEEN
         DATE_FORMAT(p.start_date, '%Y-%m-01')
     AND DATE_FORMAT(p.end_date,   '%Y-%m-01')
    GROUP BY cm.calendar_month
) ap
ON c.calendar_month = ap.calendar_month

/* ---- Newly submitted claims ---- */
LEFT JOIN (
    SELECT
        DATE_FORMAT(claim_submitted_date, '%Y-%m-01') AS calendar_month,
        COUNT(DISTINCT claimnumber) AS new_claims
    FROM claims_final_2
    GROUP BY calendar_month
) nc
ON c.calendar_month = nc.calendar_month;


SELECT
    ep.calendar_month,
    ep.earned_premium,
    cl.incurred_losses,
    cl.incurred_losses / ep.earned_premium AS loss_ratio,
    cl.incurred_losses / cl.claim_count AS avg_compensation
FROM earned_premium_monthly ep
LEFT JOIN (
    SELECT
        DATE_FORMAT(claim_approved_date, '%Y-%m-01') AS calendar_month,
        SUM(compensation_total) AS incurred_losses,
        COUNT(claimnumber) AS claim_count
    FROM claims_final_2
    WHERE claim_status IN ('paid out', 'approved')
    GROUP BY calendar_month
) cl
ON ep.calendar_month = cl.calendar_month;