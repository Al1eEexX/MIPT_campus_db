-- 1) Представление, предоставляющее информацию о том, кто в данный момент находится внутри 
-- какого-либо общежития, а также время, в течение которого студент в нем находится.

drop view if exists campus.students_inside_dormitories;

create view campus.students_inside_dormitories as
with detect_incorrect_rows as (
	select
		e.student_id,
		e.dormitory_id,
		e.last_entry_time,
		row_number() over (
			partition by e.student_id
			order by e.last_entry_time desc
		) as rn
	from campus.entry_exit_time e
	where e.last_exit_time is null
)
select 
	dir.student_id,
	s.full_name,
	d.name as dormitory_name,
	(date_trunc('minute', current_timestamp - dir.last_entry_time)) as duration
from detect_incorrect_rows dir
inner join campus.students s using (student_id)
inner join campus.dormitory d using (dormitory_id)
where dir.rn = 1;

-- 2) Материализованное представление, содержащее информацию о количестве комнат каждого типа
-- (жилая, нежилая, на ремонте) для каждого общежития. Refresh можно производить, например,
-- с частотой раз в месяц при большом числе комнат на ремонте, иначе - раз в семестр.

drop materialized view if exists campus.room_types_number;

create materialized view campus.room_types_number as
select
	d.dormitory_id,
  	d.name,
  	coalesce(inh.num_inhabited, 0) as num_inhabited,
  	coalesce(uninh.num_uninhabited, 0) as num_uninhabited,
  	coalesce(rep.num_on_repair, 0) as num_on_repair,
  	coalesce(inh.num_inhabited, 0) + coalesce(uninh.num_uninhabited, 0) + coalesce(rep.num_on_repair, 0) as total_room_number
from campus.dormitory d
left join (
	select dormitory_id, count(*) as num_inhabited
	from campus.room_info
	where status = 'Заселена'
	group by dormitory_id
	) inh using (dormitory_id)
left join (
	select dormitory_id, count(*) as num_uninhabited
	from campus.room_info
	where status = 'Нежилая'
	group by dormitory_id
	) uninh using (dormitory_id)
left join (
	select dormitory_id, count(*) as num_on_repair
	from campus.room_info
	where status = 'На ремонте'
	group by dormitory_id
) rep using (dormitory_id);