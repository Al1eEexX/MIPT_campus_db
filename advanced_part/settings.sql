UPDATE campus.room_info
SET status = 'Нежилая'
WHERE status = 'Заселена'
  AND NOT EXISTS (SELECT 1 FROM campus.accommodation
                  WHERE dormitory_id = room_info.dormitory_id
                    AND room_number = room_info.room_number);

SELECT setval('campus.students_student_id_seq', (SELECT COALESCE(MAX(student_id), 0) FROM campus.students));