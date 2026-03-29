-- Med it Easy - Pharmacy Management System Database
-- Complete Database Schema

-- Create Database
CREATE DATABASE IF NOT EXISTS mediteasy;
USE mediteasy;

-- ============================================
-- USERS TABLE - For login/authentication
-- ============================================
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE,
    full_name VARCHAR(100),
    role ENUM('Admin', 'Cashier', 'Staff', 'Customer') DEFAULT 'Customer',
    phone VARCHAR(15),
    address TEXT,
    status ENUM('Active', 'Inactive') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_username (username),
    INDEX idx_role (role)
);

-- ============================================
-- STAFF TABLE - Staff members management
-- ============================================
CREATE TABLE IF NOT EXISTS staff (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    name VARCHAR(100) NOT NULL,
    position VARCHAR(100) NOT NULL,
    phone VARCHAR(15),
    email VARCHAR(100),
    hire_date DATE,
    status ENUM('Active', 'Day Off', 'On Leave') DEFAULT 'Active',
    salary DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- ============================================
-- CATEGORIES TABLE - Product categories
-- ============================================
CREATE TABLE IF NOT EXISTS categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    icon VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- PRODUCTS TABLE - Pharmacy products
-- ============================================
CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(150) NOT NULL,
    category_id INT,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    cost_price DECIMAL(10,2),
    stock_quantity INT DEFAULT 0,
    reorder_level INT DEFAULT 10,
    unit VARCHAR(20),
    manufacturer VARCHAR(100),
    expiry_date DATE,
    batch_number VARCHAR(50),
    status ENUM('In Stock', 'Low Stock', 'Out of Stock') DEFAULT 'In Stock',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
    INDEX idx_product_id (product_id),
    INDEX idx_name (name),
    INDEX idx_status (status)
);

-- ============================================
-- CUSTOMERS TABLE - Customer information
-- ============================================
CREATE TABLE IF NOT EXISTS customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(15),
    address TEXT,
    city VARCHAR(50),
    postal_code VARCHAR(10),
    date_of_birth DATE,
    gender ENUM('Male', 'Female', 'Other'),
    loyalty_points INT DEFAULT 0,
    total_purchases DECIMAL(12,2) DEFAULT 0,
    status ENUM('Active', 'Inactive') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_phone (phone),
    INDEX idx_email (email)
);

-- ============================================
-- SUPPLIERS TABLE - Supplier information
-- ============================================
CREATE TABLE IF NOT EXISTS suppliers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    contact_person VARCHAR(100),
    phone VARCHAR(15),
    email VARCHAR(100),
    address TEXT,
    city VARCHAR(50),
    bank_details TEXT,
    payment_terms VARCHAR(100),
    status ENUM('Active', 'Inactive') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- PURCHASES TABLE - Purchase orders from suppliers
-- ============================================
CREATE TABLE IF NOT EXISTS purchases (
    id INT AUTO_INCREMENT PRIMARY KEY,
    purchase_id VARCHAR(50) UNIQUE NOT NULL,
    supplier_id INT,
    supplier VARCHAR(100),
    purchase_date DATE NOT NULL,
    expected_delivery DATE,
    total_amount DECIMAL(12,2),
    paid DECIMAL(12,2),
    residual DECIMAL(12,2),
    payment_status ENUM('Pending', 'Partial', 'Paid') DEFAULT 'Pending',
    status ENUM('Pending', 'Received', 'Completed', 'Cancelled') DEFAULT 'Pending',
    note TEXT,
    created_by INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_purchase_id (purchase_id),
    INDEX idx_status (status)
);

-- ============================================
-- PURCHASE ITEMS TABLE - Items in each purchase
-- ============================================
CREATE TABLE IF NOT EXISTS purchase_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    purchase_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_cost DECIMAL(10,2) NOT NULL,
    total_cost DECIMAL(12,2),
    FOREIGN KEY (purchase_id) REFERENCES purchases(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
);

-- ============================================
-- ORDERS TABLE - Customer orders (online & in-store)
-- ============================================
CREATE TABLE IF NOT EXISTS orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id VARCHAR(50) UNIQUE NOT NULL,
    customer_id INT,
    customer_name VARCHAR(100),
    customer_phone VARCHAR(15),
    customer_email VARCHAR(100),
    order_date DATETIME NOT NULL,
    delivery_date DATE,
    order_type ENUM('Online', 'In-Store') DEFAULT 'Online',
    total_amount DECIMAL(12,2),
    discount DECIMAL(10,2) DEFAULT 0,
    tax DECIMAL(10,2) DEFAULT 0,
    final_amount DECIMAL(12,2),
    status ENUM('New', 'Processing', 'Shipped', 'Delivered', 'Cancelled') DEFAULT 'New',
    shipping_address TEXT,
    payment_method VARCHAR(50),
    notes TEXT,
    created_by INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_order_id (order_id),
    INDEX idx_status (status),
    INDEX idx_order_date (order_date)
);

-- ============================================
-- ORDER ITEMS TABLE - Items in each order
-- ============================================
CREATE TABLE IF NOT EXISTS order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    product_name VARCHAR(150),
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(12,2),
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
);

-- ============================================
-- PAYMENTS TABLE - Payment records
-- ============================================
CREATE TABLE IF NOT EXISTS payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    payment_id VARCHAR(50) UNIQUE NOT NULL,
    order_id INT,
    purchase_id INT,
    customer_id INT,
    amount DECIMAL(12,2) NOT NULL,
    payment_method ENUM('Cash', 'Card', 'UPI', 'Bank Transfer', 'Cheque') DEFAULT 'Cash',
    transaction_id VARCHAR(100),
    payment_date DATETIME NOT NULL,
    status ENUM('Pending', 'Completed', 'Failed', 'Refunded') DEFAULT 'Pending',
    reference_number VARCHAR(100),
    notes TEXT,
    created_by INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
    FOREIGN KEY (purchase_id) REFERENCES purchases(id) ON DELETE SET NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_payment_id (payment_id),
    INDEX idx_status (status)
);

-- ============================================
-- STOCK TABLE - Stock management
-- ============================================
CREATE TABLE IF NOT EXISTS stock (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL UNIQUE,
    quantity_on_hand INT DEFAULT 0,
    quantity_reserved INT DEFAULT 0,
    quantity_available INT DEFAULT 0,
    last_counted DATE,
    reorder_quantity INT DEFAULT 50,
    reorder_level INT DEFAULT 10,
    warehouse_location VARCHAR(50),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- ============================================
-- STOCK MOVEMENTS TABLE - Track stock changes
-- ============================================
CREATE TABLE IF NOT EXISTS stock_movements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    movement_type ENUM('In', 'Out', 'Adjustment', 'Count') DEFAULT 'Out',
    quantity INT NOT NULL,
    reference_type ENUM('Purchase', 'Order', 'Manual') DEFAULT 'Manual',
    reference_id VARCHAR(50),
    notes TEXT,
    created_by INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_product_id (product_id),
    INDEX idx_created_at (created_at)
);

-- ============================================
-- ACTIVITY LOGS TABLE - System activity tracking
-- ============================================
CREATE TABLE IF NOT EXISTS activity_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action VARCHAR(100),
    module VARCHAR(50),
    reference_id VARCHAR(50),
    old_value TEXT,
    new_value TEXT,
    ip_address VARCHAR(45),
    status ENUM('Success', 'Failure') DEFAULT 'Success',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at),
    INDEX idx_module (module)
);

-- ============================================
-- SERVICES TABLE - Health services offered
-- ============================================
CREATE TABLE IF NOT EXISTS services (
    id INT AUTO_INCREMENT PRIMARY KEY,
    service_id VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category ENUM('Health & Fitness', 'Home Care', 'Online Pharmacy', 'Pet Care', 'Personal Care', 'Mother & Baby', 'Self Care', 'Ortho & Support') DEFAULT 'Online Pharmacy',
    price DECIMAL(10,2),
    duration_minutes INT,
    status ENUM('Active', 'Inactive') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- SERVICE BOOKINGS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS service_bookings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id VARCHAR(50) UNIQUE NOT NULL,
    service_id INT NOT NULL,
    customer_id INT,
    booking_date DATE NOT NULL,
    booking_time TIME NOT NULL,
    staff_assigned INT,
    status ENUM('Pending', 'Confirmed', 'Completed', 'Cancelled') DEFAULT 'Pending',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL,
    FOREIGN KEY (staff_assigned) REFERENCES staff(id) ON DELETE SET NULL,
    INDEX idx_booking_date (booking_date)
);

-- ============================================
-- QR CODES TABLE - QR codes for products
-- ============================================
CREATE TABLE IF NOT EXISTS qr_codes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    qr_code_data VARCHAR(255) UNIQUE NOT NULL,
    qr_code_image LONGBLOB,
    scans_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- ============================================
-- INSERT DEFAULT CATEGORIES
-- ============================================
INSERT INTO categories (name, description, icon) VALUES
('Health & Fitness', 'Health and fitness products', '💪'),
('Home Care', 'Home care and cleaning products', '🏠'),
('Online Pharmacy', 'Pharmaceutical products', '💊'),
('Pet Care', 'Pet health and care products', '🐾'),
('Personal Care', 'Personal hygiene products', '🧴'),
('Mother & Baby', 'Mother and baby care products', '👶'),
('Self Care', 'Self-care and wellness', '🧘'),
('Ortho & Support', 'Orthopedic support products', '🦴');

-- ============================================
-- INSERT DEFAULT ROLES/SAMPLE USERS
-- ============================================
INSERT INTO users (username, password, email, full_name, role, phone, status) VALUES
('admin', 'admin123', 'admin@mediteasy.com', 'Admin User', 'Admin', '9876543210', 'Active'),
('cashier1', 'cashier123', 'cashier@mediteasy.com', 'Cashier One', 'Cashier', '9876543211', 'Active'),
('staff1', 'staff123', 'staff@mediteasy.com', 'Staff Member', 'Staff', '9876543212', 'Active'),
('customer1', 'customer123', 'customer@mediteasy.com', 'Sample Customer', 'Customer', '9876543213', 'Active');

-- ============================================
-- INSERT DEFAULT SUPPLIERS
-- ============================================
INSERT INTO suppliers (name, contact_person, phone, email, city, status) VALUES
('Pharma Plus Distribution', 'John Smith', '9999000001', 'contact@pharmaplus.com', 'Delhi', 'Active'),
('Global Pharma Supply', 'Sarah Johnson', '9999000002', 'info@globalpharm.com', 'Mumbai', 'Active'),
('Medicine House', 'Raj Kumar', '9999000003', 'sales@medicinehouse.com', 'Bangalore', 'Active');

-- ============================================
-- INSERT SAMPLE PRODUCTS
-- ============================================
INSERT INTO products (product_id, name, category_id, price, cost_price, stock_quantity, manufacturer, status) VALUES
('PROD-001', 'Aspirin 500mg', 3, 45.00, 25.00, 100, 'Bayer Healthcare', 'In Stock'),
('PROD-002', 'Vitamin C 1000mg', 1, 150.00, 80.00, 50, 'Healthkart', 'In Stock'),
('PROD-003', 'Hand Sanitizer 500ml', 5, 80.00, 40.00, 75, 'Dettol', 'In Stock'),
('PROD-004', 'Dog Shampoo 200ml', 4, 120.00, 60.00, 30, 'Pawsitively Happy', 'In Stock'),
('PROD-005', 'Baby Wipes 100 pcs', 6, 200.00, 100.00, 40, 'Johnson & Johnson', 'Low Stock'),
('PROD-006', 'Knee Support Belt', 8, 350.00, 180.00, 20, 'Elastic Gear', 'In Stock'),
('PROD-007', 'Yoga Mat Premium', 1, 999.00, 500.00, 15, 'FitLife', 'In Stock'),
('PROD-008', 'Face Wash 100ml', 5, 180.00, 90.00, 60, 'Cetaphil', 'In Stock');

-- ============================================
-- INSERT SAMPLE SERVICES
-- ============================================
INSERT INTO services (service_id, name, category, price, duration_minutes, status) VALUES
('SVC-001', 'Gym Membership', 'Health & Fitness', 500.00, 0, 'Active'),
('SVC-002', 'Home Cleaning', 'Home Care', 800.00, 180, 'Active'),
('SVC-003', 'Online Consultation', 'Online Pharmacy', 300.00, 30, 'Active'),
('SVC-004', 'Pet Grooming', 'Pet Care', 600.00, 120, 'Active'),
('SVC-005', 'Massage Session', 'Self Care', 1000.00, 60, 'Active');

-- ============================================
-- CREATE INDEXES FOR PERFORMANCE
-- ============================================
-- Already created with table definitions

-- ============================================
-- DATABASE COMPLETE
-- ============================================
-- All tables created successfully!
