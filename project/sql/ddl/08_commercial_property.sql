-- Commercial property subtype
USE reims_db;

CREATE TABLE commercial_property (
    property_id BIGINT UNSIGNED PRIMARY KEY,
    business_type VARCHAR(60),
    floor_area_sqm DECIMAL(10,2) NOT NULL,
    parking_spaces SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    CONSTRAINT chk_commercial_area CHECK (floor_area_sqm > 0),
    CONSTRAINT fk_commercial_property FOREIGN KEY (property_id) REFERENCES property(property_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
