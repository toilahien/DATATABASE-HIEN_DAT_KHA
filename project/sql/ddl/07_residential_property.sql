-- Residential property subtype
USE reims_db;

CREATE TABLE residential_property (
    property_id BIGINT UNSIGNED PRIMARY KEY,
    bedrooms TINYINT UNSIGNED NOT NULL,
    bathrooms TINYINT UNSIGNED NOT NULL,
    area_sqm DECIMAL(10,2) NOT NULL,
    furnished_status ENUM('FURNISHED','PARTLY_FURNISHED','UNFURNISHED') NULL,
    CONSTRAINT chk_residential_area CHECK (area_sqm > 0),
    CONSTRAINT fk_residential_property FOREIGN KEY (property_id) REFERENCES property(property_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
