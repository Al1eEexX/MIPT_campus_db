-- 1) Этот индекс ускоряет операции, связанные с соединением room_info с сущностью dormitory, а также
-- ускоряет проверку на равенство статуса комнаты, что полезно с учетом большого количества строк

create index idx_room_info_dormitory_id on campus.room_info (dormitory_id, status);

-- 2) Частичный индекс для поиска студентов, которые имеют в качестве меры наказания 'Выговор' или 'Исключение'

create index idx_violations_bad_types on campus.violations (student_id)
where fine in ('Выговор', 'Исключение');

-- 3) Индекс для поиска студентов по группе, скоряет join с campus.groups, а также
-- непосредственные проверки на равенство номеров групп

create index idx_students_group_number on campus.students (group_number);