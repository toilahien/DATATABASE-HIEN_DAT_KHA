USE reims_db;

-- Q1. Search available rental listings by budget and property type.
SELECT d.property_id,d.title,d.address,d.property_type,d.asking_price
FROM v_property_dashboard d
WHERE d.status='AVAILABLE' AND d.listing_type='FOR_RENT'
  AND d.asking_price BETWEEN 8000000 AND 20000000
ORDER BY d.asking_price;
