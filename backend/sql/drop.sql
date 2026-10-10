-- Removes every table, view and function created by schema.sql.
-- WARNING: deletes all data. Used by `npm run db:reset`.

DROP VIEW IF EXISTS v_offering_roster, v_student_transcript, v_offering_seats;

DROP TABLE IF EXISTS
    exam_result,
    exam,
    enrollment,
    teaching_assignment,
    course_offering,
    course,
    semester,
    admin,
    teacher,
    student,
    department,
    users
CASCADE;

DROP FUNCTION IF EXISTS check_user_role(), check_exam_weight(), check_offering_capacity(), check_exam_result();
