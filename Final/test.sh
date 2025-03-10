
# Database connection settings
DB_NAME="healthcare_db"
DB_USER="postgres"
LOGFILE="test_results.log"

echo "Starting Healthcare Database Setup and Testing..."
> "$LOGFILE"

# Function to run a block of SQL commands in a single session
run_sql_block() {
    local role="$1"
    local sql_block="$2"
    echo "Running tests as role: $role" | tee -a "$LOGFILE"
    PGPASSWORD="postgres" psql -U "$DB_USER" -d "$DB_NAME" <<EOF 2>&1 | tee -a "$LOGFILE"
SET ROLE $role;
$sql_block
RESET ROLE;
EOF
}

echo "Creating test data..." | tee -a "$LOGFILE"
PGPASSWORD="postgres" psql -U "$DB_USER" -d "$DB_NAME" <<EOF 2>&1 | tee -a "$LOGFILE"
-- Create test staff members
INSERT INTO healthcare.staff (first_name, last_name, email, phone_number) VALUES 
    ('Alice', 'Smith', 'alice@hospital.com', '1234567890'),
    ('Bob', 'Jones', 'bob@hospital.com', '0987654321');

-- Assign staff roles
INSERT INTO healthcare.user_roles (role_name) VALUES 
    ('Doctor'),
    ('Nurse');

INSERT INTO healthcare.staff_roles (staff_id, role_id) VALUES 
    (1, 1),
    (2, 2);

-- Create test patients
INSERT INTO healthcare.patients (first_name, last_name, date_of_birth, email, phone_number, address) VALUES 
    ('John', 'Doe', '1990-05-15', 'john.doe@example.com', '1112223333', '123 Main St'),
    ('Jane', 'Roe', '1985-08-20', 'jane.roe@example.com', '4445556666', '456 Elm St');

-- Create test doctor
INSERT INTO healthcare.doctors (staff_id, speciality) VALUES 
    (1, 'Cardiology');

-- Create test appointments
INSERT INTO healthcare.appointments (patient_id, doctor_id, appointment_time, status) VALUES 
    (1, 1, '2025-02-01 10:00:00', 'Scheduled'),
    (2, 1, '2025-02-02 14:00:00', 'Scheduled');

-- Create test medical records
INSERT INTO healthcare.medical_records (patient_id, doctor_id, diagnosis, treatment) VALUES 
    (1, 1, 'Hypertension', 'Medication prescribed'),
    (2, 1, 'Asthma', 'Inhaler prescribed');

-- Create test billing records
INSERT INTO healthcare.billing (appointment_id, amount) VALUES 
    (1, 200.00),
    (2, 150.00);

-- Create test insurance details
INSERT INTO healthcare.insurance_details (patient_id, provider_name, policy_number) VALUES 
    (1, 'HealthSecure', 'POL12345'),
    (2, 'MediCare', 'POL67890');

-- Create test telehealth session
INSERT INTO healthcare.telehealth_sessions (appointment_id, session_url, session_start, status) VALUES 
    (1, 'https://telehealth.example.com/session/abcd1234', '2025-02-01 10:00:00', 'Scheduled');

-- Create test remote monitoring device for patient 1
INSERT INTO healthcare.remote_monitoring_devices (patient_id, device_type, device_serial, activation_date, status)
VALUES (1, 'Heart Monitor', 'DEVICE001', CURRENT_TIMESTAMP, 'Active');
EOF

echo "Test data inserted successfully." | tee -a "$LOGFILE"


# Testing as healthcare_admin

sql_admin="
-- Testing Views
SELECT * FROM healthcare.vw_patient_appointments LIMIT 5;
SELECT * FROM healthcare.vw_staff_roles LIMIT 5;
SELECT * FROM healthcare.vw_billing_details LIMIT 5;
SELECT * FROM healthcare.vw_telehealth_sessions LIMIT 5;
SELECT * FROM healthcare.vw_remote_devices LIMIT 5;
SELECT * FROM healthcare.vw_device_readings LIMIT 5;

-- Testing Functions (all functions)
SELECT healthcare.book_appointment(1, 1, '2025-02-10 09:00:00');
SELECT healthcare.add_medical_record(2, 1, 'Diabetes', 'Diet control');
SELECT healthcare.generate_billing(1, 250.00);
SELECT healthcare.schedule_telehealth_session(1, '2025-02-05 15:00:00', '2025-02-05 16:00:00');
SELECT healthcare.add_device_reading(1, 'Heart Rate', '75 bpm');
SELECT healthcare.register_patient('Mark', 'Johnson', '2000-10-15', 'mark.admin@example.com', '5558887777', '789 Pine St');
"
run_sql_block "healthcare_admin" "$sql_admin"

# Testing as healthcare_staff

sql_staff="
-- Testing Views
SELECT * FROM healthcare.vw_patient_appointments LIMIT 5;
SELECT * FROM healthcare.vw_staff_roles LIMIT 5;
SELECT * FROM healthcare.vw_billing_details LIMIT 5;
SELECT * FROM healthcare.vw_telehealth_sessions LIMIT 5;
SELECT * FROM healthcare.vw_remote_devices LIMIT 5;
SELECT * FROM healthcare.vw_device_readings LIMIT 5;

-- Testing Functions (all functions)
SELECT healthcare.book_appointment(1, 1, '2025-02-10 10:00:00');
SELECT healthcare.add_medical_record(2, 1, 'Diabetes', 'Diet control');
SELECT healthcare.generate_billing(1, 260.00);
SELECT healthcare.schedule_telehealth_session(1, '2025-02-05 17:00:00', '2025-02-05 18:00:00');
SELECT healthcare.add_device_reading(1, 'Heart Rate', '80 bpm');
SELECT healthcare.register_patient('Mark', 'Johnson', '2000-10-15', 'mark.staff@example.com', '5558887777', '789 Pine St');
"
run_sql_block "healthcare_staff" "$sql_staff"


# Testing as healthcare_user

sql_user="
-- Testing Views (attempt all, even those expected to fail)
SELECT * FROM healthcare.vw_patient_appointments LIMIT 5;
SELECT * FROM healthcare.vw_staff_roles LIMIT 5;
SELECT * FROM healthcare.vw_billing_details LIMIT 5;
SELECT * FROM healthcare.vw_telehealth_sessions LIMIT 5;
SELECT * FROM healthcare.vw_remote_devices LIMIT 5;
SELECT * FROM healthcare.vw_device_readings LIMIT 5;

-- Testing Functions (attempt all, even those expected to fail)
SELECT healthcare.book_appointment(1, 1, '2025-02-10 11:00:00');
SELECT healthcare.add_medical_record(2, 1, 'Diabetes', 'Diet control');
SELECT healthcare.generate_billing(1, 270.00);
SELECT healthcare.schedule_telehealth_session(1, '2025-02-05 19:00:00', '2025-02-05 20:00:00');
SELECT healthcare.add_device_reading(1, 'Heart Rate', '85 bpm');
SELECT healthcare.register_patient('Mark', 'Johnson', '2000-10-15', 'mark.user@example.com', '5558887777', '789 Pine St');
"
run_sql_block "healthcare_user" "$sql_user"

echo "All tests completed. Please check ${LOGFILE} for details!" | tee -a "$LOGFILE"

