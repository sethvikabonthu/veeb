-- ═══════════════════════════════════════════════════════════
-- VEEB — Vehicle Entry-Exit & Billing Auditor
-- Complete Database Schema with Triggers & Seed Data
-- ═══════════════════════════════════════════════════════════

CREATE DATABASE IF NOT EXISTS VEEB;
USE VEEB;

-- ───────────────────────────────────────────────────────────
-- Drop existing tables (in reverse dependency order)
-- ───────────────────────────────────────────────────────────
DROP TABLE IF EXISTS Revenue_Report;
DROP TABLE IF EXISTS Billing;
DROP TABLE IF EXISTS Entry_Exit_Log;
DROP TABLE IF EXISTS Parking_Slot;
DROP TABLE IF EXISTS Vehicle;
DROP TABLE IF EXISTS Vehicle_Type;
DROP TABLE IF EXISTS Admin_User;

-- ═══════════════════════════════════════════════════════════
-- TABLE 1: Vehicle_Type
-- Stores vehicle categories and their pricing rules
-- ═══════════════════════════════════════════════════════════
CREATE TABLE Vehicle_Type (
    type_id INT PRIMARY KEY AUTO_INCREMENT,
    type_name VARCHAR(50) NOT NULL UNIQUE,
    hourly_rate DECIMAL(10,2) NOT NULL,
    daily_max_rate DECIMAL(10,2) NOT NULL,
    description VARCHAR(200)
);

-- ═══════════════════════════════════════════════════════════
-- TABLE 2: Vehicle
-- Registered vehicles with owner info
-- ═══════════════════════════════════════════════════════════
CREATE TABLE Vehicle (
    vehicle_id INT PRIMARY KEY AUTO_INCREMENT,
    plate_number VARCHAR(20) NOT NULL UNIQUE,
    type_id INT NOT NULL,
    owner_name VARCHAR(100),
    phone VARCHAR(15),
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (type_id) REFERENCES Vehicle_Type(type_id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════
-- TABLE 3: Parking_Slot
-- Available parking slots with zone info
-- ═══════════════════════════════════════════════════════════
CREATE TABLE Parking_Slot (
    slot_id INT PRIMARY KEY AUTO_INCREMENT,
    slot_number VARCHAR(10) NOT NULL UNIQUE,
    zone ENUM('A','B','C','D') NOT NULL DEFAULT 'A',
    floor_level INT DEFAULT 1,
    is_occupied BOOLEAN DEFAULT FALSE,
    vehicle_type_allowed INT,
    FOREIGN KEY (vehicle_type_allowed) REFERENCES Vehicle_Type(type_id) ON DELETE SET NULL
);

-- ═══════════════════════════════════════════════════════════
-- TABLE 4: Entry_Exit_Log
-- Records every vehicle entry and exit
-- ═══════════════════════════════════════════════════════════
CREATE TABLE Entry_Exit_Log (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    vehicle_id INT NOT NULL,
    slot_id INT NOT NULL,
    entry_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    exit_time DATETIME DEFAULT NULL,
    duration_minutes INT DEFAULT NULL,
    fee DECIMAL(10,2) DEFAULT 0.00,
    status ENUM('Parked','Exited','Pending') DEFAULT 'Parked',
    FOREIGN KEY (vehicle_id) REFERENCES Vehicle(vehicle_id) ON DELETE CASCADE,
    FOREIGN KEY (slot_id) REFERENCES Parking_Slot(slot_id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════
-- TABLE 5: Billing
-- Payment records for each parking session
-- ═══════════════════════════════════════════════════════════
CREATE TABLE Billing (
    billing_id INT PRIMARY KEY AUTO_INCREMENT,
    log_id INT NOT NULL UNIQUE,
    amount DECIMAL(10,2) NOT NULL,
    payment_method ENUM('Cash','UPI','Card') DEFAULT 'Cash',
    payment_status ENUM('Paid','Pending','Failed') DEFAULT 'Pending',
    billed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (log_id) REFERENCES Entry_Exit_Log(log_id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════
-- TABLE 6: Revenue_Report
-- Daily/periodic revenue summaries
-- ═══════════════════════════════════════════════════════════
CREATE TABLE Revenue_Report (
    report_id INT PRIMARY KEY AUTO_INCREMENT,
    report_date DATE NOT NULL,
    total_entries INT DEFAULT 0,
    total_exits INT DEFAULT 0,
    total_revenue DECIMAL(12,2) DEFAULT 0.00,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ═══════════════════════════════════════════════════════════
-- TABLE 7: Admin_User
-- Admin accounts for system access
-- ═══════════════════════════════════════════════════════════
CREATE TABLE Admin_User (
    admin_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(100) NOT NULL,
    full_name VARCHAR(100),
    role ENUM('Admin','Operator') DEFAULT 'Operator',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ═══════════════════════════════════════════════════════════
-- TRIGGERS
-- ═══════════════════════════════════════════════════════════

-- Trigger 1: When a vehicle enters (log inserted), mark slot occupied
DROP TRIGGER IF EXISTS trg_on_entry;
DELIMITER //
CREATE TRIGGER trg_on_entry
AFTER INSERT ON Entry_Exit_Log
FOR EACH ROW
BEGIN
    UPDATE Parking_Slot SET is_occupied = TRUE WHERE slot_id = NEW.slot_id;
END;
//
DELIMITER ;

-- Trigger 2: When exit_time is updated, calculate fee & free the slot
DROP TRIGGER IF EXISTS trg_on_exit;
DELIMITER //
CREATE TRIGGER trg_on_exit
BEFORE UPDATE ON Entry_Exit_Log
FOR EACH ROW
BEGIN
    DECLARE v_hourly DECIMAL(10,2);
    DECLARE v_daily_max DECIMAL(10,2);
    DECLARE v_duration INT;
    DECLARE v_fee DECIMAL(10,2);

    IF NEW.exit_time IS NOT NULL AND OLD.exit_time IS NULL THEN
        -- Calculate duration in minutes
        SET v_duration = TIMESTAMPDIFF(MINUTE, OLD.entry_time, NEW.exit_time);
        SET NEW.duration_minutes = v_duration;

        -- Get pricing from vehicle type
        SELECT vt.hourly_rate, vt.daily_max_rate
        INTO v_hourly, v_daily_max
        FROM Vehicle v
        JOIN Vehicle_Type vt ON v.type_id = vt.type_id
        WHERE v.vehicle_id = OLD.vehicle_id;

        -- Calculate fee: hourly rate, capped at daily max
        SET v_fee = LEAST(CEIL(v_duration / 60.0) * v_hourly, v_daily_max);
        IF v_fee < v_hourly THEN
            SET v_fee = v_hourly; -- Minimum 1 hour charge
        END IF;
        SET NEW.fee = v_fee;
        SET NEW.status = 'Exited';

        -- Free up the parking slot
        UPDATE Parking_Slot SET is_occupied = FALSE WHERE slot_id = OLD.slot_id;
    END IF;
END;
//
DELIMITER ;

-- Trigger 3: After billing is inserted, update/create revenue report
DROP TRIGGER IF EXISTS trg_after_billing;
DELIMITER //
CREATE TRIGGER trg_after_billing
AFTER INSERT ON Billing
FOR EACH ROW
BEGIN
    DECLARE v_today DATE;
    SET v_today = CURDATE();

    IF EXISTS (SELECT 1 FROM Revenue_Report WHERE report_date = v_today) THEN
        UPDATE Revenue_Report
        SET total_revenue = total_revenue + NEW.amount,
            total_exits = total_exits + 1
        WHERE report_date = v_today;
    ELSE
        INSERT INTO Revenue_Report (report_date, total_entries, total_exits, total_revenue)
        VALUES (v_today, 0, 1, NEW.amount);
    END IF;
END;
//
DELIMITER ;

-- Trigger 4: Count entries in revenue report
DROP TRIGGER IF EXISTS trg_count_entry;
DELIMITER //
CREATE TRIGGER trg_count_entry
AFTER INSERT ON Entry_Exit_Log
FOR EACH ROW
BEGIN
    DECLARE v_today DATE;
    SET v_today = CURDATE();

    IF EXISTS (SELECT 1 FROM Revenue_Report WHERE report_date = v_today) THEN
        UPDATE Revenue_Report
        SET total_entries = total_entries + 1
        WHERE report_date = v_today;
    ELSE
        INSERT INTO Revenue_Report (report_date, total_entries, total_exits, total_revenue)
        VALUES (v_today, 1, 0, 0.00);
    END IF;
END;
//
DELIMITER ;

-- ═══════════════════════════════════════════════════════════
-- SEED DATA
-- ═══════════════════════════════════════════════════════════

-- Vehicle Types with pricing
INSERT INTO Vehicle_Type (type_name, hourly_rate, daily_max_rate, description) VALUES
('Two Wheeler',   20.00,  100.00, 'Bikes, scooters, mopeds'),
('Car / Sedan',   40.00,  250.00, 'Hatchbacks, sedans, SUVs'),
('SUV / MUV',     60.00,  400.00, 'Large SUVs and multi-utility vehicles'),
('Truck / Van',   80.00,  500.00, 'Commercial trucks and cargo vans'),
('Bus',          120.00,  800.00, 'Public/private buses');

-- Parking Slots (20 slots across 4 zones)
INSERT INTO Parking_Slot (slot_number, zone, floor_level, is_occupied, vehicle_type_allowed) VALUES
('A-01','A',1,FALSE,1), ('A-02','A',1,FALSE,1), ('A-03','A',1,FALSE,2), ('A-04','A',1,FALSE,2), ('A-05','A',1,FALSE,2),
('B-01','B',1,FALSE,2), ('B-02','B',1,FALSE,2), ('B-03','B',1,FALSE,3), ('B-04','B',1,FALSE,3), ('B-05','B',1,FALSE,3),
('C-01','C',2,FALSE,1), ('C-02','C',2,FALSE,1), ('C-03','C',2,FALSE,2), ('C-04','C',2,FALSE,2), ('C-05','C',2,FALSE,4),
('D-01','D',2,FALSE,4), ('D-02','D',2,FALSE,4), ('D-03','D',2,FALSE,5), ('D-04','D',2,FALSE,5), ('D-05','D',2,FALSE,3);

-- Registered Vehicles
INSERT INTO Vehicle (plate_number, type_id, owner_name, phone) VALUES
('TS09AB1234', 2, 'Rahul Sharma',   '9876543210'),
('AP31CD5678', 1, 'Priya Reddy',    '9123456780'),
('TS07EF9012', 3, 'Vikram Singh',   '9988776655'),
('KA05GH3456', 2, 'Anjali Gupta',   '9090909090'),
('MH12IJ7890', 4, 'Suresh Kumar',   '8877665544'),
('TS10KL2345', 1, 'Meena Devi',     '7766554433'),
('AP05MN6789', 2, 'Karthik Nair',   '6655443322'),
('TS08OP0123', 3, 'Deepika Joshi',  '5544332211');

-- Sample Entry/Exit Logs (some already exited, some still parked)
INSERT INTO Entry_Exit_Log (vehicle_id, slot_id, entry_time, exit_time, duration_minutes, fee, status) VALUES
(1, 3, '2025-04-28 08:00:00', '2025-04-28 11:30:00', 210, 160.00, 'Exited'),
(2, 1, '2025-04-28 09:15:00', '2025-04-28 10:45:00',  90,  40.00, 'Exited'),
(3, 8, '2025-04-28 07:30:00', '2025-04-28 14:00:00', 390, 400.00, 'Exited'),
(4, 6, '2025-04-28 10:00:00', '2025-04-28 13:00:00', 180, 120.00, 'Exited'),
(5, 15,'2025-04-28 06:00:00', '2025-04-28 18:00:00', 720, 500.00, 'Exited');

-- Mark some vehicles as currently parked
INSERT INTO Entry_Exit_Log (vehicle_id, slot_id, entry_time, status) VALUES
(6, 2,  NOW(), 'Parked'),
(7, 4,  NOW(), 'Parked'),
(8, 10, NOW(), 'Parked');

-- Update slots for currently parked vehicles
UPDATE Parking_Slot SET is_occupied = TRUE WHERE slot_id IN (2, 4, 10);

-- Billing for completed sessions
INSERT INTO Billing (log_id, amount, payment_method, payment_status) VALUES
(1, 160.00, 'UPI',  'Paid'),
(2,  40.00, 'Cash', 'Paid'),
(3, 400.00, 'Card', 'Paid'),
(4, 120.00, 'UPI',  'Paid'),
(5, 500.00, 'Cash', 'Paid');

-- Revenue Report seed
INSERT INTO Revenue_Report (report_date, total_entries, total_exits, total_revenue) VALUES
('2025-04-28', 8, 5, 1220.00),
('2025-04-27', 12, 12, 1850.00),
('2025-04-26', 15, 15, 2100.00);

-- Admin users
INSERT INTO Admin_User (username, password, full_name, role) VALUES
('admin', 'admin123', 'System Administrator', 'Admin'),
('operator1', 'op1234', 'Ravi Kumar', 'Operator');
