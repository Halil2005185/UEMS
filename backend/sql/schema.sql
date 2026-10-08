CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_users_role CHECK (
        role IN ('STUDENT', 'TEACHER', 'ADMIN')
    )
);

CREATE TABLE department (
    id SERIAL PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE student (
    user_id INT PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    student_number VARCHAR(20) NOT NULL UNIQUE,
    date_of_birth DATE NOT NULL,
    enrollment_date SMALLINT NOT NULL CHECK (
        enrollment_date >= 1900
        AND enrollment_date <= EXTRACT(
            YEAR
            FROM CURRENT_DATE
        )
    ),
    department_id INT NOT NULL REFERENCES department (id)
);

CREATE TABLE teacher (
    user_id INT PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    staff_number VARCHAR(20) NOT NULL UNIQUE,
    academic_title VARCHAR(30) NOT NULL,
    office VARCHAR(30),
    hire_date DATE NOT NULL DEFAULT CURRENT_DATE,
    department_id INT NOT NULL REFERENCES department (id)
);

CREATE TABLE admin (
    user_id INT PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    job_title VARCHAR(50) NOT NULL
);

CREATE TABLE semester (
    id SERIAL PRIMARY KEY,
    acadenic_year VARCHAR(9) NOT NULL,
    term VARCHAR(10) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_registration_open BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_semester UNIQUE (acadenic_year, term),
    CONSTRAINT ck_semester_term CHECK (
        term IN ('FALL', 'SPRING', 'SUMMER')
    ),
    CONSTRAINT ck_semester_dates CHECK (end_date > start_date)
);

CREATE TABLE course (
    id SERIAL PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    credits SMALLINT NOT NULL CHECK (credits BETWEEN 1 AND 10),
    description TEXT,
    department_id INT NOT NULL REFERENCES department (id)
);

CREATE TABLE course_offering (
    id SERIAL PRIMARY KEY,
    course_id INT NOT NULL REFERENCES course (id) ON DELETE CASCADE,
    semester_id INT NOT NULL REFERENCES semester (id) ON DELETE CASCADE,
    section_number SMALLINT NOT NULL DEFAULT 1 CHECK (section_number >= 1),
    capacity SMALLINT NOT NULL CHECK (capacity > 0),
    classroom VARCHAR(50) NOT NULL,
    CONSTRAINT uq_offering_section UNIQUE (
        course_id,
        semester_id,
        section_number
    )
);


CREATE TABLE teaching_assignment (
offering_id INT NOT NULL REFERENCES course_offering (id) ON DELETE CASCADE,
    teacher_id INT NOT NULL REFERENCES teacher (user_id) ON DELETE RESTRICT,
    teaching_role VARCHAR(20) NOT NULL DEFAULT 'INSTRUCTOR',

    PRIMARY KEY (offering_id, teacher_id),
    CONSTRAINT ck_teaching_role CHECK (
        teaching_role IN ('INSTRUCTOR', 'ASSISTANT')
    )

);



-- base data
INSERT INTO department (code, name) VALUES ('S', 'Computer Engineering');
INSERT INTO semester (acadenic_year, term, start_date, end_date)
VALUES ('2027-2028', 'FALL', '2026-09-14', '2027-01-22');
INSERT INTO course (code, name, credits, department_id) VALUES ('S', 'Database Systems', 6, 1);
INSERT INTO course_offering (course_id, semester_id, capacity, classroom) VALUES (3, 3, 25, 'B-1');

-- a teacher
INSERT INTO users (name, email, password_hash, role)
VALUES ('Ahmet Kaya', 'ahmet@uni.edu', 'x', 'TEACHER') RETURNING id;

SELECT * FROM semester;

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

select * from course_offering;

SELECT
    co.id,
    c.code AS course_code,
    c.name AS course_name,
    s.acadenic_year,
    s.term,
    co.section_number,
    co.capacity,
    co.classroom
FROM course_offering co
JOIN course c
    ON co.course_id = c.id
JOIN semester s
    ON co.semester_id = s.id;