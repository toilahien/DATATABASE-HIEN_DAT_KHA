USE reims_db;

-- Q10. Properties whose area is above the average for their own subtype.
WITH all_areas AS (
    SELECT p.property_id,p.title,p.property_type,r.area_sqm AS area
    FROM property p JOIN residential_property r ON r.property_id=p.property_id
    UNION ALL
    SELECT p.property_id,p.title,p.property_type,c.floor_area_sqm AS area
    FROM property p JOIN commercial_property c ON c.property_id=p.property_id
), subtype_avg AS (
    SELECT property_type,AVG(area) AS avg_area FROM all_areas GROUP BY property_type
)
SELECT x.property_id,x.title,x.property_type,x.area,a.avg_area
FROM all_areas x JOIN subtype_avg a USING(property_type)
WHERE x.area>a.avg_area ORDER BY x.property_type,x.area DESC;
