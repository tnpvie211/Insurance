USE Insurance;

SELECT * FROM df3;

DESCRIBE df3;

#'distributionunitname', 'mdsd', 'namsanxuat'

SELECT DISTINCT customercode FROM df3; #22,582

SELECT DISTINCT policycode FROM df3; #96,493

SELECT DISTINCT status_trans FROM df3; 

SELECT policycode, customercode, status_trans, createddate, ngaybatdau, ngayketthuc
FROM df3;

SELECT *
FROM df3
WHERE sogcn = 'OT210076419';

#sogcn that have been renewed
SELECT sogcn
FROM df3
GROUP BY sogcn
HAVING COUNT(sogcn) > 1; 

SELECT DISTINCT sogcn
FROM df3
WHERE mdsd = '-';

#Create a staging table for df3
CREATE TABLE df3_staging AS
SELECT *
FROM df3;
    
#Check if column ngaybatdau have empty or invalid or null value
SELECT *
FROM df3_staging
WHERE ngaybatdau IS NULL OR ngaybatdau= '-' OR ngaybatdau = ''; 
-- -> 1 row 

#Check if this row is a duplicated one
SELECT *
FROM df3_staging
WHERE policycode = 'A032201112004888';
-- -> No it's not duplicated

#Delete this row since we don't have much information
DELETE FROM df3_staging
WHERE policycode = 'A032201112004888';

#Change datatype to Datetime of ngaybatdau column
UPDATE df3_staging
SET ngaybatdau = DATE(STR_TO_DATE(ngaybatdau, '%d/%m/%Y'))
WHERE ngaybatdau IS NOT NULL;

ALTER TABLE df3_staging
CHANGE COLUMN ngaybatdau start_date DATE
DEFAULT NULL;

#See the date range of start_date column
SELECT MIN(start_date), MAX(start_date)
FROM df3_staging;

#See if there are policies where start_date > today & status_trans is 'ended'
SELECT *
FROM df3_staging
WHERE start_date > CURDATE() AND status_trans = 'Chấm dứt';

#Check if there's any invalid value in createddate
SELECT * 
FROM df1_staging
WHERE createddate IS NULL OR createddate = '-' OR createddate = '';
-- -> None

#Change the datatype of column 'createddate'
UPDATE df3_staging
SET createddate = DATE(STR_TO_DATE(createddate, '%d/%m/%Y'))
WHERE createddate IS NOT NULL;

ALTER TABLE df3_staging
MODIFY COLUMN createddate DATE;

#Check if there's any policy created after today
SELECT * 
FROM df3_staging
WHERE createddate > CURDATE();
-- -> None

#find the range of createddate
SELECT MIN(createddate), MAX(createddate)
FROM df3_staging;

#find unique value of column status_trans
SELECT coinsurance_trans, hasrevenueallocation_trans, rsa
FROM df3_staging;

#Drop column assigneename
ALTER TABLE df3_staging
DROP COLUMN assigneename;

SELECT sogcn, policycode, createddate, start_date, ngayketthuc, status_trans, finalprice 
FROM df3_staging
ORDER BY policycode;

SELECT DISTINCT policycode 
FROM df3_staging; #96492

SELECT DISTINCT sogcn 
FROM df3_staging; #220279

SELECT * FROM df3_staging; #220808

#change datatype
-- ngayketthuc
UPDATE df3_staging
SET ngayketthuc = DATE(STR_TO_DATE(ngayketthuc, '%d/%m/%Y'));

ALTER TABLE df3_staging
MODIFY COLUMN ngayketthuc DATE;

-- finalprice
UPDATE df3_staging
SET finalprice = REPLACE(finalprice, ',', '');

ALTER TABLE df3_staging
MODIFY COLUMN finalprice DECIMAL(15,2);

-- tndsbb
UPDATE df3_staging
SET tndsbb = REPLACE(tndsbb, ',', '');

ALTER TABLE df3_staging
MODIFY COLUMN tndsbb DECIMAL(15,2);

-- lpx
UPDATE df3_staging
SET lpx = REPLACE(lpx, ',', '');

ALTER TABLE df3_staging
MODIFY COLUMN lpx DECIMAL(15,2);

-- vcx
UPDATE df3_staging
SET vcx = REPLACE(vcx, ',', '');

ALTER TABLE df3_staging
MODIFY COLUMN vcx DECIMAL(15,2);

-- tndstn
UPDATE df3_staging
SET tndstn = REPLACE(tndstn, ',', '');

ALTER TABLE df3_staging
MODIFY COLUMN tndstn DECIMAL(15,2);

-- sochongoi
ALTER TABLE df3_staging
MODIFY COLUMN sochongoi INT;

#Change column name
ALTER TABLE df3_staging
CHANGE ngayketthuc end_date DATE;

ALTER TABLE df3_staging
CHANGE COLUMN hangxe vehicle_make TEXT;

ALTER TABLE df3_staging
CHANGE COLUMN tndsbb auto_liability_coverage DECIMAL(15,2);

ALTER TABLE df3_staging
CHANGE COLUMN tndstn comprehensive_coverage DECIMAL(15,2);

ALTER TABLE df3_staging
CHANGE COLUMN lpx personal_injury_coverage DECIMAL(15,2);

ALTER TABLE df3_staging
CHANGE COLUMN vcx collision_coverage DECIMAL(15,2);

ALTER TABLE df3_staging
CHANGE COLUMN mdsd vehicle_usage TEXT;

ALTER TABLE df3_staging
CHANGE tinhthanhchuxe regions_customer TEXT;

ALTER TABLE df3_staging
CHANGE customer_type_trans customer_type TEXT;

ALTER TABLE df3_staging
CHANGE COLUMN loaixe vehicle_type TEXT;

ALTER TABLE df3_staging
CHANGE COLUMN sochongoi vehicle_seats INT;

ALTER TABLE df3_staging
CHANGE COLUMN sogcn certificate_no TEXT;

#Translate values in column
UPDATE df3_staging
SET status_trans = CASE WHEN status_trans ='Đang có hiệu lực' THEN 'Active'
						WHEN status_trans ='Chấm dứt' THEN 'Terminated'
                        WHEN status_trans ='Hết hiệu lực' THEN 'Expired'
                        WHEN status_trans ='Chưa tới hiệu lực' THEN 'Not Activated'
                        END;

SELECT vehicle_usage, customer_type, vehicle_type FROM df3_staging;

UPDATE df3_staging
SET vehicle_usage = CASE WHEN vehicle_usage = 'Không kinh doanh' THEN 'Non-commercial'
						WHEN vehicle_usage = 'Kinh doanh' THEN 'Commercial'
                        END;
                        
UPDATE df3_staging
SET customer_type = CASE WHEN customer_type = 'Cá nhân' THEN 'Personal'
						WHEN customer_type = 'Tổ chức' THEN 'Business'
                        END;

SELECT certificate_no, policycode, createddate, start_date, end_date, status_trans, auto_liability_coverage, comprehensive_coverage, personal_injury_coverage,
		collision_coverage, finalprice, regions_customer, customer_type, vehicle_make, vehicle_seats, vehicle_type, distributionchannelname
FROM df3_staging
ORDER BY policycode;

SELECT SUM(finalprice)
FROM df3_staging
WHERE start_date > '2022-01-01' AND start_date < '2022-12-31' AND end_date > '2023-01-01';

SELECT COUNT( DISTINCT policycode)
FROM df3_staging
WHERE start_date > '2022-01-01' AND start_date < '2022-12-31' AND end_date > '2023-01-01';

