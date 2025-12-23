USE Insurance;
SELECT DATABASE();
SHOW VARIABLES LIKE 'max_allowed_packet';

#Check for correct data type of each column (Standardize the Data)
#Column names to English
#Fill in the blank of column A with values in column B (df1: flex_ngay_duyet & ngay_duyet, ubt & uoc_bt_ban_dau)
#Replace values of loai_hinh & loai_hinh_trans columns since they have same unique values but wording differently
#Find & remove duplicates
#Fill in blank values
#Remove columns & finalize tables
#Translate values
#View imported table
SELECT * 
FROM df1;

SELECT DISTINCT claimnumber 
FROM df1; #13,709 claims

SELECT DISTINCT claimnumber
FROM df2_new; #7294 claims

#Find claims that exists in df1 but not in df2
SELECT DISTINCT claimnumber
FROM df1
WHERE claimnumber NOT IN (SELECT DISTINCT claimnumber
							FROM df2_new); #6,415 claims

#find claims that exists in df2 but not df1
SELECT DISTINCT claimnumber
FROM df2_new
WHERE claimnumber NOT IN (SELECT DISTINCT claimnumber
							FROM df1); #0 claims
						
#Copy & create a new table
CREATE TABLE df1_staging
LIKE df1;

INSERT df1_staging
SELECT *
FROM df1;

#1. Translate column name & standardize data type

#Update the empty/null values in cost_giam_tru & cost_khau_tru
UPDATE df1_staging
SET 
    cost_giam_tru = CASE WHEN cost_giam_tru = '' THEN 0 ELSE cost_giam_tru END,
    cost_khau_tru = CASE WHEN cost_khau_tru = '' THEN 0 ELSE cost_khau_tru END
WHERE 
    cost_giam_tru = '' OR cost_khau_tru = '';

#Translate column name & standardize data type of cost_giam_tru & cost_khau_tru
ALTER TABLE df1_staging
CHANGE cost_giam_tru cost_copay INT,
CHANGE cost_khau_tru cost_deductible INT;

#Calculate the sum of cost_giam_tru & cost_khau_tru and fill in blank for empty cell in cost_tong_khau_giam_tru (cost_copay_deductible)
UPDATE df1_staging
SET cost_tong_khau_giam_tru =  cost_copay + cost_deductible
WHERE cost_tong_khau_giam_tru = '';

#Translate name & change the data type of cost_tong_khau_giam_tru
ALTER TABLE df1_staging
CHANGE cost_tong_khau_giam_tru cost_copay_deductible INT;

#Check for null in updateddate column
SELECT *
FROM df1_staging
WHERE updateddate = '' OR updateddate = NULL;

#Change the 'updateddate' column from str to datetime data type
UPDATE df1_staging
SET updateddate = STR_TO_DATE(updateddate, '%d/%m/%Y')
WHERE updateddate IS NOT NULL;

ALTER TABLE df1_staging
MODIFY updateddate DATETIME;

#Create new table that group claimnumber together and sorted in updateddate
CREATE TABLE df1_new AS
SELECT *
FROM df1_staging
ORDER BY claimnumber, updateddate ASC;

SELECT *
FROM df1_new;

#2. Find and delete duplicates
#Find all duplicates claimnumber
SELECT claimnumber, COUNT(*) AS count
FROM df1_new
GROUP BY claimnumber
HAVING COUNT(*) > 1;

#delete claims with same claimnumber, claim_status_name, loai_hinh, pham_vi, stbt_truoc_thue, ubt, ubt_trans, uoc_bt_ban_dau
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY claimnumber, claim_status_name, loai_hinh, pham_vi, stbt_truoc_thue, ubt, ubt_trans, uoc_bt_ban_dau) AS row_num
FROM df1_new;

WITH duplicate_cte AS
(SELECT *,
ROW_NUMBER() OVER(
PARTITION BY claimnumber, claim_status_name, loai_hinh, pham_vi, stbt_truoc_thue, ubt, ubt_trans, uoc_bt_ban_dau) AS row_num
FROM df1_new
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;

#Create df1_staging2 in which there are no duplicate claims
CREATE TABLE df1_staging2
LIKE df1_new;

ALTER TABLE df1_staging2
ADD COLUMN row_num INT;

INSERT INTO df1_staging2
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY claimnumber, claim_status_name, loai_hinh, pham_vi, stbt_truoc_thue, ubt, ubt_trans, uoc_bt_ban_dau) AS row_num
FROM df1_new
WHERE row_num = 1;

#if ubt_trans & claim_status_name values are same
SELECT ubt_trans, COUNT(*) AS count
FROM df1_staging2
GROUP BY ubt_trans AND claim_status_name
HAVING COUNT(*) > 1;

DESCRIBE df1;
#đã chi trả bồi thường: if status= 'da chi tra boi thuong' & have duplicated row & stbt_truoc_thue values are different -> SUM 2 rows together
#ngày bắt đầu -> ngày thanh toán -> ngày mở hsbt -> ngày duyệt bt -> ngày kết thúc 
# Mới (requesterdate) -> chưa giám định (ngay_mo_hsbt) -> chờ lập PASC -> chờ hoàn thiện hồ sơ -> đang xử lý/đang xử lý bồi thường  
-- -> đã duyệt/đã huỷ/từ chối -> đã chi trả bồi thường
#chưa giám định/Mới (submitted) -> chờ lập PASC (submitted) -> đang xử lý/Đang xử lý bồi thường (in process) 
-- -> đã duyệt (approved) -> đã chi trả bồi thường (paid out), Đã huỷ/Từ chối (denied)

#Check if claim_status_name = 'Mới' have the same updatedate and requesterdate 
SELECT claimnumber, claim_status_name, accidentdate, requesterdate, ngay_mo_hsbt, ngay_duyet_bt, updateddate
FROM df1_staging2
WHERE claim_status_name = 'Mới';
-- Yes

#Check if claim_status_name = 'chưa giám định' have the same updatedate and ngay_mo_hsbt 
SELECT claimnumber, claim_status_name, accidentdate, requesterdate, ngay_mo_hsbt, ngay_duyet_bt, updateddate
FROM df1_staging2
WHERE claim_status_name = 'Chưa giám định';
-- Yes

ALTER TABLE df1_staging2
DROP COLUMN row_num;

INSERT INTO df1_staging2
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY claimnumber, loai_hinh) AS row_num
FROM df1_staging2;

#Find all unique values of status
SELECT DISTINCT claim_status_name 
FROM df1_staging2;

#Find claim number with diffrent claim status 
SELECT t.claimnumber, t.claim_status_name, t.flex_ngay_duyet, t.loai_hinh, t.ngay_duyet_bt, t.ngay_mo_hsbt, t.ngay_thanh_toan, t.ngaybatdau, t.ngayketthuc, t.pham_vi, t.stbt_truoc_thue, t.ubt, t.ubt_trans, t.uoc_bt_ban_dau, t.updateddate
FROM df1_staging2 AS t
JOIN (SELECT claimnumber
		FROM df1_staging2
		WHERE claim_status_name = 'Chờ hoàn thiện hồ sơ') #OR claim_status_name = 'Chưa giám định')
	AS subs ON t.claimnumber = subs.claimnumber
ORDER BY t.claimnumber, t.updateddate
;

#chưa giám định/Mới (submitted) -> chờ lập PASC (submitted) -> đang xử lý/Đang xử lý bồi thường (in process) -> đã duyệt (approved) -> đã chi trả bồi thường (paid out), Đã huỷ/Từ chối (denied)
SELECT DISTINCT claim_status_name FROM df1_staging2;
SELECT DISTINCT claimnumber FROM df1_staging2; #13,709 returned
SELECT COUNT( DISTINCT claimnumber) FROM df1_staging2 WHERE claim_status_name = 'Chưa giám định' OR claim_status_name = 'Mới' OR claim_status_name = 'Chờ lập PASC'; #11653

-- accidentdate -> requesterdate -> ngay_mo_hsbt (opendate) -> ['Chờ lập PASC', 'Chưa giám định'] updateddate = assessrepairdate
-- -> 'Chờ hoàn thiện hồ sơ' updateddate = documentpendingdate -> 'in process' updateddate= reviewdate -> approvedate, denied/cancelled updateddate = decisiondate
#Check the workflow of claim_status_name
SELECT claimnumber, claim_status_name, accidentdate, requesterdate, ngay_mo_hsbt, ngay_duyet_bt, updateddate
FROM df1_staging2
WHERE claimnumber IN (SELECT DISTINCT claimnumber
						FROM df1_staging2
                        WHERE claim_status_name = 'Chưa giám định')
ORDER BY claimnumber, updateddate;
-- 'A012205003C004079'

#create a backup table
CREATE TABLE df1_staging3_1 AS SELECT * FROM df1_staging2;


#(1) replace 'Mới' with 'submitted', 'Chưa giám định' with 'pending assessment', 'Chờ lập PASC' with 'pending estimate', 
UPDATE df1_staging3_1
SET claim_status_name = 'submitted'
WHERE claim_status_name = 'Mới';

UPDATE df1_staging3_1
SET claim_status_name = 'assessment pending'
WHERE claim_status_name = 'Chưa giám định';

UPDATE df1_staging3_1
SET claim_status_name = 'estimate pending'
WHERE claim_status_name = 'Chờ lập PASC';


#(1) replace 'Đang xử lý', 'Đang xử lý bồi thường with 'in process' 
UPDATE df1_staging3_1
SET claim_status_name = 'in process'
WHERE claim_status_name = 'Đang xử lý' OR claim_status_name = 'Đang xử lý bồi thường';

#(1) replace 'Đã duyệt' to 'approved' on claim_status_name
UPDATE df1_staging3_1
SET claim_status_name = 'approved'
WHERE claim_status_name = 'Đã duyệt';


#(1)replace 'Đã chi trả bồi thường' to 'paid out' on claim_status_name
UPDATE df1_staging3_1
SET claim_status_name = 'paid out'
WHERE claim_status_name = 'Đã chi trả bồi thường';
 
#(1)replace 'Từ chối' to 'denied' on claim_status_name
UPDATE df1_staging3_1
SET claim_status_name = 'denied'
WHERE claim_status_name = 'Từ chối';

#(1)replace 'Đã huỷ' to 'cancelled' on claim_status_name
UPDATE df1_staging3_1
SET claim_status_name = 'cancelled'
WHERE claim_status_name = 'Đã huỷ';

#(1)replace 'Chờ hoàn thiện hồ sơ' to 'documents pending' on claim_status_name
UPDATE df1_staging3_1
SET claim_status_name = 'documents pending'
WHERE claim_status_name = 'Chờ hoàn thiện hồ sơ';

SELECT DISTINCT claim_status_name FROM df1_staging3;
SELECT DISTINCT claim_status_name FROM df1_staging3_1;
#procedure of claim_status_name: submitted -> in proccess -> cancelled or approved or denied -> paid out 
#in one claim, get the earliest row of claim_status_name = '' in case we have more than 1 (8126)

SELECT DISTINCT claimnumber FROM df1_staging3 WHERE claim_status_name = 'submitted'; #11,653 returns
-- -> There is a total of 13,709 claims but only 11,653 claims have 'submitted' status

#Check if the 'submitted' date is same as 'createddate' or 'ngay_mo_hsbt' or 'ngaybatdau' or 'requesterdate'
SELECT claimnumber, claim_status_name, accidentdate, createddate, ngay_mo_hsbt, ngaybatdau, requesterdate, updateddate
FROM df1_staging3_1 as t
WHERE EXISTS (SELECT 1
				FROM df1_staging3_1 as s
                WHERE t.claimnumber = s.claimnumber AND s.claim_status_name = 'submitted')
ORDER BY claimnumber, updateddate;
-- -> requesterdate = when the case is submitted
-- -> ngay_mo_hsbt = when case is opened for review
-- -> createddate = when the policy is paid
-- -> ngaybatdau = when the policy is started


#convert ngaybatdau from str to datetime datatype
UPDATE df1_staging3
SET ngaybatdau = DATE(STR_TO_DATE(ngaybatdau, '%d/%m/%Y'));

ALTER TABLE df1_staging3
CHANGE ngaybatdau policy_start_date DATETIME;

#(1)convert ngayketthuc from str to datetime datatype
UPDATE df1_staging3_1
SET ngayketthuc = DATE(STR_TO_DATE(ngayketthuc, '%d/%m/%Y'));

ALTER TABLE df1_staging3_1
CHANGE ngayketthuc policy_end_date DATETIME;

#(1)convert ngaybatdau from str to datetime datatype
UPDATE df1_staging3_1
SET ngaybatdau = DATE(STR_TO_DATE(ngaybatdau, '%d/%m/%Y'));

ALTER TABLE df1_staging3_1
CHANGE ngaybatdau policy_start_date DATETIME;

#(1)convert requesterdate from str to datetime datatype
UPDATE df1_staging3_1
SET requesterdate = STR_TO_DATE(requesterdate, '%d/%m/%Y');

ALTER TABLE df1_staging3_1
CHANGE requesterdate claim_submitted_date DATETIME;

#(1)convert ngay_mo_hsbt from str to datetime datatype
UPDATE df1_staging3_1
SET ngay_mo_hsbt = STR_TO_DATE(ngay_mo_hsbt, '%d/%m/%Y');

ALTER TABLE df1_staging3_1
CHANGE ngay_mo_hsbt claim_opened_date DATETIME;

#(1)convert accidentdate from str to datetime datatype
UPDATE df1_staging3_1
SET accidentdate = STR_TO_DATE(accidentdate, '%d/%m/%Y');

ALTER TABLE df1_staging3_1
CHANGE accidentdate claim_accident_date DATETIME;


#Find number of claim that has empty 'ngay_duyet_bt' but valid value in 'flex_ngay_duyet'
SELECT t.claimnumber, t.ngay_duyet_bt, t.ngay_thanh_toan, t.flex_ngay_duyet
FROM (SELECT claimnumber, ngay_duyet_bt, ngay_thanh_toan, flex_ngay_duyet
		FROM df1_staging3_1
        WHERE ngay_duyet_bt = '' OR ngay_duyet_bt IS NULL) AS t
WHERE t.flex_ngay_duyet != '';  #986 rows

#Find number of claim that has empty 'flex_ngay_duyet' but valid value in 'ngay_duyet_bt' 
SELECT t.claimnumber, t.ngay_duyet_bt, t.ngay_thanh_toan, t.flex_ngay_duyet
FROM (SELECT claimnumber, ngay_duyet_bt, ngay_thanh_toan, flex_ngay_duyet
		FROM df1_staging3_1
        WHERE flex_ngay_duyet = '' OR flex_ngay_duyet IS NULL) AS t
WHERE t.ngay_duyet_bt != '';  #0 rows
-- flex_ngay_duyet has less empty values than 'ngay_duyet_bt'


#(1)change flex_ngay_duyet column name to claim_approved_date
UPDATE df1_staging3_1
SET flex_ngay_duyet = NULL
WHERE flex_ngay_duyet = '';

UPDATE df1_staging3_1
SET flex_ngay_duyet = STR_TO_DATE(flex_ngay_duyet, '%Y-%m-%d');

ALTER TABLE df1_staging3_1
CHANGE flex_ngay_duyet claim_approved_date DATETIME;


#(1)convert ngay_thanh_toan from str to datetime datatype
UPDATE df1_staging3_1
SET ngay_thanh_toan = NULL
WHERE ngay_thanh_toan = '';

UPDATE df1_staging3_1
SET ngay_thanh_toan = STR_TO_DATE(ngay_thanh_toan, '%d/%m/%Y');

ALTER TABLE df1_staging3_1
CHANGE ngay_thanh_toan payment_date DATETIME;

#(1)Find claims where claim_status_name = approved, denied, cancelled but having Null value in claim_approved_date
SELECT claimnumber, claim_status_name, claim_approved_date, updateddate
FROM df1_staging3_1
WHERE claim_approved_date IS NULL AND (claim_status_name = 'denied' OR claim_status_name = 'approved' OR claim_status_name = 'cancelled');


#Check if all values in requesterdate <= ngay_mo_hsbt
SELECT claimnumber, claim_status_name, claim_accident_date, createddate, claim_opened_date, policy_start_date, claim_submitted_date, updateddate
FROM df1_staging3_1
WHERE claim_submitted_date > claim_opened_date;
-- -> 2 results with claimnumber = 'A022101009C000004' and 'A022103505C000125'

SELECT claimnumber, claim_status_name, claim_accident_date, createddate, claim_opened_date, policy_start_date, claim_submitted_date, updateddate
FROM df1_staging3_1 WHERE claimnumber= 'A022103505C000125';

#Switch the claim_submitted_date of two claims 'A022101009C000004' and 'A022103505C000125' to the value of claim_opened_date and vice versa
UPDATE df1_staging3_1
SET claim_submitted_date = CASE
						WHEN claimnumber = 'A022103505C000125' THEN STR_TO_DATE('2021-12-27', '%Y-%m-%d')
                        WHEN claimnumber = 'A022101009C000004' THEN STR_TO_DATE('2021-12-04', '%Y-%m-%d')
					END
WHERE claimnumber IN ('A022103505C000125', 'A022101009C000004');

UPDATE df1_staging3_1
SET claim_opened_date = CASE
						WHEN claimnumber = 'A022103505C000125' THEN STR_TO_DATE('2021-12-30', '%Y-%m-%d')
                        WHEN claimnumber = 'A022101009C000004' THEN STR_TO_DATE('2021-12-16', '%Y-%m-%d')
					END
WHERE claimnumber IN ('A022103505C000125', 'A022101009C000004');


#Check if requesterdate is always after accidentdate
SELECT claimnumber, claim_status_name, claim_accident_date, createddate, claim_opened_date, policy_start_date, claim_submitted_date, updateddate
FROM df1_staging3_1
WHERE claim_accident_date > claim_submitted_date
ORDER BY claimnumber, updateddate;
-- -> 'A032202308C008721' claim has accidentdate after ngay_mo_hsbt

#Check if ngay_mo_hsbt is always after accidentdate
SELECT claimnumber, claim_status_name, claim_accident_date, createddate, claim_opened_date, policy_start_date, claim_submitted_date, updateddate
FROM df1_staging3_1
WHERE claim_accident_date > claim_opened_date;
-- -> 'A032202308C008721' 

#Check if the updateddate is always after accidentdate
SELECT claimnumber, claim_status_name, claim_accident_date, createddate, claim_opened_date, policy_start_date, claim_submitted_date, updateddate
FROM df1_staging3_1
WHERE claim_accident_date > updateddate;
-- -> No accidentdate, ngay_mo_hsbt & requesterdate > updateddate

SELECT claimnumber, claim_status_name, claim_accident_date, createddate, claim_opened_date, policy_start_date, claim_submitted_date, updateddate, 
loai_hinh, pham_vi, stbt_truoc_thue, ubt, ubt_trans, uoc_bt_ban_dau
FROM df1_staging3_1
WHERE claimnumber = 'A032202308C008721'
ORDER BY updateddate;
-- -> ngay_mo_hsbt & requesterdate is mistakenly entered, changed it to 2022-08-06

UPDATE df1_staging3_1
SET claim_opened_date = STR_TO_DATE('2022-08-06', '%Y-%m-%d'),
	claim_submitted_date = STR_TO_DATE('2022-08-06', '%Y-%m-%d')
WHERE claimnumber = 'A032202308C008721';


#policy info: ngaybatdau, ngayketthuc, policycode
#holder info: customer_name, customer_type, customercode, hangxe, hieuxe, loaixe, mdsd, namsanxuat, sochongoi, tenchuxe
#agents info: 'agencyname', 'agencycode', distributionchannelcode, distributionchannelname, 'distributionunitname', 'gdv_xu_ly', 'salestaffcompanyname', 'salestaffname'
#claim info: don_vi_boi_thuong, loai_boi_thuong, loai_giam_dinh, loai_hinh, pham_vi
#date: accidentdate (claim_accident_date), ngay_duyet_by (claim_approved_date), ngay_mo_hsbt (claim_opened_date), ngay_thanh_toan (claim_paid_date), flex_ngay_duyet, requesterdate (claim_submited_date)
-- cost_copay_deductible, stbt_truoc_thue, estimated_compensation (ubt, uoc_bt_ban_dau, ubt_trans)
-- new columns: claim_status (submitted, in process, accepted, denied, cancelled) 
-- claim_accident_date -> claim_submitted_date -> assessment_pending_date -> estimate_pending_date -> documents_pending_date -> process_start_date -> claim_approved_date -> payment_date

##Create new datetime columns that store date of documents pending, estimate pending, assessment pending, process start date 
#(1)add columns for status such as documents_pending_date, estimate_pending_date, assessment_pending_date
ALTER TABLE df1_staging3_1
ADD COLUMN documents_pending_date VARCHAR(20),
ADD COLUMN estimate_pending_date VARCHAR(20),
ADD COLUMN assessment_pending_date VARCHAR(20),
ADD COLUMN process_start_date VARCHAR(20);

#(1)Create a temporary table that take the first updateddate of claims with duplicated claim_status_name = 'estimate pending'
CREATE TEMPORARY TABLE temp_claim_status AS
WITH ranked_claims AS (
  SELECT claimnumber, claim_status_name, updateddate,
         ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate) AS row_num
  FROM df1_staging3_1
  WHERE claim_status_name = 'estimate pending'
)
SELECT *
FROM ranked_claims
WHERE row_num = 1; #10,657 claims

#(1)Join claimnumber on df1_staging3_1 with temporary table temp_claim_status to fill in date values for new columns: estimate_pending_date
UPDATE df1_staging3_1 AS t
JOIN temp_claim_status AS s 
    ON t.claimnumber = s.claimnumber
SET t.estimate_pending_date = s.updateddate;

DROP TABLE temp_claim_status;

#(1)Create a temporary table that take the first updateddate of claims with duplicated claim_status_name = 'assessment pending'
CREATE TEMPORARY TABLE temp_claim_status AS
WITH ranked_claims AS (
  SELECT claimnumber, claim_status_name, updateddate,
         ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate) AS row_num
  FROM df1_staging3_1
  WHERE claim_status_name = 'assessment pending'
)
SELECT *
FROM ranked_claims
WHERE row_num = 1; #3,043 claims

#(1)Join claimnumber on df1_staging3_1 with temporary table temp_claim_status to fill in date values for new columns: assessment_pending_date
UPDATE df1_staging3_1 AS t
JOIN temp_claim_status AS s 
    ON t.claimnumber = s.claimnumber
SET t.assessment_pending_date = s.updateddate;

DROP TABLE temp_claim_status;


#(1)Create a temporary table that take the first updateddate of claims with duplicated claim_status_name = 'in process'
CREATE TEMPORARY TABLE temp_claim_status AS
WITH ranked_claims AS (
  SELECT claimnumber, claim_status_name, updateddate,
         ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate) AS row_num
  FROM df1_staging3_1
  WHERE claim_status_name = 'in process'
)
SELECT *
FROM ranked_claims
WHERE row_num = 1; #10,044 claims

#(1)Join claimnumber on df1_staging3_1 with temporary table temp_claim_status to fill in date values for new columns: process_start_date
UPDATE df1_staging3_1 AS t
JOIN temp_claim_status AS s 
    ON t.claimnumber = s.claimnumber
SET t.process_start_date = s.updateddate;

DROP TABLE temp_claim_status;

#(1)Create a temporary table that take the first updateddate of claims with duplicated claim_status_name = 'documents pending'
CREATE TEMPORARY TABLE temp_claim_status AS
WITH ranked_claims AS (
  SELECT claimnumber, claim_status_name, updateddate,
         ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate) AS row_num
  FROM df1_staging3_1
  WHERE claim_status_name = 'documents pending'
)
SELECT *
FROM ranked_claims
WHERE row_num = 1; #16 claims

#(1)Join claimnumber on df1_staging3_1 with temporary table temp_claim_status to fill in date values for new columns: process_start_date
UPDATE df1_staging3_1 AS t
JOIN temp_claim_status AS s 
    ON t.claimnumber = s.claimnumber
SET t.documents_pending_date = s.updateddate;

DROP TABLE temp_claim_status;

SELECT claimnumber, claim_status, claim_status_name, documents_pending_date, estimate_pending_date, assessment_pending_date, process_start_date, updateddate
FROM df1_staging3_1
ORDER BY claimnumber, updateddate;

#(=1)Add column claim_status (values: in process, accepted, denied, cancelled) 
ALTER TABLE df1_staging3_1
ADD COLUMN claim_status VARCHAR(20);

CREATE INDEX idx_claimnumber ON df1_staging3_1(claimnumber(25));
CREATE INDEX idx_claim_status_name ON df1_staging3_1(claim_status_name(20));

#(=1)Add value 'denied' to claim_status for claims that been denied
UPDATE df1_staging3_1 AS t
JOIN	(SELECT DISTINCT claimnumber
		 FROM df1_staging3_1
         WHERE claim_status_name = 'denied'
         ) AS s
ON t.claimnumber = s.claimnumber
SET t.claim_status = 'denied';

UPDATE df1_staging3_1 AS t
JOIN	(SELECT DISTINCT claimnumber
		 FROM df1_staging3_1
         WHERE claim_status_name = 'cancelled'
         ) AS s
ON t.claimnumber = s.claimnumber
SET t.claim_status = 'cancelled'
WHERE t.claim_status IS NULL;

WITH CTE_approved AS (
	SELECT DISTINCT claimnumber
	FROM df1_staging3_1
	WHERE claim_status_name = 'approved'
	)
UPDATE df1_staging3_1
SET claim_status = 'approved'
WHERE claimnumber IN (SELECT claimnumber FROM CTE_approved) AND claim_status IS NULL;

WITH CTE_approved AS (
	SELECT DISTINCT claimnumber
	FROM df1_staging3_1
	WHERE claim_status_name = 'paid out'
	)
UPDATE df1_staging3_1
SET claim_status = 'paid out'
WHERE claimnumber IN (SELECT claimnumber FROM CTE_approved);


WITH CTE_inprocess AS (
	SELECT DISTINCT claimnumber
	FROM df1_staging3_1
	WHERE claim_status_name = 'in process' 
	)
UPDATE df1_staging3_1
SET claim_status = 'in process'
WHERE claimnumber IN (SELECT claimnumber FROM CTE_inprocess) AND claim_status IS NULL;

#(=1)Find claims that labelled as 'in process' but can be assessed as 'document/estimate/assessment pending
SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.updateddate
FROM (SELECT claimnumber, claim_status_name, claim_status, updateddate
		FROM df1_staging3_1
        WHERE claim_status = 'in process') AS t
WHERE t.claim_status_name = 'documents pending' OR t.claim_status_name = 'assessment pending' OR t.claim_status_name = 'estimate pending'
ORDER BY t.claimnumber, t.updateddate; -- 1785 claims A022200302C008386, A022200709C005585, A022200806C003776

SELECT claimnumber, claim_status_name, claim_status, updateddate
FROM df1_staging3_1
WHERE claimnumber = 'A022200302C008386' OR claimnumber = 'A022200709C005585' OR claimnumber = 'A022200806C003776';

WITH CTE_inprocess AS (
	SELECT DISTINCT claimnumber
	FROM df1_staging3_1
	WHERE claim_status_name = 'documents pending'
	)
UPDATE df1_staging3_1
SET claim_status = 'documents pending'
WHERE claimnumber IN (SELECT claimnumber FROM CTE_inprocess) AND claim_status IS NULL;

#(=1)Find claims that have assessment_pending_date after estimate_pending_date
SELECT claimnumber, claim_status, claim_status_name, documents_pending_date, estimate_pending_date, assessment_pending_date, process_start_date, updateddate
FROM df1_staging3_1
WHERE assessment_pending_date > estimate_pending_date; 
-- None -> so we can fill in claim_status for claims with claim_status_name = 'estimate_pending' as 'estimate pending'. 

#(=1)Find claims that have claim_status_name = 'documents pending'
SELECT claimnumber, claim_status, claim_status_name, documents_pending_date, estimate_pending_date, assessment_pending_date, process_start_date, updateddate
FROM df1_staging3_1
WHERE claimnumber IN (SELECT DISTINCT claimnumber
						FROM df1_staging3_1
						WHERE claim_status_name = 'documents pending')
ORDER BY claimnumber, updateddate; 
-- Since all claims that have claim_status_name = 'documents pending'  have no claim_status = 'assessment pending' or 'estimate pending', we fill claim_status = 'documents pending' before filling those other status 
WITH CTE_inprocess AS (
	SELECT DISTINCT claimnumber
	FROM df1_staging3_1
	WHERE claim_status_name = 'documents pending' 
	)
UPDATE df1_staging3_1
SET claim_status = 'documents pending'
WHERE claimnumber IN (SELECT claimnumber FROM CTE_inprocess) AND claim_status IS NULL;

-- Since 'assessment pending' always happen before 'estimate pending', we fill in 'assessment pending' claim_status first
WITH CTE_inprocess AS (
	SELECT DISTINCT claimnumber
	FROM df1_staging3_1
	WHERE claim_status_name = 'assessment pending' 
	)
UPDATE df1_staging3_1
SET claim_status = 'assessment pending'
WHERE claimnumber IN (SELECT claimnumber FROM CTE_inprocess) AND claim_status IS NULL;

WITH CTE_inprocess AS (
	SELECT DISTINCT claimnumber
	FROM df1_staging3_1
	WHERE claim_status_name = 'estimate pending'
	)
UPDATE df1_staging3_1
SET claim_status = 'estimate pending'
WHERE claimnumber IN (SELECT claimnumber FROM CTE_inprocess) AND claim_status IS NULL;

#(=1)check for claims that have  in process date before estimate pending or other pending
SELECT claimnumber, claim_status, claim_status_name, documents_pending_date, estimate_pending_date, assessment_pending_date, process_start_date, updateddate
FROM df1_staging3_1
WHERE claim_status IS NULL
ORDER BY claimnumber, updateddate;
-- Since there's no claim_status = Null, we don't have to fill in for claim_status = 'submitted'


#Find amount of claims that were 'paid out' but does not have 'approved' row
SELECT DISTINCT claimnumber
FROM df1_staging3 AS t
WHERE t.claimnumber NOT IN (SELECT DISTINCT claimnumber
								FROM df1_staging3
								WHERE claim_status_name = 'approved')
AND t.claim_status_name = 'paid out'
ORDER BY claimnumber; 


#accidentdate, createddate (unecessary), ngay_mo_hsbt, ngaybatdau, requesterdate, updateddate, flex_ngay_duyet
#accidentdate (claim_accident_date), requesterdate (claim_submitted_date), ngay_mo_hsbt (claim_opened_date), flex_ngay_duyet (claim_approved_date), ngay_thanh_toan (claim_paid_date), ngaybatdau (policy_start_date), ngayketthuc (policy_end_date)

#(=1)Fill in the missing values
SELECT DISTINCT claimnumber
FROM df1_staging3_1
WHERE agencyname = ''; #3,720

SELECT DISTINCT claimnumber
FROM df1_staging3_1
WHERE cost_copay_deductible = 0; #11,962

#missing values: distributionunitname (8,790) -> del, don_vi_boi_thuong (1) -> fill, mdsd (34) -> fill, namsanxuat (156), phamvi (11,808)
#None: customer_name/tenchuxe, customer_type, customercode, distributionchannelcode, distributionchannelname, gdv_xu_ly, hangxe, hieuxe
#None: loai_boi_thuong, loai_giam_dinh, loai_hinh, loaixe, policycode, salestaffcompanyname, salestaffname, sochongoi
#DEL distributionunitname (8,790), 

#(=1)Find if the claims having missing value in distributionunitname column in table df1_staging3 have values in df2_new table
SELECT claimnumber, distributionunitname
FROM df2_new
WHERE claimnumber IN (SELECT claimnumber
						FROM df1_staging3_1
						WHERE distributionunitname = '')
AND distributionunitname != ''; #A022202207C001835

#Fill in missing value
UPDATE df1_staging3_1
SET distributionunitname = 'SCB Hoàng Minh Giám'
WHERE claimnumber = 'A022202207C001835';


#Claims with null value in don_vi_boi_thuong
SELECT DISTINCT claimnumber, don_vi_boi_thuong
FROM df1_staging3_1
WHERE don_vi_boi_thuong = ''
ORDER BY claimnumber; #'A022201206C000210'

#(=1)Look for agencycompensation of this claims in df2 
SELECT claimnumber, agencycompensation, assignee_fullname
FROM df2_new
WHERE claimnumber = 'A022201206C000210';
-- no info on agencycompensation but found assignee_fullname

#(=1)Found the assignee_fullname to get info on agencycomepensation
SELECT claimnumber, agencycompensation, assignee_fullname
FROM df2_new
WHERE assignee_fullname = 'Trần Xuân Hoàng';
-- 'Tran Xuan Hoang' mostly works for 'Bảo Long Đồng Nai' as agencycomepensation

-- -> Usually, don_vi_boi_thuong = values of salestaffcompanyname
-- -> In case of claim A022201206C000210, salestaffcompanyname = 'Bảo Long Gia Định' so we assign its don_vi_boi_thuong = 'Bảo Long Gia Định'
UPDATE df1_staging3_1
SET don_vi_boi_thuong = 'Bảo Long Gia Định'
WHERE claimnumber = 'A022201206C000210';

#MDSD
#(=1)Check to see how many missing values of MDSD claims in df1 have values in df2
SELECT DISTINCT claimnumber
FROM df1_staging3_1
WHERE mdsd = '' AND claimnumber IN (SELECT DISTINCT claimnumber
									FROM df2_new
                                    WHERE mdsd != ''
									); #0
                                    
#(=1)Find policycode with empty value 'mdsd' in df1 but has valid value 'mdsd' in df3
SELECT DISTINCT policycode
FROM df1_staging3_1
WHERE mdsd = '' AND policycode IN (SELECT DISTINCT policycode
									FROM df3
                                    WHERE mdsd != '-'); #0
               
#(=1)Find if the claim with empty values of mdsd has certain values in different row
SELECT DISTINCT claimnumber
FROM df1_staging3_1
WHERE mdsd = '' AND claimnumber IN (SELECT DISTINCT claimnumber
									FROM df1_staging3_1
                                    WHERE mdsd != ''
									); #0

#Find more info on customer_name & customer_type of claims that have missing values on mdsd
SELECT DISTINCT claimnumber, customer_name, customer_type, loaixe, mdsd
FROM df1_staging3_1
WHERE mdsd = '';

SELECT DISTINCT policycode, customername, customer_type_trans, loaixe
FROM df3
WHERE policycode IN (SELECT DISTINCT policycode
						FROM df1_staging3_1
                        WHERE mdsd = '');
-- -> for customer_type = Tổ chức (Organization), we can assume that car 'mdsd' is 'kinh doanh' (commercial)

#Fill in the missing values of mdsd in df1_staging3
UPDATE df1_staging3_1
SET mdsd = CASE
				WHEN customer_type = 'Tổ chức' THEN 'Kinh doanh'
				ELSE 'Unknown'	
                END 
WHERE mdsd = '';

#(=1) because all mdsd = 'unknown' has loaixe= 'Trên 50 cc', which is mostly personal used, we fill it in as 'Không kinh doanh'
UPDATE df1_staging3_1
SET mdsd = 'Không kinh doanh' 
WHERE mdsd = 'Unknown';

#Pham_vi
#Create a new staging table in this section: df1_staging3_2
CREATE TABLE df1_staging3_2
LIKE df1_staging3_1;

INSERT df1_staging3_2
SELECT *
FROM df1_staging3_1;

#(=1)Translate values of pham_vi
#Translate values of damage_type to english
SELECT DISTINCT pham_vi
FROM df1_staging3_2;
-- 'Tổn thất về người' -> Personal Injury Loss
-- 'Tổn thất bộ phận/toàn bộ' -> Partial/Total Loss
-- 'Tài sản bên thứ 3 về xe' -> Third-Party Vehicle Property 
-- 'Tài sản bên thứ 3 khác' -> Other Third-Party Property
-- 'Mất cắp bộ phận' -> Theft 

#(=1) for claims & accidents that have pham_vi = 'Hàng hóa trên xe' on claim_accident_note table
SELECT claimnumber, claim_status_name, pham_vi
FROM df1_staging3_2
WHERE pham_vi = 'Hàng hóa trên xe'; #'A032200901C000506'

SELECT *
FROM claim_accident_note
WHERE pham_vi = 'Hàng hóa trên xe';
-- -> There's only 1 claim 'A032200901C000506' holds value pham_vi = 'Hàng hóa trên xe'. But based on the details of accident, it shows that the claim should be categorized as pham_vi = 'Tổn thất về người'


#(=1)Update the claim 'A032200901C000506' pham_vi column value to 'Tổn thất về người'
UPDATE df1_staging3_2
SET pham_vi = 'Tổn thất về người'
WHERE claimnumber = 'A032200901C000506';


UPDATE df1_staging3_2
SET pham_vi = CASE 
						WHEN pham_vi = 'Tổn thất về người' THEN 'Personal Injury Loss'
						WHEN pham_vi = 'Tổn thất bộ phận/toàn bộ' OR pham_vi = 'Thủy kích' THEN 'Partial/Total Loss'
                        WHEN pham_vi = 'Tài sản bên thứ 3 về xe' THEN 'Third-Party Vehicle Property'
                        WHEN pham_vi = 'Tài sản bên thứ 3 khác' THEN 'Other Third-Party Property'
                        WHEN pham_vi = 'Mất cắp bộ phận' THEN 'Theft'
                        ELSE ''
					END;

#Fill in missing values for pham_vi
-- distinct values of pham_vi column: 'Tổn thất về người', 'Tài sản bên thứ 3 về xe', 'Tổn thất bộ phận/toàn bộ', 'Thủy kích', 'Mất cắp bộ phận', 'Tài sản bên thứ 3 khác', 'Hàng hóa trên xe'
SELECT DISTINCT claimnumber
FROM df1_staging3_2
WHERE pham_vi != ''; #10,847
-- there are 13,709 distinct claimnumber, while 10,847 of them do not have empty value for pham_vi. 
-- Hence, there're 2,862 claims with empty pham_vi

SELECT DISTINCT claimnumber, pham_vi
FROM df1_staging3_2
WHERE pham_vi != ''; #10,867
-- Since there are different number of distinct claims with distinct claims and pham_vi, there are claims that have more than 1 pham_vi values

#(=1)Find the claims that have different pham_vi values
SELECT DISTINCT claimnumber
FROM df1_staging3_2
WHERE pham_vi != ''
GROUP BY claimnumber
HAVING COUNT(DISTINCT pham_vi) > 1; #20 claims
-- Those claims have more than 1 pham_vi to reimburse

#(=1) more information from those 20 claims above
SELECT s.claimnumber, s.pham_vi, s.claim_status, s.claim_status_name, s.uoc_bt_ban_dau, ubt, s.ubt_trans, s.stbt_truoc_thue, s.updateddate
FROM df1_staging3_1 AS s
JOIN (
    SELECT claimnumber
    FROM df1_staging3_2
    WHERE pham_vi != ''
    GROUP BY claimnumber
    HAVING COUNT(DISTINCT pham_vi) > 1
) AS t ON s.claimnumber = t.claimnumber
ORDER BY claimnumber, updateddate;

#(=1)Find claims that have empty pham_vi rows while having valid value on other rows
SELECT DISTINCT claimnumber
FROM df1_staging3_2
GROUP BY claimnumber
HAVING COUNT(DISTINCT pham_vi) = 2 AND SUM(pham_vi = '') > 0; #8927 claims


#(=1)Fill in the missing values of claims that have empty pham_vi rows while having valid value on other rows
CREATE TEMPORARY TABLE empty_pham_vi AS
SELECT claimnumber,
       GROUP_CONCAT(DISTINCT pham_vi SEPARATOR '') AS pham_vi_list
FROM df1_staging3_2
GROUP BY claimnumber
HAVING COUNT(DISTINCT pham_vi) = 2 AND SUM(pham_vi = '') > 0;

UPDATE df1_staging3_2 AS t
JOIN empty_pham_vi AS s
ON t.claimnumber = s.claimnumber
SET t.pham_vi = s.pham_vi_list
WHERE t.pham_vi = '';


ALTER TABLE df1_staging3_2
ADD COLUMN  pham_vi_list TEXT;

#(=1)Fill in pham_vi_list claims that have more than 1 pham_vi values
UPDATE df1_staging3_2 AS t
JOIN 
	(SELECT claimnumber,
			GROUP_CONCAT(pham_vi ORDER BY pham_vi) AS pham_vi_list
	FROM df1_staging3_2
	WHERE pham_vi != ''
	GROUP BY claimnumber
	HAVING COUNT(DISTINCT pham_vi) > 1) AS s #20 claims
ON t.claimnumber = s.claimnumber
SET t.pham_vi_list = s.pham_vi_list;

#Fill in missing in pham_vi_list from claims in temporary table
UPDATE df1_staging3_2 AS t
JOIN empty_pham_vi AS s
ON t.claimnumber = s.claimnumber
SET t.pham_vi_list = s.pham_vi_list
WHERE t.pham_vi_list IS NULL;

#Copy non-null value from pham_vi to pham_vi_list column
UPDATE df1_staging3_2 
SET pham_vi_list = pham_vi
WHERE pham_vi != '' AND pham_vi_list IS NULL;

SELECT claimnumber, claim_status, claim_status_name, pham_vi, pham_vi_list, updateddate
FROM df1_staging3_2
WHERE pham_vi_list IS NULL; #4277
-- These are claims that either was cancelled or not closed -> classified as 'unclassified'

#fill in missing values in pham_vi_list and pham_vi for claims that either was cancelled or not closed -> classified as 'unknown'
UPDATE df1_staging3_2 
SET pham_vi_list = 'Unclassified'
WHERE pham_vi_list IS NULL;

UPDATE df1_staging3_2
SET pham_vi = 'Unclassified'
WHERE pham_vi_list = 'Unclassified';

#(=1)Check if claims with empty 'pham_vi' value in one row has valid value in other rows
SELECT claimnumber, pham_vi, pham_vi_list 
FROM df1_staging3_2
WHERE pham_vi != '' AND claimnumber IN (SELECT DISTINCT claimnumber
										FROM df1_staging3_2
										WHERE pham_vi = ''
										); #139 - these are claims that have more than one value in pham_vi
                                        
#Fill in missing values in pham_vi for claims with more than one value in pham_vi
UPDATE df1_staging3_2
SET pham_vi = 'Multiple'
WHERE pham_vi = '';

#Change column name pham_vi to damage_type, pham_vi_list to damage_type_list
ALTER TABLE df1_staging3_2
CHANGE pham_vi damage_type TEXT;

ALTER TABLE df1_staging3_2
CHANGE pham_vi_list damage_type_list TEXT;


##Work about ubt, ubt_trans, stbt_truoc_thue, etc. and filter out uneccessary rows
ALTER TABLE df1_staging3_2 
MODIFY claimnumber VARCHAR(50);

CREATE INDEX idx_claimnumber_status ON df1_staging3_2 (claimnumber, claim_status);
CREATE INDEX idx_claimnumber_updated ON df1_staging3_2 (claimnumber, updateddate);


#Claims that exists in both claims_staging3 and df1_staging3_2
SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.ubt, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, 
		s.statusname AS df2_statusname, s.uoc_bt_ban_dau, s.ubt, s.ubt_truoc_thue, s.tong_uoc_bt_truoc_thue, s.stbt, s.stbt_truoc_thue
FROM df1_staging3_3 AS t
JOIN claims_staging1_2 AS s
ON t.claimnumber = s.claimnumber AND t.claim_status_name = s.statusname; #8773

#Estimate pending

#Create new table df1_staging3_estpending for filtering out
CREATE TABLE df1_staging3_estpending AS
SELECT * 
FROM df1_staging3_2
WHERE claim_status = 'estimate pending';

#how many 'estimate pending' claims that have more than 1 row
SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.damage_type, t.coverage, t.ubt, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, t.updateddate
FROM df1_staging3_3 AS t
JOIN (	SELECT claimnumber
		FROM df1_staging3_3
        WHERE claim_status = 'estimate pending'
		GROUP BY claimnumber
		HAVING COUNT(claimnumber) > 1) AS s
ON t.claimnumber = s.claimnumber
ORDER BY claimnumber, updateddate;

#Keep the row with latest updateddate only
DELETE t
FROM df1_staging3_estpending AS t
JOIN (
    SELECT claimnumber, MAX(updateddate) AS latest_date
    FROM df1_staging3_estpending
    GROUP BY claimnumber
) AS latest
ON t.claimnumber = latest.claimnumber
WHERE t.updateddate < latest.latest_date;

#Fill in 0 for empty columns of ubt, uoc_bt_ban_dau
UPDATE df1_staging3_estpending
SET ubt = 0,
    uoc_bt_ban_dau = 0
WHERE ubt = '' OR uoc_bt_ban_dau = '';
		
SELECT DISTINCT claimnumber
FROM df1_staging3_2
WHERE claim_status = 'estimate pending'; #1463

#If ubt, uoc_bt_ban_dau = 0 and have more than 1 record in the table, then delete those rows
DELETE t
FROM df1_staging3_estpending AS t
JOIN (
    SELECT claimnumber
    FROM df1_staging3_estpending
    GROUP BY claimnumber
    HAVING COUNT(*) > 1
) AS s 
ON t.claimnumber = s.claimnumber
WHERE t.ubt = 0
  AND t.uoc_bt_ban_dau = 0;

#for claims with multiple rows, set ubt_trans = ubt & uoc_bt_ban_dau
SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.damage_type, t.coverage, t.ubt, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, t.updateddate
FROM df1_staging3_estpending AS t
JOIN (SELECT claimnumber, SUM(ubt) AS sum_ubt, SUM(ubt_trans) AS sum_ubt_trans
		FROM df1_staging3_estpending
		GROUP BY claimnumber
		HAVING COUNT(claimnumber) > 1) AS s
ON t.claimnumber = s.claimnumber
WHERE ubt != ubt_trans; 
-- for claims with claim_status = 'estimate pending', ubt_trans always appear as sum of two coverage under same claim. 

#Find claims in df1_staging3_estpending that have >1 rows w/ same coverage -> keep the last row and delete the rest
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_estpending
WHERE claimnumber IN (SELECT claimnumber
						FROM df1_staging3_estpending
						GROUP BY claimnumber
						HAVING COUNT(claimnumber) > 1 AND COUNT(DISTINCT coverage) = 1)
ORDER BY claimnumber, updateddate;

#Keep the last row and delete the rest for claims that have >1 rows w/ same coverage
WITH duplicates AS (
    SELECT 
        claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate,
        ROW_NUMBER() OVER (PARTITION BY claimnumber, coverage) AS row_num
    FROM df1_staging3_estpending
)
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate, row_num
FROM duplicates 
WHERE claimnumber IN (	SELECT claimnumber 
						FROM duplicates
                        WHERE row_num > 1);

DELETE t
FROM df1_staging3_estpending AS t 
JOIN (
    SELECT claimnumber, coverage, updateddate, ubt_trans,
           ROW_NUMBER() OVER (PARTITION BY claimnumber) AS row_num
    FROM df1_staging3_estpending
    WHERE claimnumber IN (
        SELECT claimnumber
        FROM df1_staging3_estpending
        GROUP BY claimnumber
        HAVING COUNT(*) > 1 AND COUNT(DISTINCT coverage) = 1
    )
) AS s
  ON t.claimnumber = s.claimnumber
  AND t.ubt_trans = s.ubt_trans
WHERE s.row_num = 1;


##documents pending

#check claims that have status = 'documents pending'
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_2
WHERE claim_status = 'documents pending'
ORDER BY claimnumber, updateddate; #'A022204210C000816'
-- only 1 claim with claim_status = 'documents pending' so we add this claim to df1_staging3_estpending

#Add 'documents pending' claim with latest updateddate row only
INSERT INTO df1_staging3_estpending
SELECT t.* 
FROM df1_staging3_2 AS t
JOIN (
    SELECT claimnumber, MAX(updateddate) AS latest_date
    FROM df1_staging3_2
    WHERE claim_status = 'documents pending'
    GROUP BY claimnumber
) AS latest
ON t.claimnumber = latest.claimnumber
WHERE t.updateddate = latest.latest_date;



##Assessment pending 

#Create new table df1_staging3_assesspending for filtering out
CREATE TABLE df1_staging3_assesspending AS
SELECT * 
FROM df1_staging3_2
WHERE claim_status = 'assessment pending';

-- assessment pending case is wrongly identified in claim_status (suppose to be estimate pending instead of assessment pending)
#Check for assessment-pending claims that wrongly identified in claim_status
SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.damage_type, t.coverage, t.ubt, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, t.updateddate
FROM df1_staging3_assesspending AS t
JOIN (	SELECT claimnumber, MAX(updateddate) AS latest_date
		FROM df1_staging3_assesspending
        GROUP BY claimnumber
	) AS s
ON t.claimnumber = s.claimnumber 
WHERE t.updateddate = s.latest_date  AND t.claim_status != t.claim_status_name; #338 rows, 324 distinct claims 

#Keep the latest date only
DELETE t
FROM df1_staging3_assesspending AS t
JOIN (
    SELECT claimnumber, MAX(updateddate) AS latest_date
    FROM df1_staging3_assesspending
    GROUP BY claimnumber
) AS s
ON t.claimnumber = s.claimnumber
WHERE t.updateddate < s.latest_date;

#how many 'estimate pending' claims that have more than 1 row
SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.damage_type, t.coverage, t.ubt, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, t.updateddate
FROM df1_staging3_assesspending AS t
JOIN (	SELECT claimnumber
		FROM df1_staging3_assesspending
		GROUP BY claimnumber
		HAVING COUNT(claimnumber) > 1) AS s
ON t.claimnumber = s.claimnumber
ORDER BY claimnumber, updateddate; #142

#Find the claims that have same latest updateddate and coverage but different claim_status_name
SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.damage_type, t.coverage, t.ubt, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, t.updateddate
FROM df1_staging3_assesspending AS t
JOIN (SELECT claimnumber
		FROM df1_staging3_assesspending
		GROUP BY claimnumber, coverage
		HAVING COUNT(claimnumber) > 1) AS s
ON t.claimnumber = s.claimnumber
WHERE t.claim_status_name != t.claim_status
ORDER BY claimnumber, updateddate;

#Delete claims that have same latest updateddate and coverage but different claim_status_name
DELETE t
FROM df1_staging3_assesspending AS t
JOIN (
    SELECT claimnumber
    FROM df1_staging3_assesspending
    GROUP BY claimnumber, coverage
    HAVING COUNT(claimnumber) > 1
) AS s
ON t.claimnumber = s.claimnumber
WHERE t.claim_status_name != t.claim_status;

#Find claim that have wrong claim_status
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_assesspending
WHERE claim_status != claim_status_name
ORDER BY claimnumber, updateddate;

#correct the wrong claim_status for those claims
UPDATE df1_staging3_assesspending AS t
SET claim_status = claim_status_name
WHERE claim_status_name != claim_status;

#find claims with claim_status = 'estimate pending'
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_assesspending
WHERE claim_status != 'assessment pending'
ORDER BY claimnumber, updateddate; #298 claims, A032200901C008486, A032201107C010282, A032201111C012800

#Since there are 'estimate pending' claims that were mistakenly located into this, we need to transfer them to tables for 'estimate pending' claims
CREATE TABLE est_pend_temp AS
SELECT *
FROM df1_staging3_assesspending
WHERE claim_status != 'assessment pending'
ORDER BY claimnumber, updateddate;

#how many 'estimate pending' claims that have more than 1 row
SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.damage_type, t.coverage, t.ubt, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, t.updateddate
FROM est_pend_temp AS t
JOIN (	SELECT claimnumber
		FROM est_pend_temp
		GROUP BY claimnumber
		HAVING COUNT(claimnumber) > 1) AS s
ON t.claimnumber = s.claimnumber
ORDER BY claimnumber, updateddate; #26, A022201109C013000 (3 rows, collision cover 6tr), A022202206C005765 (3 rows, 150tr)

#Fill in 0 for empty columns of ubt, uoc_bt_ban_dau
UPDATE est_pend_temp
SET ubt = 0,
    uoc_bt_ban_dau = 0
WHERE ubt = '' OR uoc_bt_ban_dau = '';
		
SELECT DISTINCT claimnumber
FROM est_pend_temp
WHERE claim_status = 'estimate pending'; #284

#If ubt, uoc_bt_ban_dau = 0 and have more than 1 record in the table, then delete those rows
DELETE t
FROM est_pend_temp AS t
JOIN (
    SELECT claimnumber
    FROM est_pend_temp
    GROUP BY claimnumber
    HAVING COUNT(*) > 1
) AS s 
ON t.claimnumber = s.claimnumber
WHERE t.ubt = 0
  AND t.uoc_bt_ban_dau = 0;

#for claims with multiple rows, set ubt_trans = ubt & uoc_bt_ban_dau
SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.damage_type, t.coverage, t.ubt, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, t.updateddate
FROM est_pend_temp AS t
JOIN (SELECT claimnumber, SUM(ubt) AS sum_ubt, SUM(ubt_trans) AS sum_ubt_trans
		FROM est_pend_temp
		GROUP BY claimnumber
		HAVING COUNT(claimnumber) > 1) AS s
ON t.claimnumber = s.claimnumber
WHERE ubt != ubt_trans; 
-- for claims with claim_status = 'estimate pending', ubt_trans always appear as sum of two coverage under same claim. 

#Check to see if there's same claim number from table df1_staging3_estpending and est_pend_temp
SELECT claimnumber
FROM df1_staging3_estpending
WHERE claimnumber IN (SELECT claimnumber
						FROM est_pend_temp); #0


#Merge these rows from est_pend_temp to df1_staging3_estpending
INSERT INTO df1_staging3_estpending
SELECT *
FROM est_pend_temp;

#Delete those claims from df1_staging3_assesspeding
DELETE 
FROM df1_staging3_assesspending
WHERE claim_status != 'assessment pending';

#Fill in 0 for empty columns of ubt, uoc_bt_ban_dau
UPDATE df1_staging3_assesspending
SET ubt = 0,
    uoc_bt_ban_dau = 0
WHERE ubt = '' OR uoc_bt_ban_dau = '';

#If ubt, uoc_bt_ban_dau = 0 and have more than 1 record in the table, then delete those rows
DELETE t
FROM df1_staging3_assesspending AS t
JOIN (
    SELECT claimnumber
    FROM df1_staging3_assesspending
    GROUP BY claimnumber
    HAVING COUNT(*) > 1
) AS s 
ON t.claimnumber = s.claimnumber
WHERE t.ubt = 0
  AND t.uoc_bt_ban_dau = 0;


##In process

SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_2
WHERE claim_status = 'in process'
ORDER BY claimnumber, updateddate; #4295 rows, 1648 distinct claims


#get the latest date and claim_status_name = 'in process'
SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.damage_type, t.coverage, t.ubt, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, t.updateddate
FROM df1_staging3_2 AS t
JOIN (
		SELECT claimnumber, MAX(updateddate) AS latest_date
        FROM df1_staging3_2
		WHERE claim_status = 'in process'
		GROUP BY claimnumber
	) AS s
ON t.claimnumber = s.claimnumber
WHERE t.updateddate = s.latest_date AND t.claim_status_name = 'in process'
ORDER BY claimnumber, updateddate; #1801 rows

CREATE TABLE df1_staging3_inprocess AS
	SELECT t.*
    FROM df1_staging3_2 AS t
	JOIN (
		SELECT claimnumber, MAX(updateddate) AS latest_date
        FROM df1_staging3_2
		WHERE claim_status = 'in process'
		GROUP BY claimnumber
		) AS s
	ON t.claimnumber = s.claimnumber
	WHERE t.updateddate = s.latest_date AND t.claim_status_name = 'in process'; 

#Fill in 0 for empty columns of ubt, uoc_bt_ban_dau
UPDATE df1_staging3_inprocess
SET ubt = CASE WHEN ubt = '' THEN 0 ELSE ubt END,
    uoc_bt_ban_dau = CASE WHEN uoc_bt_ban_dau = '' THEN 0 ELSE uoc_bt_ban_dau END,
    stbt_truoc_thue = CASE WHEN stbt_truoc_thue = '' THEN 0 ELSE stbt_truoc_thue END;

#Find claims with more than 1 rows
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_inprocess
WHERE claimnumber IN (	SELECT claimnumber
						FROM df1_staging3_inprocess
                        GROUP BY claimnumber
                        HAVING COUNT(claimnumber) > 1)
ORDER BY claimnumber, updateddate; #291 rows, 138 distinct claims w/ >1 rows
-- for claims with >1 rows:
	-- diff coverage -> ubt_trans= after SUM, uoc_bt_ban_dau= before SUM
    -- same coverage -> ubt_trans= after SUM, uoc_bt_ban_dau= after SUM
-- A022203806C006062, A022201105C008554

#Find claims with more than 1 rows & w/ same coverage
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_inprocess
WHERE claimnumber IN (SELECT claimnumber
						FROM df1_staging3_inprocess
						GROUP BY claimnumber
						HAVING COUNT(claimnumber) > 1 AND COUNT(DISTINCT coverage) = 1)
ORDER BY claimnumber, updateddate; #285 rows

#Get the last row for claims with more than 1 rows & w/ same coverage
#Find those claims having more than 1 rows & w/ same coverage
SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.damage_type, t.coverage, t.ubt, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, t.updateddate, s.row_num
FROM df1_staging3_inprocess AS t 
JOIN (
    SELECT claimnumber, coverage, updateddate, ubt_trans, stbt_truoc_thue,
           ROW_NUMBER() OVER (PARTITION BY claimnumber) AS row_num
	FROM df1_staging3_inprocess AS t
    WHERE claimnumber IN (
			SELECT claimnumber
			FROM df1_staging3_inprocess
			GROUP BY claimnumber
			HAVING COUNT(*) > 1 AND COUNT(DISTINCT coverage) = 1
    )
) AS s
  ON t.claimnumber = s.claimnumber
  AND t.ubt_trans = s.ubt_trans
  AND t.stbt_truoc_thue = s.stbt_truoc_thue
WHERE s.row_num > 1;

#Create temporary table to store claims having more than 1 rows & w/ same coverage and their row number, total rows for each claim.
CREATE TEMPORARY TABLE inprocess_tempt AS 
		SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.damage_type, t.coverage, t.ubt, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, t.updateddate, s.max_row,
				ROW_NUMBER() OVER (PARTITION BY claimnumber) AS row_num
		FROM df1_staging3_inprocess AS t
		JOIN (
				SELECT claimnumber, COUNT(claimnumber) AS max_row
				FROM df1_staging3_inprocess
				GROUP BY claimnumber
				HAVING COUNT(*) > 1 AND COUNT(DISTINCT coverage) = 1) AS s
		ON t.claimnumber = s.claimnumber
;

#Get the last row for claims with more than 1 rows & w/ same coverage, delete the rest.
DELETE t
FROM df1_staging3_inprocess AS t
JOIN inprocess_tempt AS s
ON 	t.claimnumber = s.claimnumber
	AND t.ubt_trans = s.ubt_trans
	AND t.stbt_truoc_thue = s.stbt_truoc_thue
WHERE s.row_num < s.max_row;  


#Find claims with more than 1 rows & w/ different coverage
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_inprocess
WHERE claimnumber IN (SELECT claimnumber
						FROM df1_staging3_inprocess
						GROUP BY claimnumber
						HAVING COUNT(claimnumber) > 1 AND COUNT(DISTINCT coverage) > 1)
ORDER BY claimnumber, updateddate; #6 rows

#Delete the duplicated rows for claims that have duplicated rows & w/ different coverage
DELETE t
FROM df1_staging3_inprocess AS t 
JOIN (
    SELECT claimnumber, coverage, updateddate, ubt_trans, stbt_truoc_thue,
           ROW_NUMBER() OVER (PARTITION BY claimnumber, coverage) AS row_num
    FROM df1_staging3_inprocess
    WHERE claimnumber IN (
        SELECT claimnumber
        FROM df1_staging3_inprocess
        GROUP BY claimnumber
        HAVING COUNT(*) > 1 AND COUNT(DISTINCT coverage) > 1
    )
) AS s
  ON t.claimnumber = s.claimnumber
  AND t.ubt_trans = s.ubt_trans
  AND t.stbt_truoc_thue = s.stbt_truoc_thue
WHERE row_num > 1;


#SUM uoc_bt_ban_dau for claims with more than 1 rows & w/ different coverage
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_inprocess
WHERE claimnumber IN (SELECT claimnumber
						FROM df1_staging3_inprocess
						GROUP BY claimnumber
						HAVING COUNT(claimnumber) > 1 AND COUNT(DISTINCT coverage) > 1)
ORDER BY claimnumber, updateddate; #6 rows

#work with stbt_truoc_thue = SUM(duplicated rows of stbt_truoc_thue) 
-- A022200808C011018, A022200808C011852, A022201009C011000,A022201105C012050

##approved

SELECT claimnumber 
FROM df1_staging3_2
WHERE claim_status = 'approved'; #4666 rows,  1175 distinct claims

CREATE TABLE df1_staging3_approved AS
SELECT *
FROM df1_staging3_2
WHERE claim_status = 'approved';

ALTER TABLE df1_staging3_approved
ADD COLUMN row_index INT AUTO_INCREMENT PRIMARY KEY;

#Set empty values '' in ubt, ubt_trans, stbt_truoc_thue = 0
UPDATE df1_staging3_approved
SET ubt = CASE WHEN ubt = '' THEN 0 ELSE ubt END,
    ubt_trans = CASE WHEN ubt_trans = '' THEN 0 ELSE ubt_trans END,
    stbt_truoc_thue = CASE WHEN stbt_truoc_thue = '' THEN 0 ELSE stbt_truoc_thue END;

#Find the duplicated rows for 'approved' claims
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_2
WHERE claimnumber IN (SELECT claimnumber
						FROM df1_staging3_2
                        WHERE claim_status = 'approved' AND claim_status_name = 'approved'
						GROUP BY claimnumber
                        HAVING COUNT(claimnumber) > 1 AND COUNT(DISTINCT coverage) = 1)
ORDER BY claimnumber, updateddate;
-- There are NO duplicated claims with DIFF coverage where claim_status_name = approved
-- for duplicated claims with same coverage where claim_status_name = approved: uoc_bt_ban_dau = valid, ubt_trans = 0 (get from last row of in process)

#Find claims that have >1 rows of claim_status_approved = in process w/ diff coverage
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_2
WHERE claimnumber IN (SELECT claimnumber
						FROM df1_staging3_2
                        WHERE claim_status = 'approved' AND claim_status_name = 'in process'
						GROUP BY claimnumber
                        HAVING COUNT(claimnumber) > 1 AND COUNT(DISTINCT coverage) > 1)
ORDER BY claimnumber, updateddate; #0 rows

#Find approved claims that does not have 'in process' status before 'approved'
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_2
WHERE claimnumber NOT IN (SELECT claimnumber
							FROM df1_staging3_2
							WHERE claim_status = 'approved'  AND claim_status_name = 'in process'
                            )
	AND claim_status = 'approved'
ORDER BY claimnumber, updateddate; #137 rows
-- For these cases, get ubt_trans = ubt_trans of the row before it

#Find claims with more than 1 rows for same latest updateddate when claim_status_name = 'in process'
SELECT s.claimnumber, s.claim_status_name, s.claim_status, s.damage_type, s.coverage, s.ubt, s.uoc_bt_ban_dau, s.ubt_trans, s.stbt_truoc_thue, s.updateddate, s.row_num
FROM 	(SELECT *, ROW_NUMBER() OVER (PARTITION BY claimnumber, updateddate) AS row_num
			FROM df1_staging3_2
			WHERE claim_status= 'approved' AND claim_status_name = 'in process'
		) AS s
WHERE s.row_num > 1
ORDER BY claimnumber, updateddate; 
-- A022200303C010889, A022200305C001290, A022200305C009826

#Get the ubt_trans at row where claim_status_name = 'approved' based on the latest row of claim_status_name = 'in process'
-- get the rows in which claim_status_name = 'approved' AND latest row where claim_status_name = 'in process'

#Get the before row for each duplicated 'approved' claim 
CREATE TEMPORARY TABLE approved_temp AS 
	SELECT s.claimnumber, s.claim_status_name, s.claim_status, s.damage_type, s.coverage, s.ubt, s.uoc_bt_ban_dau, s.ubt_trans, s.stbt_truoc_thue, s.updateddate, s.row_num
	FROM (	SELECT *, ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate DESC, row_index DESC) AS row_num
			FROM df1_staging3_approved
			WHERE claim_status_name != 'approved') AS s
	WHERE s.row_num = 1; 


#Update the ubt_trans column with values from ubt_trans of rows where claim_status_name != 'approved'
UPDATE df1_staging3_approved AS t
JOIN approved_temp AS s
ON t.claimnumber = s.claimnumber
SET t.ubt_trans = s.ubt_trans
WHERE t.ubt_trans = 0; #1242 rows affected


#Find approved claims that does not have any other claim_status_name values other than 'approved'
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate 
FROM df1_staging3_approved
WHERE claimnumber NOT IN (	SELECT claimnumber
							FROM df1_staging3_2
							WHERE claim_status_name != 'approved'
                            )
ORDER BY claimnumber, updateddate; #90 rows, 88 distinct claims
-- A022100205C000015, A022100709C000003, A022101107C000153
-- For these claims, we will get the ubt_trans = round(stbt_truoc_thue*100/92.5926)

#Update claims that does not have any other claim_status_name values other than 'approved' for ubt_trans = round(stbt_truoc_thue*100/92.5926)
UPDATE df1_staging3_approved
SET ubt_trans = round(stbt_truoc_thue*100/92.5926)
WHERE claimnumber NOT IN (	SELECT claimnumber
							FROM df1_staging3_2
							WHERE claim_status_name != 'approved'
                            ) 
		AND ubt_trans = 0 AND stbt_truoc_thue != 0;

#Check if there's any approved claim that have ubt_trans = 0
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate 
FROM df1_staging3_approved
WHERE ubt_trans = 0; #0 rows
        
#Delete all the rows that have claim_status_name != approved
DELETE FROM df1_staging3_approved
WHERE claim_status_name != 'approved';

#Get duplicated row for approved claims with same coverage
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate 
FROM df1_staging3_approved
WHERE claimnumber IN (SELECT claimnumber
						FROM df1_staging3_approved
                        GROUP BY claimnumber
                        HAVING COUNT(claimnumber) > 1)
ORDER BY claimnumber, updateddate; #302 rows
-- get the latest date and delete the rest

#Delete duplicated rows
DELETE m
FROM df1_staging3_approved AS m
JOIN (
		SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.damage_type, t.coverage, t.ubt, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, t.updateddate, t.row_index, t.row_num
		FROM (	SELECT *, ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate DESC, row_index DESC) AS row_num
				FROM df1_staging3_approved) AS t
	) AS s
	ON m.claimnumber = s.claimnumber
	AND m.ubt_trans = s.ubt_trans
	AND	m.stbt_truoc_thue = s.stbt_truoc_thue
WHERE s.row_num > 1;


-- SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.damage_type, t.coverage, t.ubt, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, t.updateddate, t.row_index, t.row_num


##Paid out

SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_2
WHERE claim_status = 'paid out'; #39,487 rows, 7,887 claims

CREATE TABLE df1_staging3_paidout AS
SELECT *
FROM df1_staging3_2
WHERE claim_status = 'paid out';

ALTER TABLE df1_staging3_paidout
ADD COLUMN row_index INT AUTO_INCREMENT PRIMARY KEY;

#Fill in the empty values of uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue = 0
UPDATE df1_staging3_paidout
SET ubt = CASE WHEN ubt = '' THEN 0 ELSE ubt END,
    ubt_trans = CASE WHEN ubt_trans = '' THEN 0 ELSE ubt_trans END,
    uoc_bt_ban_dau = CASE WHEN uoc_bt_ban_dau = '' THEN 0 ELSE uoc_bt_ban_dau END,
    stbt_truoc_thue = CASE WHEN stbt_truoc_thue = '' THEN 0 ELSE stbt_truoc_thue END;

#find claims that have either 
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_paidout
WHERE claim_status_name = 'paid out' AND (uoc_bt_ban_dau = 0 OR ubt_trans = 0 OR stbt_truoc_thue = 0);
-- 3 claims, A022200309C001430, A022200505C009534, A022201003C002757

#find these claims in other tables
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_paidout
WHERE claimnumber = 'A022200309C001430' OR claimnumber = 'A022200505C009534' OR claimnumber = 'A022201003C002757'
ORDER BY claimnumber, updateddate;

#Get the latest updateddate row and delete the rest
DELETE t 
FROM df1_staging3_paidout AS t
JOIN (
    SELECT claimnumber, MAX(updateddate) AS latest_date
    FROM df1_staging3_paidout
    GROUP BY claimnumber
) AS s 
ON t.claimnumber = s.claimnumber 
WHERE t.updateddate != s.latest_date; #9215 rows


#Find the duplicated rows for 'paid-out' claims in which claim_status_name = 'paid out' same coverage
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_paidout
WHERE claimnumber IN (	SELECT claimnumber
						FROM df1_staging3_paidout
                        WHERE claim_status_name = 'paid out'
						GROUP BY claimnumber
                        HAVING COUNT(claimnumber) > 1 AND COUNT(DISTINCT coverage) = 1
                        )
	AND claim_status_name = 'paid out'
ORDER BY claimnumber, updateddate; #2396 rows
--  >1 rows on same latest updateddate: stbt_truoc_thue -> SUM all rows 
-- 1 row on latest updateddate: keep same stbt_truoc_thue
-- rows w/ diff updateddate: A022204210C002333 (19/7), A022204305C000363 (21/4)

#Get the SUM(stbt_truoc_thue) of all rows w/ same claim and coverage
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate,
		ROW_NUMBER() OVER (PARTITION BY claimnumber, coverage ORDER BY row_index DESC) AS row_num
FROM df1_staging3_paidout
WHERE claimnumber = 'A022200707C001164' OR claimnumber = 'A022201907C002174'
;
 
UPDATE df1_staging3_paidout AS t
JOIN (
		SELECT claimnumber, coverage, SUM(stbt_truoc_thue) AS sum_stbt_truoc_thue
		FROM df1_staging3_paidout
		GROUP BY claimnumber, coverage
	) AS s
ON t.claimnumber = s.claimnumber AND t.coverage = s.coverage
SET t.stbt_truoc_thue = s.sum_stbt_truoc_thue;

#Delete the duplicates
DELETE t
FROM df1_staging3_paidout AS t
JOIN (
		SELECT claimnumber, coverage, stbt_truoc_thue, row_index,
				ROW_NUMBER() OVER (PARTITION BY claimnumber, coverage) AS row_num
		FROM df1_staging3_paidout
		) AS s
ON t.claimnumber = s.claimnumber
AND t.coverage = s.coverage
AND t.stbt_truoc_thue = s.stbt_truoc_thue
AND t.row_index = s.row_index
WHERE  s.row_num > 1; 


#Find the duplicated rows for 'paid-out' claims in which claim_status_name = 'paid out' diff coverage
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_paidout
WHERE claimnumber IN (	SELECT claimnumber
						FROM df1_staging3_paidout
                        WHERE claim_status_name = 'paid out'
						GROUP BY claimnumber
                        HAVING COUNT(claimnumber) > 1 AND COUNT(DISTINCT coverage) > 1
                        )
	AND claim_status_name = 'paid out'
ORDER BY claimnumber, updateddate;
-- A022200707C001164, A022201907C002174


##cancelled
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_2
WHERE claim_status = 'cancelled'; #2014 rows, 913 distinct claims

#Find duplicated rows for claim_status = 'cancelled'
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_2
WHERE claimnumber IN (	SELECT claimnumber
						FROM df1_staging3_2
                        WHERE claim_status = 'cancelled'
						GROUP BY claimnumber
                        HAVING COUNT(claimnumber) > 1
                        )
	-- AND claim_status_name = 'paid out'
ORDER BY claimnumber, updateddate; 

#Create table for 'cancelled' claims
CREATE TABLE df1_staging3_cancelled AS
SELECT *
FROM df1_staging3_2
WHERE claim_status = 'cancelled';

ALTER TABLE df1_staging3_cancelled
ADD COLUMN row_index INT AUTO_INCREMENT PRIMARY KEY;


#Fill in any '' empty values for ubt, stbt_truoc_thue, ubt_trans = 0
UPDATE df1_staging3_cancelled
SET ubt = CASE WHEN ubt = '' THEN 0 ELSE ubt END,
    ubt_trans = CASE WHEN ubt_trans = '' THEN 0 ELSE ubt_trans END,
    uoc_bt_ban_dau = CASE WHEN uoc_bt_ban_dau = '' THEN 0 ELSE uoc_bt_ban_dau END,
    stbt_truoc_thue = CASE WHEN stbt_truoc_thue = '' THEN 0 ELSE stbt_truoc_thue END;

#Fill in the claim_status_name = 'cancelled' row ubt, uoc_bt_ban_dau, ubt_trans the number from the row above it
#Get the before row for each duplicated 'approved' claim 
CREATE TEMPORARY TABLE cancelled_temp AS
	SELECT s.claimnumber, s.claim_status_name, s.claim_status, s.damage_type, s.coverage, s.ubt, s.uoc_bt_ban_dau, s.ubt_trans, s.stbt_truoc_thue, s.updateddate, s.row_num
	FROM (	SELECT *, ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate DESC, row_index DESC) AS row_num
			FROM df1_staging3_cancelled
			WHERE claim_status_name != 'cancelled') AS s
	WHERE s.row_num = 1
; 
-- A012200008C006281 (5m), A022200303C005863 (uoc_bt_ban_dau = 9m, ubt_trans = 215,500,000)

#Update the ubt_trans column with values from ubt_trans of rows where claim_status_name != 'cancelled'
UPDATE df1_staging3_cancelled AS t
JOIN cancelled_temp AS s
ON t.claimnumber = s.claimnumber
SET t.ubt_trans = s.ubt_trans,
	t.uoc_bt_ban_dau = s.uoc_bt_ban_dau,
	t.stbt_truoc_thue = s.stbt_truoc_thue
WHERE t.claim_status_name = 'cancelled'; 

#Delete rows that claim_status_name != 'cancelled'
DELETE FROM df1_staging3_cancelled
WHERE claim_status_name != 'cancelled';


##denied
SELECT DISTINCT claimnumber
FROM df1_staging3_2
WHERE claim_status = 'denied'; #32 distinct claims

CREATE TABLE df1_staging3_denied AS
SELECT *
FROM df1_staging3_2
WHERE claim_status = 'denied';

ALTER TABLE df1_staging3_denied
ADD COLUMN row_index INT AUTO_INCREMENT PRIMARY KEY;

#Fill in the empty values of uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue = 0
UPDATE df1_staging3_denied
SET ubt = CASE WHEN ubt = '' THEN 0 ELSE ubt END,
    ubt_trans = CASE WHEN ubt_trans = '' THEN 0 ELSE ubt_trans END,
    uoc_bt_ban_dau = CASE WHEN uoc_bt_ban_dau = '' THEN 0 ELSE uoc_bt_ban_dau END,
    stbt_truoc_thue = CASE WHEN stbt_truoc_thue = '' THEN 0 ELSE stbt_truoc_thue END;


#Find the nearest row w/ 'denied' claim in which ubt_trans = 0
SELECT 	m.claimnumber, m.claim_status_name, m.claim_status, m.damage_type, m.coverage, m.ubt, m.uoc_bt_ban_dau, m.ubt_trans, m.stbt_truoc_thue, m.updateddate, s.row_num
FROM df1_staging3_denied AS m
JOIN (
		SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.ubt_trans, t.stbt_truoc_thue, t.updateddate, t.row_num
		FROM (	SELECT *, ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate DESC, row_index DESC) AS row_num
				FROM df1_staging3_denied
				WHERE claim_status_name != 'denied') AS t
	) AS s
	ON m.claimnumber = s.claimnumber
	AND m.ubt_trans = s.ubt_trans
	AND	m.stbt_truoc_thue = s.stbt_truoc_thue
    AND m.updateddate = s.updateddate
	WHERE s.row_num = 1 AND m.ubt_trans = 0
ORDER BY claimnumber, updateddate; #2 rows/claims
-- A022200309C001250, A022201005C001406
-- For these claims, get ubt_trans = uoc_bt_ban_dau

#Create temporary table to hold valid values of ubt_trans 
CREATE TEMPORARY TABLE denied_temp AS
SELECT 	m.claimnumber, m.claim_status_name, m.uoc_bt_ban_dau, m.ubt_trans, m.stbt_truoc_thue, m.updateddate, s.row_num
FROM df1_staging3_denied AS m
JOIN (
		SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.ubt_trans, t.stbt_truoc_thue, t.updateddate, t.row_num
		FROM (	SELECT *, ROW_NUMBER() OVER (PARTITION BY claimnumber ORDER BY updateddate DESC, row_index DESC) AS row_num
				FROM df1_staging3_denied
				WHERE claim_status_name != 'denied') AS t
	) AS s
	ON m.claimnumber = s.claimnumber
	AND m.ubt_trans = s.ubt_trans
	AND	m.stbt_truoc_thue = s.stbt_truoc_thue
    AND m.updateddate = s.updateddate
	WHERE s.row_num = 1; 
    
#Fill in valid values of ubt_trans to df1_staging3_denied
UPDATE df1_staging3_denied AS t
JOIN denied_temp AS s
ON t.claimnumber = s.claimnumber
SET t.ubt_trans = s.ubt_trans
WHERE t.claim_status_name = 'denied' AND t.ubt_trans = 0;

#fill in rows which have ubt_trans = 0 -> ubt_trans = stbt_truoc_thue
UPDATE df1_staging3_denied
SET ubt_trans = stbt_truoc_thue
WHERE ubt_trans = 0;

#Delete the unecessary rows 
DELETE FROM df1_staging3_denied
WHERE claim_status_name != 'denied';



SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_2
WHERE claimnumber = 'A022200309C001250' OR claimnumber = 'A022201005C001406'
ORDER BY claimnumber, updateddate;

SELECT claimnumber, statusname, coverage, claim_estimate_first, claim_estimate, claim_estimate_beforetax, compensation_total, compensation_amount_beforetax
FROM df1_staging3_2
WHERE claimnumber = 'A022200309C001250' OR claimnumber = 'A022201005C001406';

-- SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.damage_type, t.coverage, t.ubt, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, t.updateddate
-- FROM df1_staging3_2 AS t
-- JOIN (SELECT claimnumber
-- 		FROM df1_staging3_2
--         WHERE claim_status_name = claim_status
-- 		GROUP BY claimnumber
-- 		HAVING COUNT(claimnumber) > 1 AND COUNT(DISTINCT coverage) = 1 AND COUNT(DISTINCT updateddate) = 1) AS s
-- ON t.claimnumber = s.claimnumber
-- ORDER BY claimnumber, updateddate; 

SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_estpending;


SELECT claimnumber, statusname, coverage, claim_estimate_first, claim_estimate, claim_estimate_beforetax, compensation_total, compensation_amount_beforetax
FROM claims_staging1
WHERE claimnumber = 'A022200706C008866';

#TRANSLATE COLUMN NAMES AND VALUES
-- Look up to see if there is any column in auto_insurance_claim that is same as those columns above but in different column name**
-- df1: loai_hinh -> df2: loai_hinh_trans 
-- df1: don_vi_boi_thuong -> df2: agencycompensation  
-- df1: ngay_thanh_toan -> df2: paymentdate  
-- df1: loai_boi_thuong -> df2: solutioncompensation  
-- df1: pham_vi -> df2: nguyen_nhan_ton_that  
-- df1: gdv_xu_ly -> df2: assignee_fullname  
-- df1: ubt_trans -> df2: ubt
-- df1: claim_approved_date -> flex_approved_date  
-- df1: claim_status_name -> statusname
-- df1: ngay_duyet_bt & flex_ngay_duyet same value  

#Translate column name and values for 'pham_vi'
SELECT DISTINCT loai_hinh FROM df1_staging3_2; #LPX (Personal injury protection), TNDSBB (Auto liability coverage), VCX (Collision coverage), TNDSTN (Comprehensive coverage)

ALTER TABLE df1_staging3_2
CHANGE loai_hinh coverage TEXT;

UPDATE df1_staging3_2
SET coverage = CASE WHEN coverage = 'LPX' THEN 'Personal injury coverage'
					 WHEN coverage = 'TNDSBB' THEN 'Auto liability coverage'
                     WHEN coverage = 'VCX' THEN 'Collision coverage'
					 WHEN coverage = 'TNSDTN' THEN 'Comprehensive coverage'
                     ELSE 'Unknown' END;




START TRANSACTION;

	DELETE t
	FROM your_table_name t
	WHERE t.claim_status_name = 'in process'
	AND t.updateddate < (
			SELECT MAX(updateddate)
			FROM your_table_name
			WHERE claim_number = t.claim_number
			AND claim_status_name = 'in process'
	);

COMMIT;

#if the claimnumber, loai_hinh, stbt_truoc_thue are the same and claim_status_name ='đã chi trả bồi thường', we delete one row
SELECT claimnumber, claim_status_name, flex_ngay_duyet, loai_hinh, ngay_duyet_bt, ngay_mo_hsbt, ngay_thanh_toan, ngaybatdau, ngayketthuc, pham_vi, stbt_truoc_thue, ubt, ubt_trans, uoc_bt_ban_dau, updateddate, 
		ROW_NUMBER() OVER (PARTITION BY claimnumber, loai_hinh, cl) AS row_num
FROM df1_staging2
WHERE claim_status_name = 'Đã chi trả bồi thường' AND row_num
;

SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, ubt, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_2
WHERE claimnumber IN (SELECT claimnumber
						FROM df1_staging3_2
                        GROUP BY claimnumber)
ORDER BY claimnumber, updateddate;

WITH cte_rows AS (
		SELECT claimnumber, 
		ROW_NUMBER() OVER (PARTITION BY claimnumber, claim_status_name) AS row_num
        FROM df1_staging3_2
)
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, claim_submitted_date, claim_opened_date, claim_approved_date, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_2
WHERE claimnumber IN (SELECT claimnumber
						FROM cte_rows
                        WHERE row_num > 1)
; 

#Create new table same as df1_staging3_2 but with row_index
CREATE TEMPORARY TABLE df1_staging3_2_row_index AS
SELECT *
FROM df1_staging3_2;

ALTER TABLE df1_staging3_2_row_index
ADD COLUMN row_index INT AUTO_INCREMENT PRIMARY KEY;


#Create a table that for each claim_status_name, there's only one row
CREATE TABLE df1_staging3_2_nodup AS
SELECT s.*
FROM (	SELECT *, 
		ROW_NUMBER() OVER (PARTITION BY claimnumber, claim_status_name, coverage ORDER BY updateddate, row_index DESC) AS row_num		
		FROM df1_staging3_2_row_index
	) AS s
WHERE s.row_num = 1;

#fill up empty value of numerical columns to 0
UPDATE df1_staging3_2_nodup
SET ubt = CASE WHEN ubt = '' THEN 0 ELSE ubt END,
    ubt_trans = CASE WHEN ubt_trans = '' THEN 0 ELSE ubt_trans END,
    uoc_bt_ban_dau = CASE WHEN uoc_bt_ban_dau = '' THEN 0 ELSE uoc_bt_ban_dau END,
    stbt_truoc_thue = CASE WHEN stbt_truoc_thue = '' THEN 0 ELSE stbt_truoc_thue END;

#change the claim_status of claims that are incorrectly labeled (shoud be 'assessment pending' instead of 'estimate pending') 
SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.damage_type, t.coverage, t.claim_submitted_date, t.claim_opened_date, t.claim_approved_date, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, t.updateddate, s.uoc_bt_ban_dau AS s_ubt_ban_dau, s.ubt_trans AS s_ubt_trans
FROM df1_staging3_2_nodup AS t
JOIN df1_staging3_estpending AS s
ON t.claimnumber = s.claimnumber 
WHERE t.claim_status != s.claim_status; #284 claims

UPDATE df1_staging3_2_nodup AS t
JOIN df1_staging3_estpending AS s
ON t.claimnumber = s.claimnumber
SET t.claim_status = s.claim_status
WHERE t.claim_status != s.claim_status;

#compare df1_staging3_2_nodup with each specific claim_status_name table to see if the ubt_trans match with each other
SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.damage_type, t.coverage, t.claim_submitted_date, t.claim_opened_date, t.claim_approved_date, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, t.updateddate, s.uoc_bt_ban_dau AS s_ubt_ban_dau, s.ubt_trans AS s_ubt_trans
FROM df1_staging3_2_nodup AS t
JOIN df1_staging3_inprocess AS s
ON t.claimnumber = s.claimnumber AND t.claim_status_name = s.claim_status_name AND t.coverage = s.coverage AND t.updateddate = s.updateddate
WHERE t.ubt_trans != s.ubt_trans OR t.uoc_bt_ban_dau != s.uoc_bt_ban_dau
ORDER BY t.claimnumber, t.updateddate;

#find out are there any >1 rows of in process of a same claim same coverage
SELECT claimnumber, claim_status_name, claim_status, damage_type, coverage, claim_submitted_date, claim_opened_date, claim_approved_date, uoc_bt_ban_dau, ubt_trans, stbt_truoc_thue, updateddate
FROM df1_staging3_2_nodup
WHERE claimnumber IN (	SELECT claimnumber
						FROM df1_staging3_2_nodup
                        WHERE claim_status_name = 'in process'
                        GROUP BY claimnumber, coverage
                        HAVING COUNT(claimnumber) > 1);
-- 0 row 

#Fix the claim_status_name = 'approved': ubt_trans = 0
UPDATE df1_staging3_2_nodup AS t
JOIN df1_staging3_approved AS s
ON t.claimnumber = s.claimnumber
SET t.ubt_trans = s.ubt_trans
WHERE t.claim_status_name = 'approved' AND t.claim_status = 'approved'; #1175 rows


SELECT t.claimnumber, t.claim_status_name, t.claim_status, t.damage_type, t.coverage, t.claim_submitted_date, t.claim_opened_date, t.claim_approved_date, t.uoc_bt_ban_dau, t.ubt_trans, t.stbt_truoc_thue, t.updateddate, s.ubt_trans AS s_ubt_trans
FROM df1_staging3_2_nodup AS t
JOIN df1_staging3_paidout AS s
ON t.claimnumber = s.claimnumber
WHERE t.claim_status_name = 'approved' AND t.claim_status = 'paid out'; #7184 rows




