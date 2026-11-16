-- 1) Процедура, которая полностью очищает БД от исключенных студентов и выводит количество таковых.
-- Если после такой очистки осталась пустая группа, то она также удаляется из БД. Если после такой очистки 
-- комната стала пустовать, то она автоматически переводится в режим "Нежилая" (это уже происходит с помощью триггера)

drop procedure if exists campus.remove_excluded_students;
create or replace procedure campus.remove_excluded_students()
language plpgsql
as $$
declare
	rec record;
 	counter int = 0;
	group_counter int = 0;
begin
	delete from campus.students
	where student_id in (
		select distinct student_id from campus.violations
		where fine = 'Исключение'
	);
	get diagnostics counter = row_count;

	if counter > 0 then
		raise notice 'Число удаленных из базы студентов составило: % шт.', counter;
	else
		raise notice 'Не обнаружено студентов со статусом "Исключен"';
	end if;
	
	for rec in select group_number from campus.groups g where not exists 
		(select 1 from campus.students s where s.group_number = g.group_number) loop
		delete from campus.groups where group_number = rec.group_number; 
		group_counter = group_counter + 1;
	end loop;

	if group_counter > 0 then
		raise notice 'Вследствие исключения было расформировано % групп', group_counter;
	end if;
end;
$$;

-- 2) Процедура, принимающая ФИО студента, его почту и номер телефона, номер общежития, номер комнаты,
-- в которую его заселяют, а также номер группы, к которой он относится, и этот студент добавляется в БД.
-- Предварительно делается проверка, что комната и группа не будут переполнены после добавления нового студента.
-- Группу считаем переполненной, если в ней хотя бы 20 человек.
-- Предварительно делает проверку существования вводимой комнаты и вводимой группы

drop procedure if exists campus.add_student;
create or replace procedure campus.add_student(
	p_full_name varchar(50),
	p_email varchar(50),
	p_phone_number varchar(20),
	p_dormitory_id smallint,
	p_room_number smallint,
	p_group_number varchar(10)
)
language plpgsql
as $$
declare
	cap int;
 	cur_number int;
	stud_group int;
	new_id int;
	exists_room int;
	exists_group int;
begin
	
	select count(*) into exists_room
	from campus.room_info ri
	where ri.room_number = p_room_number and ri.dormitory_id = p_dormitory_id;

	if exists_room = 0 then
		raise exception 'Такой комнаты нет в общежитии %', p_dormitory_id;
	end if;
	
	select count(*) into exists_group
	from campus.groups g
	where g.group_number = p_group_number;

	if exists_group = 0 then
		raise exception 'Такой группы не существует: %', p_group_number;
	end if;

	select capacity into cap from campus.room_info ri
	where ri.dormitory_id = p_dormitory_id and ri.room_number = p_room_number;
	
	select count(*) into cur_number from campus.accommodation a
	where a.dormitory_id = p_dormitory_id and a.room_number = p_room_number;
	
	if cur_number >= cap then
		raise exception 'Комната % в общежитии % заполнена.', p_room_number, p_dormitory_id;
	end if;

	select count(*) into stud_group
	from campus.students s  where s.group_number = p_group_number;

	if stud_group >= 20 then
		raise exception 'Эта группа заполнена.';
	end if;

	if exists (
		select 1 from campus.room_info
			where room_number = p_room_number
				and dormitory_id = p_dormitory_id
				and status = 'На ремонте'
				) then
		raise exception 'Cтудент не может быть заселен в комнату, которая находится в состоянии ремонта.';
	end if;
	
	insert into campus.students (full_name, email, phone_number, group_number) values
	(p_full_name, p_email, p_phone_number, p_group_number)
	returning student_id into new_id;

	insert into campus.accommodation (student_id, dormitory_id, room_number) values
	(new_id, p_dormitory_id, p_room_number);

	insert into campus.history_of_living (student_id, date_of_move, dormitory_moved_to, dormitory_moved_from, room_moved_to, room_moved_from) values
	(new_id, current_date, p_dormitory_id, null, p_room_number, null);
end;
$$;

-- 3) Функция, которая возвращает информацию о проценте загруженности общежития.
-- Поднимает ошибку, если переданное значение id не существует.

drop function if exists campus.dormitory_living_or_repair_load;
create or replace function campus.dormitory_living_or_repair_load(
	p_dormitory_id int
)
returns table(
	dormitory_id smallint,
	dormitory_name varchar(30),
	occupied_percentage numeric,
	free_percentage numeric
)
language plpgsql
returns null on null input
as $$
begin
	if not exists (select 1 from campus.dormitory d where d.dormitory_id = p_dormitory_id) then
		raise exception 'Такого общежития нет на кампусе МФТИ.';
	end if;

	return query
	select dv.dormitory_id,
		dv.name,
		round(((dv.num_inhabited + dv.num_on_repair)::numeric / dv.total_room_number) * 100, 1) as occupied_percantage,
		round((dv.num_uninhabited::numeric / dv.total_room_number) * 100, 1) as free_percentage
	from campus.room_types_number dv
	where dv.dormitory_id = p_dormitory_id;
end;
$$;