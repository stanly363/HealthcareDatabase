
-- Drop connections to avoid conflicts
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'healthcare_db';

-- Drop the database if it exists
DROP DATABASE IF EXISTS healthcare_db;

-- 0. Create Database
CREATE DATABASE healthcare_db;

-- Connect to the database before proceeding
\c healthcare_db;

-- 1. Create Roles

-- Adjust LOGIN / NOLOGIN according to your authentication strategy

CREATE ROLE healthcare_admin WITH LOGIN PASSWORD 'admin';
CREATE ROLE healthcare_staff WITH LOGIN PASSWORD 'doctor';
CREATE ROLE healthcare_user WITH LOGIN PASSWORD 'user';


-- 2. Create Schema


CREATE SCHEMA healthcare
  AUTHORIZATION healthcare_admin;

-- make sure no default privileges exist for public on this schema
REVOKE ALL ON SCHEMA healthcare FROM PUBLIC;

-- set search paths
ALTER ROLE healthcare_admin SET search_path TO healthcare;
ALTER ROLE healthcare_staff SET search_path TO healthcare;
ALTER ROLE healthcare_user SET search_path TO healthcare;
ALTER ROLE postgres SET search_path TO healthcare;


-- 3. Create Tables


-- Staff and roles tables
CREATE TABLE healthcare.staff (
  staff_id       SERIAL PRIMARY KEY,
  first_name     VARCHAR(50) NOT NULL,
  last_name      VARCHAR(50) NOT NULL,
  email          VARCHAR(100) NOT NULL UNIQUE,
  phone_number   VARCHAR(20)
);

CREATE TABLE healthcare.user_roles (
  role_id   SERIAL PRIMARY KEY,
  role_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE healthcare.staff_roles (
  staff_id INT NOT NULL,
  role_id  INT NOT NULL,
  PRIMARY KEY (staff_id, role_id),
  FOREIGN KEY (staff_id) REFERENCES healthcare.staff(staff_id),
  FOREIGN KEY (role_id)  REFERENCES healthcare.user_roles(role_id)
);

-- Patients and related tables
CREATE TABLE healthcare.patients (
  patient_id    SERIAL PRIMARY KEY,
  first_name    VARCHAR(50) NOT NULL,
  last_name     VARCHAR(50) NOT NULL,
  date_of_birth DATE NOT NULL,
  email         VARCHAR(100) UNIQUE,
  phone_number  VARCHAR(20),
  address       VARCHAR(200)
);

CREATE TABLE healthcare.doctors (
  doctor_id   SERIAL PRIMARY KEY,
  staff_id    INT NOT NULL UNIQUE,
  speciality  VARCHAR(100),
  FOREIGN KEY (staff_id) REFERENCES healthcare.staff(staff_id)
);

CREATE TABLE healthcare.medical_records (
  record_id   SERIAL PRIMARY KEY,
  patient_id  INT NOT NULL,
  doctor_id   INT NOT NULL,
  diagnosis   VARCHAR(255),
  treatment   VARCHAR(255),
  record_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES healthcare.patients(patient_id),
  FOREIGN KEY (doctor_id)  REFERENCES healthcare.doctors(doctor_id)
);

CREATE TABLE healthcare.appointments (
  appointment_id   SERIAL PRIMARY KEY,
  patient_id       INT NOT NULL,
  doctor_id        INT NOT NULL,
  appointment_time TIMESTAMP NOT NULL,
  status           VARCHAR(50) DEFAULT 'Scheduled',
  FOREIGN KEY (patient_id) REFERENCES healthcare.patients(patient_id),
  FOREIGN KEY (doctor_id)  REFERENCES healthcare.doctors(doctor_id)
);

CREATE TABLE healthcare.billing (
  billing_id     SERIAL PRIMARY KEY,
  appointment_id INT NOT NULL,
  amount         DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  billing_date   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (appointment_id) REFERENCES healthcare.appointments(appointment_id)
);

CREATE TABLE healthcare.insurance_details (
  insurance_id   SERIAL PRIMARY KEY,
  patient_id     INT NOT NULL,
  provider_name  VARCHAR(100),
  policy_number  VARCHAR(50),
  FOREIGN KEY (patient_id) REFERENCES healthcare.patients(patient_id)
);

-- Telehealth integration tables
CREATE TABLE healthcare.telehealth_sessions (
  session_id        SERIAL PRIMARY KEY,
  appointment_id    INT NOT NULL,
  session_url       VARCHAR(500) NOT NULL,
  session_start     TIMESTAMP NOT NULL,
  session_end       TIMESTAMP,
  status            VARCHAR(50) DEFAULT 'Scheduled',
  FOREIGN KEY (appointment_id) REFERENCES healthcare.appointments(appointment_id)
);

CREATE TABLE healthcare.remote_monitoring_devices (
  device_id       SERIAL PRIMARY KEY,
  patient_id      INT NOT NULL,
  device_type     VARCHAR(100) NOT NULL,
  device_serial   VARCHAR(100) UNIQUE NOT NULL,
  activation_date TIMESTAMP NOT NULL,
  status          VARCHAR(50) DEFAULT 'Active',
  FOREIGN KEY (patient_id) REFERENCES healthcare.patients(patient_id)
);

CREATE TABLE healthcare.device_readings (
  reading_id    SERIAL PRIMARY KEY,
  device_id     INT NOT NULL,
  reading_type  VARCHAR(50) NOT NULL,
  reading_value VARCHAR(100) NOT NULL,
  reading_date  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (device_id) REFERENCES healthcare.remote_monitoring_devices(device_id)
);


-- 4. Create Functions / Procedures


CREATE OR REPLACE FUNCTION healthcare.book_appointment(
    p_patient_id INT,
    p_doctor_id INT,
    p_appointment_time TIMESTAMP
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if the doctor is already booked at the specified time
    IF EXISTS (
        SELECT 1
        FROM healthcare.appointments
        WHERE doctor_id = p_doctor_id
          AND appointment_time = p_appointment_time
    ) THEN
        RAISE EXCEPTION 'The selected doctor is unavailable at the specified time.';
    END IF;

    -- Insert the appointment if the time slot is available
    INSERT INTO healthcare.appointments (patient_id, doctor_id, appointment_time)
    VALUES (p_patient_id, p_doctor_id, p_appointment_time);

    RAISE NOTICE 'Appointment booked for patient % with doctor % on %',
                 p_patient_id, p_doctor_id, p_appointment_time;
END;
$$;

CREATE OR REPLACE FUNCTION healthcare.add_medical_record(
  p_patient_id INT,
  p_doctor_id INT,
  p_diagnosis VARCHAR,
  p_treatment VARCHAR
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO healthcare.medical_records (patient_id, doctor_id, diagnosis, treatment)
  VALUES (p_patient_id, p_doctor_id, p_diagnosis, p_treatment);

  RAISE NOTICE 'Medical record added for patient % by doctor %',
               p_patient_id, p_doctor_id;
END;
$$;


CREATE OR REPLACE FUNCTION healthcare.add_device_reading(
  p_device_id INT,
  p_reading_type VARCHAR,
  p_reading_value VARCHAR
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Ensure the device exists
  IF NOT EXISTS (
      SELECT 1 FROM healthcare.remote_monitoring_devices WHERE device_id = p_device_id
  ) THEN
      RAISE EXCEPTION 'Device ID % does not exist.', p_device_id;
  END IF;

  INSERT INTO healthcare.device_readings (device_id, reading_type, reading_value)
  VALUES (p_device_id, p_reading_type, p_reading_value);

  RAISE NOTICE 'Reading added for device %: % = %', p_device_id, p_reading_type, p_reading_value;
END;
$$;

CREATE OR REPLACE FUNCTION healthcare.generate_billing(
    p_appointment_id INT,
    p_amount DECIMAL(10, 2)
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    -- Ensure the appointment exists
    IF NOT EXISTS (
        SELECT 1 FROM healthcare.appointments WHERE appointment_id = p_appointment_id
    ) THEN
        RAISE EXCEPTION 'Appointment ID % does not exist.', p_appointment_id;
    END IF;

    -- Insert billing record
    INSERT INTO healthcare.billing (appointment_id, amount, billing_date)
    VALUES (p_appointment_id, p_amount, CURRENT_TIMESTAMP);

    RAISE NOTICE 'Billing record created for appointment % with amount %.',
                 p_appointment_id, p_amount;
END;
$$;

CREATE OR REPLACE FUNCTION healthcare.register_patient(
  p_first_name VARCHAR,
  p_last_name VARCHAR,
  p_date_of_birth DATE,
  p_email VARCHAR,
  p_phone_number VARCHAR,
  p_address VARCHAR
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO healthcare.patients (first_name, last_name, date_of_birth, email, phone_number, address)
  VALUES (p_first_name, p_last_name, p_date_of_birth, p_email, p_phone_number, p_address);

  RAISE NOTICE 'Patient % % registered successfully.', p_first_name, p_last_name;
END;
$$;

CREATE OR REPLACE FUNCTION healthcare.schedule_telehealth_session(
  p_appointment_id INT,
  p_session_start TIMESTAMP,
  p_session_end TIMESTAMP
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO healthcare.telehealth_sessions (appointment_id, session_url, session_start, session_end)
  VALUES (p_appointment_id, 'https://telehealth.example.com/session/' || gen_random_uuid(), p_session_start, p_session_end);

  RAISE NOTICE 'Telehealth session scheduled for appointment %', p_appointment_id;
END;
$$;


-- 5. Create Views


CREATE OR REPLACE VIEW healthcare.vw_patient_appointments AS
SELECT p.patient_id,
       p.first_name || ' ' || p.last_name AS patient_name,
       a.appointment_id,
       a.appointment_time,
       a.status
FROM healthcare.patients p
LEFT JOIN healthcare.appointments a ON p.patient_id = a.patient_id
ORDER BY a.appointment_time DESC;

CREATE OR REPLACE VIEW healthcare.vw_staff_roles AS
SELECT s.staff_id,
       s.first_name || ' ' || s.last_name AS staff_name,
       r.role_name
FROM healthcare.staff s
JOIN healthcare.staff_roles sr ON s.staff_id = sr.staff_id
JOIN healthcare.user_roles r ON sr.role_id = r.role_id
ORDER BY s.staff_id;

CREATE OR REPLACE VIEW healthcare.vw_billing_details AS
SELECT b.billing_id,
       p.first_name || ' ' || p.last_name AS patient_name,
       a.appointment_time,
       b.amount,
       b.billing_date
FROM healthcare.billing b
JOIN healthcare.appointments a ON b.appointment_id = a.appointment_id
JOIN healthcare.patients p ON a.patient_id = p.patient_id
ORDER BY b.billing_date DESC;

CREATE OR REPLACE VIEW healthcare.vw_telehealth_sessions AS
SELECT ts.session_id,
       p.first_name || ' ' || p.last_name AS patient_name,
       a.appointment_time,
       ts.session_url,
       ts.session_start,
       ts.session_end,
       ts.status
FROM healthcare.telehealth_sessions ts
JOIN healthcare.appointments a ON ts.appointment_id = a.appointment_id
JOIN healthcare.patients p ON a.patient_id = p.patient_id
ORDER BY ts.session_start DESC;

CREATE OR REPLACE VIEW healthcare.vw_remote_devices AS
SELECT d.device_id,
       p.first_name || ' ' || p.last_name AS patient_name,
       d.device_type,
       d.device_serial,
       d.activation_date,
       d.status
FROM healthcare.remote_monitoring_devices d
JOIN healthcare.patients p ON d.patient_id = p.patient_id
ORDER BY d.activation_date DESC;

CREATE OR REPLACE VIEW healthcare.vw_device_readings AS
SELECT r.reading_id,
       p.first_name || ' ' || p.last_name AS patient_name,
       d.device_type,
       r.reading_type,
       r.reading_value,
       r.reading_date
FROM healthcare.device_readings r
JOIN healthcare.remote_monitoring_devices d ON r.device_id = d.device_id
JOIN healthcare.patients p ON d.patient_id = p.patient_id
ORDER BY r.reading_date DESC;


-- 6. Set Permissions / Grants


-- Revoke everything from PUBLIC
REVOKE ALL ON SCHEMA healthcare FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA healthcare FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA healthcare FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA healthcare FROM PUBLIC;

-- Give the schema owner (healthcare_admin) full privileges
GRANT ALL ON SCHEMA healthcare TO healthcare_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA healthcare TO healthcare_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA healthcare TO healthcare_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA healthcare TO healthcare_admin;



-- Permissions for Staff
GRANT USAGE ON SCHEMA healthcare TO healthcare_staff;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA healthcare TO healthcare_staff;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA healthcare TO healthcare_staff;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA healthcare TO healthcare_staff;
-- revoke modification privileges on role-related tables
REVOKE INSERT, UPDATE, DELETE ON healthcare.user_roles FROM healthcare_staff;
REVOKE INSERT, UPDATE, DELETE ON healthcare.staff_roles FROM healthcare_staff;

-- Ensure staff can still read roles
GRANT SELECT ON healthcare.user_roles TO healthcare_staff;
GRANT SELECT ON healthcare.staff_roles TO healthcare_staff;


-- Grant schema usage
GRANT USAGE ON SCHEMA healthcare TO healthcare_user;

-- Grant read-only access on underlying tables (so that views work)
GRANT SELECT ON healthcare.patients TO healthcare_user;
GRANT SELECT ON healthcare.medical_records TO healthcare_user;
GRANT SELECT ON healthcare.billing TO healthcare_user;
GRANT SELECT ON healthcare.remote_monitoring_devices TO healthcare_user;
GRANT SELECT ON healthcare.device_readings TO healthcare_user;

-- Grant SELECT on views that healthcare_user should use (except vw_staff_roles)
GRANT SELECT ON healthcare.vw_patient_appointments TO healthcare_user;
GRANT SELECT ON healthcare.vw_billing_details TO healthcare_user;
GRANT SELECT ON healthcare.vw_telehealth_sessions TO healthcare_user;
GRANT SELECT ON healthcare.vw_remote_devices TO healthcare_user;
GRANT SELECT ON healthcare.vw_device_readings TO healthcare_user;
-- Note: Do not grant SELECT on vw_staff_roles

-- Grant DML on permitted tables
GRANT SELECT, INSERT, UPDATE, DELETE ON healthcare.appointments TO healthcare_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON healthcare.insurance_details TO healthcare_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON healthcare.telehealth_sessions TO healthcare_user;

-- Grant EXECUTE on allowed functions
GRANT EXECUTE ON FUNCTION healthcare.book_appointment(int, int, timestamp) TO healthcare_user;
GRANT EXECUTE ON FUNCTION healthcare.add_device_reading(int, varchar, varchar) TO healthcare_user;
GRANT EXECUTE ON FUNCTION healthcare.register_patient(varchar, varchar, date, varchar, varchar, varchar) TO healthcare_user;
GRANT EXECUTE ON FUNCTION healthcare.schedule_telehealth_session(int, timestamp, timestamp) TO healthcare_user;


-- 7. Final Notice (optional)

RAISE NOTICE 'Healthcare database setup completed successfully.';

