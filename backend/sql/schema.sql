-- =====================================================================
-- UEMS - University Examination Management System (PostgreSQL)
-- Run the blocks in order, from top to bottom.
-- =====================================================================


-- =====================================================================
-- 0) DROP everything (tables, their triggers and the views)
-- =====================================================================
DROP TABLE IF EXISTS
    exam_result, exam, enrollment, teaching_assignment, course_offering,
    course, semester, admin, teacher, student, department, users
CASCADE;


-- =====================================================================
-- PART 1 - TABLES
-- =====================================================================

-- 1) Login table for everyone (EER superclass)
CREATE TABLE users (
    id             SERIAL PRIMARY KEY,
    name           VARCHAR(255) NOT NULL,
    email          VARCHAR(255) NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    role           VARCHAR(20)  NOT NULL,
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_users_role CHECK (role IN ('STUDENT', 'TEACHER', 'ADMIN'))
);

-- 2) Departments
CREATE TABLE department (
    id    SERIAL PRIMARY KEY,
    code  VARCHAR(10)  NOT NULL UNIQUE,
    name  VARCHAR(100) NOT NULL UNIQUE
);

-- 3) Student (EER subclass, 1:1 with users)
CREATE TABLE student (
    user_id          INT         PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    student_number   VARCHAR(20) NOT NULL UNIQUE,
    date_of_birth    DATE        NOT NULL,
    enrollment_year  SMALLINT    NOT NULL CHECK (enrollment_year >= 1950),
    department_id    INT         NOT NULL REFERENCES department (id)
);

-- 4) Teacher (EER subclass, 1:1 with users)
CREATE TABLE teacher (
    user_id         INT         PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    staff_number    VARCHAR(20) NOT NULL UNIQUE,
    academic_title  VARCHAR(30) NOT NULL,
    office          VARCHAR(30),
    hire_date       DATE        NOT NULL DEFAULT CURRENT_DATE,
    department_id   INT         NOT NULL REFERENCES department (id)
);

-- 5) Admin (EER subclass, 1:1 with users)
CREATE TABLE admin (
    user_id    INT         PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    job_title  VARCHAR(50) NOT NULL
);

-- 6) Semesters
CREATE TABLE semester (
    id                    SERIAL PRIMARY KEY,
    academic_year         VARCHAR(9)  NOT NULL,          -- e.g. 2026-2027
    term                  VARCHAR(10) NOT NULL,          -- FALL / SPRING / SUMMER
    start_date            DATE        NOT NULL,
    end_date              DATE        NOT NULL,
    is_registration_open  BOOLEAN     NOT NULL DEFAULT FALSE,

    CONSTRAINT uq_semester       UNIQUE (academic_year, term),
    CONSTRAINT ck_semester_term  CHECK (term IN ('FALL', 'SPRING', 'SUMMER')),
    CONSTRAINT ck_semester_dates CHECK (end_date > start_date)
);

-- 7) Courses (catalog)
CREATE TABLE course (
    id             SERIAL PRIMARY KEY,
    code           VARCHAR(10)  NOT NULL UNIQUE,         -- e.g. CSE301
    name           VARCHAR(100) NOT NULL,
    credits        SMALLINT     NOT NULL CHECK (credits BETWEEN 1 AND 10),
    description    TEXT,
    department_id  INT          NOT NULL REFERENCES department (id)
);

-- 8) Course offering = a course taught in one semester
CREATE TABLE course_offering (
    id              SERIAL PRIMARY KEY,
    course_id       INT         NOT NULL REFERENCES course (id)   ON DELETE RESTRICT,
    semester_id     INT         NOT NULL REFERENCES semester (id) ON DELETE RESTRICT,
    section_number  SMALLINT    NOT NULL DEFAULT 1 CHECK (section_number >= 1),
    capacity        SMALLINT    NOT NULL CHECK (capacity > 0),
    classroom       VARCHAR(50),

    CONSTRAINT uq_offering_section UNIQUE (course_id, semester_id, section_number)
);

-- 9) Who teaches which offering (M:N)
CREATE TABLE teaching_assignment (
    offering_id    INT         NOT NULL REFERENCES course_offering (id) ON DELETE CASCADE,
    teacher_id     INT         NOT NULL REFERENCES teacher (user_id)    ON DELETE RESTRICT,
    teaching_role  VARCHAR(20) NOT NULL DEFAULT 'INSTRUCTOR',

    PRIMARY KEY (offering_id, teacher_id),
    CONSTRAINT ck_teaching_role CHECK (teaching_role IN ('INSTRUCTOR', 'ASSISTANT'))
);

-- 10) Which student is in which offering (M:N)
CREATE TABLE enrollment (
    id               SERIAL PRIMARY KEY,
    student_id       INT         NOT NULL REFERENCES student (user_id)    ON DELETE RESTRICT,
    offering_id      INT         NOT NULL REFERENCES course_offering (id) ON DELETE RESTRICT,
    enrollment_date  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status           VARCHAR(10) NOT NULL DEFAULT 'ENROLLED',

    CONSTRAINT uq_enrollment        UNIQUE (student_id, offering_id),
    CONSTRAINT ck_enrollment_status CHECK (status IN ('ENROLLED', 'DROPPED', 'COMPLETED'))
);

-- 11) Exams of an offering
CREATE TABLE exam (
    id                 SERIAL PRIMARY KEY,
    offering_id        INT          NOT NULL REFERENCES course_offering (id) ON DELETE RESTRICT,
    exam_type          VARCHAR(10)  NOT NULL,
    title              VARCHAR(100) NOT NULL,
    exam_date          DATE         NOT NULL,
    start_time         TIME         NOT NULL,
    duration_minutes   SMALLINT     NOT NULL,
    exam_room          VARCHAR(30),
    max_score          NUMERIC(5,2) NOT NULL DEFAULT 100,
    weight_percent     NUMERIC(5,2) NOT NULL,
    results_published  BOOLEAN      NOT NULL DEFAULT FALSE,
    created_by         INT          NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
    created_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_exam_type     CHECK (exam_type IN ('QUIZ', 'MIDTERM', 'FINAL', 'MAKEUP', 'PROJECT')),
    CONSTRAINT ck_exam_duration CHECK (duration_minutes BETWEEN 1 AND 480),
    CONSTRAINT ck_exam_max      CHECK (max_score > 0),
    CONSTRAINT ck_exam_weight   CHECK (weight_percent BETWEEN 0 AND 100)
);

-- 12) Score of one enrolled student in one exam (M:N)
CREATE TABLE exam_result (
    id             SERIAL PRIMARY KEY,
    exam_id        INT          NOT NULL REFERENCES exam (id)       ON DELETE CASCADE,
    enrollment_id  INT          NOT NULL REFERENCES enrollment (id) ON DELETE CASCADE,
    score          NUMERIC(5,2),
    is_absent      BOOLEAN      NOT NULL DEFAULT FALSE,
    entered_by     INT          NOT NULL REFERENCES users (id)      ON DELETE RESTRICT,
    entered_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_exam_result   UNIQUE (exam_id, enrollment_id),
    CONSTRAINT ck_result_score  CHECK (score IS NULL OR score >= 0),
    CONSTRAINT ck_result_absent CHECK (
        (is_absent = TRUE  AND score IS NULL) OR
        (is_absent = FALSE AND score IS NOT NULL)
    )
);


-- =====================================================================
-- PART 2 - TRIGGERS  (rules that need data from other rows or tables)
-- =====================================================================

-- Trigger 1: student/teacher/admin row must match the user's role
CREATE OR REPLACE FUNCTION check_user_role()
RETURNS TRIGGER AS $$
DECLARE
    expected_role VARCHAR(20);
    actual_role   VARCHAR(20);
BEGIN
    -- table name 'student' -> role 'STUDENT'
    expected_role := UPPER(TG_TABLE_NAME);

    SELECT role INTO actual_role
    FROM users
    WHERE id = NEW.user_id;

    IF actual_role IS DISTINCT FROM expected_role THEN
        RAISE EXCEPTION 'User % has role %, so it cannot be added to the % table',
                        NEW.user_id, actual_role, TG_TABLE_NAME;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_student_role BEFORE INSERT OR UPDATE ON student
FOR EACH ROW EXECUTE FUNCTION check_user_role();

CREATE TRIGGER trg_teacher_role BEFORE INSERT OR UPDATE ON teacher
FOR EACH ROW EXECUTE FUNCTION check_user_role();

CREATE TRIGGER trg_admin_role BEFORE INSERT OR UPDATE ON admin
FOR EACH ROW EXECUTE FUNCTION check_user_role();


-- Trigger 2: no enrollment beyond the offering's capacity
CREATE OR REPLACE FUNCTION check_offering_capacity()
RETURNS TRIGGER AS $$
DECLARE
    seats    INT;
    enrolled INT;
BEGIN
    -- leaving a course never needs a seat
    IF NEW.status <> 'ENROLLED' THEN
        RETURN NEW;
    END IF;

    -- already enrolled in the same course: nothing changes
    IF TG_OP = 'UPDATE' AND OLD.status = 'ENROLLED'
       AND OLD.offering_id = NEW.offering_id THEN
        RETURN NEW;
    END IF;

    SELECT capacity INTO seats
    FROM course_offering
    WHERE id = NEW.offering_id;

    SELECT COUNT(*) INTO enrolled
    FROM enrollment
    WHERE offering_id = NEW.offering_id
      AND status = 'ENROLLED'
      AND id <> NEW.id;

    IF enrolled >= seats THEN
        RAISE EXCEPTION 'This course is full (% of % seats taken)', enrolled, seats;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_offering_capacity BEFORE INSERT OR UPDATE ON enrollment
FOR EACH ROW EXECUTE FUNCTION check_offering_capacity();


-- Trigger 3: exams of one offering may not add up to more than 100%
CREATE OR REPLACE FUNCTION check_exam_weight()
RETURNS TRIGGER AS $$
DECLARE
    total NUMERIC;
BEGIN
    -- sum of the OTHER exams of the same offering
    SELECT COALESCE(SUM(weight_percent), 0)
    INTO total
    FROM exam
    WHERE offering_id = NEW.offering_id
      AND id <> NEW.id;

    IF total + NEW.weight_percent > 100 THEN
        RAISE EXCEPTION 'Total exam weight would be %, the maximum is 100',
                        total + NEW.weight_percent;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_exam_weight BEFORE INSERT OR UPDATE ON exam
FOR EACH ROW EXECUTE FUNCTION check_exam_weight();


-- Trigger 4: (1) score <= exam max score
--            (2) student must be enrolled in the exam's own offering
CREATE OR REPLACE FUNCTION check_exam_result()
RETURNS TRIGGER AS $$
DECLARE
    exam_offering    INT;
    exam_max         NUMERIC;
    student_offering INT;
BEGIN
    SELECT offering_id, max_score
    INTO exam_offering, exam_max
    FROM exam
    WHERE id = NEW.exam_id;

    SELECT offering_id
    INTO student_offering
    FROM enrollment
    WHERE id = NEW.enrollment_id;

    IF exam_offering <> student_offering THEN
        RAISE EXCEPTION 'This student is not enrolled in the course of this exam';
    END IF;

    IF NEW.score > exam_max THEN
        RAISE EXCEPTION 'Score % is higher than the maximum (%)', NEW.score, exam_max;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_exam_result BEFORE INSERT OR UPDATE ON exam_result
FOR EACH ROW EXECUTE FUNCTION check_exam_result();


-- =====================================================================
-- PART 3 - VIEWS  (calculated data: computed, never stored -> 3NF)
-- =====================================================================

-- View 1: seats per offering
CREATE OR REPLACE VIEW v_offering_seats AS
SELECT
    o.id                      AS offering_id,
    o.semester_id,
    c.code                    AS course_code,
    c.name                    AS course_name,
    c.credits,
    o.section_number,
    o.classroom,
    o.capacity,
    COUNT(e.id)               AS enrolled_count,
    o.capacity - COUNT(e.id)  AS seats_left
FROM course_offering o
JOIN course c
     ON c.id = o.course_id
LEFT JOIN enrollment e
     ON e.offering_id = o.id
    AND e.status = 'ENROLLED'
GROUP BY o.id, c.id;

-- View 2: weighted points per student per course (published exams only)
CREATE OR REPLACE VIEW v_student_transcript AS
SELECT
    e.student_id,
    e.offering_id,
    c.code  AS course_code,
    c.name  AS course_name,
    COALESCE(SUM(x.weight_percent), 0)                                    AS published_weight,
    ROUND(COALESCE(SUM(r.score / x.max_score * x.weight_percent), 0), 2)  AS weighted_points
FROM enrollment e
JOIN course_offering o
     ON o.id = e.offering_id
JOIN course c
     ON c.id = o.course_id
LEFT JOIN exam x
     ON x.offering_id = e.offering_id
    AND x.results_published = TRUE
LEFT JOIN exam_result r
     ON r.exam_id = x.id
    AND r.enrollment_id = e.id
WHERE e.status = 'ENROLLED'
GROUP BY e.student_id, e.offering_id, c.code, c.name;

-- View 3: class list (enrolled students of every offering)
CREATE OR REPLACE VIEW v_offering_roster AS
SELECT
    e.offering_id,
    e.id               AS enrollment_id,
    s.user_id          AS student_id,
    s.student_number,
    u.name,
    d.code             AS department_code,
    s.enrollment_year,
    e.enrollment_date  AS enrolled_on
FROM enrollment e
JOIN student s    ON s.user_id = e.student_id
JOIN users u      ON u.id = s.user_id
JOIN department d ON d.id = s.department_id
WHERE e.status = 'ENROLLED';