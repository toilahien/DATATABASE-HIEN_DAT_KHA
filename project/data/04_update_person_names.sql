-- Replace numbered placeholder names with deterministic Vietnamese-style demo names.
-- This updates names only; all person IDs, foreign keys, and other data stay unchanged.
USE reims_db;

UPDATE person
SET full_name = CONCAT(
    ELT(1 + MOD(person_id * 7 + 3, 19),
        'Nguyen','Tran','Le','Pham','Hoang','Huynh','Phan','Vu','Vo','Dang','Bui','Do','Ho','Ngo','Duong','Ly','Truong','Cao','Ta'),
    ' ',
    IF(MOD(person_id, 2) = 0,
       ELT(1 + MOD(person_id * 11 + 7, 41),
           'Van An','Van Binh','Van Cuong','Van Dat','Van Duc','Van Dung','Van Hao','Van Hieu','Van Huan','Van Hung','Van Khai','Van Khanh','Van Khoa','Van Lam','Van Long','Van Minh','Van Nam','Van Phong','Van Phuc','Van Quan','Van Quang','Van Son','Van Tai','Van Tam','Van Thang','Van Thien','Van Thinh','Van Tuan','Van Tung','Van Viet','Van Vinh','Huu Huy','Duc Tien','Minh Quan','Quoc Bao','Thanh Cong','Gia Bao','Bao Long','Tuan Kiet','Trong Nghia','Dinh La'),
       ELT(1 + MOD(person_id * 11 + 7, 41),
           'Thi An','Thi Anh','Thi Bich','Thi Chau','Thi Chi','Thi Dung','Thi Giang','Thi Ha','Thi Hanh','Thi Hien','Thi Hoa','Thi Huong','Thi Khanh','Thi Lan','Thi Linh','Thi Mai','Thi My','Thi Nga','Thi Ngoc','Thi Nhi','Thi Phuong','Thi Quyen','Thi Thao','Thi Trang','Thi Trinh','Thi Truc','Thi Tuyet','Thi Uyen','Thi Van','Thi Vy','Thi Yen','Ngoc Anh','Ngoc Han','Thanh Tam','Minh Chau','Hoai Thu','Thuy Tien','Kim Ngan','Thu Ha','My Linh','Phuong Thao'))
  )
WHERE person_id BETWEEN 1 AND 1200;

-- Preview the result.
SELECT person_id, full_name
FROM person
WHERE person_id BETWEEN 1 AND 1200
ORDER BY person_id
LIMIT 30;
