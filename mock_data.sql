-- Clear old data FIRST (using TRUNCATE) to avoid duplicate unique key issues
TRUNCATE TABLE customers CASCADE;
TRUNCATE TABLE suppliers CASCADE;
TRUNCATE TABLE rooms CASCADE;
TRUNCATE TABLE orders CASCADE;
TRUNCATE TABLE order_items CASCADE;
TRUNCATE TABLE payments CASCADE;

-- 1. Create Rooms
INSERT INTO rooms (id, name, created_by, updated_by)
VALUES
  (gen_random_uuid(), 'Living Room', 'baqaa', 'baqaa'),
  (gen_random_uuid(), 'Kitchen', 'baqaa', 'baqaa'),
  (gen_random_uuid(), 'Bedroom', 'baqaa', 'baqaa'),
  (gen_random_uuid(), 'Bathroom', 'baqaa', 'baqaa'),
  (gen_random_uuid(), 'Garden', 'baqaa', 'baqaa');

-- 2. Create Customers
INSERT INTO customers (id, card_name, customer_name, phones, location, notes, created_by, updated_by)
VALUES 
  (gen_random_uuid(), 'Ahmed Levi', 'Ahmed Levi', '{"0501234567"}', 'Tel Aviv, Dizengoff 12', 'VIP Customer', 'baqaa', 'baqaa'),
  (gen_random_uuid(), 'Sarah Cohen', 'Sarah Cohen', '{"0529876543", "0541112222"}', 'Haifa, Horev 5', 'Requires evening delivery', 'baqaa', 'baqaa'),
  (gen_random_uuid(), 'Tariq Mansour', 'Tariq Mansour', '{"0543334444"}', 'Jerusalem, Jaffa 100', null, 'baqaa', 'baqaa'),
  (gen_random_uuid(), 'Yael Katz', 'Yael Katz', '{"0535556666"}', 'Rishon LeZion, Herzl 1', 'Always pays in cash', 'baqaa', 'baqaa');

-- 3. Create Suppliers
INSERT INTO suppliers (id, company_name, contact_name, phone, notes, created_by, updated_by)
VALUES
  (gen_random_uuid(), 'Mega Lights LTD', 'Yossi', '03-555-1234', 'Fast delivery', 'baqaa', 'baqaa'),
  (gen_random_uuid(), 'Lumina Imports', 'Rami', '09-123-4567', 'Good prices on LED strips', 'baqaa', 'baqaa');

-- 4. Create Orders
INSERT INTO orders (id, customer_id, assembly_required, assembly_date, status, total_price, notes, created_by, updated_by)
VALUES
  (gen_random_uuid(), (SELECT id FROM customers WHERE card_name = 'Ahmed Levi'), false, null, 'Active', 5000, 'Double check kitchen dimensions', 'baqaa', 'baqaa'),
  (gen_random_uuid(), (SELECT id FROM customers WHERE card_name = 'Sarah Cohen'), true, CURRENT_DATE + interval '7 days', 'In Assembly', 3500, 'Assembly scheduled for next week', 'baqaa', 'baqaa'),
  (gen_random_uuid(), (SELECT id FROM customers WHERE card_name = 'Tariq Mansour'), false, null, 'Active', 12000, 'Large villa project', 'baqaa', 'baqaa'),
  (gen_random_uuid(), (SELECT id FROM customers WHERE card_name = 'Yael Katz'), false, null, 'Delivered', 1500, 'Completed', 'baqaa', 'baqaa');

-- 5. Create Order Items
INSERT INTO order_items (id, order_id, item_number, name, quantity, price, room_id, supplier_id, created_by, updated_by)
VALUES
  -- Intercept order 1 (Ahmed)
  (gen_random_uuid(), (SELECT id FROM orders WHERE notes = 'Double check kitchen dimensions'), 'L-101', 'Crystal Chandelier', 1, 3000, (SELECT id FROM rooms WHERE name = 'Living Room'), (SELECT id FROM suppliers WHERE company_name = 'Mega Lights LTD'), 'baqaa', 'baqaa'),
  (gen_random_uuid(), (SELECT id FROM orders WHERE notes = 'Double check kitchen dimensions'), 'S-50', 'LED Spots 10W', 20, 100, (SELECT id FROM rooms WHERE name = 'Kitchen'), (SELECT id FROM suppliers WHERE company_name = 'Lumina Imports'), 'baqaa', 'baqaa'),
  
  -- Order 2 (Sarah)
  (gen_random_uuid(), (SELECT id FROM orders WHERE notes = 'Assembly scheduled for next week'), 'W-22', 'Modern Wall Lamp', 4, 350, (SELECT id FROM rooms WHERE name = 'Bedroom'), (SELECT id FROM suppliers WHERE company_name = 'Mega Lights LTD'), 'baqaa', 'baqaa'),
  (gen_random_uuid(), (SELECT id FROM orders WHERE notes = 'Assembly scheduled for next week'), 'P-05', 'Glass Pendant', 2, 1050, null, (SELECT id FROM suppliers WHERE company_name = 'Lumina Imports'), 'baqaa', 'baqaa'),
  
  -- Order 3 (Tariq)
  (gen_random_uuid(), (SELECT id FROM orders WHERE notes = 'Large villa project'), 'O-99', 'Outdoor Floodlight', 10, 250, (SELECT id FROM rooms WHERE name = 'Garden'), (SELECT id FROM suppliers WHERE company_name = 'Mega Lights LTD'), 'baqaa', 'baqaa');

-- 6. Create Payments
INSERT INTO payments (id, order_id, customer_id, card_name, customer_name, amount, type, created_by, updated_by, notes)
VALUES
  (gen_random_uuid(), (SELECT id FROM orders WHERE notes = 'Double check kitchen dimensions'), (SELECT id FROM customers WHERE card_name = 'Ahmed Levi'), 'Ahmed Levi', 'Ahmed Levi', 2000, 'Credit', 'baqaa', 'baqaa', 'Initial deposit'),
  (gen_random_uuid(), (SELECT id FROM orders WHERE notes = 'Assembly scheduled for next week'), (SELECT id FROM customers WHERE card_name = 'Sarah Cohen'), 'Sarah Cohen', 'Sarah Cohen', 1500, 'Check', 'baqaa', 'baqaa', 'First installment'),
  (gen_random_uuid(), (SELECT id FROM orders WHERE notes = 'Assembly scheduled for next week'), (SELECT id FROM customers WHERE card_name = 'Sarah Cohen'), 'Sarah Cohen', 'Sarah Cohen', 2000, 'Cash', 'baqaa', 'baqaa', 'Final payment upon assembly');
