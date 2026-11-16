-- 1) Вывести идентификаторы и имена студентов, которые на данный
-- момент времени находятся внутри какого-либо общежития (также вывести
-- название общежития)

SELECT ee.student_id, s.full_name, d.name as dormitory_name
FROM 
	(SELECT e.student_id, e.dormitory_id
	FROM campus.entry_exit_time e 
	WHERE e.last_exit_time IS NULL) ee
INNER JOIN campus.students s USING (student_id)
INNER JOIN campus.dormitory d USING (dormitory_id);


-- 2) Вывести для каждого студента историю проживания по общежитиям и комнатам
-- в формате: dormitory_1, room_1 -> ... -> dormitory_n, room_n

WITH RECURSIVE moves AS (
	SELECT 
		student_id,
		date_of_move,
		(dormitory_moved_to::text || ', ' || room_moved_to::text) AS living_path
		   
	FROM campus.history_of_living h
	WHERE date_of_move = (
		SELECT min(date_of_move)
		FROM campus.history_of_living hh
		WHERE h.student_id = hh.student_id
			AND hh.dormitory_moved_to IS NOT NULL
	)

	UNION ALL
	
	SELECT
		hol.student_id,
		hol.date_of_move,
		m.living_path || ' -> ' || (hol.dormitory_moved_to::text || ', ' || hol.room_moved_to::text)

	FROM campus.history_of_living hol
	INNER JOIN moves m ON hol.student_id = m.student_id
					AND hol.dormitory_moved_to IS NOT NULL
					AND hol.date_of_move > m.date_of_move
					AND NOT EXISTS (
					SELECT 1 
					FROM campus.history_of_living mid_h
					WHERE mid_h.student_id = m.student_id
						AND mid_h.dormitory_moved_to IS NOT NULL
						AND mid_h.date_of_move > m.date_of_move
						AND mid_h.date_of_move < hol.date_of_move
					)
)

SELECT student_id, living_path
FROM moves m
WHERE date_of_move = (
	SELECT max(date_of_move)
	FROM moves mm
	WHERE m.student_id = mm.student_id
)
ORDER BY student_id;


-- 3) Для каждого общежития вывести количество вахтёров

SELECT d.dormitory_id, d.name, count(si.staff_id) AS staff_number
FROM campus.dormitory d
LEFT JOIN campus.dormitory_staff ds USING (dormitory_id)
LEFT JOIN campus.staff_info si ON si.staff_id = ds.staff_id AND si.post = 'вахтёр'
GROUP BY d.dormitory_id, d.name
ORDER BY dormitory_id;


-- 4) Вывести группы, в которых есть хотя бы один человек, у которого есть хотя бы одно нарушение, а также количество таких студентов

SELECT g.group_number, count(vi.student_id) AS violators_number
FROM campus.groups g
INNER JOIN campus.students s USING (group_number)
INNER JOIN (
	SELECT v.student_id
	FROM campus.violations v
	GROUP BY v.student_id
	HAVING count(*) > 0
) vi USING (student_id)
GROUP BY g.group_number
ORDER BY g.group_number;


-- 5) Вывести людей из таблицы Relatives, у которых на Физтехе учится хотя бы 2 родственника (вместе с количеством
-- этих родственников)

SELECT r.relative_id, r.full_name, count(*) AS students_number
FROM campus.relatives r
INNER JOIN campus.family f USING (relative_id)
INNER JOIN campus.students s USING (student_id)
GROUP BY r.relative_id
HAVING count(*) > 1
ORDER BY r.relative_id;


-- 6) Для каждого общежития вывести количество комнат каждого статуса (заселена, нежилая, на ремонте)

SELECT 
	d.dormitory_id,
  	d.name,
  	COALESCE(inh.num_inhabited, 0) AS num_inhabited,
  	COALESCE(uninh.num_uninhabited, 0) AS num_uninhabited,
  	COALESCE(rep.num_on_repair, 0) AS num_on_repair
FROM campus.dormitory d
LEFT JOIN (
	SELECT dormitory_id, count(*) AS num_inhabited
	FROM campus.room_info
	WHERE status = 'Заселена'
	GROUP BY dormitory_id
	) inh USING (dormitory_id)
LEFT JOIN (
	SELECT dormitory_id, count(*) AS num_uninhabited
	FROM campus.room_info
	WHERE status = 'Нежилая'
	GROUP BY dormitory_id
	) uninh USING (dormitory_id)
LEFT JOIN (
	SELECT dormitory_id, count(*) AS num_on_repair
	FROM campus.room_info
	WHERE status = 'На ремонте'
	GROUP BY dormitory_id
) rep USING (dormitory_id)
ORDER BY d.dormitory_id;

	
-- 7) Вывести пары (номер общежития + номер комнаты), в которых есть пара студентов из разных групп

SELECT dormitory_id, room_number
FROM (
	SELECT a.dormitory_id, a.room_number, count(DISTINCT s.group_number) AS groups_number
	FROM campus.accommodation a
	INNER JOIN campus.students s USING (student_id)
	GROUP BY a.dormitory_id, a.room_number
	) cnt
WHERE cnt.groups_number > 1
ORDER BY dormitory_id, room_number;


-- 8) Вывести для каждого общежития количство заполненных мест и количество свободных мест

SELECT 
	d.dormitory_id,
	d.name,
	count(a.student_id) AS occupied_places,
	d.capacity - count(a.student_id) AS free_places
FROM campus.dormitory d
LEFT JOIN campus.accommodation a USING (dormitory_id)
GROUP BY d.dormitory_id, d.name
ORDER BY d.dormitory_id;


-- 9) Вывести для каждой ФШ количество студентов на каждом из курсов бакалавриата

SELECT g.phystech_school, g.course_number, count(s.student_id) AS students_number
FROM campus.groups g
LEFT JOIN campus.students s USING (group_number)
WHERE g.group_number LIKE 'Б%'
GROUP BY g.phystech_school, g.course_number
ORDER BY g.phystech_school, g.course_number;
	

-- 10) Вывести номера студентов, которые больше 3-х дней не появлялись в общежитиях
-- (в качестве дня отсчета возьмем самое позднее значение атрибута last_exit_time)

WITH each_last_exit AS (
	SELECT student_id, max(last_exit_time) AS max_exit_time
	FROM campus.entry_exit_time
	WHERE student_id NOT IN (
		SELECT student_id FROM campus.entry_exit_time
		WHERE last_exit_time IS NULL
		)
	GROUP BY student_id
),
last_exit_moment AS (
	SELECT max(last_exit_time) AS current_point
	FROM campus.entry_exit_time
)

SELECT ele.student_id, s.full_name
FROM each_last_exit ele
CROSS JOIN last_exit_moment lem
INNER JOIN campus.students s USING (student_id)
WHERE (lem.current_point::date - ele.max_exit_time::date) > 3
ORDER BY ele.student_id;

